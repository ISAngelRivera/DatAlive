#!/bin/bash
# git-setup-and-push.sh - Configura y actualiza el repositorio datalive

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Configuración del repositorio DataLive ===${NC}"

# Verificar si estamos en un repositorio git
if [ ! -d .git ]; then
    echo -e "${YELLOW}No se detectó repositorio Git. Inicializando...${NC}"
    git init
    git branch -M main
fi

# Crear .gitignore si no existe
if [ ! -f .gitignore ]; then
    echo -e "${GREEN}Creando .gitignore...${NC}"
    cat > .gitignore << 'EOF'
# Environment variables
.env
.env.local
.env.*.local

# Secrets - NEVER commit these!
secrets/
*.key
*.pem
*.crt
*.p12

# Docker volumes
volumes/
data/

# Logs
logs/
*.log

# Backups
backups/
*.sql
*.dump
*.tar.gz
*.zip

# OS files
.DS_Store
Thumbs.db

# IDE
.idea/
.vscode/
*.swp
*.swo
*~

# Python
__pycache__/
*.py[cod]
*$py.class
venv/
env/

# Node
node_modules/
npm-debug.log*
yarn-debug.log*
yarn-error.log*

# Temporary files
tmp/
temp/
*.tmp
*.temp

# N8N
n8n_data/
.n8n/

# MinIO data
minio_data/

# Database dumps
*.sql.gz
postgres_data/
qdrant_data/

# Model files (too large)
ollama_models/
*.gguf
*.bin

# Monitoring data
prometheus_data/
grafana_data/
loki_data/

# Keep example files
!*.example
!.env.example

# Generated credential files
config/n8n/credential-ids.env
config/n8n/setup-summary.txt
config/minio/service-keys.env
config/ollama/init-summary.txt
EOF
fi

# Crear README si no existe
if [ ! -f README.md ]; then
    echo -e "${GREEN}Creando README.md básico...${NC}"
    cat > README.md << 'EOF'
# DataLive RAG System

Sistema RAG híbrido multi-modal con N8N para procesamiento inteligente de documentos.

## Setup

1. Copiar `.env.example` a `.env` y configurar
2. Ejecutar `./scripts/setup-datalive.sh`

Ver documentación completa en `docs/`
EOF
fi

# Crear estructura de directorios con archivos .gitkeep
echo -e "${GREEN}Creando estructura de directorios...${NC}"
directories=(
    "docker"
    "scripts"
    "workflows/ingestion"
    "workflows/query"
    "workflows/optimization"
    "config/n8n"
    "config/prometheus"
    "config/grafana/provisioning/datasources"
    "config/grafana/provisioning/dashboards"
    "config/grafana/dashboards"
    "config/loki"
    "config/promtail"
    "config/qdrant"
    "config/ollama"
    "config/minio"
    "postgres-init"
    "docs"
    "resources/crdtls"
)

for dir in "${directories[@]}"; do
    mkdir -p "$dir"
    # Crear .gitkeep solo si el directorio está vacío
    if [ -z "$(ls -A "$dir" 2>/dev/null)" ]; then
        touch "$dir/.gitkeep"
    fi
done

# Crear archivo de ejemplo para secrets
if [ ! -f secrets/.gitkeep ]; then
    mkdir -p secrets
    cat > secrets/README.md << 'EOF'
# Secrets Directory

Este directorio contiene archivos sensibles que NO deben ser commiteados a Git.

## Archivos esperados:
- postgres_password.txt
- minio_secret_key.txt
- n8n_encryption_key.txt
- grafana_password.txt

Estos archivos se generan automáticamente al ejecutar setup-datalive.sh
EOF
fi

# Agregar todos los archivos al staging
echo -e "${GREEN}Agregando archivos al repositorio...${NC}"

# Archivos principales
git add -f .gitignore README.md
git add -f .env.example

# Docker
git add -f docker/docker-compose.yml
git add -f docker/docker-compose.*.yml 2>/dev/null || true

# Scripts
git add -f scripts/*.sh

# Workflows (solo archivos JSON)
git add -f workflows/**/*.json 2>/dev/null || true

# Configuraciones
git add -f config/**/*.yml 2>/dev/null || true
git add -f config/**/*.yaml 2>/dev/null || true
git add -f config/**/*.json 2>/dev/null || true
git add -f config/**/.gitkeep 2>/dev/null || true

# PostgreSQL init
git add -f postgres-init/*.sql

# Documentación
git add -f docs/* 2>/dev/null || true

# Resources (sin credenciales reales)
git add -f resources/**/.gitkeep 2>/dev/null || true

# Verificar que no estamos agregando archivos sensibles
echo -e "${YELLOW}Verificando archivos sensibles...${NC}"
if git diff --cached --name-only | grep -E "(\.env$|secrets/|password|key\.txt|token)" | grep -v ".example"; then
    echo -e "${RED}¡ADVERTENCIA! Se detectaron posibles archivos sensibles.${NC}"
    echo "Revisa los archivos antes de hacer commit."
    git diff --cached --name-only | grep -E "(\.env$|secrets/|password|key\.txt)"
fi

# Mostrar estado
echo -e "${BLUE}Estado actual del repositorio:${NC}"
git status

# Preguntar si hacer commit
echo ""
read -p "¿Deseas hacer commit de estos cambios? (s/n): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Ss]$ ]]; then
    # Hacer commit
    echo -e "${GREEN}Creando commit...${NC}"
    git commit -m "feat: actualización del sistema DataLive RAG

- Arquitectura Docker Compose completa
- Scripts de automatización con N8N
- Configuración de servicios (Ollama, Qdrant, MinIO)
- Workflows de sincronización con eliminación
- Soporte para Git como fuente de datos
- Sistema de monitoreo con Prometheus/Grafana"

    # Configurar remote si no existe
    if ! git remote | grep -q "origin"; then
        echo -e "${YELLOW}No se detectó remote 'origin'.${NC}"
        echo "Para agregar tu repositorio remoto, ejecuta:"
        echo -e "${BLUE}git remote add origin https://github.com/tu-usuario/datalive.git${NC}"
    else
        # Preguntar si hacer push
        echo ""
        read -p "¿Deseas hacer push al repositorio remoto? (s/n): " -n 1 -r
        echo ""
        
        if [[ $REPLY =~ ^[Ss]$ ]]; then
            echo -e "${GREEN}Haciendo push...${NC}"
            git push -u origin main
            echo -e "${GREEN}✓ Push completado${NC}"
        fi
    fi
else
    echo -e "${YELLOW}Commit cancelado. Los archivos siguen en staging.${NC}"
fi

echo ""
echo -e "${BLUE}=== Resumen ===${NC}"
echo "- Archivos en staging: $(git diff --cached --numstat | wc -l)"
echo "- Archivos no trackeados: $(git ls-files --others --exclude-standard | wc -l)"
echo "- Branch actual: $(git branch --show-current)"

if git remote -v | grep -q origin; then
    echo "- Remote: $(git remote get-url origin)"
fi

echo ""
echo -e "${GREEN}✓ Script completado${NC}"