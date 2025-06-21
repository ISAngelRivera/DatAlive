#!/bin/bash
# setup-google-oauth.sh - Guía interactiva para configurar Google OAuth
# Este script ayuda a configurar las credenciales de Google Drive

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

clear

echo -e "${CYAN}"
cat << "EOF"
   ____                   _        ____    _         _   _     
  / ___| ___   ___   __ _| | ___  / __ \  / \  _   _| |_| |__  
 | |  _ / _ \ / _ \ / _` | |/ _ \| |  | |/ _ \| | | | __| '_ \ 
 | |_| | (_) | (_) | (_| | |  __/| |__| / ___ \ |_| | |_| | | |
  \____|\___/ \___/ \__, |_|\___| \____/_/   \_\__,_|\__|_| |_|
                    |___/                                       
EOF
echo -e "${NC}"

echo -e "${BLUE}=== Configuración de Google OAuth para DataLive ===${NC}\n"

# Check if .env exists
if [ ! -f "$PROJECT_ROOT/.env" ]; then
    echo -e "${RED}ERROR: No se encontró el archivo .env${NC}"
    echo "Por favor, ejecuta primero: cp .env.template .env"
    exit 1
fi

# Function to update .env
update_env() {
    local key=$1
    local value=$2
    
    # Escape special characters for sed
    value=$(echo "$value" | sed 's/[[\.*^$()+?{|]/\\&/g')
    
    # Update or add the key
    if grep -q "^${key}=" "$PROJECT_ROOT/.env"; then
        sed -i "s/^${key}=.*/${key}=${value}/" "$PROJECT_ROOT/.env"
    else
        echo "${key}=${value}" >> "$PROJECT_ROOT/.env"
    fi
}

echo -e "${YELLOW}Este script te guiará para configurar Google OAuth.${NC}"
echo -e "${YELLOW}Necesitarás acceso a Google Cloud Console.${NC}\n"

echo -e "${GREEN}Paso 1: Crear un proyecto en Google Cloud${NC}"
echo "1. Ve a: https://console.cloud.google.com/"
echo "2. Crea un nuevo proyecto o selecciona uno existente"
echo "3. Anota el ID del proyecto"
echo ""
read -p "Presiona ENTER cuando hayas completado este paso..."

echo -e "\n${GREEN}Paso 2: Habilitar Google Drive API${NC}"
echo "1. En el menú lateral, ve a 'APIs y servicios' > 'Biblioteca'"
echo "2. Busca 'Google Drive API'"
echo "3. Haz clic en ella y presiona 'HABILITAR'"
echo ""
read -p "Presiona ENTER cuando hayas habilitado la API..."

echo -e "\n${GREEN}Paso 3: Crear credenciales OAuth 2.0${NC}"
echo "1. Ve a 'APIs y servicios' > 'Credenciales'"
echo "2. Haz clic en '+ CREAR CREDENCIALES' > 'ID de cliente de OAuth'"
echo "3. Si es la primera vez, configura la pantalla de consentimiento:"
echo "   - Tipo de usuario: Interno (si es G Suite) o Externo"
echo "   - Completa la información básica"
echo "   - Añade los scopes:"
echo "     • https://www.googleapis.com/auth/drive.readonly"
echo "     • https://www.googleapis.com/auth/drive.metadata.readonly"
echo ""
read -p "Presiona ENTER cuando hayas configurado la pantalla de consentimiento..."

echo -e "\n${GREEN}Paso 4: Configurar el cliente OAuth${NC}"
echo "1. Tipo de aplicación: 'Aplicación web'"
echo "2. Nombre: 'DataLive RAG System' (o el que prefieras)"
echo "3. URIs de redirección autorizadas, añade:"
echo -e "   ${CYAN}http://localhost:5678/rest/oauth2-credential/callback${NC}"
echo "4. Haz clic en 'CREAR'"
echo ""
read -p "Presiona ENTER cuando hayas creado las credenciales..."

echo -e "\n${GREEN}Paso 5: Copiar las credenciales${NC}"
echo "Ahora verás tu Client ID y Client Secret."
echo ""

# Read Client ID
while true; do
    read -p "$(echo -e ${CYAN})Pega aquí tu Client ID: $(echo -e ${NC})" client_id
    if [[ $client_id =~ ^[0-9]+-[a-z0-9]+\.apps\.googleusercontent\.com$ ]]; then
        break
    else
        echo -e "${RED}El Client ID no parece válido. Debería terminar en .apps.googleusercontent.com${NC}"
    fi
done

# Read Client Secret
while true; do
    read -p "$(echo -e ${CYAN})Pega aquí tu Client Secret: $(echo -e ${NC})" client_secret
    if [[ -n $client_secret ]]; then
        break
    else
        echo -e "${RED}El Client Secret no puede estar vacío${NC}"
    fi
done

echo -e "\n${BLUE}Actualizando archivo .env...${NC}"
update_env "GOOGLE_CLIENT_ID" "$client_id"
update_env "GOOGLE_CLIENT_SECRET" "$client_secret"

# Optional: Configure folders to sync
echo -e "\n${GREEN}Paso 6: Configurar carpetas de Google Drive (opcional)${NC}"
echo "Para sincronizar carpetas específicas, necesitas sus IDs."
echo "Para obtener el ID de una carpeta:"
echo "1. Abre la carpeta en Google Drive"
echo "2. La URL será algo como: https://drive.google.com/drive/folders/[FOLDER_ID]"
echo "3. Copia el FOLDER_ID"
echo ""

read -p "¿Quieres configurar carpetas específicas? (s/N): " configure_folders
if [[ $configure_folders =~ ^[Ss]$ ]]; then
    read -p "IDs de carpetas (separados por comas): " folder_ids
    update_env "GOOGLE_DRIVE_FOLDERS" "$folder_ids"
fi

# Create OAuth file if needed
echo -e "\n${BLUE}Creando archivo de configuración OAuth...${NC}"
mkdir -p "$PROJECT_ROOT/resources/crdtls"

cat > "$PROJECT_ROOT/resources/crdtls/OauthGoogle.json" <<EOF
{
  "web": {
    "client_id": "${client_id}",
    "project_id": "datalive-rag",
    "auth_uri": "https://accounts.google.com/o/oauth2/auth",
    "token_uri": "https://oauth2.googleapis.com/token",
    "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
    "client_secret": "${client_secret}",
    "redirect_uris": [
      "http://localhost:5678/rest/oauth2-credential/callback"
    ]
  }
}
EOF

update_env "GOOGLE_OAUTH_FILE" "./resources/crdtls/OauthGoogle.json"

echo -e "\n${GREEN}✅ Configuración guardada exitosamente!${NC}"

echo -e "\n${YELLOW}Próximos pasos:${NC}"
echo "1. Reinicia los servicios: docker restart datalive-n8n"
echo "2. Accede a N8N: http://localhost:5678"
echo "3. Ve a Credentials > Google Drive"
echo "4. Haz clic en 'Connect' y autoriza el acceso"
echo ""

echo -e "${BLUE}Configuración guardada en:${NC}"
echo "- Client ID: ${client_id:0:20}..."
echo "- Archivo OAuth: $PROJECT_ROOT/resources/crdtls/OauthGoogle.json"
echo "- Variables actualizadas en .env"

echo -e "\n${GREEN}¡Listo! Las credenciales de Google OAuth están configuradas.${NC}"

# Test if N8N is running
if curl -sf "http://localhost:5678/healthz" > /dev/null 2>&1; then
    echo -e "\n${CYAN}N8N está ejecutándose. Puedes proceder con la autorización.${NC}"
else
    echo -e "\n${YELLOW}N8N no está ejecutándose. Inicia los servicios primero.${NC}"
fi