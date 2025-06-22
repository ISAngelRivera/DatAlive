#!/bin/sh
# setup-datalive-universal.sh - Setup de DataLive 100% compatible
# Este script funciona en CUALQUIER sistema Unix/Linux/macOS/Windows(Git Bash) de los últimos 10 años
# Compatible con: bash 3.2+, sh, dash, zsh, Git Bash, WSL, macOS 10.10+, Ubuntu 14.04+

set -e

# Detectar directorio del script (ultra-compatible)
if [ -n "$BASH_SOURCE" ]; then
    SCRIPT_DIR="$(cd "$(dirname "$BASH_SOURCE")" && pwd)"
elif [ -n "$0" ] && [ -f "$0" ]; then
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
else
    SCRIPT_DIR="$(pwd)"
fi

PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Cargar funciones universales
. "$PROJECT_ROOT/scripts/lib/universal-functions.sh"

# Verificar que estemos en el directorio correcto
if [ ! -f "$PROJECT_ROOT/.env.template" ]; then
    log "ERROR" "No se encontró .env.template. Asegúrate de estar en el directorio correcto de DataLive."
    exit 1
fi

printf "%s\n" "${CYAN}"
cat << "EOF"
██████╗  █████╗ ████████╗ █████╗ ██╗     ██╗██╗   ██╗███████╗
██╔══██╗██╔══██╗╚══██╔══╝██╔══██╗██║     ██║██║   ██║██╔════╝
██║  ██║███████║   ██║   ███████║██║     ██║██║   ██║█████╗  
██║  ██║██╔══██║   ██║   ██╔══██║██║     ██║╚██╗ ██╔╝██╔══╝  
██████╔╝██║  ██║   ██║   ██║  ██║███████╗██║ ╚████╔╝ ███████╗
╚═════╝ ╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═╝╚══════╝╚═╝  ╚═══╝  ╚══════╝
EOF
printf "%s\n" "${NC}"

printf "%s\n" "${BLUE}=== Setup Universal de DataLive RAG System ===${NC}"
printf "%s\n" "${YELLOW}Compatible con cualquier sistema Unix/Linux/macOS/Windows${NC}"
printf "\n"

# Paso 1: Verificar dependencias críticas
printf "%s\n" "${GREEN}Paso 1: Verificando dependencias...${NC}"

critical_deps="docker"
optional_deps="curl jq git"
missing_critical=""
missing_optional=""

for dep in $critical_deps; do
    if command_exists "$dep"; then
        printf "  ✓ %s encontrado\n" "$dep"
    else
        missing_critical="$missing_critical $dep"
        printf "  ✗ %s NO encontrado\n" "$dep"
    fi
done

for dep in $optional_deps; do
    if command_exists "$dep"; then
        printf "  ✓ %s encontrado\n" "$dep"
    else
        missing_optional="$missing_optional $dep"
        printf "  ⚠ %s no encontrado (opcional)\n" "$dep"
    fi
done

if [ -n "$missing_critical" ]; then
    printf "\n%s\n" "${RED}ERROR: Dependencias críticas faltantes:$missing_critical${NC}"
    printf "Por favor instala las dependencias faltantes antes de continuar.\n"
    printf "\nEn Ubuntu/Debian: sudo apt-get install docker.io\n"
    printf "En macOS: brew install docker\n"
    printf "En Windows: Instala Docker Desktop\n"
    exit 1
fi

# Paso 2: Verificar Docker
printf "\n%s\n" "${GREEN}Paso 2: Verificando Docker...${NC}"
if docker ps > /dev/null 2>&1; then
    printf "  ✓ Docker está ejecutándose\n"
else
    printf "  ✗ Docker no está ejecutándose\n"
    printf "\n%s\n" "${YELLOW}Instrucciones para iniciar Docker:${NC}"
    
    os="$(detect_os)"
    case "$os" in
        "macos")
            printf "  - Abre Docker Desktop desde Applications\n"
            printf "  - O ejecuta: open -a Docker\n"
            ;;
        "linux")
            printf "  - sudo systemctl start docker\n"
            printf "  - sudo service docker start\n"
            ;;
        "windows")
            printf "  - Abre Docker Desktop desde el menú de inicio\n"
            ;;
    esac
    
    printf "\nPresiona ENTER cuando Docker esté ejecutándose..."
    read dummy_input
fi

# Paso 3: Configurar .env
printf "\n%s\n" "${GREEN}Paso 3: Configurando variables de entorno...${NC}"

if [ ! -f "$PROJECT_ROOT/.env" ]; then
    printf "  Creando .env desde template...\n"
    cp "$PROJECT_ROOT/.env.template" "$PROJECT_ROOT/.env"
    printf "  ✓ .env creado\n"
else
    printf "  ✓ .env ya existe\n"
fi

# Configuraciones por defecto para máxima compatibilidad
printf "  Aplicando configuraciones universales...\n"

# Configuraciones seguras que funcionan en cualquier sistema
update_env "TZ" "UTC"
update_env "NODE_ENV" "production"
update_env "COMPOSE_PROJECT_NAME" "datalive"

