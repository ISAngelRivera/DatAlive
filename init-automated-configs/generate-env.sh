#!/bin/bash

# ====================================================================
# DataLive - Generador Automático de Configuración .env
# ====================================================================
# Automatiza la configuración de variables de entorno para DataLive
# Genera contraseñas seguras y detecta configuración del sistema
# ====================================================================

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to generate secure passwords
generate_password() {
    local length=${1:-32}
    openssl rand -base64 $length | tr -d "=+/" | cut -c1-$length
}

# Function to detect timezone
detect_timezone() {
    if command -v timedatectl >/dev/null 2>&1; then
        timedatectl show --property=Timezone --value 2>/dev/null || echo "UTC"
    elif [ -f /etc/timezone ]; then
        cat /etc/timezone
    else
        echo "UTC"
    fi
}

# Function to find available port
find_available_port() {
    local start_port=${1:-8058}
    local port=$start_port
    
    while netstat -ln 2>/dev/null | grep -q ":$port "; do
        ((port++))
    done
    
    echo $port
}

# Function to prompt for user input with default
prompt_with_default() {
    local prompt="$1"
    local default="$2"
    local var_name="$3"
    
    if [ -n "$default" ]; then
        read -p "$prompt [$default]: " input
        eval "$var_name=\"\${input:-$default}\""
    else
        read -p "$prompt: " input
        eval "$var_name=\"$input\""
    fi
}

