#!/bin/bash
# DataLive Infrastructure Deployment Script
# Etapa 1: Infraestructura - Despliegue y verificación completa

set -e

echo "🚀 DataLive Unified RAG+KAG+CAG - Deployment Infrastructure"
echo "================================================================"
echo "ETAPA 1: INFRAESTRUCTURA"
echo "================================================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Change to project directory
PROJECT_DIR="/Users/angelrivera/Desktop/GIT/DatAlive"
cd "$PROJECT_DIR"

echo -e "\n${BLUE}📍 Working directory: $(pwd)${NC}"

# Step 1: Check current Docker containers
echo -e "\n${YELLOW}🔍 PASO 1: Verificando contenedores Docker actuales...${NC}"
echo "================================================================"
if docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "datalive|n8n|postgres|neo4j|redis|ollama"; then
    echo -e "${YELLOW}⚠️  Contenedores DataLive existentes encontrados${NC}"
    CONTAINERS_EXIST=true
else
    echo -e "${GREEN}✅ No hay contenedores DataLive ejecutándose${NC}"
    CONTAINERS_EXIST=false
fi

# Step 2: Stop and clean existing containers
if [ "$CONTAINERS_EXIST" = true ]; then
    echo -e "\n${YELLOW}🛑 PASO 2: Deteniendo contenedores existentes...${NC}"
    echo "================================================================"
    
    # Stop containers with datalive prefix
    docker ps -q --filter "name=datalive" | xargs -r docker stop
    echo -e "${GREEN}✅ Contenedores DataLive detenidos${NC}"
    
    # Remove containers
    docker ps -aq --filter "name=datalive" | xargs -r docker rm
    echo -e "${GREEN}✅ Contenedores DataLive eliminados${NC}"
    
    # Clean up networks
    docker network ls --format "{{.Name}}" | grep -E "datalive|docker_" | xargs -r docker network rm 2>/dev/null || true
    echo -e "${GREEN}✅ Redes limpiadas${NC}"
    
    # Clean up volumes (optional - preserves data)
    read -p "¿Deseas eliminar también los volúmenes de datos? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        docker volume ls --format "{{.Name}}" | grep -E "datalive|docker_" | xargs -r docker volume rm 2>/dev/null || true
        echo -e "${YELLOW}⚠️  Volúmenes eliminados - se perderán datos existentes${NC}"
    else
        echo -e "${GREEN}✅ Volúmenes preservados${NC}"
    fi
else
    echo -e "\n${GREEN}✅ PASO 2: No hay contenedores que limpiar${NC}"
fi

# Step 3: Deploy enhanced infrastructure
echo -e "\n${BLUE}🏗️  PASO 3: Desplegando infraestructura mejorada...${NC}"
echo "================================================================"

cd docker

# Check if enhanced compose file exists
if [ ! -f "docker-compose-enhanced.yml" ]; then
    echo -e "${RED}❌ Error: docker-compose-enhanced.yml no encontrado${NC}"
    exit 1
fi

# Check environment file
if [ ! -f "../.env" ]; then
    echo -e "${YELLOW}⚠️  Archivo .env no encontrado, copiando template...${NC}"
    cp ../.env.template ../.env
fi

# Verify secrets directory
if [ ! -d "../secrets" ]; then
    echo -e "${RED}❌ Error: Directorio secrets/ no encontrado${NC}"
    exit 1
fi

# Check required secret files
SECRETS=("postgres_password.txt" "n8n_encryption_key.txt" "minio_secret_key.txt" "grafana_password.txt")
for secret in "${SECRETS[@]}"; do
    if [ ! -f "../secrets/$secret" ]; then
        echo -e "${RED}❌ Error: secrets/$secret no encontrado${NC}"
        exit 1
    fi
done

echo -e "${GREEN}✅ Archivos de configuración verificados${NC}"

