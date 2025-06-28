#!/bin/bash
# generate-n8n-api-key.sh - Genera automáticamente una API key de N8N
# Parte del proceso de setup automatizado de DataLive

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
    echo "ERROR: .env file not found"
    exit 1
fi

# Configuration
N8N_URL="${N8N_URL:-http://localhost:5678}"
N8N_USER_EMAIL="${N8N_USER_EMAIL}"
N8N_USER_PASSWORD="${N8N_USER_PASSWORD}"
API_KEY_FILE="${PROJECT_ROOT}/secrets/n8n_api_key.txt"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

# Wait for N8N to be ready
wait_for_n8n() {
    log "Waiting for N8N to be ready..."
    local max_attempts=30
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if curl -sf "${N8N_URL}/healthz" > /dev/null 2>&1; then
            log "${GREEN}N8N is ready!${NC}"
            return 0
        fi
        attempt=$((attempt + 1))
        sleep 2
    done
    
    log "${RED}N8N is not responding after ${max_attempts} attempts${NC}"
    return 1
}

# Login to N8N and get cookie
login_to_n8n() {
    log "Logging into N8N..."
    
    # Try to login
    local response=$(curl -s -c /tmp/n8n_cookies.txt \
        -X POST "${N8N_URL}/rest/login" \
        -H "Content-Type: application/json" \
        -d "{\"emailOrLdapLoginId\":\"${N8N_USER_EMAIL}\",\"password\":\"${N8N_USER_PASSWORD}\"}" \
        -w "\n%{http_code}")
    
    local http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | sed '$d')
    
    if [ "$http_code" = "200" ]; then
        log "${GREEN}Successfully logged into N8N${NC}"
        return 0
    else
        log "${RED}Failed to login to N8N. HTTP code: $http_code${NC}"
        log "Response: $body"
        return 1
    fi
}

# Check if API key already exists
check_existing_api_key() {
    if [ -f "$API_KEY_FILE" ] && [ -s "$API_KEY_FILE" ]; then
        local existing_key=$(cat "$API_KEY_FILE")
        log "${YELLOW}API key already exists in $API_KEY_FILE${NC}"
        
        # Verify if it's still valid
        local test_response=$(curl -sf -X GET \
            -H "X-N8N-API-KEY: ${existing_key}" \
            "${N8N_URL}/api/v1/workflows" 2>&1)
        
        if [ $? -eq 0 ]; then
            log "${GREEN}Existing API key is valid${NC}"
            return 0
        else
            log "${YELLOW}Existing API key is invalid, generating new one...${NC}"
            rm -f "$API_KEY_FILE"
            return 1
        fi
    fi
    return 1
}

# Generate API key
generate_api_key() {
    log "Generating new API key..."
    
    # First, get current user info
    local user_response=$(curl -s -b /tmp/n8n_cookies.txt \
        -X GET "${N8N_URL}/rest/me" \
        -H "Content-Type: application/json")
    
    # Generate API key with 1 year expiration
    local expires_at=$(($(date +%s) + 31536000))000  # 1 year from now in milliseconds
    local api_response=$(curl -s -b /tmp/n8n_cookies.txt \
        -X POST "${N8N_URL}/rest/api-keys" \
        -H "Content-Type: application/json" \
        -d "{\"label\":\"DataLive Auto-Generated Key\",\"scopes\":[\"workflow:list\",\"workflow:read\",\"workflow:create\",\"workflow:update\",\"workflow:delete\"],\"expiresAt\":${expires_at}}" \
        -w "\n%{http_code}")
    
    local http_code=$(echo "$api_response" | tail -n1)
    local body=$(echo "$api_response" | sed '$d')
    
    if [ "$http_code" = "201" ] || [ "$http_code" = "200" ]; then
        # Extract API key from response
        local api_key=$(echo "$body" | jq -r '.data.rawApiKey // .rawApiKey // empty' 2>/dev/null)
        
        if [ -n "$api_key" ]; then
            # Create secrets directory if it doesn't exist
            mkdir -p "$(dirname "$API_KEY_FILE")"
            
            # Save API key
            echo "$api_key" > "$API_KEY_FILE"
            chmod 600 "$API_KEY_FILE"
            
            log "${GREEN}API key generated and saved to $API_KEY_FILE${NC}"
            return 0
        else
            log "${RED}Failed to extract API key from response${NC}"
            log "Response: $body"
            return 1
        fi
    else
        log "${RED}Failed to generate API key. HTTP code: $http_code${NC}"
        log "Response: $body"
        return 1
    fi
}

# Main execution
main() {
    log "Starting N8N API key generation process..."
    
    # Check if API key already exists and is valid
    if check_existing_api_key; then
        log "${GREEN}Using existing valid API key${NC}"
        exit 0
    fi
    
    # Wait for N8N
    if ! wait_for_n8n; then
        exit 1
    fi
    
    # Login to N8N
    if ! login_to_n8n; then
        log "${RED}Cannot proceed without login${NC}"
        exit 1
    fi
    
    # Generate API key
    if generate_api_key; then
        log "${GREEN}API key generation completed successfully!${NC}"
        
        # Clean up
        rm -f /tmp/n8n_cookies.txt
        
        # Verify the key works
        local api_key=$(cat "$API_KEY_FILE")
        if curl -sf -X GET \
            -H "X-N8N-API-KEY: ${api_key}" \
            "${N8N_URL}/api/v1/workflows" > /dev/null; then
            log "${GREEN}API key verified and working!${NC}"
        else
            log "${YELLOW}Warning: API key was generated but verification failed${NC}"
        fi
    else
        log "${RED}Failed to generate API key${NC}"
        exit 1
    fi
}

# Run main function
main "$@"