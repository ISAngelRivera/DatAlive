#!/bin/bash

# DataLive Enterprise RAG+KAG System v3.0
# Script de inicialización completa del sistema
# Fecha: 2025-06-28

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función para logging
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

# Banner del sistema
echo "========================================================================"
echo "    DataLive Enterprise RAG+KAG System v3.0"
echo "    Iniciando sistema completo..."
echo "========================================================================"

# Verificar si estamos en el directorio correcto
if [ ! -f "docker/docker-compose.yml" ]; then
    error "No se encuentra docker/docker-compose.yml. Ejecuta desde el directorio raíz del proyecto."
    exit 1
fi

# Verificar dependencias
log "Verificando dependencias del sistema..."

if ! command -v docker &> /dev/null; then
    error "Docker no está instalado"
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    error "Docker Compose no está instalado"
    exit 1
fi

# Verificar archivo .env
if [ ! -f ".env" ]; then
    warning "Archivo .env no encontrado. Copiando desde .env.example..."
    cp .env.example .env
    info "Por favor, edita el archivo .env con tus configuraciones antes de continuar."
    echo "Presiona Enter cuando hayas configurado .env..."
    read
fi

# Crear directorios necesarios
log "Creando directorios necesarios..."
mkdir -p docker/logs
mkdir -p docker/backups/postgres
mkdir -p docker/backups/neo4j
mkdir -p data/uploads
mkdir -p data/exports

# Verificar y crear secrets si no existen
log "Verificando archivos de secrets..."
if [ ! -f "docker/secrets/postgres_password.txt" ]; then
    warning "Creando archivo de password para PostgreSQL..."
    echo "adminpassword" > docker/secrets/postgres_password.txt
fi

if [ ! -f "docker/secrets/neo4j_password.txt" ]; then
    warning "Creando archivo de password para Neo4j..."
    echo "adminpassword" > docker/secrets/neo4j_password.txt
fi

if [ ! -f "docker/secrets/minio_secret_key.txt" ]; then
    warning "Creando archivo de secret key para MinIO..."
    openssl rand -base64 32 > docker/secrets/minio_secret_key.txt
fi

if [ ! -f "docker/secrets/n8n_encryption_key.txt" ]; then
    warning "Creando archivo de encryption key para N8N..."
    openssl rand -base64 32 > docker/secrets/n8n_encryption_key.txt
fi

if [ ! -f "docker/secrets/grafana_password.txt" ]; then
    warning "Creando archivo de password para Grafana..."
    echo "admin123" > docker/secrets/grafana_password.txt
fi

# Parar servicios existentes si están corriendo
log "Parando servicios existentes..."
cd docker
docker-compose down --remove-orphans 2>/dev/null || true

# Limpiar volúmenes huérfanos
log "Limpiando volúmenes huérfanos..."
docker volume prune -f

# Construir imágenes necesarias
log "Construyendo imágenes personalizadas..."
if [ -f "../agents/Dockerfile.unified" ]; then
    log "Construyendo imagen del Unified Agent..."
    docker-compose build unified-agent
fi

# Iniciar servicios core primero (base de datos, cache)
log "Iniciando servicios de infraestructura..."
docker-compose up -d postgres redis

# Esperar a que PostgreSQL esté listo
log "Esperando a que PostgreSQL esté listo..."
timeout=60
counter=0
until docker exec datalive-postgres pg_isready -U ${POSTGRES_USER:-datalive_user} 2>/dev/null; do
    if [ $counter -eq $timeout ]; then
        error "Timeout esperando PostgreSQL"
        exit 1
    fi
    counter=$((counter + 1))
    sleep 1
done

# Iniciar Neo4j
log "Iniciando Neo4j Knowledge Graph..."
docker-compose up -d neo4j

# Esperar a que Neo4j esté listo
log "Esperando a que Neo4j esté listo..."
timeout=120
counter=0
until docker exec datalive-neo4j neo4j status 2>/dev/null; do
    if [ $counter -eq $timeout ]; then
        error "Timeout esperando Neo4j"
        exit 1
    fi
    counter=$((counter + 1))
    sleep 2
done

# Iniciar servicios de AI
log "Iniciando servicios de AI (Qdrant, Ollama)..."
docker-compose up -d qdrant ollama

# Esperar a que Qdrant esté listo
log "Esperando a que Qdrant esté listo..."
timeout=60
counter=0
until curl -s http://localhost:6333/health >/dev/null 2>&1; do
    if [ $counter -eq $timeout ]; then
        error "Timeout esperando Qdrant"
        exit 1
    fi
    counter=$((counter + 1))
    sleep 1
done

# Iniciar MinIO
log "Iniciando MinIO Object Storage..."
docker-compose up -d minio

# Iniciar N8N
log "Iniciando N8N Orchestrator..."
docker-compose up -d n8n

# Iniciar Unified Agent
log "Iniciando Unified Agent..."
docker-compose up -d unified-agent

# Iniciar servicios de monitoreo
log "Iniciando servicios de monitoreo..."
docker-compose up -d prometheus grafana loki promtail

# Verificar estado de todos los servicios
log "Verificando estado de todos los servicios..."
sleep 10

echo ""
echo "========================================================================"
echo "    ESTADO DE LOS SERVICIOS"
echo "========================================================================"

# Función para verificar estado de servicio
check_service() {
    local service=$1
    local url=$2
    local expected_code=${3:-200}
    
    if curl -s -o /dev/null -w "%{http_code}" "$url" | grep -q "$expected_code"; then
        echo -e "${GREEN}✓${NC} $service - OK"
    else
        echo -e "${RED}✗${NC} $service - ERROR"
    fi
}

# Verificar servicios
check_service "PostgreSQL" "http://localhost:5432" "000"
check_service "Redis" "http://localhost:6379" "000" 
check_service "Neo4j Browser" "http://localhost:7474"
check_service "Qdrant" "http://localhost:6333/health"
check_service "Ollama" "http://localhost:11434/api/tags"
check_service "MinIO Console" "http://localhost:9001"
check_service "N8N" "http://localhost:5678"
check_service "Unified Agent" "http://localhost:8058/health"
check_service "Prometheus" "http://localhost:9090"
check_service "Grafana" "http://localhost:3000"
check_service "Loki" "http://localhost:3100/ready"

echo ""
echo "========================================================================"
echo "    INFORMACIÓN DE ACCESO"
echo "========================================================================"
echo "🌐 N8N Orchestrator:     http://localhost:5678"
echo "🧠 Neo4j Browser:        http://localhost:7474"
echo "🔍 Qdrant Console:       http://localhost:6333/dashboard" 
echo "🤖 Ollama API:           http://localhost:11434"
echo "📦 MinIO Console:        http://localhost:9001"
echo "🚀 Unified Agent API:    http://localhost:8058"
echo "📊 Prometheus:           http://localhost:9090"
echo "📈 Grafana:              http://localhost:3000"
echo "📋 Logs (Loki):          http://localhost:3100"
echo ""
echo "📋 Para ver logs: docker-compose logs -f [service_name]"
echo "🛑 Para parar: docker-compose down"
echo "🔄 Para reiniciar: docker-compose restart [service_name]"
echo ""
log "¡Sistema DataLive Enterprise RAG+KAG iniciado correctamente!"
echo "========================================================================"