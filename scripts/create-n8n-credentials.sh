#!/bin/bash
# create-n8n-credentials.sh - Creación completa de credenciales N8N
# Basado en el sistema que funcionaba en el proyecto antiguo
# Completamente idempotente y robusto

set -e

# Detectar directorio del script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Cargar variables de entorno
if [ -f "$PROJECT_ROOT/.env" ]; then
    set -a
    source "$PROJECT_ROOT/.env"
    set +a
else
    echo "ERROR: .env file not found at $PROJECT_ROOT/.env"
    exit 1
fi

# Configuración
N8N_URL="${N8N_URL:-http://localhost:5678}"
N8N_API="${N8N_URL}/rest"
COOKIE_FILE="${PROJECT_ROOT}/secrets/n8n_cookies.txt"
CRED_FILE="${PROJECT_ROOT}/config/n8n/credential-ids.env"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Contador de credenciales
CREDENTIALS_CREATED=0

echo -e "${CYAN}===============================================${NC}"
echo -e "${CYAN}DataLive N8N Credentials Setup${NC}"
echo -e "${CYAN}===============================================${NC}"

# Función para log
log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1: $2"
}

# Verificar si credencial existe
credential_exists() {
    local cred_name="$1"
    local existing=$(curl -sf -b "${COOKIE_FILE}" "${N8N_API}/credentials" 2>/dev/null)
    
    if echo "$existing" | jq -e ".data[] | select(.name == \"$cred_name\")" > /dev/null 2>&1; then
        local existing_id=$(echo "$existing" | jq -r ".data[] | select(.name == \"$cred_name\") | .id")
        log "INFO" "${YELLOW}⚠ Credential '${cred_name}' already exists (ID: ${existing_id})${NC}" >&2
        echo "$existing_id"
        return 0
    else
        return 1
    fi
}

# Función para crear credencial
create_credential() {
    local cred_name=$1
    local cred_type=$2
    local cred_data=$3
    
    # Verificar si ya existe
    if existing_id=$(credential_exists "$cred_name"); then
        echo "$existing_id"
        return 0
    fi
    
    log "INFO" "${CYAN}Creating credential: ${cred_name}${NC}" >&2
    
    local credential_json=$(cat <<EOF
{
    "name": "${cred_name}",
    "type": "${cred_type}",
    "data": ${cred_data}
}
EOF
)
    
    local response=$(curl -sf -X POST \
        -H "Content-Type: application/json" \
        -b "${COOKIE_FILE}" \
        -d "${credential_json}" \
        "${N8N_API}/credentials" 2>&1)
    
    if [ $? -eq 0 ]; then
        local cred_id=$(echo "$response" | jq -r '.data.id // empty' 2>/dev/null)
        if [ -n "$cred_id" ]; then
            log "INFO" "${GREEN}✓ Created credential '${cred_name}' (ID: ${cred_id})${NC}" >&2
            CREDENTIALS_CREATED=$((CREDENTIALS_CREATED + 1))
            echo "${cred_id}"
            return 0
        fi
    fi
    
    log "ERROR" "${RED}✗ Failed to create credential '${cred_name}'${NC}"
    log "DEBUG" "Response: $response"
    return 1
}

# Crear directorio de configuración
mkdir -p "$(dirname "$CRED_FILE")"

# Inicializar archivo de IDs
echo "# N8N Credential IDs - Auto-generated $(date)" > "$CRED_FILE"

log "INFO" "${BLUE}Setting up N8N credentials...${NC}"

# 1. Ollama credential (LLM y Embeddings)
log "INFO" "Setting up Ollama credential..."
ollama_data=$(cat <<EOF
{
    "baseUrl": "http://ollama:11434"
}
EOF
)
if ollama_id=$(create_credential "DataLive Ollama" "ollamaApi" "$ollama_data"); then
    echo "OLLAMA_CREDENTIAL_ID=${ollama_id}" >> "$CRED_FILE"
fi

# 2. Qdrant credential (Vector Database)
log "INFO" "Setting up Qdrant credential..."
qdrant_data=$(cat <<EOF
{
    "url": "http://qdrant:6333",
    "apiKey": ""
}
EOF
)
if qdrant_id=$(create_credential "DataLive Qdrant" "qdrantApi" "$qdrant_data"); then
    echo "QDRANT_CREDENTIAL_ID=${qdrant_id}" >> "$CRED_FILE"
fi

