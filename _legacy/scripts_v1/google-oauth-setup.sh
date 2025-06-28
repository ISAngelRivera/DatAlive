#!/bin/sh
# google-oauth-setup.sh - Guía interactiva para configurar Google OAuth
# Este script ayuda a configurar las credenciales de Google Drive
# Compatible con: bash 3.2+, sh, dash, zsh, Git Bash, WSL

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

# Verificar dependencias mínimas
check_dependencies grep cut sed

# Clear screen de manera compatible
if command_exists clear; then
    clear
elif command_exists cls; then
    cls
else
    printf "\033[2J\033[H"
fi

printf "%s\n" "$CYAN"
cat << "EOF"
   ____                   _        ____    _         _   _     
  / ___| ___   ___   __ _| | ___  / __ \  / \  _   _| |_| |__  
 | |  _ / _ \ / _ \ / _` | |/ _ \| |  | |/ _ \| | | | __| '_ \ 
 | |_| | (_) | (_) | (_| | |  __/| |__| / ___ \ |_| | |_| | | |
  \____|\___/ \___/ \__, |_|\___| \____/_/   \_\__,_|\__|_| |_|
                    |___/                                       
EOF
printf "%s\n" "$NC"

printf "%s\n" "${BLUE}=== Configuración de Google OAuth para DataLive ===${NC}"
printf "\n"

# Check if .env exists
if [ ! -f "$PROJECT_ROOT/.env" ]; then
    printf "%s\n" "${RED}ERROR: No se encontró el archivo .env${NC}"
    printf "Por favor, ejecuta primero: cp .env.template .env\n"
    exit 1
fi

printf "%s\n" "${YELLOW}Este script te guiará para configurar Google OAuth.${NC}"
printf "%s\n" "${YELLOW}Necesitarás acceso a Google Cloud Console.${NC}"
printf "\n"

printf "%s\n" "${GREEN}Paso 1: Crear un proyecto en Google Cloud${NC}"
printf "1. Ve a: https://console.cloud.google.com/\n"
printf "2. Crea un nuevo proyecto o selecciona uno existente\n"
printf "3. Anota el ID del proyecto\n"
printf "\n"
printf "Presiona ENTER cuando hayas completado este paso..."
read dummy_input

printf "\n%s\n" "${GREEN}Paso 2: Habilitar Google Drive API${NC}"
printf "1. En el menú lateral, ve a 'APIs y servicios' > 'Biblioteca'\n"
printf "2. Busca 'Google Drive API'\n"
printf "3. Haz clic en ella y presiona 'HABILITAR'\n"
printf "\n"
printf "Presiona ENTER cuando hayas habilitado la API..."
read dummy_input

printf "\n%s\n" "${GREEN}Paso 3: Crear credenciales OAuth 2.0${NC}"
printf "1. Ve a 'APIs y servicios' > 'Credenciales'\n"
printf "2. Haz clic en '+ CREAR CREDENCIALES' > 'ID de cliente de OAuth'\n"
printf "3. Si es la primera vez, configura la pantalla de consentimiento:\n"
printf "   - Tipo de usuario: Interno (si es G Suite) o Externo\n"
printf "   - Completa la información básica\n"
printf "   - Añade los scopes:\n"
printf "     • https://www.googleapis.com/auth/drive.readonly\n"
printf "     • https://www.googleapis.com/auth/drive.metadata.readonly\n"
printf "\n"
printf "Presiona ENTER cuando hayas configurado la pantalla de consentimiento..."
read dummy_input

printf "\n%s\n" "${GREEN}Paso 4: Configurar el cliente OAuth${NC}"
printf "1. Tipo de aplicación: 'Aplicación web'\n"
printf "2. Nombre: 'DataLive RAG System' (o el que prefieras)\n"
printf "3. URIs de redirección autorizadas, añade:\n"
printf "   %s\n" "${CYAN}http://localhost:5678/rest/oauth2-credential/callback${NC}"
printf "4. Haz clic en 'CREAR'\n"
printf "\n"
printf "Presiona ENTER cuando hayas creado las credenciales..."
read dummy_input

printf "\n%s\n" "${GREEN}Paso 5: Copiar las credenciales${NC}"
printf "Ahora verás tu Client ID y Client Secret.\n"
printf "\n"

# Función para validar Client ID
validate_client_id() {
    local id="$1"
    # Verificar que termine en .apps.googleusercontent.com y contenga números y guiones
    case "$id" in
        *[0-9]*-*apps.googleusercontent.com) return 0 ;;
        *) return 1 ;;
    esac
}

# Read Client ID con validación compatible
while true; do
    printf "%s" "${CYAN}Pega aquí tu Client ID: ${NC}"
    read client_id
    client_id="$(trim "$client_id")"
    
    if [ -n "$client_id" ] && validate_client_id "$client_id"; then
        break
    else
        printf "%s\n" "${RED}El Client ID no parece válido. Debería terminar en .apps.googleusercontent.com${NC}"
    fi
done

# Read Client Secret con validación básica
while true; do
    printf "%s" "${CYAN}Pega aquí tu Client Secret: ${NC}"
    read client_secret
    client_secret="$(trim "$client_secret")"
    
    if [ -n "$client_secret" ]; then
        break
    else
        printf "%s\n" "${RED}El Client Secret no puede estar vacío${NC}"
    fi
done

printf "\n%s\n" "${BLUE}Actualizando archivo .env...${NC}"
update_env "GOOGLE_CLIENT_ID" "$client_id"
update_env "GOOGLE_CLIENT_SECRET" "$client_secret"

# Optional: Configure folders to sync
printf "\n%s\n" "${GREEN}Paso 6: Configurar carpetas de Google Drive (opcional)${NC}"
printf "Para sincronizar carpetas específicas, necesitas sus IDs.\n"
printf "Para obtener el ID de una carpeta:\n"
printf "1. Abre la carpeta en Google Drive\n"
printf "2. La URL será algo como: https://drive.google.com/drive/folders/[FOLDER_ID]\n"
printf "3. Copia el FOLDER_ID\n"
printf "\n"

printf "¿Quieres configurar carpetas específicas? (s/N): "
read configure_folders

# Verificar respuesta de manera compatible
case "$configure_folders" in
    [Ss]|[Ss][Ii]|[Yy]|[Yy][Ee][Ss])
        printf "IDs de carpetas (separados por comas): "
        read folder_ids
        folder_ids="$(trim "$folder_ids")"
        if [ -n "$folder_ids" ]; then
            update_env "GOOGLE_DRIVE_FOLDERS" "$folder_ids"
        fi
        ;;
esac

# Create OAuth file if needed
printf "\n%s\n" "${BLUE}Creando archivo de configuración OAuth...${NC}"
ensure_dir "$PROJECT_ROOT/resources/crdtls"

# Crear archivo JSON de manera compatible (evitar here-documents complejos)
cat > "$PROJECT_ROOT/resources/crdtls/OauthGoogle.json" << EOF
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

printf "\n%s\n" "${GREEN}✅ Configuración guardada exitosamente!${NC}"

printf "\n%s\n" "${YELLOW}Próximos pasos:${NC}"
printf "1. Reinicia los servicios: docker restart datalive-n8n\n"
printf "2. Accede a N8N: http://localhost:5678\n"
printf "3. Ve a Credentials > Google Drive\n"
printf "4. Haz clic en 'Connect' y autoriza el acceso\n"
printf "\n"

printf "%s\n" "${BLUE}Configuración guardada en:${NC}"
# Mostrar solo primeros 20 caracteres del client_id de manera compatible
client_id_preview="$(echo "$client_id" | cut -c1-20)"
printf "- Client ID: %s...\n" "$client_id_preview"
printf "- Archivo OAuth: %s/resources/crdtls/OauthGoogle.json\n" "$PROJECT_ROOT"
printf "- Variables actualizadas en .env\n"

printf "\n%s\n" "${GREEN}¡Listo! Las credenciales de Google OAuth están configuradas.${NC}"

# Test if N8N is running usando funciones universales
if wait_for_service "http://localhost:5678/healthz" 1; then
    printf "\n%s\n" "${CYAN}N8N está ejecutándose. Puedes proceder con la autorización.${NC}"
else
    printf "\n%s\n" "${YELLOW}N8N no está ejecutándose. Inicia los servicios primero.${NC}"
fi