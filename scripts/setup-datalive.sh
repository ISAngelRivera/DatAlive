#!/bin/bash
# setup-datalive.sh - Script principal de configuración completa
# Orquesta todos los scripts de inicialización leyendo desde .env

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
    echo "Please copy .env.example to .env and configure it"
    exit 1
fi

# Configuration
LOG_FILE="${PROJECT_ROOT}/logs/setup-complete.log"
SKIP_HEALTH_CHECKS="${SKIP_HEALTH_CHECKS:-false}"
ENABLE_TEST_MODE="${ENABLE_TEST_MODE:-false}"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# ASCII Art Banner
print_banner() {
    echo -e "${CYAN}"
    cat << "EOF"
    ____        __        __    _           
   / __ \____ _/ /_____ _/ /   (_)   _____  
  / / / / __ `/ __/ __ `/ /   / / | / / _ \ 
 / /_/ / /_/ / /_/ /_/ / /___/ /| |/ /  __/ 
/_____/\__,_/\__/\__,_/_____/_/ |___/\___/  
                                             
   RAG System Setup v2.0 - 2025 Edition
EOF
    echo -e "${NC}"
}

# Logging function
log() {
    local level=$1
    shift
    echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] [${level}] $*" | tee -a "${LOG_FILE}"
}

# Create required directories
setup_directories() {
    log "INFO" "Creating required directories..."
    
    local dirs=(
        "logs"
        "secrets"
        "config/n8n"
        "config/ollama"
        "config/minio"
        "config/prometheus"
        "config/grafana/provisioning/datasources"
        "config/grafana/provisioning/dashboards"
        "config/grafana/dashboards"
        "config/loki"
        "config/promtail"
        "config/qdrant"
        "backups/postgres"
        "backups/qdrant"
        "backups/n8n"
        "workflows/ingestion"
        "workflows/query"
        "workflows/optimization"
    )
    
    for dir in "${dirs[@]}"; do
        mkdir -p "${PROJECT_ROOT}/${dir}"
    done
    
    log "INFO" "${GREEN}✓ Directories created${NC}"
}

