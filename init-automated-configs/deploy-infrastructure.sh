#!/bin/bash

# DataLive Infrastructure Deployment Script
# Automated deployment with golden path approach

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running from correct directory
if [[ ! -f "docker-compose.yml" ]]; then
    log_error "docker-compose.yml not found. Please run from DataLive root directory."
    exit 1
fi

log_info "🚀 Starting DataLive Infrastructure Deployment"
echo "=================================================="

# Check system requirements
log_info "📋 Checking system requirements..."

# Check Docker
if ! command -v docker &> /dev/null; then
    log_error "Docker is not installed. Please install Docker first."
    exit 1
fi

# Check Docker Compose
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    log_error "Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

log_success "✅ Docker and Docker Compose are available"

# Set Docker Compose command
if docker compose version &> /dev/null; then
    DOCKER_COMPOSE="docker compose"
else
    DOCKER_COMPOSE="docker-compose"
fi

# Check if .env file exists
if [[ ! -f ".env" ]]; then
    log_warning "⚠️  .env file not found. Creating from template..."
    if [[ -f ".env.template" ]]; then
        cp .env.template .env
        log_info "📝 Please review and update .env file with your settings"
    else
        log_error ".env.template not found. Cannot create .env file."
        exit 1
    fi
fi

# Check available memory and disk space
log_info "💾 Checking system resources..."

# Check available memory (minimum 4GB recommended)
if command -v free &> /dev/null; then
    available_memory=$(free -m | awk 'NR==2{printf "%.0f", $7/1024}')
    if [[ $available_memory -lt 4 ]]; then
        log_warning "⚠️  Less than 4GB available memory. DataLive may run slowly."
    else
        log_success "✅ Sufficient memory available: ${available_memory}GB"
    fi
fi

# Check available disk space (minimum 10GB recommended)
available_disk=$(df -BG . | awk 'NR==2{print $4}' | sed 's/G//')
if [[ $available_disk -lt 10 ]]; then
    log_warning "⚠️  Less than 10GB available disk space. Consider freeing up space."
else
    log_success "✅ Sufficient disk space available: ${available_disk}GB"
fi

# Stop existing containers if running
log_info "🛑 Stopping existing containers (if any)..."
$DOCKER_COMPOSE down --remove-orphans 2>/dev/null || true

# Clean up old images if requested
read -p "🧹 Do you want to clean up old Docker images? (y/N): " -r
if [[ $REPLY =~ ^[Yy]$ ]]; then
    log_info "🧹 Cleaning up Docker images..."
    docker system prune -f
    log_success "✅ Docker cleanup completed"
fi

# Build the DataLive agent with poetry
log_info "🏗️  Building DataLive Agent with Poetry..."

# Check if datalive_agent directory exists
if [[ ! -d "datalive_agent" ]]; then
    log_error "datalive_agent directory not found"
    exit 1
fi

# Check if pyproject.toml exists
if [[ ! -f "datalive_agent/pyproject.toml" ]]; then
    log_error "pyproject.toml not found in datalive_agent directory"
    exit 1
fi

# Build the agent image
log_info "🐳 Building DataLive Agent Docker image..."
$DOCKER_COMPOSE build datalive_agent

if [[ $? -ne 0 ]]; then
    log_error "Failed to build DataLive Agent image"
    exit 1
fi

log_success "✅ DataLive Agent image built successfully"

# Start infrastructure services first
log_info "🏗️  Starting infrastructure services..."

# Start database services first
log_info "📊 Starting databases..."
$DOCKER_COMPOSE up -d postgres neo4j qdrant minio

# Wait for databases to be healthy
log_info "⏳ Waiting for databases to be ready..."
timeout=300  # 5 minutes timeout
elapsed=0
interval=10

while [[ $elapsed -lt $timeout ]]; do
    if $DOCKER_COMPOSE ps --format "table {{.Name}}\t{{.Status}}" | grep -E "(postgres|neo4j|qdrant|minio)" | grep -q "healthy"; then
        healthy_count=$($DOCKER_COMPOSE ps --format "table {{.Name}}\t{{.Status}}" | grep -E "(postgres|neo4j|qdrant|minio)" | grep -c "healthy")
        total_count=4
        
        if [[ $healthy_count -eq $total_count ]]; then
            log_success "✅ All database services are healthy"
            break
        fi
    fi
    
    echo -n "."
    sleep $interval
    elapsed=$((elapsed + interval))
done

if [[ $elapsed -ge $timeout ]]; then
    log_error "⏰ Timeout waiting for database services to be healthy"
    log_info "📋 Current service status:"
    $DOCKER_COMPOSE ps
    exit 1
