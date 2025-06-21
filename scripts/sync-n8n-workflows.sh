#!/bin/bash
# sync-n8n-workflows.sh - Sincroniza workflows de N8N desde Git
# Lee toda la configuración desde el archivo .env

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Load environment variables
if [ -f "$PROJECT_ROOT/.env" ]; then
    set -a
    source "$PROJECT_ROOT/.env"
    set +a
else
    echo "ERROR: .env file not found at $PROJECT_ROOT/.env"
    exit 1
fi

# Configuration from .env with defaults
N8N_URL="${N8N_URL:-http://localhost:5678}"
N8N_API_ENDPOINT="${N8N_URL}/api/v1"
WORKFLOWS_DIR="${WORKFLOWS_DIR:-${PROJECT_ROOT}/workflows}"
LOG_FILE="${LOG_FILE:-${PROJECT_ROOT}/logs/n8n-sync.log}"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Logging function
log() {
    local level=$1
    shift
    echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] [${level}] $*" | tee -a "${LOG_FILE}"
}

# Check if N8N is accessible
check_n8n_health() {
    log "INFO" "Checking N8N health..."
    
    if ! curl -sf "${N8N_URL}/healthz" > /dev/null; then
        log "ERROR" "N8N is not accessible at ${N8N_URL}"
        return 1
    fi
    
    log "INFO" "N8N is healthy"
    return 0
}

# Get N8N API key from environment or file
get_api_key() {
    if [ -n "${N8N_API_KEY:-}" ]; then
        echo "${N8N_API_KEY}"
    elif [ -f "${PROJECT_ROOT}/secrets/n8n_api_key.txt" ]; then
        cat "${PROJECT_ROOT}/secrets/n8n_api_key.txt"
    else
        log "ERROR" "N8N API key not found"
        exit 1
    fi
}

# Get all existing workflows from N8N
get_existing_workflows() {
    local api_key=$1
    
    log "INFO" "Fetching existing workflows from N8N..."
    
    local response=$(curl -sf -X GET \
        -H "X-N8N-API-KEY: ${api_key}" \
        -H "Content-Type: application/json" \
        "${N8N_API_ENDPOINT}/workflows" || echo "ERROR")
    
    if [ "${response}" = "ERROR" ]; then
        log "ERROR" "Failed to fetch workflows from N8N"
        return 1
    fi
    
    echo "${response}"
}

# Create or update workflow
sync_workflow() {
    local api_key=$1
    local workflow_file=$2
    local existing_workflows=$3
    local workflow_name=$(basename "${workflow_file}" .json)
    
    log "INFO" "Processing workflow: ${workflow_name}"
    
    # Validate JSON
    if ! jq empty "${workflow_file}" 2>/dev/null; then
        log "ERROR" "Invalid JSON in ${workflow_file}"
        return 1
    fi
    
    # Read workflow content
    local workflow_data=$(cat "${workflow_file}")
    
    # Extract workflow name from JSON
    local name_in_file=$(echo "${workflow_data}" | jq -r '.name // empty')
    if [ -z "${name_in_file}" ]; then
        # Add name if missing
        workflow_data=$(echo "${workflow_data}" | jq --arg name "${workflow_name}" '. + {name: $name}')
    fi
    
    # Check if workflow exists
    local workflow_id=$(echo "${existing_workflows}" | jq -r --arg name "${name_in_file:-$workflow_name}" '.data[] | select(.name == $name) | .id // empty')
    
    if [ -n "${workflow_id}" ]; then
        # Update existing workflow
        log "INFO" "Updating workflow ${workflow_name} (ID: ${workflow_id})"
        
        # Add ID to workflow data
        workflow_data=$(echo "${workflow_data}" | jq --arg id "${workflow_id}" '. + {id: $id}')
        
        local response=$(curl -sf -X PUT \
            -H "X-N8N-API-KEY: ${api_key}" \
            -H "Content-Type: application/json" \
            -d "${workflow_data}" \
            "${N8N_API_ENDPOINT}/workflows/${workflow_id}")
        
        if [ $? -eq 0 ]; then
            log "INFO" "${GREEN}Successfully updated workflow ${workflow_name}${NC}"
        else
            log "ERROR" "${RED}Failed to update workflow ${workflow_name}${NC}"
            return 1
        fi
    else
        # Create new workflow
        log "INFO" "Creating new workflow ${workflow_name}"
        
        local response=$(curl -sf -X POST \
            -H "X-N8N-API-KEY: ${api_key}" \
            -H "Content-Type: application/json" \
            -d "${workflow_data}" \
            "${N8N_API_ENDPOINT}/workflows")
        
        if [ $? -eq 0 ]; then
            local new_id=$(echo "${response}" | jq -r '.data.id')
            log "INFO" "${GREEN}Successfully created workflow ${workflow_name} (ID: ${new_id})${NC}"
        else
            log "ERROR" "${RED}Failed to create workflow ${workflow_name}${NC}"
            return 1
        fi
    fi
}

