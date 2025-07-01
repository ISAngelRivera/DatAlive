#!/bin/sh
# setup-n8n.sh - v4.0 Auto-configuración completa de N8N
# Actualizado para versiones modernas de N8N

set -e

# -- Variables --
N8N_URL="http://n8n:5678"
API_URL="${N8N_URL}/api/v1"
REST_URL="${N8N_URL}/rest"
COOKIE_FILE="/tmp/n8n_session_cookie.txt"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [n8n-setup] $1"
}

# -- Funciones de Utilidad --

wait_for_n8n() {
    log "Esperando a que la API de n8n en ${N8N_URL} esté disponible..."
    timeout 120 sh -c '
        while ! curl -s -f "$0/healthz" > /dev/null; do
            echo "[$(date +"%Y-%m-%d %H:%M:%S")] [n8n-setup] n8n no está listo, reintentando en 3 segundos..."
            sleep 3
        done
    ' "${N8N_URL}"
    log "✓ n8n está listo y saludable."
}

# -- Funciones de Setup --

register_owner() {
    log "Verificando si el registro del propietario es necesario..."
    
    # Probar acceso a la API sin autenticación
    response=$(curl -s -o /dev/null -w "%{http_code}" "${REST_URL}/settings")
    
    if [ "$response" -eq 401 ]; then
        log "Se requiere autenticación. Posiblemente el owner ya está configurado."
        return 0
    fi
    
    # Si podemos acceder sin auth, intentar el registro
    log "No se requiere autenticación. Procediendo con el registro del owner..."
    
    # Intentar el endpoint moderno de owner setup
    json_payload=$(cat <<EOF
{
    "email": "${N8N_USER_EMAIL}",
    "firstName": "${N8N_USER_FIRSTNAME}",
    "lastName": "${N8N_USER_LASTNAME}",
    "password": "${N8N_USER_PASSWORD}"
}
EOF
)
    
    # Probar primero el endpoint REST
    response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "$json_payload" \
        "${REST_URL}/owner/setup" 2>&1)
    
    if echo "$response" | grep -q "error\|Error\|Cannot"; then
        log "El endpoint /rest/owner/setup no existe, probando /rest/users..."
        
        # Intentar crear usuario directamente
        response=$(curl -s -X POST \
            -H "Content-Type: application/json" \
            -d "$json_payload" \
            "${REST_URL}/users" 2>&1)
    fi
    
    if echo "$response" | grep -q "${N8N_USER_EMAIL}"; then
        log "✓ Propietario registrado con éxito: ${N8N_USER_EMAIL}"
        return 0
    else
        log "ADVERTENCIA: No se pudo registrar el propietario. Puede que ya esté configurado."
        log "Respuesta: $response"
        return 0  # Continuar de todos modos
    fi
}

login_and_get_cookie() {
    log "Autenticando con n8n para obtener cookie de sesión..."
    
    # Limpiar cookie anterior si existe
    rm -f "$COOKIE_FILE"
    
    # Login para obtener cookie - probar diferentes formatos
    response=$(curl -s -c "$COOKIE_FILE" -X POST \
        -H "Content-Type: application/json" \
        -d "{\"email\":\"${N8N_USER_EMAIL}\",\"password\":\"${N8N_USER_PASSWORD}\"}" \
        "${REST_URL}/login" 2>&1)
    
    # Si falla, intentar con el nuevo formato
    if ! [ -f "$COOKIE_FILE" ] || ! grep -q "n8n-auth" "$COOKIE_FILE" 2>/dev/null; then
        log "Intentando formato de login alternativo..."
        response=$(curl -s -c "$COOKIE_FILE" -X POST \
            -H "Content-Type: application/json" \
            -d "{\"emailOrLdapLoginId\":\"${N8N_USER_EMAIL}\",\"password\":\"${N8N_USER_PASSWORD}\"}" \
            "${REST_URL}/login" 2>&1)
    fi
    
    if [ -f "$COOKIE_FILE" ] && grep -q "n8n-auth" "$COOKIE_FILE" 2>/dev/null; then
        log "✓ Autenticación exitosa. Cookie de sesión obtenida."
        return 0
    else
        log "ERROR: No se pudo autenticar con n8n"
        echo "$response"
        return 1
    fi
}

