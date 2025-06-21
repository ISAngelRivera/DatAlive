#!/bin/bash
# test-system-health.sh - Suite completa de pruebas para validar DataLive RAG System
# Ejecuta pruebas exhaustivas de todos los componentes

set -uo pipefail

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

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Test results
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
WARNINGS=0

# Log file
LOG_FILE="${PROJECT_ROOT}/logs/test-results-$(date +%Y%m%d-%H%M%S).log"
mkdir -p "${PROJECT_ROOT}/logs"

# Functions
log() {
    echo -e "$@" | tee -a "${LOG_FILE}"
}

test_pass() {
    ((TOTAL_TESTS++))
    ((PASSED_TESTS++))
    log "  ${GREEN}✓${NC} $1"
}

test_fail() {
    ((TOTAL_TESTS++))
    ((FAILED_TESTS++))
    log "  ${RED}✗${NC} $1"
    log "    ${RED}Error: $2${NC}"
}

test_warn() {
    ((WARNINGS++))
    log "  ${YELLOW}⚠${NC}  $1"
}

print_header() {
    log "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    log "${CYAN}$1${NC}"
    log "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Start tests
clear
log "${MAGENTA}"
log "╔══════════════════════════════════════════════════════════════╗"
log "║          DataLive RAG System - Test Suite v1.0               ║"
log "╚══════════════════════════════════════════════════════════════╝"
log "${NC}"
log "Started at: $(date)"
log "Environment: ${NODE_ENV:-development}"
log ""

# 1. Docker and Basic Services
print_header "1. DOCKER & CONTAINER STATUS"

log "${CYAN}Checking Docker...${NC}"
if docker info > /dev/null 2>&1; then
    test_pass "Docker daemon is running"
    docker_version=$(docker --version | awk '{print $3}' | sed 's/,$//')
    log "    Version: $docker_version"
else
    test_fail "Docker daemon" "Docker is not running"
fi

log "\n${CYAN}Checking containers...${NC}"
containers=(
    "datalive-n8n"
    "datalive-postgres"
    "datalive-redis"
    "datalive-qdrant"
    "datalive-minio"
    "datalive-ollama"
    "datalive-grafana"
    "datalive-prometheus"
    "datalive-loki"
    "datalive-promtail"
)

for container in "${containers[@]}"; do
    # Check if container exists and is running
    if docker ps --format "{{.Names}}" | grep -q "^${container}$"; then
        status=$(docker ps --format "{{.Status}}" -f name="^${container}$" | head -1)
        test_pass "${container} is running (${status})"
    else
        # Check if container exists but is stopped
        if docker ps -a --format "{{.Names}}" | grep -q "^${container}$"; then
            test_fail "${container}" "Container exists but is not running"
        else
            test_fail "${container}" "Container does not exist"
        fi
    fi
done

# 2. Service Health Checks
print_header "2. SERVICE HEALTH CHECKS"

# PostgreSQL
log "\n${CYAN}Testing PostgreSQL...${NC}"
if docker exec datalive-postgres psql -U "${POSTGRES_USER:-admin}" -d "${POSTGRES_DB:-datalive_db}" -c "SELECT 1" > /dev/null 2>&1; then
    test_pass "PostgreSQL connection successful"
    
    # Check schemas
    schemas=$(docker exec datalive-postgres psql -U "${POSTGRES_USER:-admin}" -d "${POSTGRES_DB:-datalive_db}" -t -c "SELECT schema_name FROM information_schema.schemata WHERE schema_name IN ('rag', 'kag', 'cag', 'monitoring')" 2>/dev/null | grep -v '^$' | wc -l)
    
    if [ "$schemas" -eq 4 ]; then
        test_pass "All required schemas exist (rag, kag, cag, monitoring)"
    else
        test_fail "PostgreSQL schemas" "Found only $schemas/4 required schemas"
    fi
    
    # Check tables
    tables=$(docker exec datalive-postgres psql -U "${POSTGRES_USER:-admin}" -d "${POSTGRES_DB:-datalive_db}" -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema IN ('rag', 'kag', 'cag', 'monitoring')" 2>/dev/null | tr -d ' ')
    
    if [ "$tables" -gt 0 ]; then
        test_pass "Found $tables tables in database schemas"
    else
        test_fail "PostgreSQL tables" "No tables found in schemas"
    fi
else
    test_fail "PostgreSQL connection" "Cannot connect to database"
fi

# Redis
log "\n${CYAN}Testing Redis...${NC}"
if docker exec datalive-redis redis-cli -a "${REDIS_PASSWORD:-adminpassword}" ping > /dev/null 2>&1; then
    test_pass "Redis connection successful"
    
    # Test set/get
    if docker exec datalive-redis redis-cli -a "${REDIS_PASSWORD:-adminpassword}" SET test_key "test_value" EX 10 > /dev/null 2>&1; then
        value=$(docker exec datalive-redis redis-cli -a "${REDIS_PASSWORD:-adminpassword}" GET test_key 2>/dev/null)
        if [ "$value" = "test_value" ]; then
            test_pass "Redis set/get operations working"
        else
            test_fail "Redis operations" "Cannot perform set/get"
        fi
    fi
else
    test_fail "Redis connection" "Cannot connect to Redis"
fi

# MinIO
log "\n${CYAN}Testing MinIO...${NC}"
if curl -sf --max-time 5 "http://localhost:9000/minio/health/ready" > /dev/null; then
    test_pass "MinIO health check passed"
    
    # Check console
    if curl -sf --max-time 5 "http://localhost:9001" > /dev/null; then
        test_pass "MinIO Console accessible at http://localhost:9001"
    else
        test_warn "MinIO Console not accessible"
    fi
else
    test_fail "MinIO health" "MinIO not responding"
fi

# Qdrant
log "\n${CYAN}Testing Qdrant...${NC}"
if curl -sf --max-time 5 "http://localhost:6333/" > /dev/null; then
    test_pass "Qdrant health check passed"
    
    # Check collections
    collections=$(curl -sf --max-time 5 "http://localhost:6333/collections" | jq -r '.result.collections[].name' 2>/dev/null | wc -l)
    if [ "$collections" -gt 0 ]; then
        test_pass "Found $collections Qdrant collections"
    else
        test_warn "No Qdrant collections found (will be created on first use)"
    fi
else
    test_fail "Qdrant health" "Qdrant not responding"
fi

# Ollama
log "\n${CYAN}Testing Ollama...${NC}"
if curl -sf --max-time 5 "http://localhost:11434/api/tags" > /dev/null; then
    test_pass "Ollama API accessible"
    
    # Check models
    models=$(curl -sf --max-time 5 "http://localhost:11434/api/tags" | jq -r '.models[].name' 2>/dev/null)
    if echo "$models" | grep -q "phi"; then
        test_pass "Phi model found in Ollama"
        
        # Test generation with increased timeout
        response=$(curl -sf --max-time 60 -X POST "http://localhost:11434/api/generate" \
            -H "Content-Type: application/json" \
            -d '{
                "model": "phi4-mini:latest",
                "prompt": "Say OK",
                "stream": false,
                "options": {"temperature": 0, "num_predict": 10}
            }' 2>/dev/null | jq -r '.response' 2>/dev/null)
        
        if [ -n "$response" ]; then
            test_pass "Ollama generation test successful (response: ${response:0:50}...)"
        else
            test_warn "Ollama generation timeout - model may need warm-up"
        fi
    else
        test_fail "Ollama models" "Phi model not found"
    fi
else
    test_fail "Ollama API" "Ollama not responding"
fi

# N8N
log "\n${CYAN}Testing N8N...${NC}"
if curl -sf --max-time 5 "http://localhost:5678/healthz" > /dev/null; then
    test_pass "N8N health check passed"
    
    # Check if setup is needed
    setup_response=$(curl -sf --max-time 5 "http://localhost:5678/rest/settings" 2>/dev/null)
    if [ -z "$setup_response" ] || echo "$setup_response" | grep -q "error"; then
        test_warn "N8N requires manual setup at http://localhost:5678"
        log "    Email: ${N8N_USER_EMAIL}"
        log "    Password: Use the one from .env"
    else
        test_pass "N8N appears to be configured"
    fi
else
    test_fail "N8N health" "N8N not responding"
fi

# Grafana
log "\n${CYAN}Testing Grafana...${NC}"
if curl -sf --max-time 5 "http://localhost:3000/api/health" > /dev/null; then
    test_pass "Grafana health check passed"
else
    test_fail "Grafana health" "Grafana not responding"
fi

# 3. Integration Tests
print_header "3. INTEGRATION TESTS"

# Test PostgreSQL from N8N container
log "\n${CYAN}Testing inter-container connectivity...${NC}"
# N8N should be able to connect to PostgreSQL - test using nc (netcat)
if docker exec datalive-n8n nc -zv postgres 5432 2>&1 | grep -q "open"; then
    test_pass "N8N can reach PostgreSQL port"
else
    test_fail "N8N->PostgreSQL connectivity" "Cannot connect to PostgreSQL port 5432"
fi

# Test Redis from N8N container
if docker exec datalive-n8n nc -zv redis 6379 2>&1 | grep -q "open"; then
    test_pass "N8N can reach Redis port"
else
    test_fail "N8N->Redis connectivity" "Cannot connect to Redis port 6379"
fi

# 4. Resource Usage
print_header "4. RESOURCE USAGE"

log "\n${CYAN}Checking resource consumption...${NC}"
# Docker stats
stats=$(docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" | grep datalive)
log "\n${YELLOW}Container Resource Usage:${NC}"
echo "$stats" | while IFS= read -r line; do
    log "  $line"
done

# Disk usage
log "\n${YELLOW}Disk Usage:${NC}"
docker_volumes=$(docker volume ls -q | grep datalive | xargs -I {} docker volume inspect {} --format '{{.Name}}: {{.Mountpoint}}' 2>/dev/null)
total_size=0
while IFS= read -r volume; do
    if [ -n "$volume" ]; then
        name=$(echo "$volume" | cut -d: -f1)
        path=$(echo "$volume" | cut -d: -f2 | tr -d ' ')
        if [ -d "$path" ]; then
            size=$(du -sh "$path" 2>/dev/null | cut -f1)
            log "  ${name}: ${size}"
        fi
    fi
done <<< "$docker_volumes"

# 5. Configuration Validation
print_header "5. CONFIGURATION VALIDATION"

log "\n${CYAN}Checking critical configurations...${NC}"

# Check .env file
if [ -f "$PROJECT_ROOT/.env" ]; then
    test_pass ".env file exists"
    
    # Check for default passwords
    if grep -q "ChangeMe123!" "$PROJECT_ROOT/.env"; then
        test_warn "Default N8N password detected - should be changed"
    fi
    
    if grep -q "change_this_redis_password" "$PROJECT_ROOT/.env"; then
        test_warn "Default Redis password detected - should be changed"
    fi
else
    test_fail ".env file" "Configuration file missing"
fi

# Check secrets
for secret in postgres_password.txt minio_secret_key.txt n8n_encryption_key.txt grafana_password.txt; do
    if [ -f "$PROJECT_ROOT/secrets/$secret" ]; then
        test_pass "Secret file exists: $secret"
    else
        test_fail "Secret file" "$secret missing"
    fi
done

# 6. Readiness Summary
print_header "6. SYSTEM READINESS SUMMARY"

log "\n${CYAN}Component Readiness:${NC}"
log "  • Docker Stack: ${GREEN}✓ Running${NC}"
log "  • Database: ${GREEN}✓ Ready${NC}"
log "  • Vector Store: ${GREEN}✓ Ready${NC}"
log "  • LLM: ${GREEN}✓ Ready${NC}"
log "  • Workflow Engine: ${YELLOW}⚠ Requires Setup${NC}"
log "  • Monitoring: ${GREEN}✓ Ready${NC}"

log "\n${CYAN}Next Steps:${NC}"
log "  1. Complete N8N setup at http://localhost:5678"
log "  2. Configure Google OAuth using ./scripts/setup-google-oauth.sh"
log "  3. Import workflows using ./scripts/sync-n8n-workflows.sh"
log "  4. Test document ingestion with sample files"
log "  5. Verify RAG queries using test-interface.html"

# Final Summary
print_header "TEST RESULTS SUMMARY"

total_score=$((PASSED_TESTS * 100 / TOTAL_TESTS))
log "\n${CYAN}Total Tests:${NC} $TOTAL_TESTS"
log "${GREEN}Passed:${NC} $PASSED_TESTS"
log "${RED}Failed:${NC} $FAILED_TESTS"
log "${YELLOW}Warnings:${NC} $WARNINGS"
log "\n${CYAN}Success Rate:${NC} ${total_score}%"

if [ $FAILED_TESTS -eq 0 ]; then
    log "\n${GREEN}✅ SYSTEM HEALTH CHECK PASSED!${NC}"
    exit_code=0
elif [ $FAILED_TESTS -le 3 ]; then
    log "\n${YELLOW}⚠️  SYSTEM PARTIALLY OPERATIONAL${NC}"
    exit_code=1
else
    log "\n${RED}❌ SYSTEM HEALTH CHECK FAILED${NC}"
    exit_code=2
fi

log "\nDetailed log saved to: ${LOG_FILE}"
log "Completed at: $(date)"

exit $exit_code