#!/bin/bash
# wait-for-healthy.sh - Espera a que todos los servicios estén saludables
# Lee configuración desde .env

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Load environment variables
if [ -f "$PROJECT_ROOT/.env" ]; then
    set -a
    source "$PROJECT_ROOT/.env"
    set +a
fi

# Configuration
TIMEOUT=${HEALTH_CHECK_TIMEOUT:-300}
INTERVAL=2
LOG_FILE="${PROJECT_ROOT}/logs/health-check.log"

# Services to check with their health endpoints
declare -A SERVICES=(
    ["n8n"]="http://localhost:5678/healthz"
    ["postgres"]="pg_isready -h localhost -p 5432 -U ${POSTGRES_USER}"
    ["redis"]="redis-cli -h localhost -p 6379 ping"
    ["qdrant"]="http://localhost:6333/health"
    ["minio"]="http://localhost:9000/minio/health/ready"
    ["ollama"]="http://localhost:11434/api/tags"
    ["grafana"]="http://localhost:3000/api/health"
    ["prometheus"]="http://localhost:9090/-/healthy"
    ["loki"]="http://localhost:3100/ready"
)

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging
log() {
    local level=$1
    shift
    echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] [${level}] $*" | tee -a "${LOG_FILE}"
}

# Check HTTP endpoint
check_http() {
    local url=$1
    curl -sf "$url" > /dev/null 2>&1
}

# Check PostgreSQL
check_postgres() {
    PGPASSWORD=$(cat "$PROJECT_ROOT/secrets/postgres_password.txt" 2>/dev/null || echo "") \
    pg_isready -h localhost -p 5432 -U "${POSTGRES_USER}" > /dev/null 2>&1
}

# Check Redis
check_redis() {
    if [ -n "${REDIS_PASSWORD:-}" ]; then
        redis-cli -h localhost -p 6379 -a "${REDIS_PASSWORD}" ping > /dev/null 2>&1
    else
        redis-cli -h localhost -p 6379 ping > /dev/null 2>&1
    fi
}

# Check individual service
check_service() {
    local service=$1
    local check=${SERVICES[$service]}
    
    case $service in
        "postgres")
            check_postgres
            ;;
        "redis")
            check_redis
            ;;
        "n8n"|"qdrant"|"minio"|"ollama"|"grafana"|"prometheus"|"loki")
            check_http "$check"
            ;;
        *)
            return 1
            ;;
    esac
}

# Wait for service
wait_for_service() {
    local service=$1
    local elapsed=0
    
    echo -n "  Waiting for $service"
    
    while [ $elapsed -lt $TIMEOUT ]; do
        if check_service "$service"; then
            echo -e "\r  ${GREEN}✓${NC} $service is healthy"
            return 0
        fi
        
        echo -n "."
        sleep $INTERVAL
        elapsed=$((elapsed + INTERVAL))
    done
    
    echo -e "\r  ${RED}✗${NC} $service failed to become healthy"
    return 1
}

# Main function
main() {
    mkdir -p "$(dirname "$LOG_FILE")"
    
    log "INFO" "${BLUE}Waiting for all services to be healthy...${NC}"
    log "INFO" "Timeout: ${TIMEOUT} seconds"
    
    local failed_services=()
    local healthy_count=0
    local total_count=${#SERVICES[@]}
    
    # Check each service
    for service in "${!SERVICES[@]}"; do
        if wait_for_service "$service"; then
            ((healthy_count++))
        else
            failed_services+=("$service")
        fi
    done
    
    echo ""
    log "INFO" "================================================"
    log "INFO" "Health Check Summary:"
    log "INFO" "${GREEN}Healthy: $healthy_count/$total_count${NC}"
    
    if [ ${#failed_services[@]} -gt 0 ]; then
        log "ERROR" "${RED}Failed services: ${failed_services[*]}${NC}"
        
        # Show docker logs for failed services
        for service in "${failed_services[@]}"; do
            log "ERROR" "Logs for $service:"
            docker-compose -f "$PROJECT_ROOT/docker/docker-compose.yml" logs --tail=20 "$service" 2>&1 | while read line; do
                log "ERROR" "  $line"
            done
        done
        
        return 1
    else
        log "INFO" "${GREEN}✓ All services are healthy!${NC}"
        return 0
    fi
}

# Run main
main "$@"