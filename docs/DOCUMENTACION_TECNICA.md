# 📚 Documentación Técnica Completa - DataLive

**Sistema de Inteligencia Empresarial Soberano**  
**Versión:** 4.0  
**Última Actualización:** 2025-07-02  
**Estado:** ✅ Operacional con Automatización Completa

## 📑 Tabla de Contenidos

1. [Arquitectura del Sistema](#arquitectura-del-sistema)
2. [Stack Tecnológico](#stack-tecnológico)
3. [Configuración de Entorno](#configuración-de-entorno)
4. [Procedimientos de Despliegue](#procedimientos-de-despliegue)
5. [Configuración de Servicios y Healthchecks](#configuración-de-servicios-y-healthchecks)
6. [Documentación de API](#documentación-de-api)
7. [Guías de Resolución de Problemas](#guías-de-resolución-de-problemas)
8. [Configuraciones Especiales](#configuraciones-especiales)

---

## 🏗️ Arquitectura del Sistema

### Descripción General

DataLive es un sistema de inteligencia empresarial soberano diseñado para actuar como el **cerebro de conocimiento centralizado** de una organización. El sistema democratiza el acceso al conocimiento corporativo, permitiendo a los empleados obtener respuestas precisas y auditables a preguntas complejas a través de sus herramientas de colaboración habituales.

### Diagrama de Arquitectura

```text
                                      +-------------------------------------------------------------------------+
                                      |                      NÚCLEO SOBERANO DATALIVE (Docker Stack)            |
                                      |                                                                         |
+--------------------------+          |   +---------------------------+        +-----------------------------+  |          +----------------------------+
| FUENTES DE DATOS         |          |   | CAPA DE ORQUESTACIÓN Y    |        | API Y LÓGICA DE APLICACIÓN  |  |          | DESTINOS DE NOTIFICACIÓN   |
| (Google Drive,           |--Ingesta-->| CONECTORES (n8n)            |------> | (datalive_agent)            |--Respuesta-->| (Slack, Teams, etc.)       |
| SharePoint, Confluence)  |<--Consulta--|                           |<------ |                             |  |          |                            |
+--------------------------+          |   +---------------------------+        +-------------+---------------+  |          +----------------------------+
                                      |                                        (Orquestador) |                 |
                                      |                                                      |                 |
                                      |                +-------------------------------------+-----------------+------------------+
                                      |                |                                     |                 |                  |
                                      |                V                                     V                 V                  V
                                      | +--------------------------+        +--------------------------+       +------------------+       +---------------+
                                      | |      GRAFO (Neo4j)       |        |    VECTORES (Qdrant)     |       | METADATOS (PostgreSQL)|       | FICHEROS (MinIO)|
                                      | +--------------------------+        +--------------------------+       +------------------+       +---------------+
                                      | (Relaciones, Entidades)             | (Embeddings, Búsqueda Semántica)|  (Chunks, Logs, Caché) |   (PDFs, DOCX)    |
                                      |                                                                         |                  |                  |
                                      |                ^                                     ^                 ^                  ^                  |
                                      |                |                                     |                 |                  |                  |
                                      |                +-------------------------------------+-----------------+------------------+                  |
                                      |                                        (LLMs Locales - Ollama)         (Inferencia)                         |
                                      |                                                                                                               |
                                      +---------------------------------------------------------------------------------------------------------------+
```

### Principios Arquitectónicos

1. **Núcleo Soberano, Conectores Universales**: Stack de procesamiento y almacenamiento 100% gratuito y auto-alojado
2. **La Herramienta Correcta para Cada Trabajo**: Cada componente se elige por ser el especialista en su dominio
3. **Automatización Total**: Setup con mínima intervención humana
4. **Seguridad por Diseño**: Contraseñas auto-generadas, SSL/TLS, aislamiento de red

---

## 💻 Stack Tecnológico

### Componentes Principales

| Componente | Tecnología | Versión | Rol en la Arquitectura |
|:-----------|:-----------|:--------|:-----------------------|
| **Orquestación** | Docker Compose | 2.0+ | Define, configura y ejecuta todo el ecosistema |
| **Agente Principal** | Python (FastAPI) | 3.11+ | API principal y lógica de agentes inteligentes |
| **Base de Datos Relacional** | PostgreSQL | 16-alpine | Metadatos, chunks, caché y logs |
| **Base de Datos de Grafo** | Neo4j | 5-community | Knowledge graph de entidades y relaciones |
| **Base de Datos Vectorial** | Qdrant | latest | Búsqueda semántica con embeddings |
| **Almacenamiento de Objetos** | MinIO | latest | Repositorio S3-compatible para archivos |
| **Automatización** | n8n | latest | Workflows y conectores externos |
| **Inferencia de IA** | Ollama | latest | LLMs locales y privados |
| **Gestión de Dependencias** | Poetry | 1.8+ | Entornos reproducibles |

### Tecnologías de Soporte

- **Monitoreo**: Prometheus + Grafana (opcional)
- **Caché**: Redis (preparado pero no activado por defecto)
- **Proxy Reverso**: Nginx/Traefik (producción)
- **SSL/TLS**: Certificados auto-generados para Neo4j

---

## 🔧 Configuración de Entorno

### Variables de Entorno Críticas

#### 🔐 Variables de Seguridad (Obligatorio cambiar en producción)

```bash
# PostgreSQL
POSTGRES_PASSWORD=adminpassword        # Cambiar por contraseña segura
POSTGRES_USER=datalive
POSTGRES_DB=datalive

# Neo4j
NEO4J_AUTH=neo4j/adminpassword        # Formato: usuario/contraseña

# MinIO
MINIO_ROOT_USER=datalive_admin
MINIO_ROOT_PASSWORD=change_this_minio_password

# N8N
N8N_USER_EMAIL=tu-email@ejemplo.com   # Requerido para setup
N8N_USER_FIRSTNAME=TuNombre
N8N_USER_LASTNAME=TuApellido
N8N_USER_PASSWORD=TuPasswordSegura
N8N_ENCRYPTION_KEY=$(openssl rand -base64 32)  # Generar automáticamente

# Grafana (si se usa)
GF_SECURITY_ADMIN_PASSWORD=change_this_grafana_password
```

#### 🌐 Variables de Integración Externa (Opcionales)

```bash
# Google Drive/Docs
GOOGLE_CLIENT_ID=tu-client-id.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=tu-client-secret

# Confluence
CONFLUENCE_URL=https://tu-empresa.atlassian.net
CONFLUENCE_USERNAME=usuario@empresa.com
CONFLUENCE_API_TOKEN=tu-api-token

# SharePoint
SHAREPOINT_TENANT_ID=tu-tenant-id
SHAREPOINT_CLIENT_ID=tu-client-id
SHAREPOINT_CLIENT_SECRET=tu-client-secret
```

#### ✅ Variables Automatizadas (No modificar)

```bash
# Configuración de red y puertos
DATALIVE_AGENT_PORT=8058
TZ=Europe/Madrid

# URLs internas de servicios
POSTGRES_URL=postgresql://datalive:password@postgres:5432/datalive
NEO4J_URI=bolt://neo4j:7687
REDIS_URL=redis://redis:6379
QDRANT_URL=http://qdrant:6333
MINIO_URL=http://minio:9000

# Modelos AI optimizados
OLLAMA_EMBEDDING_MODEL=nomic-embed-text:v1.5
OLLAMA_ROUTER_MODEL=phi3:medium
```

### Generación Automática de Configuración

```bash
# Script que automatiza la generación del archivo .env
./scripts/generate-env.sh
```

Este script:
- ✅ Genera 15 contraseñas seguras automáticamente
- ✅ Detecta zona horaria del sistema
- ✅ Verifica puertos disponibles
- ✅ Crea claves de cifrado únicas
- ✅ Solo requiere email y nombre del administrador

---

## 🚀 Procedimientos de Despliegue

### Despliegue Rápido (Golden Path)

#### Prerrequisitos
- Docker 20.10+
- Docker Compose 2.0+
- 8GB RAM mínimo
- 20GB espacio en disco

#### Proceso de Despliegue Completo

```bash
# 1. Clonar repositorio
git clone <repository-url>
cd DataLive

# 2. Generar configuración (solo requiere email y nombre)
./scripts/generate-env.sh

# 3. Desplegar infraestructura completa
./scripts/deploy-infrastructure.sh

# 4. Verificar instalación
./scripts/test-functionality.sh
```

### Qué Hace el Script de Despliegue

1. **Verificación del Sistema**
   - Comprueba versiones de Docker
   - Verifica recursos disponibles
   - Valida configuración

2. **Construcción de Servicios**
   - Build de contenedores con Poetry
   - Optimización multi-stage
   - Caché de dependencias

3. **Inicialización de Infraestructura**
   - PostgreSQL con esquemas
   - Neo4j con índices
   - Qdrant con colecciones
   - MinIO con buckets

4. **Configuración de Servicios**
   - N8N con credenciales automáticas
   - Ollama con modelos descargados
   - SSL/TLS para Neo4j

5. **Healthchecks y Validación**
   - Espera servicios listos
   - Verifica conectividad
   - Ejecuta tests básicos

### URLs de Servicios Post-Despliegue

| Servicio | URL | Credenciales |
|----------|-----|--------------|
| **DataLive API** | http://localhost:8058 | Sin autenticación (desarrollo) |
| **API Docs** | http://localhost:8058/docs | Acceso abierto |
| **N8N** | http://localhost:5678 | Usuario configurado en .env |
| **Neo4j Browser** | http://localhost:7474 | neo4j / contraseña en .env |
| **Qdrant Dashboard** | http://localhost:6333/dashboard | Sin autenticación |
| **MinIO Console** | http://localhost:9001 | Credenciales en .env |

---

## 🏥 Configuración de Servicios y Healthchecks

### Estado de Healthchecks

| Servicio | Endpoint | Intervalo | Timeout | Start Period | Criticidad |
|----------|----------|-----------|---------|--------------|------------|
| **PostgreSQL** | `pg_isready` | 10s | 5s | - | ✅ Crítico |
| **Neo4j** | HTTP/HTTPS check | 15s | 10s | 45s | ✅ Crítico |
| **Qdrant** | `/health` | 15s | 10s | 30s | ✅ Crítico |
| **MinIO** | `/minio/health/live` | 10s | 5s | - | ✅ Crítico |
| **Ollama** | `/api/version` | 30s | 15s | 60s | ✅ Crítico |
| **N8N** | `/healthz` | 30s | 10s | 60s | ✅ Crítico |
| **DataLive Agent** | `/health` | 30s | 10s | 90s | ✅ Crítico |

### Configuraciones Detalladas por Servicio

#### PostgreSQL
```yaml
healthcheck:
  test: ["CMD-SHELL", "pg_isready -U $$POSTGRES_USER -d $$POSTGRES_DB"]
  interval: 10s
  timeout: 5s
  retries: 5
```
- Verifica disponibilidad de base de datos
- Crítico para N8N y DataLive Agent

#### Neo4j
```yaml
healthcheck:
  test: ["CMD-SHELL", "wget --spider -q http://localhost:7474 || exit 1"]
  interval: 15s
  timeout: 10s
  retries: 5
  start_period: 45s
```
- Start period largo por inicialización SSL
- Soporta HTTP y HTTPS

#### DataLive Agent
```yaml
healthcheck:
  test: ["CMD-SHELL", "python -c \"import urllib.request; urllib.request.urlopen('http://localhost:8058/health')\""]
  interval: 30s
  timeout: 10s
  retries: 5
  start_period: 90s
```
- Start period más largo por múltiples dependencias
- Verifica API completamente funcional

### Orden de Arranque y Dependencias

```mermaid
graph TD
    A[PostgreSQL] --> E[N8N]
    A --> F[DataLive Agent]
    B[Neo4j] --> F
    C[Qdrant] --> F
    D[MinIO] --> F
    E --> F
    G[Ollama] --> F
```

### Tiempos de Arranque Típicos

| Entorno | Tiempo Total | Observaciones |
|---------|--------------|---------------|
| **Primera vez** | 8-12 min | Descarga de modelos Ollama |
| **Desarrollo** | 3-5 min | Sin modelos, servicios básicos |
| **Producción** | 5-8 min | Todos los servicios con checks |

---

## 📡 Documentación de API

### Endpoints Principales

#### 1. Estado del Sistema
```http
GET /health
GET /status
GET /metrics
```

#### 2. Ingesta de Documentos

**Ingesta de Texto**
```http
POST /api/v1/ingest
Content-Type: application/json

{
  "source_type": "txt",
  "source": "Contenido del documento...",
  "metadata": {
    "title": "Título del documento",
    "author": "Autor",
    "tags": ["tag1", "tag2"]
  }
}
```

**Carga de Archivos**
```http
POST /api/v1/ingest/file
Content-Type: multipart/form-data

file: [archivo binario]
```

Formatos soportados:
- 📝 TXT - Texto plano con detección de encoding
- 📖 Markdown - Procesamiento con frontmatter
- 📊 CSV - Datos tabulares con detección de tipos
- 📄 PDF - Extracción de texto con metadatos
- 📊 XLSX - Archivos Excel multi-hoja

#### 3. Consultas al Sistema

**Query Básico**
```http
POST /api/v1/query
Content-Type: application/json

{
  "query": "¿Cuáles son las políticas de vacaciones?",
  "strategy": "auto",      // auto, rag, kag, hybrid
  "max_results": 5,
  "filters": {
    "date_from": "2024-01-01",
    "tags": ["rrhh", "políticas"]
  }
}
```

**Respuesta**
```json
{
  "response": "Las políticas de vacaciones establecen...",
  "sources": [
    {
      "document_id": "doc123",
      "title": "Manual de RRHH",
      "relevance": 0.95,
      "chunk": "Texto relevante..."
    }
  ],
  "confidence": 0.92,
  "strategy_used": ["rag", "kag"],
  "processing_time": 1.23,
  "cached": false
}
```

#### 4. Chat Interactivo

**Iniciar Conversación**
```http
POST /api/v1/chat
Content-Type: application/json

{
  "message": "Explica el proceso de onboarding",
  "session_id": "session123",
  "use_cache": true,
  "context": {
    "department": "IT",
    "role": "developer"
  }
}
```

### Autenticación y Seguridad

#### Desarrollo
- Sin autenticación por defecto
- Acceso abierto a todos los endpoints

#### Producción
```http
Authorization: Bearer <API_KEY>
X-API-Key: <DATALIVE_API_KEY>
```

### Rate Limiting

| Endpoint | Límite | Ventana |
|----------|--------|---------|
| `/query` | 100 | 1 minuto |
| `/ingest` | 50 | 1 minuto |
| `/chat` | 200 | 1 minuto |

### Documentación Interactiva

Accesible en: **http://localhost:8058/docs**

Incluye:
- Prueba interactiva de endpoints
- Esquemas de request/response
- Ejemplos de código
- Modelos de datos

---

## 🔧 Guías de Resolución de Problemas

### Problemas Comunes y Soluciones

#### 1. Neo4j no Accesible en Safari

**Problema**: Safari bloquea conexiones no encriptadas
```
Unencrypted connections are not supported in Safari
```

**Soluciones**:
- ✅ Usar Chrome, Firefox o Edge
- ✅ Acceder por HTTPS (cuando esté configurado): https://localhost:7473
- ✅ Usar API REST directamente

#### 2. Fallo en Healthcheck de Servicios

**PostgreSQL**
```bash
# Verificar logs
docker logs datalive-postgres --tail 50

# Test manual
docker exec datalive-postgres pg_isready -U datalive
```

**Qdrant**
```bash
# Verificar endpoint
curl http://localhost:6333/health

# Revisar inicialización
docker logs datalive-qdrant | grep -i error
```

**DataLive Agent**
```bash
# Verificar dependencias
docker-compose ps

# Test endpoint
curl http://localhost:8058/health

# Logs detallados
docker logs datalive-agent --tail 100
```

#### 3. Ollama No Descarga Modelos

```bash
# Verificar modelos instalados
docker exec datalive-ollama ollama list

# Descargar manualmente
docker exec datalive-ollama ollama pull phi3:medium
docker exec datalive-ollama ollama pull nomic-embed-text:v1.5
```

#### 4. Problemas de Memoria

**Síntomas**: Servicios reiniciándose, OOM kills

**Solución**: Ajustar límites en `docker-compose.override.yml`
```yaml
services:
  neo4j:
    environment:
      - NEO4J_server_memory_heap_max__size=2G
      - NEO4J_server_memory_pagecache_size=1G
  
  datalive_agent:
    deploy:
      resources:
        limits:
          memory: 2G
```

### Comandos de Diagnóstico Útiles

```bash
# Estado general del sistema
docker-compose ps

# Logs en tiempo real
docker-compose logs -f --tail=50

# Uso de recursos
docker stats

# Limpiar y reiniciar
docker-compose down -v
docker system prune -f
./scripts/deploy-infrastructure.sh

# Backup de datos
docker-compose exec postgres pg_dump -U datalive datalive > backup.sql
docker-compose exec neo4j neo4j-admin database dump neo4j --to=/backup/
```

---

## 🔐 Configuraciones Especiales

### Configuración SSL/TLS para Neo4j

#### Generación de Certificados
```bash
./scripts/generate-neo4j-ssl.sh
```

Este script:
- Genera certificados auto-firmados
- Los coloca en `init-neo4j/ssl/`
- Configura Neo4j para HTTPS
- Compatible con Safari

#### Configuración Manual
```yaml
# En docker-compose.yml
neo4j:
  environment:
    - NEO4J_server_https_enabled=true
    - NEO4J_server_https_listen__address=0.0.0.0:7473
  volumes:
    - ./init-neo4j/ssl:/ssl:ro
```

### Integración con N8N

#### Credenciales Automáticas
El sistema crea automáticamente credenciales para:
- PostgreSQL
- Neo4j (requiere nodo comunitario)
- Qdrant
- MinIO (S3-compatible)
- Ollama
- DataLive Agent

#### Workflows Preconfigurados
Ubicación: `datalive_agent/n8n_workflows/`
- `ingestion/`: Workflows de ingesta de datos
- `enhanced/`: Procesamiento avanzado
- `optimization/`: Mejoras de rendimiento

### Configuración para Producción

#### 1. Variables de Entorno
```bash
# Usar variables del sistema operativo
export POSTGRES_PASSWORD=$(openssl rand -base64 32)
export NEO4J_AUTH="neo4j/$(openssl rand -base64 32)"
export MINIO_ROOT_PASSWORD=$(openssl rand -base64 32)
```

#### 2. Reverse Proxy (Nginx)
```nginx
server {
    listen 443 ssl;
    server_name datalive.empresa.com;
    
    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;
    
    location / {
        proxy_pass http://localhost:8058;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

#### 3. Backups Automatizados
```bash
# Crontab para backups diarios
0 2 * * * /opt/datalive/scripts/backup-all.sh
```

#### 4. Monitoreo con Prometheus
```yaml
# prometheus.yml
scrape_configs:
  - job_name: 'datalive'
    static_configs:
      - targets: ['localhost:8058']
    metrics_path: '/metrics'
```

### Optimización de Rendimiento

#### 1. Ajustes de PostgreSQL
```sql
-- En init-postgres/init.sql
ALTER SYSTEM SET shared_buffers = '2GB';
ALTER SYSTEM SET effective_cache_size = '6GB';
ALTER SYSTEM SET maintenance_work_mem = '512MB';
```

#### 2. Configuración de Qdrant
```yaml
# En docker-compose.yml
qdrant:
  environment:
    - QDRANT__SERVICE__GRPC_PORT=6334
    - QDRANT__SERVICE__MAX_REQUEST_SIZE_MB=100
```

#### 3. Caché con Redis (Opcional)
```yaml
redis:
  image: redis:alpine
  container_name: datalive-redis
  command: redis-server --maxmemory 2gb --maxmemory-policy allkeys-lru
```

---

## 📊 Métricas y Monitoreo

### Métricas Disponibles

#### Sistema
- `system_cpu_usage`: Uso de CPU
- `system_memory_usage`: Uso de memoria
- `system_disk_usage`: Uso de disco

#### Aplicación
- `query_total`: Total de consultas
- `query_duration_seconds`: Duración de consultas
- `cache_hit_ratio`: Ratio de aciertos de caché
- `ingestion_documents_total`: Documentos procesados
- `ingestion_errors_total`: Errores de ingesta

#### Bases de Datos
- `postgres_connections_active`: Conexiones activas
- `neo4j_node_count`: Número de nodos
- `qdrant_vector_count`: Vectores almacenados

### Dashboard de Grafana

Importar dashboard: `monitoring/grafana-dashboard.json`

Paneles incluidos:
- Estado general del sistema
- Rendimiento de consultas
- Estadísticas de ingesta
- Uso de recursos por servicio
- Alertas y anomalías

---

## 🎯 Mejores Prácticas

### Desarrollo
1. Usar branch por feature
2. Tests antes de merge
3. Documentar cambios en API
4. Mantener logs limpios

### Producción
1. Cambiar TODAS las contraseñas por defecto
2. Habilitar SSL/TLS en todos los servicios
3. Configurar backups automáticos
4. Monitorear recursos continuamente
5. Mantener logs centralizados

### Seguridad
1. Aislar red Docker
2. Limitar acceso a puertos
3. Rotar API keys regularmente
4. Auditar accesos
5. Encriptar datos sensibles

---

## 📞 Soporte y Recursos

### Documentación Adicional
- **README Principal**: `/README.md`
- **Estado del Proyecto**: `/docs/PROJECT_STATE.md`
- **Guía de Variables**: `/docs/ENV_CONF_README.md`
- **Solución Safari**: `/docs/SAFARI_NEO4J_SOLUTION.md`

### Logs y Debugging
```bash
# Logs completos
docker-compose logs > datalive-logs.txt

# Información del sistema
docker system df
docker-compose ps
docker stats --no-stream
```

### Comunidad y Contribución
- Issues: GitHub Issues del proyecto
- PRs: Bienvenidos siguiendo guías de contribución
- Documentación: Mantener actualizada con cambios

---

**🏆 DataLive v4.0** - Sistema de Inteligencia Empresarial Soberano con Automatización Completa