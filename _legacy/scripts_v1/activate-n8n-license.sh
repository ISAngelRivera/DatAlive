#!/bin/bash
# activate-n8n-license.sh - Activa la licencia Community de N8N automáticamente
# Maneja casos de licencias agotadas y proporciona guía clara
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
ACTIVATION_KEY="${N8N_LICENSE_KEY}"
LICENSE_CHECK_FILE="${PROJECT_ROOT}/config/n8n/license-status.txt"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log() {
    echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

# Create config directory
mkdir -p "$(dirname "$LICENSE_CHECK_FILE")"

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

# Check current license status
check_license_status() {
    log "Checking current license status..."
    
    if [ ! -f "${PROJECT_ROOT}/secrets/n8n_cookies.txt" ]; then
        log "${RED}No session cookies found. Please run generate-n8n-api-key.sh first${NC}"
        return 1
    fi
    
    local license_info=$(curl -s -b "${PROJECT_ROOT}/secrets/n8n_cookies.txt" \
        "${N8N_URL}/rest/license" 2>&1)
    
    # Save current status
    echo "Last check: $(date)" > "$LICENSE_CHECK_FILE"
    echo "License key: ${ACTIVATION_KEY}" >> "$LICENSE_CHECK_FILE"
    echo "Response: ${license_info}" >> "$LICENSE_CHECK_FILE"
    
    # Check if license features are active
    local settings_info=$(curl -s -b "${PROJECT_ROOT}/secrets/n8n_cookies.txt" \
        "${N8N_URL}/rest/settings" 2>&1)
    
    if echo "$settings_info" | grep -q '"workflowHistory":true' 2>/dev/null; then
        log "${GREEN}✓ License features are ACTIVE${NC}"
        echo "Status: ACTIVE" >> "$LICENSE_CHECK_FILE"
        return 0
    elif echo "$license_info" | grep -q '"planName":"Community"' 2>/dev/null; then
        log "${YELLOW}Community plan detected but features not active${NC}"
        echo "Status: INACTIVE" >> "$LICENSE_CHECK_FILE"
        return 1
    else
        log "${YELLOW}No community license detected${NC}"
        echo "Status: NOT_FOUND" >> "$LICENSE_CHECK_FILE"
        return 1
    fi
}

# Attempt to activate license
activate_license() {
    log "${CYAN}Attempting to activate N8N Community license...${NC}"
    log "Using license key: ${ACTIVATION_KEY}"
    
    # Try the standard activation endpoint
    local activation_data=$(cat << EOF
{
    "activationKey": "${ACTIVATION_KEY}"
}
EOF
)
    
    local response=$(curl -s -X POST \
        -b "${PROJECT_ROOT}/secrets/n8n_cookies.txt" \
        -H "Content-Type: application/json" \
        -d "${activation_data}" \
        "${N8N_URL}/rest/license/activate" \
        -w "\n%{http_code}")
    
    local http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | sed '$d')
    
    # Handle different response codes
    if [ "$http_code" = "200" ] || [ "$http_code" = "201" ]; then
        log "${GREEN}✓ License activated successfully!${NC}"
        echo "Activation: SUCCESS" >> "$LICENSE_CHECK_FILE"
        return 0
    elif echo "$body" | grep -q "too many times" 2>/dev/null; then
        log "${RED}✗ License key exhausted: This key has been used too many times${NC}"
        echo "Activation: EXHAUSTED" >> "$LICENSE_CHECK_FILE"
        
        # Provide clear instructions
        log ""
        log "${YELLOW}=== ACTION REQUIRED ===${NC}"
        log "This license key has reached its activation limit."
        log ""
        log "${CYAN}To fix this:${NC}"
        log "1. Get a new Community license key:"
        log "   - Go to: ${BLUE}https://n8n.io/get-community-activation-key${NC}"
        log "   - Enter your email: ${N8N_USER_EMAIL}"
        log "   - Check your email for the new key"
        log ""
        log "2. Update your .env file:"
        log "   ${YELLOW}N8N_LICENSE_KEY=YOUR_NEW_KEY_HERE${NC}"
        log ""
        log "3. Re-run the setup:"
        log "   ${GREEN}./scripts/setup-datalive.sh${NC}"
        log ""
        log "${YELLOW}Current exhausted key: ${ACTIVATION_KEY}${NC}"
        log "${YELLOW}====================${NC}"
        
        return 1
    elif echo "$body" | grep -q "Invalid\|invalid" 2>/dev/null; then
        log "${RED}✗ Invalid license key format${NC}"
        echo "Activation: INVALID" >> "$LICENSE_CHECK_FILE"
        
        log ""
        log "${YELLOW}The license key format is invalid.${NC}"
        log "Please ensure you copied the complete key from the email."
        log "It should look like: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
        
        return 1
    else
        log "${YELLOW}Unexpected response: $body${NC}"
        echo "Activation: UNKNOWN - $body" >> "$LICENSE_CHECK_FILE"
        
        # Try manual activation as fallback
        log ""
        log "${CYAN}Automatic activation failed. Trying manual activation steps...${NC}"
        log ""
        log "Please try manual activation:"
        log "1. Go to: ${BLUE}http://localhost:5678${NC}"
        log "2. Click on your name (top right) → Settings"
        log "3. Enter activation key: ${YELLOW}${ACTIVATION_KEY}${NC}"
        log "4. Click 'Activate'"
        log ""
        
        return 1
    fi
}

# Verify license activation
verify_activation() {
    log "Verifying license activation..."
    
    # Give N8N a moment to apply the license
    sleep 3
    
    if check_license_status; then
        log ""
        log "${GREEN}✓ License successfully activated and verified!${NC}"
        log ""
        log "You now have access to:"
        log "  📁 ${GREEN}Folders${NC} - Organize workflows in nested structures"
        log "  🕰️  ${GREEN}Workflow History${NC} - 24-hour version history"
        log "  🐞 ${GREEN}Advanced Debugging${NC} - Debug and re-run failed executions"
        log "  🔎 ${GREEN}Execution Search${NC} - Search and tag executions"
        log ""
        return 0
    else
        log "${YELLOW}License activated but features not yet available${NC}"
        log "This might require a container restart."
        return 1
    fi
}

# Main execution
main() {
    log "${BLUE}=== N8N Community License Activation ===${NC}"
    log "Project: DataLive RAG System"
    log "License Key: ${ACTIVATION_KEY}"
    log ""
    
    # Wait for N8N
    if ! wait_for_n8n; then
        exit 1
    fi
    
    # Check current status
    if check_license_status; then
        log "${GREEN}✓ License is already activated and working!${NC}"
        exit 0
    fi
    
    # Attempt activation
    if activate_license; then
        # Verify it worked
        verify_activation
        exit 0
    else
        # Activation failed - exit with error
        exit 1
    fi
}

# Run main function
main "$@"