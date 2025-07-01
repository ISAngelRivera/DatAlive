# Procedimientos Especiales - DataLive

**Versión:** 1.0  
**Fecha:** 2025-07-01  
**Autor:** Claude Code + Angel Rivera  

Este documento contiene procedimientos técnicos avanzados desarrollados para el proyecto DataLive que pueden ser reutilizados en otros proyectos.

---

## 1. Automatización Completa de N8N

### 1.1. Problema Identificado

N8N requiere múltiples pasos manuales al inicializar una nueva instancia:
- Registro del usuario propietario (owner)
- Completar wizard de onboarding (preguntas de personalización)
- Activación de licencia
- Creación manual de credenciales
- Importación manual de workflows

**Consecuencia:** Cada vez que se destruye y recrea el entorno Docker, hay que repetir estos pasos manualmente.

### 1.2. Solución Implementada: Sidecar Container de Setup

#### Arquitectura de la Solución

```yaml
# docker-compose.yml
n8n-setup:
  image: alpine:latest
  container_name: datalive-n8n-setup
  env_file: .env
  volumes:
    - ./init-n8n/setup-n8n.sh:/setup-n8n.sh:ro
    - ./datalive_agent/n8n_workflows:/workflows:ro
  depends_on:
    n8n:
      condition: service_healthy
  command: >
    sh -c "
      apk add --no-cache curl jq &&
      sh /setup-n8n.sh
    "
  networks:
    - datalive-net
```

**Características clave:**
- **Sidecar temporal**: Se ejecuta una sola vez después de que N8N esté healthy
- **Idempotente**: Puede ejecutarse múltiples veces sin romper nada
- **Auto-contenido**: Instala sus propias dependencias (curl, jq)

#### 1.3. Desafío Crítico: Autenticación Básica

**Problema:** N8N con `N8N_BASIC_AUTH_ACTIVE=true` no permite el registro automático del owner.

**Solución:** Proceso de dos fases:

```yaml
# Fase 1: Setup inicial sin autenticación básica
n8n:
  environment:
    - N8N_BASIC_AUTH_ACTIVE=false  # Temporal para setup
```

```bash
# Fase 2: Reactivar autenticación básica después del setup
docker-compose stop n8n && docker-compose rm -f n8n
# Quitar override de environment y reiniciar
docker-compose up -d n8n
```

### 1.4. Script de Setup Completo

#### Estructura del Script (`init-n8n/setup-n8n.sh`)

```bash
#!/bin/sh
# setup-n8n.sh - v4.0 Auto-configuración completa de N8N

# Variables de configuración
N8N_URL="http://n8n:5678"
REST_URL="${N8N_URL}/rest"
COOKIE_FILE="/tmp/n8n_session_cookie.txt"

# Funciones principales:
# 1. wait_for_n8n()        - Espera a que N8N esté disponible
# 2. register_owner()      - Registra el usuario propietario
# 3. login_and_get_cookie() - Autentica y obtiene cookie de sesión
# 4. complete_onboarding() - Completa el wizard automáticamente
# 5. activate_license()    - Activa la licencia empresarial
# 6. create_credentials()  - Crea todas las credenciales
# 7. import_workflows()    - Importa workflows desde JSON
```

#### Función Clave: Completar Onboarding

```bash
complete_onboarding() {
    log "Completando el wizard de onboarding..."
    
    # Paso 1: Respuestas de personalización
    personalization_data=$(cat <<EOF
{
    "version": "v4",
    "personalization_survey_submitted_at": "$(date -u +%Y-%m-%dT%H:%M:%S.000Z)",
    "personalization_survey_n8n_version": "1.99.0",
    "company_size": "20+",
    "work_area": "IT",
    "company_industry": "Technology",
    "automation_goal": "improve_efficiency",
    "coding_skill": "advanced",
    "other_automation_tools": [],
    "marketing_consent": false
}
EOF
)
    
    curl -s -b "$COOKIE_FILE" -X POST \
        -H "Content-Type: application/json" \
        -d "$personalization_data" \
        "${REST_URL}/me/survey"
    
    # Paso 2: Marcar como completado
    settings_data=$(cat <<EOF
{
    "userActivated": true,
    "firstSuccessfulWorkflowId": "",
    "userActivatedAt": "$(date -u +%Y-%m-%dT%H:%M:%S.000Z)"
}
EOF
)
    
    curl -s -b "$COOKIE_FILE" -X PATCH \
        -H "Content-Type: application/json" \
        -d "$settings_data" \
        "${REST_URL}/me/settings"
}
```

#### Creación de Credenciales

**Tipos de credenciales correctos para cada servicio:**

```bash
# PostgreSQL
create_credential "DataLive PostgreSQL" "postgres" '{
    "host": "postgres",
    "port": 5432,
    "database": "'"${POSTGRES_DB}"'",
    "user": "'"${POSTGRES_USER}"'",
    "password": "'"${POSTGRES_PASSWORD}"'",
    "ssl": "disable"
}'

# Qdrant - IMPORTANTE: Incluir URL en data
create_credential "DataLive Qdrant" "qdrantApi" '{
    "url": "http://qdrant:6333",
    "apiKey": ""
}'

# Ollama
create_credential "DataLive Ollama" "ollamaApi" '{
    "baseUrl": "http://ollama:11434"
}'

# Neo4j
create_credential "DataLive Neo4j" "neo4jApi" '{
    "host": "neo4j",
    "port": 7687,
    "protocol": "bolt",
    "username": "neo4j",
    "password": "'"${NEO4J_AUTH#neo4j/}"'",
    "database": "neo4j"
}'

# Google Drive OAuth2
create_credential "DataLive Google Drive" "googleDriveOAuth2Api" '{
    "clientId": "'"${GOOGLE_CLIENT_ID}"'",
    "clientSecret": "'"${GOOGLE_CLIENT_SECRET}"'",
    "scopes": [
        "https://www.googleapis.com/auth/drive.readonly",
        "https://www.googleapis.com/auth/drive.metadata.readonly"
    ]
}'
```

