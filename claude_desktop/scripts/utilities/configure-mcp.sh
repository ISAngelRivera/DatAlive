#!/bin/bash
# Script para configurar el MCP de N8N para DataLive
# Este script configurará el MCP para trabajar con nuestra instancia de N8N

set -e

MCP_DIR="/Users/angelrivera/Desktop/GIT/n8n-mcp-main"
DATALIVE_DIR="/Users/angelrivera/Desktop/GIT/DatAlive"

echo "🔧 Configurando N8N MCP para DataLive..."

# Verificar que el directorio MCP existe
if [ ! -d "$MCP_DIR" ]; then
    echo "❌ Error: Directorio MCP no encontrado: $MCP_DIR"
    exit 1
fi

# Verificar que Node.js está instalado
if ! command -v node &> /dev/null; then
    echo "❌ Error: Node.js no está instalado"
    exit 1
fi

# Verificar que npm está instalado
if ! command -v npm &> /dev/null; then
    echo "❌ Error: npm no está instalado"
    exit 1
fi

echo "📦 Verificando instalación del MCP..."

# Cambiar al directorio MCP
cd "$MCP_DIR"

# Verificar si está instalado
if [ ! -d "node_modules" ]; then
    echo "📦 Instalando dependencias del MCP..."
    npm install
fi

# Verificar si está compilado
if [ ! -d "dist" ]; then
    echo "🔨 Compilando MCP..."
    npm run build
fi

# Verificar si la base de datos existe
if [ ! -f "data/nodes.db" ]; then
    echo "🗄️ Inicializando base de datos del MCP..."
    npm run rebuild
fi

echo "✅ MCP configurado correctamente"

# Generar clave API de N8N si no existe
echo "🔑 Configurando acceso a N8N de DataLive..."

# Obtener la URL de N8N desde docker-compose
N8N_URL="http://localhost:5678"

echo "📋 Configuración del MCP:"
echo "   • Directorio MCP: $MCP_DIR"
echo "   • N8N URL: $N8N_URL"
echo "   • Base de datos: $MCP_DIR/data/nodes.db"

echo ""
echo "🚀 Para usar el MCP:"
echo "   1. Asegurate de que N8N esté ejecutándose (docker-compose up -d)"
echo "   2. Genera una API Key en N8N (Settings > API)"
echo "   3. Actualiza el archivo .env con la API Key"
echo "   4. Ejecuta: cd $MCP_DIR && npm start"

echo ""
echo "🔧 Para configurar Claude Desktop:"
echo "   Agrega esta configuración a tu claude_desktop_config.json:"
echo ""
echo '{'
echo '  "mcpServers": {'
echo '    "n8n-datalive": {'
echo '      "command": "node",'
echo '      "args": ["'$MCP_DIR'/dist/mcp/index.js"],'
echo '      "env": {'
echo '        "MCP_MODE": "stdio",'
echo '        "LOG_LEVEL": "error",'
echo '        "DISABLE_CONSOLE_OUTPUT": "true",'
echo '        "N8N_API_URL": "'$N8N_URL'",'
echo '        "N8N_API_KEY": "YOUR_N8N_API_KEY_HERE"'
echo '      }'
echo '    }'
echo '  }'
echo '}'

echo ""
echo "✅ Configuración del MCP completada"