fi

# Start Ollama and download model
log_info "🤖 Starting Ollama service..."
$DOCKER_COMPOSE up -d ollama

# Wait for Ollama to be ready
log_info "⏳ Waiting for Ollama to be ready..."
timeout=180  # 3 minutes for Ollama
elapsed=0

while [[ $elapsed -lt $timeout ]]; do
    if $DOCKER_COMPOSE ps ollama --format "table {{.Status}}" | grep -q "healthy"; then
        log_success "✅ Ollama service is ready"
        break
    fi
    
    echo -n "."
    sleep $interval
    elapsed=$((elapsed + interval))
done

if [[ $elapsed -ge $timeout ]]; then
    log_warning "⚠️  Ollama service not ready, but continuing..."
fi

# Download required model
log_info "📥 Downloading required LLM model (phi3:medium)..."
$DOCKER_COMPOSE exec -T ollama ollama pull phi3:medium || log_warning "⚠️  Failed to download model, will retry later"

# Start N8N
log_info "🔄 Starting N8N automation service..."
$DOCKER_COMPOSE up -d n8n

# Wait for N8N to be ready
log_info "⏳ Waiting for N8N to be ready..."
timeout=120  # 2 minutes for N8N
elapsed=0

while [[ $elapsed -lt $timeout ]]; do
    if $DOCKER_COMPOSE ps n8n --format "table {{.Status}}" | grep -q "healthy"; then
        log_success "✅ N8N service is ready"
        break
    fi
    
    echo -n "."
    sleep $interval
    elapsed=$((elapsed + interval))
done

# Run N8N setup
log_info "⚙️  Running N8N setup..."
$DOCKER_COMPOSE up n8n-setup || log_warning "⚠️  N8N setup completed with warnings"

# Finally start the DataLive Agent
log_info "🤖 Starting DataLive Agent..."
$DOCKER_COMPOSE up -d datalive_agent

# Wait for agent to be ready
log_info "⏳ Waiting for DataLive Agent to be ready..."
timeout=120  # 2 minutes for agent
elapsed=0

while [[ $elapsed -lt $timeout ]]; do
    if $DOCKER_COMPOSE ps datalive_agent --format "table {{.Status}}" | grep -q "healthy"; then
        log_success "✅ DataLive Agent is ready"
        break
    fi
    
    echo -n "."
    sleep $interval
    elapsed=$((elapsed + interval))
done

if [[ $elapsed -ge $timeout ]]; then
    log_warning "⚠️  DataLive Agent health check timeout, but service may still be starting..."
fi

# Final status check
log_info "📊 Final deployment status:"
echo "=================================================="
$DOCKER_COMPOSE ps

# Test connectivity
log_info "🔍 Testing service connectivity..."

# Test DataLive Agent
if curl -s http://localhost:8058/status > /dev/null; then
    log_success "✅ DataLive Agent API is responding"
else
    log_warning "⚠️  DataLive Agent API not responding yet"
fi

# Test N8N
if curl -s http://localhost:5678/healthz > /dev/null; then
    log_success "✅ N8N is responding"
else
    log_warning "⚠️  N8N not responding yet"
fi

# Success message
echo ""
log_success "🎉 DataLive Infrastructure Deployment Complete!"
echo "=================================================="
echo ""
echo "📡 Service URLs:"
echo "   • DataLive Agent API: http://localhost:8058"
echo "   • DataLive Agent Docs: http://localhost:8058/docs"
echo "   • N8N Automation: http://localhost:5678"
echo "   • Neo4j Browser: http://localhost:7474"
echo "   • Qdrant Dashboard: http://localhost:6333/dashboard"
echo "   • MinIO Console: http://localhost:9001"
echo ""
echo "🚀 Quick Start:"
echo "   # Test ingestion endpoint"
echo "   curl -X POST http://localhost:8058/api/v1/ingest \\"
echo "     -H 'Content-Type: application/json' \\"
echo "     -d '{\"source_type\": \"txt\", \"source\": \"DataLive is ready!\"}'"
echo ""
echo "   # Test query endpoint"
echo "   curl -X POST http://localhost:8058/api/v1/query \\"
echo "     -H 'Content-Type: application/json' \\"
echo "     -d '{\"query\": \"What is DataLive?\"}'"
echo ""
echo "📚 Documentation: http://localhost:8058/docs"
echo "📊 Metrics: http://localhost:8058/metrics"
echo ""
log_info "🐳 All services running in Docker containers with Poetry dependency management"
log_info "✨ Golden path achieved: Maximum automation, minimal user steps"