#### Importación de Workflows

**Formato JSON requerido para workflows:**

```json
{
  "name": "Mi Workflow",
  "nodes": [...],
  "connections": {...},
  "active": false,    // CRÍTICO: Campo obligatorio
  "settings": {},     // CRÍTICO: Campo obligatorio  
  "id": "mi-workflow" // CRÍTICO: Campo obligatorio
}
```

**Errores comunes:**
- `SQLITE_CONSTRAINT: NOT NULL constraint failed: workflow_entity.active`
- **Solución:** Asegurar que todos los workflows tengan los campos `active`, `settings` e `id`

### 1.5. Proceso de Ejecución

#### Flujo Completo Automatizado

1. **Arranque inicial**: `docker-compose up -d`
2. **N8N se inicia** sin autenticación básica
3. **Sidecar container se ejecuta** automáticamente cuando N8N está healthy
4. **Setup completo**:
   - Registro de owner
   - Login y cookie de sesión
   - Onboarding completado
   - Licencia activada
   - 7 credenciales creadas
   - 5 workflows importados
5. **Reactivación de autenticación**: Reinicio de N8N con auth básica

#### Comando para Ejecución Manual

```bash
# Si necesitas ejecutar el setup manualmente
docker-compose run --rm n8n-setup
```

### 1.6. Debugging y Troubleshooting

#### Logs Detallados

El script incluye logging detallado para cada paso:

```bash
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [n8n-setup] $1"
}

# Ejemplo de uso
log "✓ Credencial '$name' creada exitosamente"
log "⚠ Error creando credencial '$name'"
```

#### Problemas Comunes y Soluciones

| Error | Causa | Solución |
|-------|-------|----------|
| `Instance owner already setup` | Usuario ya existe | Normal, continúa con login |
| `Wrong username or password` | Auth básica activa durante setup | Desactivar temporalmente |
| `workflow_entity.active NULL` | Workflow JSON sin campo active | Añadir campos obligatorios |
| `Cannot GET /rest/owner` | Endpoint no existe en versión | Usar endpoints correctos |

#### Verificación de Estado

```bash
# Verificar credenciales creadas
curl -s -b "$COOKIE_FILE" "${REST_URL}/credentials" | jq '.data[].name'

# Verificar workflows importados  
curl -s -b "$COOKIE_FILE" "${REST_URL}/workflows" | jq '.data[].name'
```

### 1.7. Beneficios de esta Aproximación

#### Para el Proyecto Actual
- ✅ **Setup completamente automático**: De 30 minutos manuales a 2 minutos automáticos
- ✅ **Idempotente**: Se puede ejecutar múltiples veces
- ✅ **Reproducible**: Mismo resultado en cualquier entorno
- ✅ **Sin intervención manual**: Perfecto para CI/CD

#### Para Reutilización en Otros Proyectos
- 📁 **Script portable**: Solo cambiar variables de entorno
- 🔧 **Credenciales configurables**: Fácil adaptación a otros servicios
- 📋 **Workflows modulares**: Sistema de directorios por categoría
- 🐳 **Docker-native**: Se integra perfectamente con cualquier stack Docker

### 1.8. Adaptación a Otros Proyectos

#### Variables a Personalizar

```bash
# En .env del nuevo proyecto
N8N_USER_EMAIL=tu@email.com
N8N_USER_FIRSTNAME=Tu
N8N_USER_LASTNAME=Apellido
N8N_USER_PASSWORD=TuPassword
N8N_LICENSE_KEY=tu-licencia

# Credenciales específicas del proyecto
POSTGRES_DB=tu_db
POSTGRES_USER=tu_user
# ... otras variables
```

#### Credenciales a Adaptar

Solo modificar la función `create_credentials()` con los servicios específicos del nuevo proyecto.

#### Workflows a Incluir

Crear directorio de workflows específicos y asegurar el formato JSON correcto.

---

## 2. Lecciones Aprendidas

### 2.1. Principios de Automatización

1. **Idempotencia es clave**: El script debe poder ejecutarse múltiples veces
2. **Logging detallado**: Fundamental para debugging en entornos Docker
3. **Validación de prerrequisitos**: Verificar que los servicios estén listos
4. **Gestión de errores graceful**: No fallar completamente por un error menor

### 2.2. Mejores Prácticas

1. **Sidecar containers**: Perfectos para tareas de setup one-time
2. **Healthchecks**: Usar `depends_on.condition: service_healthy`
3. **Secretos desde variables**: Nunca hardcodear credenciales
4. **Documentación inline**: Comentarios en el código para el futuro

### 2.3. Escalabilidad

Este enfoque se puede extender para:
- Configuración automática de Grafana
- Setup de bases de datos con esquemas iniciales
- Configuración de reverse proxies
- Inicialización de clusters de microservicios

---

## 3. Referencias y Recursos

- **API de N8N**: https://docs.n8n.io/api/
- **Docker Compose depends_on**: https://docs.docker.com/compose/compose-file/compose-file-v3/#depends_on
- **jq Documentation**: https://stedolan.github.io/jq/manual/

---

**Nota:** Este procedimiento fue desarrollado específicamente para N8N v1.99.1. Futuras versiones pueden requerir ajustes en los endpoints de API o estructura de datos.