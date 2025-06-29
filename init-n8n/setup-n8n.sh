#!/bin/sh
# scripts/setup-n8n.sh - v2.0 con Lógica de Setup Real

set -e

# -- Variables --
N8N_URL="http://n8n:5678"
API_URL="${N8N_URL}/api/v1"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [n8n-setup] $1"
}

# -- Funciones de Lógica de Negocio --

wait_for_n8n() {
    log "Esperando a que la API de n8n en ${N8N_URL} esté disponible..."
    timeout 60 sh -c '
        while ! curl -s -f "$0/healthz" > /dev/null; do
            log "n8n no está listo, reintentando en 3 segundos..."
            sleep 3
        done
    ' "${N8N_URL}"
    log "✓ n8n está listo y saludable."
}

register_owner() {
    log "Verificando si el registro del propietario es necesario..."
    
    # Comprobar si el endpoint de setup está activo
    http_code=$(curl -s -o /dev/null -w "%{http_code}" "${API_URL}/users/setup")

    if [ "$http_code" -eq 200 ]; then
        log "La instancia de n8n no tiene propietario. Procediendo con el registro automático..."
        
        # Construir el cuerpo JSON
        json_payload=$(cat <<EOF
{
    "firstName": "${N8N_USER_FIRSTNAME}",
    "lastName": "${N8N_USER_LASTNAME}",
    "email": "${N8N_USER_EMAIL}",
    "password": "${N8N_USER_PASSWORD}",
    "telemetry": false
}
EOF
)
        # Registrar el usuario
        response_code=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
            -H "Content-Type: application/json" \
            -d "$json_payload" \
            "${API_URL}/users/setup")

        if [ "$response_code" -eq 200 ]; then
            log "✓ Propietario registrado con éxito: ${N8N_USER_EMAIL}"
        else
            log "ERROR: Falló el registro del propietario. Código HTTP: ${response_code}"
            exit 1
        fi
    else
        log "✓ El propietario ya está configurado. Omitiendo registro."
    fi
}

activate_license() {
    if [ -z "${N8N_LICENSE_KEY}" ]; then
        log "No se encontró N8N_LICENSE_KEY. Omitiendo activación de licencia."
        return
    fi
    
    log "Intentando activar la licencia..."
    
    # Comprobar el estado actual antes de intentar activar
    current_license=$(curl -s -u "${N8N_USER_EMAIL}:${N8N_USER_PASSWORD}" "${N8N_URL}/api/v1/licenses")
    
    if echo "$current_license" | jq -e '.features.sso' 2>/dev/null; then
        log "✓ La licencia ya parece estar activa. Omitiendo."
        return
    fi
    
    # Activar la licencia
    response_code=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
        -u "${N8N_USER_EMAIL}:${N8N_USER_PASSWORD}" \
        -H "Content-Type: application/json" \
        -d "{\"license\": \"${N8N_LICENSE_KEY}\"}" \
        "${N8N_URL}/api/v1/licenses")
        
    if [ "$response_code" -eq 200 ] || [ "$response_code" -eq 201 ]; then
        log "✓ Licencia activada con éxito."
    else
        log "ADVERTENCIA: Falló la activación de la licencia (Código HTTP: ${response_code}). Puede que ya estuviera activa o que la clave sea inválida. Continuando..."
    fi
}

# --- Flujo de Ejecución Principal ---
wait_for_n8n
register_owner
sleep 2 # Pequeña pausa para que el registro se asiente
activate_license

log "✓ Setup de n8n finalizado."
exit 0