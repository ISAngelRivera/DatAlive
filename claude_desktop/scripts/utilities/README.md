# Development Utilities Scripts

Esta carpeta contiene scripts de utilidad para desarrollo y configuración del sistema DataLive.

## 📁 Scripts Disponibles

### 🔧 Configuración y Setup

#### `configure-mcp.sh`
Configura el n8n-MCP para trabajar con la instancia de N8N de DataLive.

```bash
./claude_desktop/scripts/utilities/configure-mcp.sh
```

**Características:**
- Verifica instalación de Node.js y npm
- Instala y compila dependencias del MCP
- Configura base de datos del MCP
- Genera configuración para Claude Desktop

#### `start-development.sh`
Inicia DataLive en modo desarrollo con herramientas adicionales.

```bash
./claude_desktop/scripts/utilities/start-development.sh
```

**Incluye:**
- Perfil de desarrollo de Docker Compose
- N8N MCP Server para creación de workflows
- Herramientas de desarrollo adicionales

#### `use-n8n-mcp.sh`
Utilidad para ejecutar n8n-MCP durante el desarrollo de workflows.

```bash
./claude_desktop/scripts/utilities/use-n8n-mcp.sh
```

**Funcionalidades:**
- Modo documentación (sin API key)
- Modo completo (con API key de N8N)
- Conexión automática a la red de DataLive

### 🚀 Workflow Management

#### `deploy-ultimate-workflow.sh`
Script completo para desplegar workflows de DataLive en N8N.

```bash
./claude_desktop/scripts/utilities/deploy-ultimate-workflow.sh
```

**Características:**
- Verificación de prerrequisitos automática
- Backup de workflows existentes
- Creación de credenciales necesarias
- Validación post-despliegue
- Activación automática de workflows

#### `validate-ultimate-workflow.sh`
Valida workflows antes del despliegue para asegurar calidad.

```bash
./claude_desktop/scripts/utilities/validate-ultimate-workflow.sh
```

**Validaciones:**
- Estructura JSON válida
- Nodos requeridos presentes
- Conexiones entre nodos correctas
- Configuraciones críticas
- Referencias a credenciales
- Configuraciones de seguridad
- Optimizaciones de rendimiento

#### `import-workflow-automatic.sh`
Facilita la importación manual de workflows en N8N.

```bash
./claude_desktop/scripts/utilities/import-workflow-automatic.sh
```

**Proceso:**
- Validación del archivo de workflow
- Backup automático
- Instrucciones paso a paso
- Información post-importación

## 🎯 Casos de Uso

### Desarrollo de Workflows
```bash
# 1. Configurar entorno de desarrollo
./claude_desktop/scripts/utilities/configure-mcp.sh

# 2. Iniciar en modo desarrollo
./claude_desktop/scripts/utilities/start-development.sh

# 3. Usar MCP para desarrollo
./claude_desktop/scripts/utilities/use-n8n-mcp.sh
```

### Despliegue de Workflows
```bash
# 1. Validar workflow
./claude_desktop/scripts/utilities/validate-ultimate-workflow.sh

# 2. Desplegar automáticamente
./claude_desktop/scripts/utilities/deploy-ultimate-workflow.sh

# O importar manualmente
./claude_desktop/scripts/utilities/import-workflow-automatic.sh
```

## 🔧 Requisitos

### Para MCP Scripts
- Node.js >= 16
- npm
- Docker y Docker Compose
- DataLive corriendo (`docker-compose up -d`)

### Para Workflow Scripts
- jq (JSON processor)
- curl
- N8N accesible en http://localhost:5678

## 📋 Variables de Entorno

Los scripts usan estas variables de entorno:

```bash
# URLs de servicios
N8N_URL=http://localhost:5678
N8N_API_KEY=your-api-key-here

# Rutas de archivos
WORKFLOW_FILE=datalive_agent/n8n_workflows/workflow.json
MCP_DIR=/path/to/n8n-mcp-main
```

## 🔒 Seguridad

- Los scripts **no almacenan credenciales** en texto plano
- Las API keys se obtienen automáticamente de contenedores
- Se crean backups antes de modificaciones
- Validación de seguridad en workflows

## 🐛 Troubleshooting

### Error: Docker no está corriendo
```bash
# Verificar Docker
docker info

# Iniciar Docker si es necesario
sudo systemctl start docker  # Linux
open /Applications/Docker.app  # macOS
```

### Error: N8N no accesible
```bash
# Verificar que DataLive esté corriendo
docker-compose ps

# Reiniciar si es necesario
docker-compose restart n8n
```

### Error: jq no encontrado
```bash
# Instalar jq
brew install jq           # macOS
sudo apt install jq      # Ubuntu/Debian
sudo yum install jq       # CentOS/RHEL
```

### Error: No se puede obtener API key
```bash
# Obtener manualmente del contenedor
docker exec datalive-n8n cat /home/node/.n8n/n8n_api_key

# O generar nueva desde interfaz N8N
# Settings > API > Create New API Key
```

## 📚 Referencias

- [N8N MCP Documentation](https://github.com/czlonkowski/n8n-mcp)
- [DataLive Workflow Documentation](../../docs/ULTIMATE_WORKFLOW_DOCUMENTATION.md)
- [N8N API Documentation](https://docs.n8n.io/api/)

## 🤝 Contribuir

Para añadir nuevos scripts de utilidad:

1. Crear el script en esta carpeta
2. Hacer ejecutable: `chmod +x script.sh`
3. Añadir documentación a este README
4. Probar con diferentes configuraciones
5. Actualizar scripts de CI/CD si es necesario