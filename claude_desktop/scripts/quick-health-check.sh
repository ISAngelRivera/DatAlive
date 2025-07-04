#!/bin/bash
# DataLive Quick Health Check
# Simple, fast verification of all services

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Service configuration
declare -A SERVICES=(
    ["neo4j"]="7474:7687"
    ["postgres"]="5432"
    ["redis"]="6379" 
    ["qdrant"]="6333"
    ["ollama"]="11434"
    ["datalive-agent"]="8058"
    ["n8n"]="5678"
    ["prometheus"]="9090"
    ["grafana"]="3000"
    ["minio"]="9000:9001"
)

# Global counters
TOTAL_SERVICES=0
HEALTHY_SERVICES=0
EXIT_CODE=0

echo -e "${CYAN}🚀 DataLive Quick Health Check${NC}"
echo -e "${CYAN}==============================${NC}"
echo ""

# Function to check service quickly
quick_check_service() {
    local service_name="$1"
    local ports="$2"
    
    TOTAL_SERVICES=$((TOTAL_SERVICES + 1))
    
    # Find container name
    local container_name=""
    local container_found=false
    
    # Try different naming patterns
    for pattern in "${service_name}" "datalive-${service_name}" "datalive_${service_name}" "${service_name}-1" "datalive_${service_name}_1"; do
        if docker ps --format "{{.Names}}" | grep -q "^${pattern}$"; then
            container_name="${pattern}"
            container_found=true
            break
        fi
    done
    
    if [ "${container_found}" = false ]; then
        # Try partial matches
        container_name=$(docker ps --format "{{.Names}}" | grep "${service_name}" | head -1)
        if [ -n "${container_name}" ]; then
            container_found=true
        fi
    fi
    
    if [ "${container_found}" = false ]; then
        echo -e "${RED}❌ ${service_name^}${NC} - Container not found"
        EXIT_CODE=1
        return 1
    fi
    
    # Check container status
    local container_status=$(docker inspect --format='{{.State.Status}}' "${container_name}" 2>/dev/null)
    local container_health=$(docker inspect --format='{{.State.Health.Status}}' "${container_name}" 2>/dev/null || echo "no-healthcheck")
    
    if [ "${container_status}" = "running" ]; then
        if [ "${container_health}" = "healthy" ] || [ "${container_health}" = "no-healthcheck" ]; then
            echo -e "${GREEN}✅ ${service_name^}${NC} - Running (${container_name})"
            HEALTHY_SERVICES=$((HEALTHY_SERVICES + 1))
        else
            echo -e "${YELLOW}⚠️  ${service_name^}${NC} - Running but unhealthy (${container_health})"
            EXIT_CODE=1
        fi
    else
        echo -e "${RED}❌ ${service_name^}${NC} - Not running (${container_status})"
        EXIT_CODE=1
    fi
}

# Function to check Docker quickly
quick_check_docker() {
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}❌ Docker not installed${NC}"
        EXIT_CODE=1
        return 1
    fi
    
    if ! docker info &> /dev/null; then
        echo -e "${RED}❌ Docker daemon not running${NC}"
        EXIT_CODE=1
        return 1
    fi
    
    echo -e "${GREEN}✅ Docker${NC} - Available"
    return 0
}

# Function to check connectivity quickly (optional)
quick_check_connectivity() {
    # Find DataLive agent container
    local agent_container=$(docker ps --format "{{.Names}}" | grep -i "datalive" | head -1)
    
    if [ -z "${agent_container}" ]; then
        echo -e "${YELLOW}⚠️  Inter-service connectivity${NC} - Cannot test (no agent container)"
        return 0
    fi
    
    # Test key connections quickly
    local failed_connections=0
    local total_connections=0
    
    for service in "postgres:5432" "redis:6379" "qdrant:6333"; do
        total_connections=$((total_connections + 1))
        local service_name=$(echo "${service}" | cut -d':' -f1)
        local port=$(echo "${service}" | cut -d':' -f2)
        
        if ! docker exec "${agent_container}" timeout 2 nc -z "${service_name}" "${port}" &>/dev/null; then
            failed_connections=$((failed_connections + 1))
        fi
    done
    
    if [ ${failed_connections} -eq 0 ]; then
        echo -e "${GREEN}✅ Inter-service connectivity${NC} - All core services reachable"
    elif [ ${failed_connections} -eq ${total_connections} ]; then
        echo -e "${RED}❌ Inter-service connectivity${NC} - No services reachable"
        EXIT_CODE=1
    else
        echo -e "${YELLOW}⚠️  Inter-service connectivity${NC} - ${failed_connections}/${total_connections} connections failed"
        EXIT_CODE=1
    fi
}

# Main execution
main() {
    # Check Docker first
    if ! quick_check_docker; then
        echo -e "${RED}❌ Cannot proceed without Docker${NC}"
        exit 1
    fi
    
    echo ""
    
    # Check all services
    for service in "${!SERVICES[@]}"; do
        quick_check_service "${service}" "${SERVICES[${service}]}"
    done
    
    echo ""
    
    # Quick connectivity check
    quick_check_connectivity
    
    echo ""
    echo -e "${WHITE}📊 SUMMARY${NC}"
    echo -e "${WHITE}=========${NC}"
    
    local health_percentage=$((HEALTHY_SERVICES * 100 / TOTAL_SERVICES))
    
    echo -e "Services: ${HEALTHY_SERVICES}/${TOTAL_SERVICES} healthy (${health_percentage}%)"
    
    if [ ${EXIT_CODE} -eq 0 ]; then
        echo -e "${GREEN}✅ All systems operational${NC}"
        echo -e "${BLUE}🚀 Ready for DataLive operations${NC}"
    else
        echo -e "${RED}❌ Issues detected${NC}"
        echo -e "${YELLOW}🔧 Run ./infrastructure-diagnostic.sh for detailed analysis${NC}"
    fi
    
    echo ""
    echo -e "${CYAN}💡 Tip: Use './infrastructure-diagnostic.sh' for comprehensive diagnostics${NC}"
    
    exit ${EXIT_CODE}
}

# Handle command line options
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "DataLive Quick Health Check"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  --no-color     Disable colored output"
    echo ""
    echo "Exit codes:"
    echo "  0 - All services healthy"
    echo "  1 - One or more issues detected"
    echo ""
    echo "For detailed diagnostics, use: ./infrastructure-diagnostic.sh"
    exit 0
fi

if [ "$1" = "--no-color" ]; then
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    CYAN=''
    WHITE=''
    NC=''
fi

# Execute main function
main "$@"