# Generate secrets if they don't exist
generate_secrets() {
    log "INFO" "Checking and generating secrets..."
    
    local secrets_generated=0
    
    # Function to generate secure password
    generate_password() {
        openssl rand -base64 32 | tr -d "=+/" | cut -c1-25
    }
    
    # Check each secret file
    if [ ! -f "${PROJECT_ROOT}/secrets/postgres_password.txt" ]; then
        generate_password > "${PROJECT_ROOT}/secrets/postgres_password.txt"
        log "INFO" "Generated PostgreSQL password"
        ((secrets_generated++))
    fi
    
    if [ ! -f "${PROJECT_ROOT}/secrets/minio_secret_key.txt" ]; then
        generate_password > "${PROJECT_ROOT}/secrets/minio_secret_key.txt"
        log "INFO" "Generated MinIO secret key"
        ((secrets_generated++))
    fi
    
    if [ ! -f "${PROJECT_ROOT}/secrets/n8n_encryption_key.txt" ]; then
        generate_password > "${PROJECT_ROOT}/secrets/n8n_encryption_key.txt"
        log "INFO" "Generated N8N encryption key"
        ((secrets_generated++))
    fi
    
    if [ ! -f "${PROJECT_ROOT}/secrets/grafana_password.txt" ]; then
        generate_password > "${PROJECT_ROOT}/secrets/grafana_password.txt"
        log "INFO" "Generated Grafana password"
        ((secrets_generated++))
    fi
    
    # Set secure permissions on secrets
    chmod 600 "${PROJECT_ROOT}"/secrets/*.txt
    
    if [ $secrets_generated -gt 0 ]; then
        log "INFO" "${GREEN}✓ Generated ${secrets_generated} new secrets${NC}"
    else
        log "INFO" "${GREEN}✓ All secrets already exist${NC}"
    fi
}

# Validate environment configuration
validate_env() {
    log "INFO" "Validating environment configuration..."
    
    local errors=0
    local warnings=0
    
    # Required variables
    local required_vars=(
        "POSTGRES_USER"
        "POSTGRES_DB"
        "MINIO_ROOT_USER"
        "N8N_USER_EMAIL"
        "N8N_USER_FIRSTNAME"
        "N8N_USER_LASTNAME"
        "N8N_LICENSE_KEY"
        "GRAFANA_USER"
        "OLLAMA_LLM_PRIMARY"
        "OLLAMA_EMBED_TEXT_PRIMARY"
    )
    
    for var in "${required_vars[@]}"; do
        if [ -z "${!var:-}" ]; then
            log "ERROR" "${RED}Missing required variable: $var${NC}"
            ((errors++))
        fi
    done
    
    # Check for default passwords
    if [ "${N8N_USER_PASSWORD}" = "ChangeMe123!" ]; then
        log "WARN" "${YELLOW}Using default N8N password - please change it!${NC}"
        ((warnings++))
    fi
    
    if [ "${REDIS_PASSWORD}" = "change_this_redis_password" ]; then
        log "WARN" "${YELLOW}Using default Redis password - please change it!${NC}"
        ((warnings++))
    fi
    
    # Validate email format
    if ! [[ "${N8N_USER_EMAIL}" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        log "ERROR" "${RED}Invalid email format: ${N8N_USER_EMAIL}${NC}"
        ((errors++))
    fi
    
    if [ $errors -gt 0 ]; then
        log "ERROR" "${RED}Environment validation failed with $errors errors${NC}"
        return 1
    fi
    
    if [ $warnings -gt 0 ]; then
        log "WARN" "${YELLOW}Environment validation completed with $warnings warnings${NC}"
    else
        log "INFO" "${GREEN}✓ Environment validation passed${NC}"
    fi
    
    return 0
}

# Check Docker and Docker Compose
check_docker() {
    log "INFO" "Checking Docker installation..."
    
    if ! command -v docker &> /dev/null; then
        log "ERROR" "${RED}Docker is not installed${NC}"
        return 1
    fi
    
    if ! docker info &> /dev/null; then
        log "ERROR" "${RED}Docker daemon is not running${NC}"
        return 1
    fi
    
    local docker_version=$(docker --version | grep -oP '\d+\.\d+\.\d+')
    log "INFO" "Docker version: $docker_version"
    
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        log "ERROR" "${RED}Docker Compose is not installed${NC}"
        return 1
    fi
    
    log "INFO" "${GREEN}✓ Docker and Docker Compose are ready${NC}"
    return 0
}

# Start Docker stack
start_docker_stack() {
    log "INFO" "${BLUE}Starting Docker stack...${NC}"
    
    cd "${PROJECT_ROOT}"
    
    # Pull latest images
    log "INFO" "Pulling latest Docker images..."
    docker-compose -f docker/docker-compose.yml pull
    
    # Start services with environment file
    log "INFO" "Starting services..."
    docker-compose -f docker/docker-compose.yml --env-file .env up -d
    
    # Wait for services to be healthy
    if [ "$SKIP_HEALTH_CHECKS" != "true" ]; then
        log "INFO" "Waiting for services to be healthy..."
        "${SCRIPT_DIR}/wait-for-healthy.sh"
    fi
    
    log "INFO" "${GREEN}✓ Docker stack started${NC}"
}

# Initialize services
initialize_services() {
    log "INFO" "${BLUE}Initializing services...${NC}"
    
    # Initialize PostgreSQL schemas first (required for N8N)
    log "INFO" "${CYAN}[1/5] Initializing PostgreSQL schemas...${NC}"
    if docker exec datalive-postgres psql -U admin -d datalive_db -f /docker-entrypoint-initdb.d/init.sql > /dev/null 2>&1; then
        log "INFO" "${GREEN}✓ PostgreSQL schemas initialized${NC}"
    else
        log "WARN" "${YELLOW}PostgreSQL schemas may already exist${NC}"
    fi
    
    # Initialize N8N (early, needs database)
    log "INFO" "${CYAN}[2/5] Initializing N8N...${NC}"
    if "${SCRIPT_DIR}/init-n8n-setup.sh"; then
        log "INFO" "${GREEN}✓ N8N initialized with user, credentials, and workflows${NC}"
    else
        log "ERROR" "${RED}Failed to initialize N8N${NC}"
        return 1
    fi
    
    # Initialize MinIO buckets
    log "INFO" "${CYAN}[3/5] Initializing MinIO buckets...${NC}"
    if "${SCRIPT_DIR}/init-minio-buckets.sh"; then
        log "INFO" "${GREEN}✓ MinIO buckets initialized${NC}"
    else
        log "ERROR" "${RED}Failed to initialize MinIO buckets${NC}"
        return 1
    fi
    
    # Initialize Ollama models
    log "INFO" "${CYAN}[4/5] Initializing Ollama models...${NC}"
    if "${SCRIPT_DIR}/init-ollama-models.sh"; then
        log "INFO" "${GREEN}✓ Ollama models initialized${NC}"
    else
        log "ERROR" "${RED}Failed to initialize Ollama models${NC}"
        return 1
    fi
    
    # Initialize Qdrant collections
    log "INFO" "${CYAN}[5/5] Initializing Qdrant collections...${NC}"
    if "${SCRIPT_DIR}/init-qdrant-collections.sh"; then
        log "INFO" "${GREEN}✓ Qdrant collections initialized${NC}"
    else
        log "WARN" "${YELLOW}Failed to initialize Qdrant collections - continuing${NC}"
    fi
    
    log "INFO" "${GREEN}✓ All services initialized${NC}"
}

# Configure monitoring
configure_monitoring() {
    log "INFO" "Configuring monitoring stack..."
    
    # Create Prometheus configuration
    cat > "${PROJECT_ROOT}/config/prometheus/prometheus.yml" <<EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'n8n'
    static_configs:
      - targets: ['n8n:5678']
  
  - job_name: 'postgres'
    static_configs:
      - targets: ['postgres:5432']
  
  - job_name: 'minio'
    static_configs:
      - targets: ['minio:9000']
    metrics_path: /minio/v2/metrics/cluster
  
  - job_name: 'qdrant'
    static_configs:
      - targets: ['qdrant:6333']
    metrics_path: /metrics
EOF
    
    # Create Grafana datasource
    cat > "${PROJECT_ROOT}/config/grafana/provisioning/datasources/prometheus.yml" <<EOF
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    
  - name: Loki
    type: loki
    access: proxy
    url: http://loki:3100
EOF
    
    log "INFO" "${GREEN}✓ Monitoring configured${NC}"
}

# Run post-setup tests
run_tests() {
    if [ "$ENABLE_TEST_MODE" != "true" ]; then
        return 0
    fi
    
    log "INFO" "${BLUE}Running post-setup tests...${NC}"
    
    local tests_passed=0
    local tests_failed=0
    
    # Test N8N API
    if curl -sf "${N8N_URL}/healthz" > /dev/null; then
        log "INFO" "${GREEN}✓ N8N API test passed${NC}"
        ((tests_passed++))
    else
        log "ERROR" "${RED}✗ N8N API test failed${NC}"
        ((tests_failed++))
    fi
    
    # Test Ollama
    if curl -sf "${OLLAMA_URL}/api/tags" > /dev/null; then
        log "INFO" "${GREEN}✓ Ollama API test passed${NC}"
        ((tests_passed++))
    else
        log "ERROR" "${RED}✗ Ollama API test failed${NC}"
        ((tests_failed++))
    fi
    
    # Test MinIO
    if curl -sf "${MINIO_URL}/minio/health/ready" > /dev/null; then
        log "INFO" "${GREEN}✓ MinIO health test passed${NC}"
        ((tests_passed++))
    else
        log "ERROR" "${RED}✗ MinIO health test failed${NC}"
        ((tests_failed++))
    fi
    
    # Test PostgreSQL
    if PGPASSWORD=$(cat "${PROJECT_ROOT}/secrets/postgres_password.txt") \
       psql -h localhost -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -c "SELECT 1" > /dev/null 2>&1; then
        log "INFO" "${GREEN}✓ PostgreSQL connection test passed${NC}"
        ((tests_passed++))
    else
        log "ERROR" "${RED}✗ PostgreSQL connection test failed${NC}"
        ((tests_failed++))
    fi
    
    log "INFO" "Test Results: ${GREEN}${tests_passed} passed${NC}, ${RED}${tests_failed} failed${NC}"
    
    if [ $tests_failed -gt 0 ]; then
        return 1
    fi
    return 0
}

# Generate final summary
generate_summary() {
    local summary_file="${PROJECT_ROOT}/setup-summary.md"
    
    cat > "$summary_file" <<EOF
# DataLive RAG System - Setup Summary

**Date:** $(date)  
**Version:** 2.0  
**Status:** ✅ Successfully Deployed

## 🌐 Service URLs

| Service | URL | Credentials |
|---------|-----|-------------|
| N8N | ${N8N_URL} | ${N8N_USER_EMAIL} |
| MinIO Console | ${MINIO_URL}:9001 | ${MINIO_ROOT_USER} |
| Grafana | http://localhost:3000 | ${GRAFANA_USER} |
| Qdrant Dashboard | http://localhost:6333/dashboard | N/A |

## 📊 Deployed Components

### Core Services
- ✅ N8N Workflow Engine (with ${N8N_LICENSE_KEY:0:8}... license)
- ✅ PostgreSQL Database (${POSTGRES_DB})
- ✅ Qdrant Vector Database
- ✅ MinIO Object Storage
- ✅ Redis Cache
- ✅ Ollama LLM Server

### AI Models
- **Primary LLM:** ${OLLAMA_LLM_PRIMARY}
- **Text Embeddings:** ${OLLAMA_EMBED_TEXT_PRIMARY}
- **Vision Model:** ${OLLAMA_MULTIMODAL_PRIMARY}

### Storage Buckets
$(echo "${MINIO_DEFAULT_BUCKETS}" | tr ',' '\n' | sed 's/^/- /')

## 📁 Configuration Files

- N8N Credentials: \`config/n8n/credential-ids.env\`
- Ollama Models: \`config/ollama/models.json\`
- MinIO Setup: \`config/minio/setup-summary.txt\`

## 🔐 Security Notes

- All secrets stored in: \`secrets/\` directory
- Default passwords should be changed before production use
- Google OAuth requires manual authorization if configured

## 📝 Next Steps

1. **Complete Google Drive OAuth** (if using):
   - Navigate to N8N > Credentials > Google Drive
   - Click "Connect" and authorize

2. **Import Sample Documents**:
   - Upload documents to MinIO documents bucket
   - Trigger ingestion workflow in N8N

3. **Configure Alerts**:
   - Access Grafana at http://localhost:3000
   - Set up alert rules for monitoring

4. **Test the System**:
   - Run a test query through the RAG pipeline
   - Verify embeddings are being generated
   - Check cache functionality

## 🛠️ Maintenance Commands

\`\`\`bash
# View logs
docker-compose -f docker/docker-compose.yml logs -f [service]

# Backup databases
./scripts/backup-all.sh

# Update workflows from Git
./scripts/sync-n8n-workflows.sh

# Check system health
./scripts/health-check.sh
\`\`\`

## 📈 Monitoring

Access Grafana dashboards for:
- System performance metrics
- Query latency analysis
- Cache hit rates
- Model inference times

---

For issues or questions, check logs in: \`logs/\`
EOF
    
    log "INFO" "${GREEN}✓ Setup summary saved to: $summary_file${NC}"
}

# Main setup flow
main() {
    print_banner
    
    log "INFO" "${MAGENTA}Starting DataLive RAG System setup...${NC}"
    log "INFO" "Configuration file: ${PROJECT_ROOT}/.env"
    
    # Create directories
    setup_directories
    
    # Validate environment
    if ! validate_env; then
        log "ERROR" "Setup aborted due to configuration errors"
        exit 1
    fi
    
    # Check Docker
    if ! check_docker; then
        log "ERROR" "Setup aborted due to Docker issues"
        exit 1
    fi
    
    # Generate secrets
    generate_secrets
    
    # Configure monitoring
    configure_monitoring
    
    # Start Docker stack
    start_docker_stack
    
    # Initialize all services
    initialize_services
    
    # Run tests if enabled
    if [ "$ENABLE_TEST_MODE" = "true" ]; then
        run_tests
    fi
    
    # Generate summary
    generate_summary
    
    # Final message
    echo ""
    log "INFO" "${GREEN}🎉 DataLive RAG System setup completed successfully!${NC}"
    log "INFO" "${CYAN}Access N8N at: ${N8N_URL}${NC}"
    log "INFO" "${CYAN}Login with: ${N8N_USER_EMAIL}${NC}"
    echo ""
    log "INFO" "Full summary available at: ${PROJECT_ROOT}/setup-summary.md"
    echo ""
}

# Error handling
trap 'log "ERROR" "Setup failed at line $LINENO"; exit 1' ERR

# Run main function
main "$@"