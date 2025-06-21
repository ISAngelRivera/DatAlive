#!/bin/bash
# init-n8n-setup.sh - Configuración automática completa de N8N
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
N8N_API="${N8N_URL}/rest"
TIMEOUT_SECONDS="${N8N_SETUP_TIMEOUT:-300}"
LOG_FILE="${PROJECT_ROOT}/logs/n8n-setup.log"

# User configuration from .env
N8N_USER_EMAIL="${N8N_USER_EMAIL}"
N8N_USER_FIRSTNAME="${N8N_USER_FIRSTNAME}"
N8N_USER_LASTNAME="${N8N_USER_LASTNAME}"
N8N_USER_PASSWORD="${N8N_USER_PASSWORD}"
N8N_LICENSE_KEY="${N8N_LICENSE_KEY}"

# Survey configuration from .env
N8N_COMPANY_SIZE="${N8N_COMPANY_SIZE:-20+}"
N8N_INDUSTRY="${N8N_INDUSTRY:-other}"
N8N_INDUSTRY_OTHER="${N8N_INDUSTRY_OTHER:-Technology}"
N8N_ROLE="${N8N_ROLE:-engineering}"
N8N_ROLE_OTHER="${N8N_ROLE_OTHER:-Development}"
N8N_CODING_SKILL="${N8N_CODING_SKILL:-advanced}"
N8N_GOALS="${N8N_GOALS:-automation}"
N8N_HEARD_FROM="${N8N_HEARD_FROM:-youtube}"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging function
log() {
    local level=$1
    shift
    echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] [${level}] $*" | tee -a "${LOG_FILE}"
}

# Wait for N8N to be ready
wait_for_n8n() {
    log "INFO" "Waiting for N8N to be ready at ${N8N_URL}..."
    local count=0
    
    while [ $count -lt $TIMEOUT_SECONDS ]; do
        if curl -sf "${N8N_URL}/healthz" > /dev/null 2>&1; then
            log "INFO" "${GREEN}N8N is ready!${NC}"
            return 0
        fi
        
        echo -n "."
        sleep 1
        ((count++))
    done
    
    log "ERROR" "${RED}Timeout waiting for N8N${NC}"
    return 1
}

# Check if N8N is already initialized
check_if_initialized() {
    log "INFO" "Checking if N8N is already initialized..."
    
    # Try to access the API without auth - if it returns 401, it's initialized
    local response=$(curl -s -o /dev/null -w "%{http_code}" "${N8N_API}/users")
    
    if [ "$response" = "401" ]; then
        log "INFO" "N8N is already initialized"
        return 0
    else
        log "INFO" "N8N needs initialization"
        return 1
    fi
}

# Setup initial user
setup_initial_user() {
    log "INFO" "Setting up initial N8N user: ${N8N_USER_EMAIL}"
    
    local setup_data=$(cat <<EOF
{
    "email": "${N8N_USER_EMAIL}",
    "firstName": "${N8N_USER_FIRSTNAME}",
    "lastName": "${N8N_USER_LASTNAME}",
    "password": "${N8N_USER_PASSWORD}",
    "agree": true
}
EOF
)
    
    local response=$(curl -sf -X POST \
        -H "Content-Type: application/json" \
        -d "${setup_data}" \
        "${N8N_API}/owner/setup" 2>&1)
    
    if [ $? -eq 0 ]; then
        log "INFO" "${GREEN}Initial user created successfully${NC}"
        return 0
    else
        log "ERROR" "${RED}Failed to create initial user${NC}"
        log "DEBUG" "Response: $response"
        return 1
    fi
}

# Login to N8N
login_to_n8n() {
    log "INFO" "Logging in to N8N..."
    
    local login_data=$(cat <<EOF
{
    "email": "${N8N_USER_EMAIL}",
    "password": "${N8N_USER_PASSWORD}"
}
EOF
)
    
    local response=$(curl -sf -X POST \
        -H "Content-Type: application/json" \
        -c "${PROJECT_ROOT}/secrets/n8n_cookies.txt" \
        -d "${login_data}" \
        "${N8N_API}/login")
    
    if [ $? -eq 0 ]; then
        log "INFO" "${GREEN}Successfully logged in${NC}"
        
        # Save auth token if provided
        local token=$(echo "$response" | jq -r '.data.token // empty')
        if [ -n "$token" ]; then
            echo "$token" > "${PROJECT_ROOT}/secrets/n8n_auth_token.txt"
        fi
        
        return 0
    else
        log "ERROR" "${RED}Failed to login${NC}"
        return 1
    fi
}

