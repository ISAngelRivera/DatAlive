#!/bin/bash
# DataLive Infrastructure Diagnostic Script
# Generates comprehensive system health report for Claude Desktop review

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
REPORT_FILE="${SCRIPT_DIR}/../reports/infrastructure-report.md"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S UTC')

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
CRITICAL_ISSUES=()
WARNINGS=()
RECOMMENDATIONS=()

echo -e "${CYAN}🚀 DataLive Infrastructure Diagnostic Starting...${NC}"
echo -e "${WHITE}Generated at: ${TIMESTAMP}${NC}"
echo -e "${WHITE}Report will be saved to: ${REPORT_FILE}${NC}"
echo ""

# Initialize report
cat > "${REPORT_FILE}" << EOF
# DataLive Infrastructure Diagnostic Report

**Generated:** ${TIMESTAMP}  
**System:** $(uname -s) $(uname -r)  
**Docker:** $(docker --version 2>/dev/null || echo "Not available")  
**Docker Compose:** $(docker-compose --version 2>/dev/null || echo "Not available")

---

EOF

# Function to log to both console and report
log_both() {
    local level="$1"
    local message="$2"
    local color_message="$3"
    
    echo -e "${color_message}"
    echo "${message}" >> "${REPORT_FILE}"
}

# Function to check Docker installation
check_docker() {
    echo -e "${BLUE}📋 Checking Docker Environment...${NC}"
    
    if ! command -v docker &> /dev/null; then
        log_both "ERROR" "❌ Docker not installed" "${RED}❌ Docker not installed${NC}"
        CRITICAL_ISSUES+=("Docker not installed")
        return 1
    fi
    
    if ! docker info &> /dev/null; then
        log_both "ERROR" "❌ Docker daemon not running" "${RED}❌ Docker daemon not running${NC}"
        CRITICAL_ISSUES+=("Docker daemon not running")
        return 1
    fi
    
    local docker_version=$(docker --version | cut -d' ' -f3 | tr -d ',')
    log_both "INFO" "✅ Docker version: ${docker_version}" "${GREEN}✅ Docker version: ${docker_version}${NC}"
    
    if ! command -v docker-compose &> /dev/null; then
        log_both "WARN" "⚠️  Docker Compose not found (checking docker compose plugin)" "${YELLOW}⚠️  Docker Compose not found (checking docker compose plugin)${NC}"
        if ! docker compose version &> /dev/null; then
            CRITICAL_ISSUES+=("Docker Compose not available")
            return 1
        fi
    fi
    
    local compose_version=$(docker-compose --version 2>/dev/null || docker compose version | head -1)
    log_both "INFO" "✅ ${compose_version}" "${GREEN}✅ ${compose_version}${NC}"
    
    return 0
}

# Function to get container stats
get_container_stats() {
    local container_name="$1"
    
    if docker ps --format "table {{.Names}}" | grep -q "^${container_name}$"; then
        local stats=$(docker stats --no-stream --format "table {{.CPUPerc}}\t{{.MemUsage}}" "${container_name}" 2>/dev/null | tail -n +2)
        echo "${stats}"
    else
        echo "Container not running"
    fi
}