# Activate workflow
activate_workflow() {
    local api_key=$1
    local workflow_id=$2
    
    log "INFO" "Activating workflow ID: ${workflow_id}"
    
    local response=$(curl -sf -X PATCH \
        -H "X-N8N-API-KEY: ${api_key}" \
        -H "Content-Type: application/json" \
        -d '{"active": true}' \
        "${N8N_API_ENDPOINT}/workflows/${workflow_id}")
    
    if [ $? -eq 0 ]; then
        log "INFO" "Successfully activated workflow"
    else
        log "WARN" "Failed to activate workflow"
    fi
}

# Main sync function
main() {
    log "INFO" "Starting N8N workflow synchronization"
    
    # Create log directory if needed
    mkdir -p "$(dirname "${LOG_FILE}")"
    
    # Check N8N health
    if ! check_n8n_health; then
        exit 1
    fi
    
    # Get API key
    API_KEY=$(get_api_key)
    
    # Get existing workflows
    EXISTING_WORKFLOWS=$(get_existing_workflows "${API_KEY}")
    if [ $? -ne 0 ]; then
        exit 1
    fi
    
    # Track statistics
    local total=0
    local success=0
    local failed=0
    
    # Process each workflow directory
    for dir in "${WORKFLOWS_DIR}"/*; do
        if [ -d "${dir}" ]; then
            log "INFO" "Processing directory: $(basename "${dir}")"
            
            # Process all JSON files in directory
            for workflow_file in "${dir}"/*.json; do
                if [ -f "${workflow_file}" ]; then
                    ((total++))
                    
                    if sync_workflow "${API_KEY}" "${workflow_file}" "${EXISTING_WORKFLOWS}"; then
                        ((success++))
                        
                        # Get workflow ID for activation
                        local workflow_name=$(basename "${workflow_file}" .json)
                        local workflow_id=$(echo "${EXISTING_WORKFLOWS}" | jq -r --arg name "${workflow_name}" '.data[] | select(.name == $name) | .id // empty')
                        
                        if [ -n "${workflow_id}" ]; then
                            activate_workflow "${API_KEY}" "${workflow_id}"
                        fi
                    else
                        ((failed++))
                    fi
                fi
            done
        fi
    done
    
    # Summary
    log "INFO" "================================================"
    log "INFO" "Synchronization complete"
    log "INFO" "Total workflows: ${total}"
    log "INFO" "${GREEN}Successful: ${success}${NC}"
    if [ ${failed} -gt 0 ]; then
        log "WARN" "${RED}Failed: ${failed}${NC}"
        exit 1
    fi
    
    log "INFO" "All workflows synchronized successfully"
}

# Handle script interruption
trap 'log "ERROR" "Script interrupted"; exit 130' INT TERM

# Run main function
main "$@"