# Guía de Configuración de Variables de Entorno - DataLive

## 🎯 Propósito
Esta guía explica qué variables de entorno necesitas configurar manualmente y cuáles se automatizan durante el despliegue de DataLive.

## 📋 Variables que Requieren Configuración Manual

### 🔐 Variables de Seguridad CRÍTICAS
**⚠️ OBLIGATORIO cambiar antes de producción:**

```bash
# PostgreSQL - Cambiar por contraseña segura
POSTGRES_PASSWORD=adminpassword

# Neo4j - Cambiar por contraseña segura  
NEO4J_AUTH=neo4j/adminpassword

# MinIO - Cambiar por credenciales seguras
MINIO_ROOT_USER=datalive_admin
MINIO_ROOT_PASSWORD=change_this_minio_password

# N8N - Cambiar por datos personales seguros
N8N_USER_EMAIL=tu-email@ejemplo.com
N8N_USER_FIRSTNAME=TuNombre
N8N_USER_LASTNAME=TuApellido
N8N_USER_PASSWORD=TuPasswordSegura

# Grafana - Cambiar por contraseña segura
GF_SECURITY_ADMIN_PASSWORD=change_this_grafana_password
```

**🔑 Generar clave única:**
```bash
# N8N Encryption Key - Generar nueva clave
N8N_ENCRYPTION_KEY=$(openssl rand -base64 32)
```

### 🌐 Variables de Integración Externa
**Opcional según tu caso de uso:**

```bash
# Google Drive/Docs (si usas ingesta de Google)
GOOGLE_CLIENT_ID=tu-client-id.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=tu-client-secret

# N8N API Key (se obtiene después del primer arranque)
N8N_API_KEY=# Déjala vacía inicialmente
```

## ✅ Variables Completamente Automatizadas

### 🏗️ Configuración de Servicios
```bash
# Bases de datos - Nombres y puertos estándar
POSTGRES_DB=datalive_db
POSTGRES_USER=datalive_user

# Configuración de red interna
DATALIVE_AGENT_PORT=8058
TZ=Europe/Madrid

# N8N - Configuración de autenticación automática
N8N_BASIC_AUTH_ACTIVE=true
N8N_SECURE_COOKIE=false
```

### 🤖 Modelos AI
```bash
# Ollama - Modelos preconfigurados optimizados
OLLAMA_EMBEDDING_MODEL=nomic-embed-text:v1.5
OLLAMA_ROUTER_MODEL=phi3:medium
```

## 🔄 Variables Semi-Automatizadas

### 📊 N8N API Key
- **Estado**: Se genera automáticamente después del primer arranque
- **Acción requerida**: Ninguna (el sistema la obtiene solo)
- **Uso**: Permite importación automática de workflows

### 🔒 Certificados SSL
- **Estado**: Se generan automáticamente para Neo4j
- **Ubicación**: `init-neo4j/ssl/`
- **Propósito**: Compatibilidad con Safari

## 🚀 Proceso de Configuración Recomendado

### 1. Configuración Mínima (Desarrollo)
```bash
# Solo cambiar estas 3 variables para empezar:
N8N_USER_EMAIL=tu-email@ejemplo.com
N8N_USER_FIRSTNAME=TuNombre  
N8N_USER_LASTNAME=TuApellido
```

### 2. Configuración Segura (Producción)
```bash
# Generar contraseñas seguras para todas las variables marcadas como ⚠️
# Usar: openssl rand -base64 32 para generar contraseñas fuertes
```

### 3. Configuración Completa (Con integraciones)
```bash
# Añadir credenciales de Google si necesitas ingesta de documentos
# Configurar variables específicas de tu organización
```

## 📝 Variables por Servicio

| Servicio | Variables Manuales | Variables Automáticas |
|----------|-------------------|----------------------|
| **PostgreSQL** | `POSTGRES_PASSWORD` | `POSTGRES_DB`, `POSTGRES_USER` |
| **Neo4j** | `NEO4J_AUTH` | Certificados SSL, configuración de red |
| **MinIO** | `MINIO_ROOT_USER`, `MINIO_ROOT_PASSWORD` | Configuración de buckets |
| **N8N** | Email, nombre, contraseña del usuario | Setup automático, workflows |
| **DataLive Agent** | Ninguna | Configuración completa |
| **Ollama** | Ninguna | Modelos preconfigurados |

## 🛡️ Notas de Seguridad

### ⚠️ Para Desarrollo Local
- Las contraseñas por defecto son **aceptables** solo para desarrollo
- Todos los servicios están aislados en red Docker privada

### 🔒 Para Producción
- **OBLIGATORIO** cambiar todas las contraseñas por defecto
- Usar variables de entorno del sistema operativo en lugar de archivo .env
- Activar SSL/TLS en todos los servicios
- Configurar firewall para limitar acceso externo

## 🔧 Detección de Variables No Configuradas

El sistema detecta automáticamente variables faltantes y muestra avisos específicos:

```bash
# El sistema verificará y avisará si faltan:
- Contraseñas por defecto en producción
- Claves de cifrado no generadas
- Credenciales de servicios externos no configuradas
```

## 📖 Referencias

- **Configuración completa**: Ver archivo `.env`
- **Solución Safari**: Ver `docs/SAFARI_NEO4J_SOLUTION.md`
- **Scripts de automatización**: Ver `init-n8n/setup-n8n.sh`

---

**💡 Consejo**: Para el primer uso, solo necesitas cambiar tu email y nombre en las variables de N8N. Todo lo demás funciona automáticamente en desarrollo.