complete_onboarding() {
    log "Completando el wizard de onboarding..."
    
    # Obtener el estado actual del usuario
    user_info=$(curl -s -b "$COOKIE_FILE" "${REST_URL}/me")
    
    # Verificar si necesita completar el onboarding
    if echo "$user_info" | grep -q "personalizationAnswers"; then
        log "El onboarding ya parece estar completado."
        return 0
    fi
    
    # Paso 1: Responder las preguntas de personalización
    log "  → Enviando respuestas de personalización..."
    personalization_data=$(cat <<EOF
{
    "version": "v4",
    "personalization_survey_submitted_at": "$(date -u +%Y-%m-%dT%H:%M:%S.000Z)",
    "personalization_survey_n8n_version": "1.99.0",
    "company_size": "20+",
    "work_area": "IT",
    "company_industry": "Technology",
    "automation_goal": "improve_efficiency",
    "coding_skill": "advanced",
    "other_automation_tools": [],
    "marketing_consent": false
}
EOF
)
    
    response=$(curl -s -b "$COOKIE_FILE" -X POST \
        -H "Content-Type: application/json" \
        -d "$personalization_data" \
        "${REST_URL}/me/survey")
    
    if echo "$response" | grep -q "success\|true"; then
        log "    ✓ Respuestas de personalización enviadas"
    else
        log "    ⚠ No se pudieron enviar las respuestas de personalización"
    fi
    
    # Paso 2: Marcar el onboarding como completado
    log "  → Marcando onboarding como completado..."
    settings_data=$(cat <<EOF
{
    "userActivated": true,
    "firstSuccessfulWorkflowId": "",
    "userActivatedAt": "$(date -u +%Y-%m-%dT%H:%M:%S.000Z)"
}
EOF
)
    
    response=$(curl -s -b "$COOKIE_FILE" -X PATCH \
        -H "Content-Type: application/json" \
        -d "$settings_data" \
        "${REST_URL}/me/settings")
    
    if [ $? -eq 0 ]; then
        log "    ✓ Onboarding marcado como completado"
    else
        log "    ⚠ No se pudo marcar el onboarding como completado"
    fi
    
    log "✓ Proceso de onboarding completado"
    
    # Dar un momento para que se procesen los cambios
    sleep 2
}

activate_license() {
    if [ -z "${N8N_LICENSE_KEY}" ]; then
        log "No se encontró N8N_LICENSE_KEY. Omitiendo activación de licencia."
        return 0
    fi
    
    log "Activando licencia de n8n..."
    
    response=$(curl -s -b "$COOKIE_FILE" -X POST \
        -H "Content-Type: application/json" \
        -d "{\"activationKey\":\"${N8N_LICENSE_KEY}\"}" \
        "${REST_URL}/license/activate")
    
    if echo "$response" | grep -q "success\|activated"; then
        log "✓ Licencia activada correctamente."
        return 0
    else
        log "ADVERTENCIA: No se pudo activar la licencia. Puede que ya esté activa."
        return 0
    fi
}