# Pull latest images
echo -e "\n${BLUE}📥 Descargando imágenes Docker más recientes...${NC}"
docker-compose -f docker-compose-enhanced.yml pull

# Start infrastructure
echo -e "\n${BLUE}🚀 Iniciando infraestructura...${NC}"
docker-compose -f docker-compose-enhanced.yml up -d

echo -e "${GREEN}✅ Contenedores iniciados${NC}"

# Step 4: Wait for services to be ready
echo -e "\n${YELLOW}⏳ PASO 4: Esperando que los servicios estén listos...${NC}"
echo "================================================================"

# Function to check service health
check_service() {
    local service_name=$1
    local url=$2
    local max_attempts=30
    local attempt=1
    
    echo -n "Verificando $service_name..."
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s -f "$url" > /dev/null 2>&1; then
            echo -e " ${GREEN}✅${NC}"
            return 0
        fi
        echo -n "."
        sleep 2
        ((attempt++))
    done
    
    echo -e " ${RED}❌ (timeout después de $(($max_attempts * 2)) segundos)${NC}"
    return 1
}

# Check core services
echo "Verificando servicios principales:"

# PostgreSQL (using pg_isready through docker exec)
echo -n "Verificando PostgreSQL..."
attempt=1
while [ $attempt -le 30 ]; do
    if docker exec datalive-postgres pg_isready -U admin -d datalive_db > /dev/null 2>&1; then
        echo -e " ${GREEN}✅${NC}"
        POSTGRES_OK=true
        break
    fi
    echo -n "."
    sleep 2
    ((attempt++))
done

if [ "$POSTGRES_OK" != true ]; then
    echo -e " ${RED}❌${NC}"
fi

# Redis
echo -n "Verificando Redis..."
attempt=1
while [ $attempt -le 30 ]; do
    if docker exec datalive-redis redis-cli ping > /dev/null 2>&1; then
        echo -e " ${GREEN}✅${NC}"
        REDIS_OK=true
        break
    fi
    echo -n "."
    sleep 2
    ((attempt++))
done

if [ "$REDIS_OK" != true ]; then
    echo -e " ${RED}❌${NC}"
fi

# N8N
check_service "N8N" "http://localhost:5678/healthz" && N8N_OK=true

# Neo4j
check_service "Neo4j" "http://localhost:7474" && NEO4J_OK=true

# Unified Agent (may take longer to start)
echo -n "Verificando Unified Agent..."
attempt=1
while [ $attempt -le 60 ]; do  # Longer timeout for agent
    if curl -s -f "http://localhost:8058/health" > /dev/null 2>&1; then
        echo -e " ${GREEN}✅${NC}"
        AGENT_OK=true
        break
    fi
    echo -n "."
    sleep 3
    ((attempt++))
done

if [ "$AGENT_OK" != true ]; then
    echo -e " ${RED}❌${NC}"
fi

# Step 5: Service status summary
echo -e "\n${BLUE}📊 PASO 5: Resumen del estado de servicios${NC}"
echo "================================================================"

docker-compose -f docker-compose-enhanced.yml ps

# Step 6: Check logs for errors
echo -e "\n${YELLOW}📝 PASO 6: Verificando logs por errores críticos...${NC}"
echo "================================================================"

check_logs() {
    local service=$1
    echo "Revisando logs de $service..."
    
    # Get last 20 lines and check for common error patterns
    if docker logs --tail 20 "datalive-$service" 2>&1 | grep -i -E "(error|exception|failed|fatal)" | head -5; then
        echo -e "${YELLOW}⚠️  Errores encontrados en $service (ver logs completos)${NC}"
    else
        echo -e "${GREEN}✅ Sin errores críticos en $service${NC}"
    fi
    echo ""
}

# Check logs for each service
for service in "postgres" "redis" "neo4j" "n8n" "unified-agent"; do
    if docker ps --format "{{.Names}}" | grep -q "datalive-$service"; then
        check_logs "$service"
    fi
