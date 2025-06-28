#!/bin/bash
# auto-register-n8n-owner.sh - Automatiza el registro inicial del owner account en N8N
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
N8N_USER_FIRSTNAME="${N8N_USER_FIRSTNAME}"
N8N_USER_LASTNAME="${N8N_USER_LASTNAME}"
N8N_USER_PASSWORD="${N8N_USER_PASSWORD}"

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

# Check if N8N needs setup (no owner exists)
check_setup_needed() {
    log "Checking if N8N setup is needed..."
    
    # Check if the setup page exists by looking for redirect to /setup
    local main_response=$(curl -s -L "${N8N_URL}/" 2>&1)
    local setup_check=$(curl -s -w "%{redirect_url}" "${N8N_URL}/" 2>&1)
    
    # If we get redirected to /setup or the main page contains setup elements
    if echo "${setup_check}" | grep -q "/setup" 2>/dev/null || echo "${main_response}" | grep -q "setup" 2>/dev/null; then
        log "${YELLOW}N8N needs initial owner setup${NC}"
        return 0
    fi
    
    # Also try the direct setup endpoint
    local setup_response=$(curl -s "${N8N_URL}/setup" 2>&1)
    if echo "${setup_response}" | grep -q -i "setup\|owner\|register\|first.*user" 2>/dev/null; then
        log "${YELLOW}N8N needs initial owner setup (setup page accessible)${NC}"
        return 0
    fi
    
    # Try login to see if account exists
    local login_test=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d '{"emailOrLdapLoginId":"test","password":"test"}' \
        "${N8N_URL}/rest/login" 2>&1)
    
    if echo "${login_test}" | grep -q "Wrong username or password" 2>/dev/null; then
        log "${GREEN}N8N owner already exists (login endpoint active)${NC}"
        return 1
    elif echo "${login_test}" | grep -q "not found\|502\|503" 2>/dev/null; then
        log "${YELLOW}N8N needs initial owner setup (login not available)${NC}"
        return 0
    fi
    
    log "${GREEN}N8N owner already exists${NC}"
    return 1
}

# Register the owner account
register_owner() {
    log "Registering N8N owner account..."
    
    # Prepare registration data
    local registration_data=$(cat << EOF
{
    "email": "${N8N_USER_EMAIL}",
    "firstName": "${N8N_USER_FIRSTNAME}",
    "lastName": "${N8N_USER_LASTNAME}",
    "password": "${N8N_USER_PASSWORD}",
    "agree": true
}
EOF
)
    
    # Attempt registration
    local response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "${registration_data}" \
        "${N8N_URL}/rest/owner/setup" \
        -w "\n%{http_code}")
    
    local http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | sed '$d')
    
    if [ "$http_code" = "200" ] || [ "$http_code" = "201" ]; then
        log "${GREEN}Successfully registered N8N owner account${NC}"
        log "Email: ${N8N_USER_EMAIL}"
        log "Name: ${N8N_USER_FIRSTNAME} ${N8N_USER_LASTNAME}"
        return 0
    else
        log "${RED}Failed to register owner account. HTTP code: $http_code${NC}"
        log "Response: $body"
        
        # Check if it's because user already exists
        if echo "$body" | grep -q "already.*exist" 2>/dev/null; then
            log "${YELLOW}Owner account may already exist, continuing...${NC}"
            return 0
        fi
        
        return 1
    fi
}

# Verify registration by attempting login
verify_registration() {
    log "Verifying owner registration..."
    
    local login_data=$(cat << EOF
{
    "emailOrLdapLoginId": "${N8N_USER_EMAIL}",
    "password": "${N8N_USER_PASSWORD}"
}
EOF
)
    
    local response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "${login_data}" \
        "${N8N_URL}/rest/login" \
        -w "\n%{http_code}")
    
    local http_code=$(echo "$response" | tail -n1)
    
    if [ "$http_code" = "200" ]; then
        log "${GREEN}Owner account verified successfully${NC}"
        return 0
    else
        log "${RED}Failed to verify owner account. HTTP code: $http_code${NC}"
        return 1
    fi
}

# Main execution
main() {
    log "Starting N8N owner account auto-registration..."
    
    # Wait for N8N to be ready
    if ! wait_for_n8n; then
        exit 1
    fi
    
    # Check if setup is needed
    if ! check_setup_needed; then
        log "${GREEN}N8N owner account already exists, skipping registration${NC}"
        
        # Still verify we can login
        if verify_registration; then
            log "${GREEN}Existing owner account verified${NC}"
            exit 0
        else
            log "${YELLOW}Warning: Could not verify existing account, but continuing${NC}"
            exit 0
        fi
    fi
    
    # Register the owner
    if register_owner; then
        log "${GREEN}Owner registration completed${NC}"
        
        # Verify registration
        sleep 2  # Give N8N a moment to process
        if verify_registration; then
            log "${GREEN}Owner account registration and verification successful!${NC}"
            exit 0
        else
            log "${YELLOW}Registration successful but verification failed, continuing...${NC}"
            exit 0
        fi
    else
        log "${RED}Failed to register owner account${NC}"
        exit 1
    fi
}

# Run main function
main "$@"