# Function to check service health
check_service_health() {
    local service_name="$1"
    local ports="$2"
    
    echo -e "${PURPLE}🔍 Checking ${service_name}...${NC}"
    
    TOTAL_SERVICES=$((TOTAL_SERVICES + 1))
    
    # Find container name patterns
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
    
    cat >> "${REPORT_FILE}" << EOF

## ${service_name^} Service

EOF
    
    if [ "${container_found}" = false ]; then
        log_both "ERROR" "❌ Container not found for ${service_name}" "${RED}❌ Container not found for ${service_name}${NC}"
        CRITICAL_ISSUES+=("${service_name} container not found")
        
        cat >> "${REPORT_FILE}" << EOF
**Status:** ❌ Container not found  
**Ports:** ${ports}  
**Issue:** Container does not exist or is not running

EOF
        return 1
    fi
    
    # Check container status
    local container_status=$(docker inspect --format='{{.State.Status}}' "${container_name}" 2>/dev/null)
    local container_health=$(docker inspect --format='{{.State.Health.Status}}' "${container_name}" 2>/dev/null || echo "no-healthcheck")
    
    if [ "${container_status}" = "running" ]; then
        if [ "${container_health}" = "healthy" ] || [ "${container_health}" = "no-healthcheck" ]; then
            log_both "SUCCESS" "✅ ${service_name} is running" "${GREEN}✅ ${service_name} is running${NC}"
            HEALTHY_SERVICES=$((HEALTHY_SERVICES + 1))
        else
            log_both "WARN" "⚠️  ${service_name} running but unhealthy (${container_health})" "${YELLOW}⚠️  ${service_name} running but unhealthy (${container_health})${NC}"
            WARNINGS+=("${service_name} unhealthy: ${container_health}")
        fi
    else
        log_both "ERROR" "❌ ${service_name} not running (${container_status})" "${RED}❌ ${service_name} not running (${container_status})${NC}"
        CRITICAL_ISSUES+=("${service_name} not running: ${container_status}")
    fi
    
    # Get container stats
    local stats=$(get_container_stats "${container_name}")
    
    # Get container image
    local image=$(docker inspect --format='{{.Config.Image}}' "${container_name}" 2>/dev/null || echo "unknown")
    
    # Get recent logs (last 20 lines)
    local logs=$(docker logs --tail 20 "${container_name}" 2>&1 | head -20)
    
    cat >> "${REPORT_FILE}" << EOF
**Status:** ${container_status} (Health: ${container_health})  
**Container:** ${container_name}  
**Image:** ${image}  
**Ports:** ${ports}  
**Stats:** ${stats}

**Recent Logs:**
\`\`\`
${logs}
\`\`\`

EOF
    
    # Service-specific checks
    case "${service_name}" in
        "neo4j")
            check_neo4j_specific "${container_name}"
            ;;
        "postgres")
            check_postgres_specific "${container_name}"
            ;;
        "redis")
            check_redis_specific "${container_name}"
            ;;
        "qdrant")
            check_qdrant_specific "${container_name}"
            ;;
        "ollama")
            check_ollama_specific "${container_name}"
            ;;
        "datalive-agent")
            check_agent_specific "${container_name}"
            ;;
        "n8n")
            check_n8n_specific "${container_name}"
            ;;
    esac
}

# Neo4j specific checks
check_neo4j_specific() {
    local container="$1"
    
    echo -e "  ${CYAN}🔍 Neo4j specific checks...${NC}"
    
    # Check APOC plugin
    local apoc_check=$(docker exec "${container}" sh -c "ls /var/lib/neo4j/plugins/ | grep apoc" 2>/dev/null || echo "")
    if [ -n "${apoc_check}" ]; then
        log_both "INFO" "  ✅ APOC plugin found: ${apoc_check}" "${GREEN}  ✅ APOC plugin found${NC}"
    else
        log_both "WARN" "  ⚠️  APOC plugin not found" "${YELLOW}  ⚠️  APOC plugin not found${NC}"
        WARNINGS+=("Neo4j APOC plugin missing")
    fi
    
    # Check GDS plugin
    local gds_check=$(docker exec "${container}" sh -c "ls /var/lib/neo4j/plugins/ | grep gds" 2>/dev/null || echo "")
    if [ -n "${gds_check}" ]; then
        log_both "INFO" "  ✅ GDS plugin found: ${gds_check}" "${GREEN}  ✅ GDS plugin found${NC}"
    else
        log_both "WARN" "  ⚠️  GDS plugin not found" "${YELLOW}  ⚠️  GDS plugin not found${NC}"
        WARNINGS+=("Neo4j GDS plugin missing")
    fi
    
    cat >> "${REPORT_FILE}" << EOF
**Neo4j Plugins:**
- APOC: ${apoc_check:-"Not found"}
- GDS: ${gds_check:-"Not found"}

EOF
}

# PostgreSQL specific checks
check_postgres_specific() {
    local container="$1"
    
    echo -e "  ${CYAN}🔍 PostgreSQL specific checks...${NC}"
    
    # Check databases
    local databases=$(docker exec "${container}" psql -U datalive_user -d datalive_db -t -c "SELECT datname FROM pg_database WHERE datistemplate = false;" 2>/dev/null | xargs || echo "Error connecting")
    
    # Check schemas
    local schemas=$(docker exec "${container}" psql -U datalive_user -d datalive_db -t -c "SELECT schema_name FROM information_schema.schemata WHERE schema_name IN ('rag', 'cag', 'monitoring');" 2>/dev/null | xargs || echo "Error connecting")
    
    cat >> "${REPORT_FILE}" << EOF
**PostgreSQL Details:**
- Databases: ${databases}
- DataLive Schemas: ${schemas}

EOF
    
    if [[ "${schemas}" == *"rag"* ]] && [[ "${schemas}" == *"cag"* ]] && [[ "${schemas}" == *"monitoring"* ]]; then
        log_both "INFO" "  ✅ All required schemas present" "${GREEN}  ✅ All required schemas present${NC}"
    else
        log_both "WARN" "  ⚠️  Missing required schemas" "${YELLOW}  ⚠️  Missing required schemas${NC}"
        WARNINGS+=("PostgreSQL missing required schemas")
    fi
}

# Redis specific checks
check_redis_specific() {
    local container="$1"
    
    echo -e "  ${CYAN}🔍 Redis specific checks...${NC}"
    
    local info=$(docker exec "${container}" redis-cli info memory 2>/dev/null | grep used_memory_human || echo "Error connecting")
    local keys=$(docker exec "${container}" redis-cli dbsize 2>/dev/null || echo "Error connecting")
    
    cat >> "${REPORT_FILE}" << EOF
**Redis Details:**
- Memory Usage: ${info}
- Total Keys: ${keys}

EOF
}

# Qdrant specific checks
check_qdrant_specific() {
    local container="$1"
    
    echo -e "  ${CYAN}🔍 Qdrant specific checks...${NC}"
    
    # Check collections via API
    local collections=$(docker exec "${container}" curl -s "http://localhost:6333/collections" 2>/dev/null | jq -r '.result.collections[].name' 2>/dev/null | tr '\n' ',' || echo "Error connecting")
    
    cat >> "${REPORT_FILE}" << EOF
**Qdrant Details:**
- Collections: ${collections}

EOF
    
    if [[ "${collections}" == *"documents"* ]] && [[ "${collections}" == *"entities"* ]]; then
        log_both "INFO" "  ✅ Required collections present" "${GREEN}  ✅ Required collections present${NC}"
    else
        log_both "WARN" "  ⚠️  Missing required collections" "${YELLOW}  ⚠️  Missing required collections${NC}"
        WARNINGS+=("Qdrant missing required collections")
    fi
}

# Ollama specific checks
check_ollama_specific() {
    local container="$1"
    
    echo -e "  ${CYAN}🔍 Ollama specific checks...${NC}"
    
    local models=$(docker exec "${container}" ollama list 2>/dev/null | tail -n +2 | awk '{print $1}' | tr '\n' ',' || echo "Error connecting")
    
    cat >> "${REPORT_FILE}" << EOF
**Ollama Details:**
- Available Models: ${models}

EOF
    
    if [ "${models}" = "Error connecting" ] || [ -z "${models}" ]; then
        log_both "WARN" "  ⚠️  No models found or connection error" "${YELLOW}  ⚠️  No models found or connection error${NC}"
        WARNINGS+=("Ollama has no models or connection issues")
    else
        log_both "INFO" "  ✅ Models available: ${models}" "${GREEN}  ✅ Models available${NC}"
    fi
}

# DataLive Agent specific checks
check_agent_specific() {
    local container="$1"
    
    echo -e "  ${CYAN}🔍 DataLive Agent specific checks...${NC}"
    
    # Try to curl health endpoint
    local health=$(docker exec "${container}" curl -s "http://localhost:8058/health" 2>/dev/null || echo "Error connecting")
    
    cat >> "${REPORT_FILE}" << EOF
**DataLive Agent Details:**
- Health Check: ${health}

EOF
    
    if [[ "${health}" == *"healthy"* ]] || [[ "${health}" == *"ok"* ]]; then
        log_both "INFO" "  ✅ Health endpoint responding" "${GREEN}  ✅ Health endpoint responding${NC}"
    else
        log_both "WARN" "  ⚠️  Health endpoint not responding" "${YELLOW}  ⚠️  Health endpoint not responding${NC}"
        WARNINGS+=("DataLive Agent health endpoint not responding")
    fi
}

# N8N specific checks
check_n8n_specific() {
    local container="$1"
    
    echo -e "  ${CYAN}🔍 N8N specific checks...${NC}"
    
    # Try to curl health endpoint
    local health=$(docker exec "${container}" curl -s "http://localhost:5678/healthz" 2>/dev/null || echo "Error connecting")
    
    cat >> "${REPORT_FILE}" << EOF
**N8N Details:**
- Health Check: ${health}

EOF
}

# Function to check connectivity between services
check_connectivity() {
    echo -e "${BLUE}🔗 Checking Inter-Service Connectivity...${NC}"
    
    cat >> "${REPORT_FILE}" << EOF

## Inter-Service Connectivity

EOF
    
    # Get running containers
    local containers=$(docker ps --format "{{.Names}}" | grep -E "(neo4j|postgres|redis|qdrant|ollama|datalive|n8n)" || true)
    
    if [ -z "${containers}" ]; then
        log_both "ERROR" "❌ No DataLive containers running" "${RED}❌ No DataLive containers running${NC}"
        CRITICAL_ISSUES+=("No DataLive containers running")
        return 1
    fi
    
    # Test key connections from datalive-agent
    local agent_container=$(echo "${containers}" | grep -i "datalive" | head -1)
    
    if [ -n "${agent_container}" ]; then
        echo -e "  ${CYAN}Testing from ${agent_container}...${NC}"
        
        # Test database connections
        for service in "postgres:5432" "redis:6379" "qdrant:6333" "neo4j:7687" "ollama:11434"; do
            local service_name=$(echo "${service}" | cut -d':' -f1)
            local port=$(echo "${service}" | cut -d':' -f2)
            
            local result=$(docker exec "${agent_container}" timeout 5 nc -z "${service_name}" "${port}" 2>/dev/null && echo "✅ Connected" || echo "❌ Failed")
            log_both "INFO" "  ${service}: ${result}" "${NC}  ${service}: ${result}${NC}"
            
            cat >> "${REPORT_FILE}" << EOF
- **${service}:** ${result}
EOF
        done
    else
        log_both "WARN" "⚠️  DataLive agent container not found for connectivity tests" "${YELLOW}⚠️  DataLive agent container not found for connectivity tests${NC}"
        WARNINGS+=("Cannot test inter-service connectivity - agent container not found")
    fi
}

# Function to check important files
check_files() {
    echo -e "${BLUE}📁 Checking Important Files...${NC}"
    
    cat >> "${REPORT_FILE}" << EOF

## File System Checks

EOF
    
    local files_to_check=(
        "docker-compose.yml"
        ".env"
        "datalive_agent/pyproject.toml"
        "init-automated-configs/postgres/init.sql"
        "init-automated-configs/qdrant/setup.sh"
        "docs/datalive_complete_project.md"
    )
    
    for file in "${files_to_check[@]}"; do
        if [ -f "${PROJECT_ROOT}/${file}" ]; then
            local size=$(stat -f%z "${PROJECT_ROOT}/${file}" 2>/dev/null || stat -c%s "${PROJECT_ROOT}/${file}" 2>/dev/null || echo "unknown")
            log_both "INFO" "✅ ${file} (${size} bytes)" "${GREEN}✅ ${file} (${size} bytes)${NC}"
            
            cat >> "${REPORT_FILE}" << EOF
- **${file}:** ✅ Present (${size} bytes)
EOF
        else
            log_both "WARN" "⚠️  ${file} not found" "${YELLOW}⚠️  ${file} not found${NC}"
            WARNINGS+=("Missing file: ${file}")
            
            cat >> "${REPORT_FILE}" << EOF
- **${file}:** ❌ Missing
EOF
        fi
    done
}

# Function to generate final summary
generate_summary() {
    echo -e "${WHITE}📊 Generating Final Report...${NC}"
    
    local health_percentage=$((HEALTHY_SERVICES * 100 / TOTAL_SERVICES))
    
    # Insert summary at the beginning of the report
    local temp_file=$(mktemp)
    cat > "${temp_file}" << EOF
# DataLive Infrastructure Diagnostic Report

**Generated:** ${TIMESTAMP}  
**System:** $(uname -s) $(uname -r)  
**Docker:** $(docker --version 2>/dev/null || echo "Not available")  
**Docker Compose:** $(docker-compose --version 2>/dev/null || echo "Not available")

---

## Executive Summary

| Metric | Value |
|--------|-------|
| **Total Services** | ${TOTAL_SERVICES} |
| **Healthy Services** | ${HEALTHY_SERVICES} |
| **Health Percentage** | ${health_percentage}% |
| **Critical Issues** | ${#CRITICAL_ISSUES[@]} |
| **Warnings** | ${#WARNINGS[@]} |

## Service Status Overview

| Service | Status | Health |
|---------|--------|--------|
EOF
    
    # Add service status table
    for service in "${!SERVICES[@]}"; do
        local container_name=""
        local container_found=false
        
        # Try different naming patterns
        for pattern in "${service}" "datalive-${service}" "datalive_${service}" "${service}-1" "datalive_${service}_1"; do
            if docker ps --format "{{.Names}}" | grep -q "^${pattern}$"; then
                container_name="${pattern}"
                container_found=true
                break
            fi
        done
        
        if [ "${container_found}" = false ]; then
            container_name=$(docker ps --format "{{.Names}}" | grep "${service}" | head -1)
            if [ -n "${container_name}" ]; then
                container_found=true
            fi
        fi
        
        if [ "${container_found}" = true ]; then
            local status=$(docker inspect --format='{{.State.Status}}' "${container_name}" 2>/dev/null)
            local health=$(docker inspect --format='{{.State.Health.Status}}' "${container_name}" 2>/dev/null || echo "no-healthcheck")
            
            if [ "${status}" = "running" ]; then
                if [ "${health}" = "healthy" ] || [ "${health}" = "no-healthcheck" ]; then
                    echo "| ${service} | ✅ Running | ✅ ${health} |" >> "${temp_file}"
                else
                    echo "| ${service} | ⚠️ Running | ❌ ${health} |" >> "${temp_file}"
                fi
            else
                echo "| ${service} | ❌ ${status} | ❌ N/A |" >> "${temp_file}"
            fi
        else
            echo "| ${service} | ❌ Not Found | ❌ N/A |" >> "${temp_file}"
        fi
    done
    
    # Add critical issues section
    cat >> "${temp_file}" << EOF

## Critical Issues

EOF
    
    if [ ${#CRITICAL_ISSUES[@]} -eq 0 ]; then
        echo "✅ No critical issues detected" >> "${temp_file}"
    else
        for issue in "${CRITICAL_ISSUES[@]}"; do
            echo "- ❌ ${issue}" >> "${temp_file}"
        done
    fi
    
    # Add warnings section
    cat >> "${temp_file}" << EOF

## Warnings

EOF
    
    if [ ${#WARNINGS[@]} -eq 0 ]; then
        echo "✅ No warnings" >> "${temp_file}"
    else
        for warning in "${WARNINGS[@]}"; do
            echo "- ⚠️ ${warning}" >> "${temp_file}"
        done
    fi
    
    # Add recommendations
    cat >> "${temp_file}" << EOF

## Recommendations

EOF
    
    generate_recommendations >> "${temp_file}"
    
    # Append the rest of the report
    echo "" >> "${temp_file}"
    echo "---" >> "${temp_file}"
    echo "" >> "${temp_file}"
    echo "# Detailed Service Reports" >> "${temp_file}"
    
    # Skip the header in the original report and append the rest
    tail -n +7 "${REPORT_FILE}" >> "${temp_file}"
    
    mv "${temp_file}" "${REPORT_FILE}"
}

# Function to generate recommendations
generate_recommendations() {
    if [ ${#CRITICAL_ISSUES[@]} -gt 0 ]; then
        echo "### Critical Actions Required:"
        for issue in "${CRITICAL_ISSUES[@]}"; do
            case "${issue}" in
                *"Docker"*)
                    echo "- 🚨 Install Docker and Docker Compose before proceeding"
                    ;;
                *"not running"*)
                    echo "- 🚨 Start missing services with: \`docker-compose up -d\`"
                    ;;
                *"not found"*)
                    echo "- 🚨 Check docker-compose.yml configuration for missing services"
                    ;;
            esac
        done
        echo ""
    fi
    
    if [ ${#WARNINGS[@]} -gt 0 ]; then
        echo "### Recommended Improvements:"
        for warning in "${WARNINGS[@]}"; do
            case "${warning}" in
                *"APOC"*)
                    echo "- 📦 Install Neo4j APOC plugin for enhanced functionality"
                    ;;
                *"GDS"*)
                    echo "- 📦 Install Neo4j GDS plugin for graph algorithms"
                    ;;
                *"models"*)
                    echo "- 🤖 Download required Ollama models: \`docker exec ollama-container ollama pull phi-4:latest\`"
                    ;;
                *"health"*)
                    echo "- 🔍 Investigate health check failures in container logs"
                    ;;
                *"collections"*)
                    echo "- 🗄️ Initialize Qdrant collections using setup scripts"
                    ;;
                *"schemas"*)
                    echo "- 🗄️ Initialize PostgreSQL schemas using init scripts"
                    ;;
            esac
        done
        echo ""
    fi
    
    # Always recommend if health is below 90%
    local health_percentage=$((HEALTHY_SERVICES * 100 / TOTAL_SERVICES))
    if [ ${health_percentage} -lt 90 ]; then
        echo "### Performance Optimization:"
        echo "- 🔧 System health is ${health_percentage}% - investigate failing services"
        echo "- 📊 Run detailed logs analysis: \`docker-compose logs [service-name]\`"
        echo "- 🔄 Consider restarting unhealthy services: \`docker-compose restart [service-name]\`"
        echo ""
    fi
    
    echo "### Next Steps:"
    echo "- 📋 Review this report with Claude Desktop for optimization recommendations"
    echo "- 🔧 Execute suggested fixes in order of priority (Critical → Warnings → Performance)"
    echo "- ✅ Re-run this diagnostic after fixes: \`./claude_desktop/scripts/infrastructure-diagnostic.sh\`"
    echo "- 🚀 Proceed with N8N workflow implementation once infrastructure is stable"
}

# Main execution
main() {
    echo -e "${WHITE}🔍 DataLive Infrastructure Diagnostic${NC}"
    echo -e "${WHITE}=====================================${NC}"
    echo ""
    
    # Check Docker first
    if ! check_docker; then
        echo -e "${RED}❌ Docker environment check failed. Cannot proceed.${NC}"
        exit 1
    fi
    
    echo ""
    
    # Check all services
    for service in "${!SERVICES[@]}"; do
        check_service_health "${service}" "${SERVICES[${service}]}"
        echo ""
    done
    
    # Check connectivity
    check_connectivity
    echo ""
    
    # Check files
    check_files
    echo ""
    
    # Generate final report
    generate_summary
    
    # Print summary to console
    echo -e "${WHITE}📊 DIAGNOSTIC SUMMARY${NC}"
    echo -e "${WHITE}===================${NC}"
    echo -e "Total Services: ${TOTAL_SERVICES}"
    echo -e "Healthy Services: ${HEALTHY_SERVICES}"
    echo -e "Health Percentage: $((HEALTHY_SERVICES * 100 / TOTAL_SERVICES))%"
    echo -e "Critical Issues: ${#CRITICAL_ISSUES[@]}"
    echo -e "Warnings: ${#WARNINGS[@]}"
    echo ""
    echo -e "${GREEN}✅ Report generated: ${REPORT_FILE}${NC}"
    echo -e "${BLUE}📋 Ready for Claude Desktop review${NC}"
    
    # Exit code based on critical issues
    if [ ${#CRITICAL_ISSUES[@]} -gt 0 ]; then
        exit 1
    else
        exit 0
    fi
}

# Execute main function
main "$@"