# 3. PostgreSQL credential
log "INFO" "Setting up PostgreSQL credential..."
postgres_data=$(cat <<EOF
{
    "host": "postgres",
    "port": 5432,
    "database": "${POSTGRES_DB}",
    "user": "${POSTGRES_USER}",
    "password": "${POSTGRES_PASSWORD}",
    "ssl": "disable"
}
EOF
)
if postgres_id=$(create_credential "DataLive PostgreSQL" "postgres" "$postgres_data"); then
    echo "POSTGRES_CREDENTIAL_ID=${postgres_id}" >> "$CRED_FILE"
fi

# 4. MinIO credential (S3 compatible)
log "INFO" "Setting up MinIO credential..."
minio_data=$(cat <<EOF
{
    "accessKeyId": "${MINIO_ROOT_USER}",
    "secretAccessKey": "${MINIO_ROOT_PASSWORD}",
    "region": "us-east-1",
    "customEndpoint": "http://minio:9000",
    "forcePathStyle": true
}
EOF
)
if minio_id=$(create_credential "DataLive MinIO" "aws" "$minio_data"); then
    echo "MINIO_CREDENTIAL_ID=${minio_id}" >> "$CRED_FILE"
fi

# 5. Redis credential
log "INFO" "Setting up Redis credential..."
redis_data=$(cat <<EOF
{
    "host": "redis",
    "port": 6379,
    "password": "${REDIS_PASSWORD}"
}
EOF
)
if redis_id=$(create_credential "DataLive Redis" "redis" "$redis_data"); then
    echo "REDIS_CREDENTIAL_ID=${redis_id}" >> "$CRED_FILE"
fi

# 6. Neo4j credential (Knowledge Graph)
log "INFO" "Setting up Neo4j credential..."
neo4j_data=$(cat <<EOF
{
    "host": "neo4j",
    "port": 7687,
    "user": "neo4j",
    "password": "${NEO4J_PASSWORD:-adminpassword}",
    "scheme": "bolt",
    "database": "neo4j"
}
EOF
)
if neo4j_id=$(create_credential "DataLive Neo4j" "neo4j" "$neo4j_data"); then
    echo "NEO4J_CREDENTIAL_ID=${neo4j_id}" >> "$CRED_FILE"
fi

# 7. Google Drive OAuth2 credential (si está configurado)
if [ -n "${GOOGLE_CLIENT_ID:-}" ] && [ -n "${GOOGLE_CLIENT_SECRET:-}" ]; then
    log "INFO" "Setting up Google Drive OAuth credential..."
    
    google_data=$(cat <<EOF
{
    "clientId": "${GOOGLE_CLIENT_ID}",
    "clientSecret": "${GOOGLE_CLIENT_SECRET}",
    "oauthTokenData": {}
}
EOF
)
    if google_id=$(create_credential "DataLive Google Drive" "googleDriveOAuth2Api" "$google_data"); then
        echo "GOOGLE_DRIVE_CREDENTIAL_ID=${google_id}" >> "$CRED_FILE"
        log "WARN" "${YELLOW}⚠ Google Drive credential created but requires manual OAuth authorization${NC}"
        log "INFO" "Complete authorization at: ${N8N_URL}/credentials/${google_id}"
    fi
else
    log "WARN" "${YELLOW}⚠ Google OAuth not configured - skipping Google Drive credential${NC}"
fi

echo ""
log "INFO" "${GREEN}✓ Credentials setup completed (${CREDENTIALS_CREATED} created/verified)${NC}"
log "INFO" "Credential IDs saved to: ${CRED_FILE}"

# Limpiar archivo de IDs (remover logs mezclados)
if [ -f "$CRED_FILE" ]; then
    grep '^[A-Z_]*_CREDENTIAL_ID=' "$CRED_FILE" > "${CRED_FILE}.tmp" 2>/dev/null || true
    if [ -s "${CRED_FILE}.tmp" ]; then
        echo "# N8N Credential IDs - Auto-generated $(date)" > "$CRED_FILE"
        cat "${CRED_FILE}.tmp" >> "$CRED_FILE"
        rm "${CRED_FILE}.tmp"
    fi
fi

# Mostrar resumen
echo ""
echo -e "${CYAN}Credentials Summary:${NC}"
if [ -f "$CRED_FILE" ]; then
    grep '^[A-Z_]*_CREDENTIAL_ID=' "$CRED_FILE" | while IFS='=' read -r key value; do
        if [ -n "$key" ] && [ -n "$value" ]; then
            echo -e "  ${GREEN}✓${NC} $key: $value"
        fi
    done
fi

echo ""
echo -e "${GREEN}🚀 N8N credentials are ready for use!${NC}"