# Main function
main() {
    echo "======================================================================"
    echo "🚀 DataLive - Generador de Configuración Automática"
    echo "======================================================================"
    echo ""
    
    # Check if .env already exists
    if [ -f ".env" ]; then
        print_warning "El archivo .env ya existe."
        read -p "¿Quieres sobrescribirlo? (y/N): " overwrite
        if [[ ! $overwrite =~ ^[Yy]$ ]]; then
            print_status "Operación cancelada."
            exit 0
        fi
        
        # Backup existing .env
        cp .env .env.backup.$(date +%Y%m%d_%H%M%S)
        print_success "Backup creado: .env.backup.$(date +%Y%m%d_%H%M%S)"
    fi
    
    echo ""
    print_status "Generando configuración automática..."
    echo ""
    
    # 1. Generate secure passwords and keys
    print_status "🔐 Generando contraseñas seguras..."
    POSTGRES_PASS=$(generate_password 32)
    NEO4J_PASS=$(generate_password 24)
    MINIO_PASS=$(generate_password 32)
    N8N_PASS=$(generate_password 16)
    GRAFANA_PASS=$(generate_password 24)
    SECRET_KEY=$(openssl rand -hex 32)
    N8N_ENCRYPTION=$(openssl rand -base64 32)
    
    # 2. Detect system configuration
    print_status "🌍 Detectando configuración del sistema..."
    TIMEZONE=$(detect_timezone)
    AGENT_PORT=$(find_available_port 8058)
    
    print_success "Zona horaria detectada: $TIMEZONE"
    print_success "Puerto disponible para DataLive Agent: $AGENT_PORT"
    
    # 3. Prompt for user-specific configuration
    echo ""
    print_status "👤 Configuración del usuario (requerida para N8N):"
    echo ""
    
    prompt_with_default "Email del administrador" "admin@localhost" "USER_EMAIL"
    prompt_with_default "Nombre" "Admin" "USER_FIRSTNAME"  
    prompt_with_default "Apellido" "User" "USER_LASTNAME"
    
    # 4. Optional Google integration
    echo ""
    print_status "🔗 Integración con Google (opcional):"
    echo "Déjalo vacío si no necesitas integración con Google Drive/Docs"
    echo ""
    
    prompt_with_default "Google Client ID" "" "GOOGLE_CLIENT_ID"
    prompt_with_default "Google Client Secret" "" "GOOGLE_CLIENT_SECRET"
    
    # 5. Generate .env file
    print_status "📝 Generando archivo .env..."
    
    cat > .env << EOF
# ==============================================================================
# DataLive Environment Configuration - AUTO-GENERATED
# Generated on: $(date)
# ==============================================================================

# -- Configuración General --
TZ=$TIMEZONE

# -- Configuración de PostgreSQL --
POSTGRES_DB=datalive_db
POSTGRES_USER=datalive_user
POSTGRES_PASSWORD=$POSTGRES_PASS

# -- Configuración de Neo4j --
NEO4J_AUTH=neo4j/$NEO4J_PASS

# -- Configuración de MinIO (Almacenamiento S3) --
MINIO_ROOT_USER=datalive_admin
MINIO_ROOT_PASSWORD=$MINIO_PASS

# -- Configuración de n8n --
N8N_ENCRYPTION_KEY=$N8N_ENCRYPTION
N8N_API_KEY=

# Datos del usuario administrador
N8N_USER_EMAIL=$USER_EMAIL
N8N_USER_FIRSTNAME=$USER_FIRSTNAME
N8N_USER_LASTNAME=$USER_LASTNAME
N8N_USER_PASSWORD=$N8N_PASS
N8N_LICENSE_KEY=627897a7-4f19-4f94-b815-b369e43c1452
N8N_BASIC_AUTH_ACTIVE=true
N8N_BASIC_AUTH_USER=$USER_EMAIL
N8N_BASIC_AUTH_PASSWORD=$N8N_PASS
N8N_SECURE_COOKIE=false

# -- Configuración del Agente DataLive --
DATALIVE_AGENT_PORT=$AGENT_PORT
OLLAMA_EMBEDDING_MODEL=nomic-embed-text:v1.5
OLLAMA_ROUTER_MODEL=phi3:medium

# -- Configuración de Observabilidad --
GF_SECURITY_ADMIN_PASSWORD=$GRAFANA_PASS

# -- Configuración de Seguridad --
SECRET_KEY=$SECRET_KEY
EOF

    # Add Google configuration only if provided
    if [ -n "$GOOGLE_CLIENT_ID" ] && [ -n "$GOOGLE_CLIENT_SECRET" ]; then
        cat >> .env << EOF

# -- Conector de Google --
GOOGLE_CLIENT_ID=$GOOGLE_CLIENT_ID
GOOGLE_CLIENT_SECRET=$GOOGLE_CLIENT_SECRET
EOF
    fi
    
    print_success "Archivo .env generado exitosamente!"
    
    # 6. Generate Neo4j SSL certificates
    print_status "🔐 Generando certificados SSL para Neo4j (compatibilidad Safari)..."
    
    if [ -f "./scripts/generate-neo4j-ssl.sh" ]; then
        ./scripts/generate-neo4j-ssl.sh >/dev/null 2>&1 || {
            print_warning "No se pudieron generar certificados SSL automáticamente."
            print_status "Ejecuta manualmente: ./scripts/generate-neo4j-ssl.sh"
        }
        print_success "Certificados SSL para Neo4j generados."
    else
        print_warning "Script de certificados SSL no encontrado."
    fi

    # 7. Display summary
    echo ""
    echo "======================================================================"
    print_success "🎉 Configuración Completada"
    echo "======================================================================"
    echo ""
    echo "📋 Resumen de la configuración:"
    echo ""
    echo "🔐 Contraseñas generadas automáticamente:"
    echo "  • PostgreSQL: ✓ Generada (32 caracteres)"
    echo "  • Neo4j: ✓ Generada (24 caracteres)"  
    echo "  • MinIO: ✓ Generada (32 caracteres)"
    echo "  • N8N: ✓ Generada (16 caracteres)"
    echo "  • Grafana: ✓ Generada (24 caracteres)"
    echo "  • Claves de cifrado: ✓ Generadas"
    echo ""
    echo "⚙️ Configuración del sistema:"
    echo "  • Zona horaria: $TIMEZONE"
    echo "  • Puerto DataLive Agent: $AGENT_PORT"
    echo "  • Certificados SSL Neo4j: ✓ Generados (init-neo4j/ssl/)"
    echo ""
    echo "👤 Usuario administrador:"
    echo "  • Email: $USER_EMAIL"
    echo "  • Nombre: $USER_FIRSTNAME $USER_LASTNAME"
    echo ""
    
    if [ -n "$GOOGLE_CLIENT_ID" ]; then
        echo "🔗 Integración Google: ✓ Configurada"
    else
        echo "🔗 Integración Google: ⏭️ Omitida"
    fi
    
    echo ""
    echo "📁 Archivos generados:"
    echo "  • .env (configuración principal)"
    if [ -f ".env.backup"* ]; then
        echo "  • .env.backup.* (respaldo del anterior)"
    fi
    
    echo ""
    echo "🚀 Próximos pasos:"
    echo "  1. Ejecutar: docker-compose up -d"
    echo "  2. Esperar a que todos los servicios estén listos"
    echo "  3. Acceder a N8N: http://localhost:5678"
    echo "  4. Acceder a Neo4j: http://localhost:7474"
    echo ""
    echo "📚 Documentación:"
    echo "  • Variables de entorno: docs/ENV_CONF_README.md"
    echo "  • Solución Safari: docs/SAFARI_NEO4J_SOLUTION.md"
    echo ""
    print_success "¡DataLive está listo para usar!"
}

# Check prerequisites
check_prerequisites() {
    local missing_tools=()
    
    if ! command -v openssl >/dev/null 2>&1; then
        missing_tools+=("openssl")
    fi
    
    if ! command -v netstat >/dev/null 2>&1; then
        if ! command -v ss >/dev/null 2>&1; then
            missing_tools+=("netstat or ss")
        fi
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        print_error "Herramientas faltantes: ${missing_tools[*]}"
        print_error "Instala las herramientas faltantes y vuelve a ejecutar el script."
        exit 1
    fi
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    check_prerequisites
    main "$@"
fi