# Skip personalization survey
skip_personalization() {
    log "INFO" "Configuring N8N personalization settings..."
    
    local personalization_data=$(cat <<EOF
{
    "values": {
        "codingSkill": "${N8N_CODING_SKILL}",
        "companyIndustry": "${N8N_INDUSTRY}",
        "companySize": "${N8N_COMPANY_SIZE}",
        "otherCompanyIndustry": "${N8N_INDUSTRY_OTHER}",
        "otherWorkArea": "${N8N_ROLE_OTHER}",
        "workArea": "${N8N_ROLE}",
        "goals": "${N8N_GOALS}",
        "heardFrom": "${N8N_HEARD_FROM}"
    }
}
EOF
)
    
    curl -sf -X POST \
        -H "Content-Type: application/json" \
        -b "${PROJECT_ROOT}/secrets/n8n_cookies.txt" \
        -d "${personalization_data}" \
        "${N8N_API}/user/survey" > /dev/null 2>&1 || true
}

# Activate license
activate_license() {
    log "INFO" "Activating N8N license..."
    
    local license_data=$(cat <<EOF
{
    "activationKey": "${N8N_LICENSE_KEY}",
    "email": "${N8N_USER_EMAIL}"
}
EOF
)
    
    local response=$(curl -sf -X POST \
        -H "Content-Type: application/json" \
        -b "${PROJECT_ROOT}/secrets/n8n_cookies.txt" \
        -d "${license_data}" \
        "${N8N_API}/license/activate")
    
    if [ $? -eq 0 ]; then
        log "INFO" "${GREEN}License activated successfully${NC}"
        return 0
    else
        log "WARN" "${YELLOW}Failed to activate license - continuing anyway${NC}"
        return 0
    fi
}

# Create credential type
create_credential() {
    local cred_name=$1
    local cred_type=$2
    local cred_data=$3
    
    log "INFO" "Creating credential: ${cred_name}"
    
    local credential_json=$(cat <<EOF
{
    "name": "${cred_name}",
    "type": "${cred_type}",
    "data": ${cred_data}
}
EOF
)
    
    local response=$(curl -sf -X POST \
        -H "Content-Type: application/json" \
        -b "${PROJECT_ROOT}/secrets/n8n_cookies.txt" \
        -d "${credential_json}" \
        "${N8N_API}/credentials")
    
    if [ $? -eq 0 ]; then
        local cred_id=$(echo "$response" | jq -r '.data.id')
        log "INFO" "${GREEN}Created credential ${cred_name} with ID: ${cred_id}${NC}"
        echo "${cred_id}"
        return 0
    else
        log "ERROR" "${RED}Failed to create credential ${cred_name}${NC}"
        return 1
    fi
}