create_credentials() {
    log "Creando credenciales automáticamente..."
    
    # Función auxiliar para crear una credencial
    create_credential() {
        local name="$1"
        local type="$2"
        local data="$3"
        
        log "  → Creando credencial: $name"
        
        response=$(curl -s -b "$COOKIE_FILE" -X POST \
            -H "Content-Type: application/json" \
            -d "{\"name\":\"$name\",\"type\":\"$type\",\"data\":$data}" \
            "${REST_URL}/credentials")
        
        if echo "$response" | grep -q "\"id\""; then
            log "    ✓ Credencial '$name' creada exitosamente"
            return 0
        else
            log "    ⚠ Error creando credencial '$name'"
            echo "    Respuesta: $response"
            return 1
        fi
    }
    
    # 1. PostgreSQL
    create_credential "DataLive PostgreSQL" "postgres" '{
        "host": "postgres",
        "port": 5432,
        "database": "'"${POSTGRES_DB}"'",
        "user": "'"${POSTGRES_USER}"'",
        "password": "'"${POSTGRES_PASSWORD}"'",
        "ssl": "disable"
    }'
    
    # 2. MinIO (S3)
    create_credential "DataLive MinIO" "s3" '{
        "endpoint": "http://minio:9000",
        "accessKeyId": "'"${MINIO_ROOT_USER}"'",
        "secretAccessKey": "'"${MINIO_ROOT_PASSWORD}"'",
        "region": "us-east-1",
        "forcePathStyle": true
    }'
    
    # 3. Ollama API
    create_credential "DataLive Ollama" "ollamaApi" '{
        "baseUrl": "http://ollama:11434"
    }'
    
    # 4. Qdrant API - Con URL correcta en data
    create_credential "DataLive Qdrant" "qdrantApi" '{
        "url": "http://qdrant:6333",
        "apiKey": ""
    }'
    
    # 5. Neo4j
    create_credential "DataLive Neo4j" "neo4jApi" '{
        "host": "neo4j",
        "port": 7687,
        "protocol": "bolt",
        "username": "neo4j",
        "password": "'"${NEO4J_AUTH#neo4j/}"'",
        "database": "neo4j"
    }'
    
    # 6. DataLive Agent (HTTP Request para API custom)
    create_credential "DataLive Agent" "httpRequestAuth" '{
        "authentication": "noAuth"
    }'
    
    # 7. Google Drive OAuth2
    if [ -n "${GOOGLE_CLIENT_ID}" ] && [ -n "${GOOGLE_CLIENT_SECRET}" ]; then
        log "  → Creando credencial: DataLive Google Drive"
        create_credential "DataLive Google Drive" "googleDriveOAuth2Api" '{
            "clientId": "'"${GOOGLE_CLIENT_ID}"'",
            "clientSecret": "'"${GOOGLE_CLIENT_SECRET}"'",
            "scopes": [
                "https://www.googleapis.com/auth/drive.readonly",
                "https://www.googleapis.com/auth/drive.metadata.readonly"
            ],
            "authUrl": "https://accounts.google.com/o/oauth2/v2/auth",
            "accessTokenUrl": "https://oauth2.googleapis.com/token",
            "authQueryParameters": "",
            "authentication": "oAuth2",
            "grantType": "authorizationCode",
            "oauthTokenData": {}
        }'
    else
        log "  ⚠ Saltando Google Drive - CLIENT_ID/SECRET no configurados"
    fi
    
    log "✓ Proceso de creación de credenciales completado"
}

import_workflows() {
    log "Importando workflows desde el directorio montado..."
    
    # Verificar si hay workflows para importar
    if [ ! -d "/workflows" ]; then
        log "⚠ No se encontró directorio de workflows. Omitiendo importación."
        return 0
    fi
    
    # Listar directorios y archivos disponibles
    log "Estructura de workflows disponible:"
    ls -la "/workflows/" 2>/dev/null | while read line; do
        log "  $line"
    done
    
    workflow_count=0
    
    # Buscar archivos JSON de workflows
    for category_dir in /workflows/*/; do
        if [ -d "$category_dir" ]; then
            log "Explorando directorio: $category_dir"
            for workflow_file in "$category_dir"*.json; do
                if [ -f "$workflow_file" ]; then
                    workflow_name=$(basename "$workflow_file" .json)
                    log "  → Importando workflow: $workflow_name"
                    
                    # Validar JSON antes de enviar
                    if ! jq empty "$workflow_file" 2>/dev/null; then
                        log "    ⚠ JSON inválido en $workflow_file"
                        continue
                    fi
                    
                    response=$(curl -s -b "$COOKIE_FILE" -X POST \
                        -H "Content-Type: application/json" \
                        -d "@$workflow_file" \
                        "${REST_URL}/workflows")
                    
                    if echo "$response" | grep -q "\"id\""; then
                        log "    ✓ Workflow importado exitosamente"
                        workflow_count=$((workflow_count + 1))
                    else
                        log "    ⚠ Error importando workflow: $workflow_name"
                        log "    Respuesta: $response"
                    fi
                fi
            done
        fi
    done
    
    log "✓ Importación completada. Total de workflows importados: $workflow_count"
}

# --- Flujo de Ejecución Principal ---
log "Iniciando configuración automática de n8n..."

wait_for_n8n
register_owner

# Dar tiempo a N8N para procesar el registro
sleep 3

# Si el registro fue exitoso o ya había owner, continuar
if login_and_get_cookie; then
    # Completar el onboarding wizard antes de continuar
    complete_onboarding
    activate_license
    create_credentials
    import_workflows
else
    log "ADVERTENCIA: No se pudo autenticar. Algunas configuraciones pueden requerir intervención manual."
fi

# Limpiar archivos temporales
rm -f "$COOKIE_FILE"

log "✓ Proceso de configuración de n8n completado!"
log "  → URL: ${N8N_URL}"
log "  → Usuario: ${N8N_USER_EMAIL}"
log "  → Contraseña: (la configurada en .env)"

exit 0