done

# Final status report
echo -e "\n${BLUE}🎯 RESUMEN FINAL - ETAPA 1: INFRAESTRUCTURA${NC}"
echo "================================================================"

# Service URLs
echo -e "\n${BLUE}🌐 URLs de Servicios:${NC}"
echo "• N8N (Workflows):     http://localhost:5678"
echo "• Neo4j (Graph DB):    http://localhost:7474"
echo "• Unified Agent API:   http://localhost:8058/docs"
echo "• Prometheus:          http://localhost:9090"
echo "• Grafana:             http://localhost:3000"

# Service status
echo -e "\n${BLUE}📋 Estado de Servicios:${NC}"
[ "$POSTGRES_OK" = true ] && echo -e "• PostgreSQL: ${GREEN}✅ FUNCIONANDO${NC}" || echo -e "• PostgreSQL: ${RED}❌ ERROR${NC}"
[ "$REDIS_OK" = true ] && echo -e "• Redis: ${GREEN}✅ FUNCIONANDO${NC}" || echo -e "• Redis: ${RED}❌ ERROR${NC}"
[ "$N8N_OK" = true ] && echo -e "• N8N: ${GREEN}✅ FUNCIONANDO${NC}" || echo -e "• N8N: ${RED}❌ ERROR${NC}"
[ "$NEO4J_OK" = true ] && echo -e "• Neo4j: ${GREEN}✅ FUNCIONANDO${NC}" || echo -e "• Neo4j: ${RED}❌ ERROR${NC}"
[ "$AGENT_OK" = true ] && echo -e "• Unified Agent: ${GREEN}✅ FUNCIONANDO${NC}" || echo -e "• Unified Agent: ${RED}❌ ERROR${NC}"

# Overall status
FAILED_SERVICES=0
[ "$POSTGRES_OK" != true ] && ((FAILED_SERVICES++))
[ "$REDIS_OK" != true ] && ((FAILED_SERVICES++))
[ "$N8N_OK" != true ] && ((FAILED_SERVICES++))
[ "$NEO4J_OK" != true ] && ((FAILED_SERVICES++))
[ "$AGENT_OK" != true ] && ((FAILED_SERVICES++))

echo -e "\n${BLUE}🏆 RESULTADO FINAL:${NC}"
if [ $FAILED_SERVICES -eq 0 ]; then
    echo -e "${GREEN}✅ ETAPA 1 COMPLETADA EXITOSAMENTE${NC}"
    echo -e "${GREEN}   Todos los servicios están funcionando correctamente${NC}"
    echo -e "\n${BLUE}➡️  Listo para ETAPA 2: FUNCIONALIDAD${NC}"
elif [ $FAILED_SERVICES -le 2 ]; then
    echo -e "${YELLOW}⚠️  ETAPA 1 COMPLETADA CON ADVERTENCIAS${NC}"
    echo -e "${YELLOW}   $FAILED_SERVICES servicio(s) con problemas${NC}"
    echo -e "\n${YELLOW}🔧 Revisar logs y corregir antes de continuar a ETAPA 2${NC}"
else
    echo -e "${RED}❌ ETAPA 1 FALLÓ${NC}"
    echo -e "${RED}   $FAILED_SERVICES servicio(s) no funcionan${NC}"
    echo -e "\n${RED}🚨 Revisar configuración y logs antes de continuar${NC}"
fi

echo -e "\n${BLUE}📚 Comandos útiles:${NC}"
echo "• Ver todos los logs:     docker-compose -f docker-compose-enhanced.yml logs"
echo "• Ver logs específicos:   docker logs datalive-[servicio]"
echo "• Reiniciar servicios:    docker-compose -f docker-compose-enhanced.yml restart"
echo "• Detener todo:           docker-compose -f docker-compose-enhanced.yml down"

echo -e "\n${GREEN}🎉 Script de infraestructura completado${NC}"