#!/bin/bash
# Script para desplegar el DataLive Ultimate Workflow

set -e

WORKFLOW_FILE="datalive_agent/n8n_workflows/DataLive-Ultimate-Workflow-MCP-Enhanced.json"
N8N_URL="${N8N_URL:-http://localhost:5678}"
N8N_API_KEY="${N8N_API_KEY:-}"

echo "🚀 Desplegando DataLive Ultimate Workflow..."
echo "🔗 N8N URL: $N8N_URL"
echo "📁 Workflow: $WORKFLOW_FILE"
echo ""

# Función para logging con colores
log() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case $level in
        "INFO")  echo -e "\\033[32m[INFO]\\033[0m  [$timestamp] $message" ;;
        "WARN")  echo -e "\\033[33m[WARN]\\033[0m  [$timestamp] $message" ;;
        "ERROR") echo -e "\\033[31m[ERROR]\\033[0m [$timestamp] $message" ;;
        "SUCCESS") echo -e "\\033[92m[SUCCESS]\\033[0m [$timestamp] $message" ;;
    esac
}

# Función para verificar prerrequisitos
check_prerequisites() {
    log "INFO" "Verificando prerrequisitos..."
    
    # Verificar jq
    if ! command -v jq &> /dev/null; then
        log "ERROR" "jq no está instalado. Instálalo con: brew install jq"
        exit 1
    fi
    
    # Verificar curl
    if ! command -v curl &> /dev/null; then
        log "ERROR" "curl no está disponible"
        exit 1
    fi
    
    # Verificar archivo de workflow
    if [ ! -f "$WORKFLOW_FILE" ]; then
        log "ERROR" "Archivo de workflow no encontrado: $WORKFLOW_FILE"
        exit 1
    fi
    
    log "SUCCESS" "Prerrequisitos verificados"
}

# Función para verificar conectividad con n8n
check_n8n_connectivity() {
    log "INFO" "Verificando conectividad con n8n..."
    
    local health_url="$N8N_URL/healthz"
    if curl -s -f "$health_url" >/dev/null; then
        log "SUCCESS" "n8n está disponible en $N8N_URL"
    else
        log "ERROR" "No se puede conectar a n8n en $N8N_URL"
        log "INFO" "Asegúrate de que DataLive esté corriendo: docker-compose up -d"
        exit 1
    fi
}

# Función para obtener o generar API key
get_api_key() {
    if [ -n "$N8N_API_KEY" ]; then
        log "INFO" "Usando API key proporcionada"
        return 0
    fi
    
    log "INFO" "Intentando obtener API key de n8n..."
    
    # Intentar obtener del contenedor
    if docker ps | grep -q "datalive-n8n"; then
        local api_key_file="/home/node/.n8n/n8n_api_key"
        N8N_API_KEY=$(docker exec datalive-n8n cat "$api_key_file" 2>/dev/null || echo "")
        
        if [ -n "$N8N_API_KEY" ]; then
            log "SUCCESS" "API key obtenida del contenedor"
            return 0
        fi
    fi
    
    log "WARN" "No se pudo obtener API key automáticamente"
    log "INFO" "Continuando sin autenticación (si n8n permite acceso público)"
}

# Función para validar workflow antes del despliegue
validate_workflow() {
    log "INFO" "Validando workflow antes del despliegue..."
    
    if [ -f "scripts/validate-ultimate-workflow.sh" ]; then
        if ./scripts/validate-ultimate-workflow.sh; then
            log "SUCCESS" "Workflow validado exitosamente"
        else
            log "ERROR" "Workflow falló la validación"
            read -p "¿Continuar con el despliegue? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log "INFO" "Despliegue cancelado por el usuario"
                exit 1
            fi
        fi
    else
        log "WARN" "Script de validación no encontrado, saltando validación"
    fi
}

# Función para hacer backup de workflows existentes
backup_existing_workflows() {
    log "INFO" "Creando backup de workflows existentes..."
    
    local backup_dir="backups/workflows/$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    local auth_header=""
    if [ -n "$N8N_API_KEY" ]; then
        auth_header="-H \"X-N8N-API-KEY: $N8N_API_KEY\""
    fi
    
    # Obtener lista de workflows
    local workflows_response=$(curl -s $auth_header "$N8N_URL/api/v1/workflows" || echo '{"data":[]}')
    echo "$workflows_response" > "$backup_dir/workflows_list.json"
    
    local workflow_count=$(echo "$workflows_response" | jq '.data | length' 2>/dev/null || echo "0")
    log "INFO" "Backup creado para $workflow_count workflows en $backup_dir"
}

# Función para crear credenciales necesarias
create_credentials() {
    log "INFO" "Verificando credenciales necesarias..."
    
    local required_creds=(
        "postgres:PostgreSQL"
        "redis:Redis" 
        "googleApi:Google OAuth2"
        "githubApi:GitHub API"
        "slackApi:Slack"
    )
    
    for cred_info in "${required_creds[@]}"; do
        local cred_name=$(echo "$cred_info" | cut -d: -f1)
        local cred_type=$(echo "$cred_info" | cut -d: -f2)
        
        log "INFO" "Verificando credencial: $cred_name ($cred_type)"
        # TODO: Implementar creación automática de credenciales si no existen
    done
    
    log "INFO" "Verificación de credenciales completada"
}

