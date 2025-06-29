#!/bin/sh
# ==============================================================================
# DataLive - n8n Automatic Setup Script (Sidecar)
#
# Rol: Configurador automático y centralizado de n8n.
# Ejecutado por el contenedor 'n8n-setup' definido en docker-compose.yml.
# Es idempotente: puede ejecutarse múltiples veces sin causar problemas.
# ==============================================================================

# Termina el script inmediatamente si cualquier comando falla
set -e

# -- Configuración y Variables --
# Docker Compose nos pasa las variables del .env
N8N_API_URL="http://n8n:5678/api/v1"
N8N_LEGACY_URL="http://n8n:5678"
WORKFLOWS_DIR="/datalive_agent/n8n_workflows" # Directorio montado desde el agente

# Colores para los logs
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [n8n-setup] $1"
}

# --- Funciones de Lógica de Negocio ---

wait_for_n8n() {
    log "Esperando a que la API de n8n en ${N8N_LEGACY_URL} esté disponible..."
    timeout 60 sh -c '
        while ! curl -s -f "$0/healthz" > /dev/null; do
            log "n8n no está listo, reintentando en 3 segundos..."
            sleep 3
        done
    ' "${N8N_LEGACY_URL}"
    log "${GREEN}✓ n8n está listo y saludable.${NC}"
}

setup_owner_and_get_apikey() {
    log "Verificando si el setup del propietario es necesario..."
    # n8n >v1 no tiene API para registrar el primer usuario. Se gestiona con variables de entorno
    # N8N_BASIC_AUTH_USER, N8N_BASIC_AUTH_PASSWORD o un formulario.
    # La estrategia robusta es usar la API KEY que el usuario debe proveer en el .env
    # o que se genera en el primer arranque.
    # Por ahora, asumimos que N8N_API_KEY se ha definido en .env
    
    if [ -z "${N8N_API_KEY}" ]; then
        log "${YELLOW}ADVERTENCIA: N8N_API_KEY no está definida en .env. No se pueden importar workflows ni credenciales.${NC}"
        return 1
    else
        log "${GREEN}✓ Se utilizará la N8N_API_KEY proporcionada.${NC}"
        return 0
    fi
}

import_workflows() {
    log "Iniciando importación de workflows desde ${WORKFLOWS_DIR}..."
    
    if ! ls -A "${WORKFLOWS_DIR}"/*.json >/dev/null 2>&1; then
        log "${YELLOW}No se encontraron workflows .json en ${WORKFLOWS_DIR}. Omitiendo importación.${NC}"
        return
    fi
    
    # Iterar sobre cada fichero .json en el directorio de workflows
    for workflow_file in "${WORKFLOWS_DIR}"/*.json; do
        log "Procesando workflow: $(basename "${workflow_file}")..."
        
        # El endpoint de la API espera un POST con el contenido del JSON
        response=$(curl -s -w "%{http_code}" -X POST "${N8N_API_URL}/workflows" \
            -H "Authorization: Bearer ${N8N_API_KEY}" \
            -H "Content-Type: application/json" \
            --data-binary @"${workflow_file}")
        
        http_code=$(echo "$response" | tail -n1)
        
        if [ "$http_code" = "201" ]; then
            log "${GREEN}✓ Workflow importado con éxito: $(basename "${workflow_file}")${NC}"
            # Extraer el ID del workflow de la respuesta para activarlo
            workflow_id=$(echo "$response" | sed '$ d' | grep -o '"id":"[^"]*' | cut -d'"' -f4) # Solución simple sin jq
            
            # Activar el workflow
            curl -s -X POST "${N8N_API_URL}/workflows/${workflow_id}/activate" \
                 -H "Authorization: Bearer ${N8N_API_KEY}" > /dev/null
            log "Activando workflow ID: ${workflow_id}"

        elif [ "$http_code" = "409" ]; then
             log "${YELLOW}ℹ Workflow ya existe (Conflicto 409): $(basename "${workflow_file}"). Omitiendo.${NC}"
        else
            log "ERROR: Falló la importación de $(basename "${workflow_file}"). Código HTTP: ${http_code}"
            # Opcional: podríamos decidir terminar el script aquí con `exit 1`
        fi
        sleep 1 # Pequeña pausa para no sobrecargar la API
    done
}

# --- Flujo de Ejecución Principal ---

main() {
    log "==============================================="
    log "INICIANDO SETUP AUTOMÁTICO DE DATALIVE N8N"
    log "==============================================="

    wait_for_n8n
    
    if setup_owner_and_get_apikey; then
        import_workflows
    fi

    log "==============================================="
    log "${GREEN}SETUP DE N8N FINALIZADO CON ÉXITO${NC}"
    log "==============================================="
    
    # El contenedor se apagará después de esto
}

# Ejecutar la función principal
main