# Setup all required credentials
setup_credentials() {
    log "INFO" "Setting up N8N credentials..."
    
    # Create credentials file to store IDs
    local cred_file="${PROJECT_ROOT}/config/n8n/credential-ids.env"
    mkdir -p "$(dirname "$cred_file")"
    echo "# N8N Credential IDs - Auto-generated $(date)" > "$cred_file"
    
    # Ollama credential
    local ollama_data=$(cat <<EOF
{
    "baseUrl": "http://ollama:11434"
}
EOF
)
    local ollama_id=$(create_credential "Ollama Local" "ollamaApi" "$ollama_data")
    if [ -n "$ollama_id" ]; then
        echo "OLLAMA_CREDENTIAL_ID=${ollama_id}" >> "$cred_file"
    fi
    
    # Qdrant credential
    local qdrant_data=$(cat <<EOF
{
    "url": "http://qdrant:6333",
    "apiKey": ""
}
EOF
)
    local qdrant_id=$(create_credential "Qdrant Local" "qdrantApi" "$qdrant_data")
    if [ -n "$qdrant_id" ]; then
        echo "QDRANT_CREDENTIAL_ID=${qdrant_id}" >> "$cred_file"
    fi
    
    # PostgreSQL credential
    local postgres_password=$(cat "${PROJECT_ROOT}/secrets/postgres_password.txt")
    local postgres_data=$(cat <<EOF
{
    "host": "postgres",
    "port": 5432,
    "database": "${POSTGRES_DB}",
    "user": "${POSTGRES_USER}",
    "password": "${postgres_password}",
    "ssl": "disable"
}
EOF
)
    local postgres_id=$(create_credential "PostgreSQL Local" "postgres" "$postgres_data")
    if [ -n "$postgres_id" ]; then
        echo "POSTGRES_CREDENTIAL_ID=${postgres_id}" >> "$cred_file"
    fi
    
    # MinIO credential (S3 compatible)
    local minio_secret=$(cat "${PROJECT_ROOT}/secrets/minio_secret_key.txt")
    local minio_data=$(cat <<EOF
{
    "accessKeyId": "${MINIO_ROOT_USER}",
    "secretAccessKey": "${minio_secret}",
    "region": "${MINIO_REGION:-us-east-1}",
    "endpoint": "http://minio:9000",
    "forcePathStyle": true
}
EOF
)
    local minio_id=$(create_credential "MinIO Local" "aws" "$minio_data")
    if [ -n "$minio_id" ]; then
        echo "MINIO_CREDENTIAL_ID=${minio_id}" >> "$cred_file"
    fi
    
    # Redis credential
    local redis_data=$(cat <<EOF
{
    "host": "redis",
    "port": 6379,
    "password": "${REDIS_PASSWORD}"
}
EOF
)
    local redis_id=$(create_credential "Redis Local" "redis" "$redis_data")
    if [ -n "$redis_id" ]; then
        echo "REDIS_CREDENTIAL_ID=${redis_id}" >> "$cred_file"
    fi
    
    # Google Drive credential (if configured)
    if [ -n "${GOOGLE_CLIENT_ID}" ] && [ -n "${GOOGLE_CLIENT_SECRET}" ]; then
        log "INFO" "Setting up Google Drive OAuth..."
        
        local gdrive_data=$(cat <<EOF
{
    "clientId": "${GOOGLE_CLIENT_ID}",
    "clientSecret": "${GOOGLE_CLIENT_SECRET}",
    "oauthTokenData": {}
}
EOF
)
        local gdrive_id=$(create_credential "Google Drive" "googleDriveOAuth2Api" "$gdrive_data")
        if [ -n "$gdrive_id" ]; then
            echo "GDRIVE_CREDENTIAL_ID=${gdrive_id}" >> "$cred_file"
            log "WARN" "${YELLOW}Google Drive credential created but needs manual OAuth authorization${NC}"
        fi
    elif [ -f "${GOOGLE_OAUTH_FILE}" ]; then
        # Read from file if specified
        log "INFO" "Reading Google OAuth from file: ${GOOGLE_OAUTH_FILE}"
        local oauth_content=$(cat "${GOOGLE_OAUTH_FILE}")
        local client_id=$(echo "$oauth_content" | jq -r '.web.client_id // .installed.client_id // empty')
        local client_secret=$(echo "$oauth_content" | jq -r '.web.client_secret // .installed.client_secret // empty')
        
        if [ -n "$client_id" ] && [ -n "$client_secret" ]; then
            local gdrive_data=$(cat <<EOF
{
    "clientId": "${client_id}",
    "clientSecret": "${client_secret}",
    "oauthTokenData": {}
}
EOF
)
            local gdrive_id=$(create_credential "Google Drive" "googleDriveOAuth2Api" "$gdrive_data")
            if [ -n "$gdrive_id" ]; then
                echo "GDRIVE_CREDENTIAL_ID=${gdrive_id}" >> "$cred_file"
                log "WARN" "${YELLOW}Google Drive credential created but needs manual OAuth authorization${NC}"
            fi
        fi
    fi
    
    log "INFO" "${GREEN}Credentials setup completed${NC}"
}