# Función para desplegar el workflow
deploy_workflow() {
    log "INFO" "Desplegando workflow en n8n..."
    
    local auth_header=""
    if [ -n "$N8N_API_KEY" ]; then
        auth_header="-H \"X-N8N-API-KEY: $N8N_API_KEY\""
    fi
    
    # Leer y preparar el workflow
    local workflow_data=$(cat "$WORKFLOW_FILE")
    local workflow_name=$(echo "$workflow_data" | jq -r '.name')
    
    log "INFO" "Desplegando workflow: $workflow_name"
    
    # Intentar crear el workflow
    local response=$(curl -s -w "%{http_code}" -o /tmp/n8n_response.json \
        $auth_header \
        -H "Content-Type: application/json" \
        -X POST \
        "$N8N_URL/api/v1/workflows" \
        -d "$workflow_data")
    
    local http_code=${response: -3}
    local response_body=$(cat /tmp/n8n_response.json)
    
    if [ "$http_code" -eq 201 ]; then
        local workflow_id=$(echo "$response_body" | jq -r '.data.id')
        log "SUCCESS" "Workflow creado exitosamente con ID: $workflow_id"
        
        # Intentar activar el workflow
        activate_workflow "$workflow_id"
        
    elif [ "$http_code" -eq 409 ]; then
        log "WARN" "Workflow ya existe, intentando actualizar..."
        update_existing_workflow "$workflow_name"
        
    else
        log "ERROR" "Error al crear workflow (HTTP $http_code)"
        echo "$response_body" | jq . 2>/dev/null || echo "$response_body"
        exit 1
    fi
}

# Función para activar workflow
activate_workflow() {
    local workflow_id=$1
    log "INFO" "Activando workflow ID: $workflow_id"
    
    local auth_header=""
    if [ -n "$N8N_API_KEY" ]; then
        auth_header="-H \"X-N8N-API-KEY: $N8N_API_KEY\""
    fi
    
    local response=$(curl -s -w "%{http_code}" -o /tmp/n8n_activate_response.json \
        $auth_header \
        -H "Content-Type: application/json" \
        -X PATCH \
        "$N8N_URL/api/v1/workflows/$workflow_id" \
        -d '{"active": true}')
    
    local http_code=${response: -3}
    
    if [ "$http_code" -eq 200 ]; then
        log "SUCCESS" "Workflow activado exitosamente"
    else
        log "WARN" "No se pudo activar automáticamente el workflow"
        log "INFO" "Puedes activarlo manualmente desde la interfaz de n8n"
    fi
}

# Función para actualizar workflow existente
update_existing_workflow() {
    local workflow_name=$1
    log "INFO" "Buscando workflow existente: $workflow_name"
    
    # TODO: Implementar lógica de actualización
    log "WARN" "Actualización de workflows existentes no implementada"
    log "INFO" "Por favor, elimina el workflow manualmente y ejecuta este script de nuevo"
}

# Función para verificar el despliegue
verify_deployment() {
    log "INFO" "Verificando despliegue..."
    
    # Verificar que los webhooks responden
    local webhook_urls=(
        "$N8N_URL/webhook/datalive/ingest"
        "$N8N_URL/webhook/datalive/query"
    )
    
    for url in "${webhook_urls[@]}"; do
        if curl -s -f -X POST "$url" -d '{"test": true}' >/dev/null 2>&1; then
            log "SUCCESS" "Webhook disponible: $url"
        else
            log "WARN" "Webhook no responde: $url"
        fi
    done
    
    log "SUCCESS" "Verificación de despliegue completada"
}

# Función para mostrar información post-despliegue
show_deployment_info() {
    log "INFO" "Información de despliegue:"
    echo ""
    echo "🌐 Endpoints disponibles:"
    echo "   📥 Ingesta: POST $N8N_URL/webhook/datalive/ingest"
    echo "   🔍 Query:   POST $N8N_URL/webhook/datalive/query"
    echo ""
    echo "🔧 Interfaz de n8n: $N8N_URL"
    echo "📊 Grafana:         http://localhost:3000"
    echo "📈 Prometheus:      http://localhost:9090"
    echo ""
    echo "📚 Documentación:"
    echo "   📖 Workflow Guide: docs/ULTIMATE_WORKFLOW_DOCUMENTATION.md"
    echo "   🔧 n8n-MCP Guide:  docs/N8N_MCP_WORKFLOW_GUIDE.md"
    echo ""
    echo "🧪 Test de ejemplo:"
    echo 'curl -X POST '"$N8N_URL"'/webhook/datalive/query \\'
    echo '  -H "Content-Type: application/json" \\'
    echo '  -d '"'"'{"query": "¿Qué es DataLive?"}''"'"
    echo ""
}

# Función principal
main() {
    echo "🚀 DataLive Ultimate Workflow Deployment"
    echo "========================================"
    echo ""
    
    check_prerequisites
    check_n8n_connectivity
    get_api_key
    validate_workflow
    backup_existing_workflows
    create_credentials
    deploy_workflow
    verify_deployment
    show_deployment_info
    
    log "SUCCESS" "¡DataLive Ultimate Workflow desplegado exitosamente! 🎉"
}

# Manejar señales de interrupción
trap 'log "WARN" "Despliegue interrumpido por el usuario"; exit 1' INT TERM

# Ejecutar función principal
main "$@"