#!/bin/bash
# fix-permissions.sh - Corrige permisos de todos los archivos del proyecto
# Este script debe estar en la carpeta scripts/

set -euo pipefail

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Corrigiendo permisos del proyecto DataLive ===${NC}"

# Obtener el directorio del script y el directorio raíz del proyecto
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Verificar que estamos en la estructura correcta
if [ ! -f "$PROJECT_ROOT/docker/docker-compose.yml" ]; then
    echo -e "${RED}Error: No parece ser la estructura correcta de DataLive${NC}"
    echo "Esperado: scripts/fix-permissions.sh"
    exit 1
fi

echo -e "${YELLOW}Directorio de scripts: $SCRIPT_DIR${NC}"
echo -e "${YELLOW}Directorio del proyecto: $PROJECT_ROOT${NC}"

# Cambiar al directorio raíz para trabajar
cd "$PROJECT_ROOT"

# 1. Scripts ejecutables
echo -e "\n${GREEN}1. Dando permisos de ejecución a scripts...${NC}"
if [ -d "scripts" ]; then
    chmod +x scripts/*.sh 2>/dev/null || true
    echo "   ✓ Scripts en scripts/*.sh"
fi

# 2. Script de git setup
if [ -f "git-setup-and-push.sh" ]; then
    chmod +x git-setup-and-push.sh
    echo "   ✓ git-setup-and-push.sh"
fi

# 3. Directorios con permisos correctos
echo -e "\n${GREEN}2. Asegurando permisos de directorios...${NC}"
directories=(
    "secrets"
    "logs"
    "config"
    "workflows"
    "docker"
)

for dir in "${directories[@]}"; do
    if [ -d "$dir" ]; then
        chmod 755 "$dir"
        echo "   ✓ $dir/"
    fi
done

# 4. Archivos sensibles (más restrictivos)
echo -e "\n${GREEN}3. Protegiendo archivos sensibles...${NC}"
if [ -d "secrets" ]; then
    chmod 700 secrets
    chmod 600 secrets/*.txt 2>/dev/null || true
    echo "   ✓ secrets/ (solo owner)"
fi

# 5. Archivos de configuración
echo -e "\n${GREEN}4. Permisos de archivos de configuración...${NC}"
config_files=(
    ".env"
    ".env.example"
    "docker/docker-compose.yml"
)

for file in "${config_files[@]}"; do
    if [ -f "$file" ]; then
        chmod 644 "$file"
        echo "   ✓ $file"
    fi
done

# 6. Verificar permisos finales
echo -e "\n${BLUE}=== Verificación de permisos ===${NC}"
echo -e "\n${YELLOW}Scripts (deberían ser ejecutables -rwxr-xr-x):${NC}"
ls -la scripts/*.sh 2>/dev/null | grep -E "\.sh$" || echo "No se encontraron scripts"

echo -e "\n${YELLOW}Secrets (deberían ser restrictivos drwx------):${NC}"
ls -ld secrets 2>/dev/null || echo "Directorio secrets no existe aún"

echo -e "\n${GREEN}✓ Permisos corregidos exitosamente${NC}"
echo -e "${BLUE}Nota: Si estás en macOS/Linux, estos permisos se preservarán en Git${NC}"
echo -e "${BLUE}Para Windows, puede que necesites ejecutar este script después de clonar${NC}"

# Crear un .gitattributes para preservar permisos en Git
echo -e "\n${GREEN}5. Creando .gitattributes para preservar permisos...${NC}"
cat > .gitattributes << 'EOF'
# Preserve execute permissions for shell scripts
*.sh text eol=lf
scripts/*.sh text eol=lf

# Ensure consistent line endings
*.yml text eol=lf
*.yaml text eol=lf
*.json text eol=lf
*.md text eol=lf
.env* text eol=lf
Dockerfile* text eol=lf

# Mark scripts as executable (Git 2.9.1+)
scripts/*.sh filter=fix-perms
*.sh filter=fix-perms
EOF

echo "   ✓ .gitattributes creado"

# Mostrar siguiente paso
echo -e "\n${GREEN}=== ¡Listo! ===${NC}"
echo -e "Ahora puedes hacer commit de estos cambios:"
echo -e "${YELLOW}git add -A${NC}"
echo -e "${YELLOW}git commit -m \"fix: correct file permissions for scripts\"${NC}"
echo -e "${YELLOW}git push${NC}"