# Update workflow files with credential IDs
update_workflow_credentials() {
    log "INFO" "Updating workflow files with credential IDs..."
    
    # Source the credential IDs
    source "${PROJECT_ROOT}/config/n8n/credential-ids.env"
    
    # Process each workflow file
    for workflow_file in "${PROJECT_ROOT}"/workflows/**/*.json; do
        if [ -f "$workflow_file" ]; then
            log "INFO" "Updating credentials in: $workflow_file"
            
            # Create backup
            cp "$workflow_file" "${workflow_file}.bak"
            
            # Update credential IDs using jq
            local updated=$(cat "$workflow_file" | \
                jq --arg ollama "${OLLAMA_CREDENTIAL_ID:-}" \
                   --arg qdrant "${QDRANT_CREDENTIAL_ID:-}" \
                   --arg postgres "${POSTGRES_CREDENTIAL_ID:-}" \
                   --arg minio "${MINIO_CREDENTIAL_ID:-}" \
                   --arg redis "${REDIS_CREDENTIAL_ID:-}" \
                   --arg gdrive "${GDRIVE_CREDENTIAL_ID:-}" '
                walk(
                    if type == "object" and has("credentials") then
                        .credentials |= 
                        if .ollamaApi then .ollamaApi.id = $ollama
                        elif .qdrantApi then .qdrantApi.id = $qdrant
                        elif .postgres then .postgres.id = $postgres
                        elif .aws then .aws.id = $minio
                        elif .redis then .redis.id = $redis
                        elif .googleDriveOAuth2Api and $gdrive != "" then .googleDriveOAuth2Api.id = $gdrive
                        else . end
                    else . end
                )')
            
            echo "$updated" > "$workflow_file"
        fi
    done
    
    log "INFO" "${GREEN}Workflow credentials updated${NC}"
}

# Configure N8N settings
configure_n8n_settings() {
    log "INFO" "Configuring N8N settings..."
    
    # Build settings based on .env variables
    local settings_data=$(cat <<EOF
{
    "versionNotifications": ${N8N_VERSION_NOTIFICATIONS_ENABLED:-false},
    "telemetry": {
        "enabled": ${N8N_DIAGNOSTICS_ENABLED:-false}
    },
    "templates": {
        "enabled": ${N8N_TEMPLATES_ENABLED:-true}
    },
    "personalization": {
        "enabled": ${N8N_PERSONALIZATION_ENABLED:-false}
    },
    "hiring": {
        "enabled": ${N8N_HIRING_BANNER_ENABLED:-false}
    }
}
EOF
)
    
    curl -sf -X PATCH \
        -H "Content-Type: application/json" \
        -b "${PROJECT_ROOT}/secrets/n8n_cookies.txt" \
        -d "${settings_data}" \
        "${N8N_API}/settings" > /dev/null 2>&1 || true
}

# Main setup function
main() {
    log "INFO" "${BLUE}Starting N8N automated setup${NC}"
    log "INFO" "Project root: ${PROJECT_ROOT}"
    log "INFO" "N8N URL: ${N8N_URL}"
    log "INFO" "User email: ${N8N_USER_EMAIL}"
    
    # Create necessary directories
    mkdir -p "${PROJECT_ROOT}/logs" "${PROJECT_ROOT}/secrets" "${PROJECT_ROOT}/config/n8n"
    
    # Wait for N8N to be ready
    if ! wait_for_n8n; then
        exit 1
    fi
    
    # Check if already initialized
    if check_if_initialized; then
        log "INFO" "N8N already initialized, attempting login..."
        if ! login_to_n8n; then
            log "ERROR" "Failed to login to existing N8N instance"
            exit 1
        fi
    else
        # Fresh setup
        if ! setup_initial_user; then
            exit 1
        fi
        
        if ! login_to_n8n; then
            exit 1
        fi
        
        # Skip personalization
        skip_personalization
        
        # Activate license
        activate_license
    fi
    
    # Configure settings
    configure_n8n_settings
    
    # Setup credentials
    setup_credentials
    
    # Update workflow files with credential IDs
    update_workflow_credentials
    
    # Import workflows using the sync script
    log "INFO" "Importing workflows..."
    "${PROJECT_ROOT}/scripts/sync-n8n-workflows.sh"
    
    log "INFO" "${GREEN}✓ N8N setup completed successfully!${NC}"
    log "INFO" "You can now access N8N at: ${N8N_URL}"
    log "INFO" "Login with: ${N8N_USER_EMAIL}"
    
    # Save summary
    cat > "${PROJECT_ROOT}/config/n8n/setup-summary.txt" <<EOF
N8N Setup Summary
=================
Date: $(date)
URL: ${N8N_URL}
Email: ${N8N_USER_EMAIL}
License Key: ${N8N_LICENSE_KEY}

Credentials Created:
$(cat "${PROJECT_ROOT}/config/n8n/credential-ids.env" | grep -v '^#')

Next Steps:
1. If using Google Drive, complete OAuth authorization manually
2. Verify all workflows are active
3. Test the system with sample documents
EOF
    
    log "INFO" "Setup summary saved to: ${PROJECT_ROOT}/config/n8n/setup-summary.txt"
}

# Error handling
trap 'log "ERROR" "Setup failed at line $LINENO"; exit 1' ERR

# Run main function
main "$@"