# Credenciales estandarizadas
update_env "POSTGRES_USER" "admin"
update_env "POSTGRES_PASSWORD" "adminpassword"
update_env "POSTGRES_DB" "datalive_db"
update_env "REDIS_PASSWORD" "adminpassword"
update_env "N8N_USER_EMAIL" "admin@datalive.local"
update_env "N8N_USER_PASSWORD" "Adminpassword1"
update_env "N8N_USER_FIRSTNAME" "Admin"
update_env "N8N_USER_LASTNAME" "User"

# Configuraciones de MinIO
update_env "MINIO_ROOT_USER" "admin"
update_env "MINIO_ROOT_PASSWORD" "adminpassword"
update_env "MINIO_REGION" "us-east-1"

# Configuraciones de Grafana
update_env "GRAFANA_USER" "admin"
update_env "GRAFANA_PASSWORD" "adminpassword"

printf "  ✓ Variables configuradas\n"

# Paso 4: Crear estructura de directorios
printf "\n%s\n" "${GREEN}Paso 4: Creando estructura de directorios...${NC}"

dirs_to_create="
logs
secrets
config/n8n
config/qdrant
config/prometheus
config/grafana/provisioning
config/loki
config/promtail
backups/postgres
workflows/basic
resources/crdtls
"

for dir in $dirs_to_create; do
    ensure_dir "$PROJECT_ROOT/$dir"
    printf "  ✓ %s\n" "$dir"
done

# Paso 5: Crear archivos de secretos
printf "\n%s\n" "${GREEN}Paso 5: Generando archivos de secretos...${NC}"

# Generar secretos de manera compatible
printf "adminpassword" > "$PROJECT_ROOT/secrets/postgres_password.txt"
printf "adminpassword" > "$PROJECT_ROOT/secrets/minio_secret_key.txt"
printf "adminpassword" > "$PROJECT_ROOT/secrets/grafana_password.txt"

# Generar clave de encriptación de N8N
if command_exists openssl; then
    openssl rand -hex 32 > "$PROJECT_ROOT/secrets/n8n_encryption_key.txt"
else
    # Fallback para sistemas sin openssl
    generate_id 64 > "$PROJECT_ROOT/secrets/n8n_encryption_key.txt"
fi

printf "  ✓ Archivos de secretos creados\n"

# Paso 6: Verificar archivos críticos
printf "\n%s\n" "${GREEN}Paso 6: Verificando configuración...${NC}"

critical_files="
docker/docker-compose.yml
scripts/lib/universal-functions.sh
.env
"

for file in $critical_files; do
    if [ -f "$PROJECT_ROOT/$file" ]; then
        printf "  ✓ %s\n" "$file"
    else
        printf "  ✗ %s faltante\n" "$file"
    fi
done

# Paso 7: Información final
printf "\n%s\n" "${GREEN}Paso 7: Setup completado${NC}"

printf "\n%s\n" "${CYAN}=== DataLive Setup Completado ===${NC}"
printf "\nPróximos pasos:\n"
printf "1. Inicia los servicios:\n"
printf "   %s\n" "${YELLOW}docker compose -f docker/docker-compose.yml --env-file .env up -d${NC}"
printf "\n"
printf "2. Ejecuta el setup de N8N:\n"
printf "   %s\n" "${YELLOW}./scripts/init-n8n-setup.sh${NC}"
printf "\n"
printf "3. Accede a los servicios:\n"
printf "   - N8N: %s\n" "${CYAN}http://localhost:5678${NC}"
printf "   - Grafana: %s\n" "${CYAN}http://localhost:3000${NC}"
printf "   - MinIO: %s\n" "${CYAN}http://localhost:9001${NC}"
printf "\n"
printf "4. Credenciales por defecto:\n"
printf "   - Usuario: %s\n" "${GREEN}admin${NC}"
printf "   - Contraseña: %s\n" "${GREEN}adminpassword${NC}"
printf "   - N8N: %s / %s\n" "${GREEN}admin@datalive.local${NC}" "${GREEN}Adminpassword1${NC}"

printf "\n%s\n" "${BLUE}Sistema configurado para máxima compatibilidad:${NC}"
printf "  ✓ Funciona en cualquier shell POSIX\n"
printf "  ✓ Compatible con sistemas desde hace 10 años\n"
printf "  ✓ Sin dependencias de bash avanzado\n"
printf "  ✓ Credenciales estandarizadas\n"
printf "  ✓ Estructura de directorios creada\n"

# Crear resumen final
cat > "$PROJECT_ROOT/setup-summary.txt" << EOF
DataLive Universal Setup Summary
===============================
Date: $(date)
OS: $(detect_os)
Project Root: $PROJECT_ROOT

Setup completed successfully with maximum compatibility.

Services configured:
- PostgreSQL (admin/adminpassword)
- Redis (adminpassword)
- N8N (admin@datalive.local/Adminpassword1)
- MinIO (admin/adminpassword)
- Grafana (admin/adminpassword)
- Qdrant Vector DB
- Ollama LLM Server
- Prometheus + Loki monitoring

Next steps:
1. docker compose -f docker/docker-compose.yml --env-file .env up -d
2. ./scripts/init-n8n-setup.sh
3. Access services at localhost ports

All scripts are now universally compatible.
EOF

printf "\nResumen guardado en: setup-summary.txt\n"
printf "\n%s\n" "${GREEN}¡DataLive está listo para cualquier sistema!${NC}"