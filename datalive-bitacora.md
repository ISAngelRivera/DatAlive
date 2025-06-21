# 📋 BITÁCORA DEL PROYECTO DATALIVE - ESTADO ACTUAL

> **Última actualización**: 2025-01-24
> **Versión del proyecto**: 2.0
> **Estado**: En desarrollo activo
> **Desarrollador principal**: Angel Rivera

## 🎯 RESUMEN EJECUTIVO PARA NUEVOS AGENTES

### ¿Qué es DataLive?
Sistema RAG (Retrieval-Augmented Generation) híbrido on-premise que:
- Procesa documentos de Google Drive/SharePoint/Git
- Responde preguntas a través de Microsoft Teams
- Usa IA local (Ollama) para privacidad total
- Se auto-optimiza con el uso (cache inteligente)

### Estado Actual
✅ **Completado**:
- Estructura completa del proyecto
- Docker Compose con todos los servicios
- Scripts de inicialización automatizados
- Esquema PostgreSQL completo
- Workflows N8N básicos (ingesta y consulta)
- Configuración via .env
- GitHub Actions para CI/CD

❌ **Pendiente**:
- Integración con Microsoft Teams
- Workflows de optimización (Agente 3)
- Dashboard de Grafana personalizado
- Pruebas end-to-end
- Documentación de usuario final

## 🏗️ ARQUITECTURA ACTUAL

### Servicios Desplegados
```yaml
Servicios Core:
- N8N (5678): Orquestador de workflows
- PostgreSQL (5432): Base de datos principal (RAG/KAG/CAG)
- Qdrant (6333): Vector database
- Ollama (11434): LLM + Embeddings
- MinIO (9000/9001): Object storage
- Redis (6379): Cache rápido

Monitoreo:
- Grafana (3000): Dashboards
- Prometheus (9090): Métricas
- Loki (3100): Logs
- Promtail: Recolector de logs
```

### Modelos IA Configurados
- **LLM Principal**: phi-4:latest (14B params)
- **Embeddings Texto**: nomic-embed-text:v1.5 (768 dims)
- **Multimodal**: llava:latest

## 📁 ESTRUCTURA DEL REPOSITORIO

```
datalive/
├── .env (configuración principal)
├── docker/
│   └── docker-compose.yml (stack completo)
├── scripts/
│   ├── setup-datalive.sh ✅ (setup maestro)
│   ├── init-ollama-models.sh ✅
│   ├── init-minio-buckets.sh ✅
│   ├── init-n8n-setup.sh ✅
│   ├── init-qdrant-collections.sh ✅
│   ├── sync-n8n-workflows.sh ✅
│   └── wait-for-healthy.sh ✅
├── workflows/
│   ├── ingestion/
│   │   ├── document-sync-deletion.json ✅
│   │   └── git-repository-ingestion.json ✅
│   ├── query/
│   │   └── rag-query-router.json ✅
│   └── optimization/ (vacío - pendiente)
├── postgres-init/
│   └── init.sql ✅ (esquema completo)
└── config/ (directorios para configuraciones)
```

## 🔧 CONFIGURACIÓN CLAVE (.env)

### Credenciales Críticas
```bash
# Usuario N8N
N8N_USER_EMAIL=contacto@angelrivera.es
N8N_USER_PASSWORD=ChangeMe123! # ⚠️ CAMBIAR EN PRODUCCIÓN

# Bases de datos
POSTGRES_USER=datalive_user
POSTGRES_DB=datalive_db

# MinIO
MINIO_ROOT_USER=datalive_admin

# Modelos Ollama
OLLAMA_LLM_PRIMARY=phi-4:latest
OLLAMA_EMBED_TEXT_PRIMARY=nomic-embed-text:v1.5
```

## 💡 DECISIONES TÉCNICAS IMPORTANTES

### 1. **Seguridad con Docker Secrets**
- Todas las contraseñas en archivos separados (`secrets/`)
- Montados como secrets en Docker, no variables de entorno
- Generación automática si no existen

### 2. **Esquema PostgreSQL Multi-Schema**
```sql
- rag.*: Documentos, chunks, media
- kag.*: Knowledge graph (entities, relations)
- cag.*: Cache de queries
- monitoring.*: Logs y métricas
```

### 3. **Estrategia de Embeddings**
- Texto: nomic-embed-text (768 dims)
- Imágenes: llava para multimodal
- Chunking inteligente por tipo de archivo

### 4. **Workflows N8N Como Código**
- JSON versionado en Git
- IDs de credenciales dinámicos
- Sincronización automática via API

## 🚀 COMANDOS DE DESARROLLO

### Setup Inicial Completo
```bash
# 1. Configurar entorno
cp .env.template .env
nano .env  # Editar valores

# 2. Ejecutar setup maestro
./scripts/setup-datalive.sh

# Esto ejecuta automáticamente:
# - Creación de directorios
# - Generación de secrets
# - Docker compose up
# - Inicialización de servicios
# - Importación de workflows
```

### Comandos Útiles
```bash
# Ver logs de un servicio
docker logs -f datalive-n8n

# Reiniciar servicio
docker restart datalive-ollama

# Sincronizar workflows
./scripts/sync-n8n-workflows.sh

# Acceder a PostgreSQL
docker exec -it datalive-postgres psql -U datalive_user -d datalive_db
```

## 🐛 PROBLEMAS CONOCIDOS Y SOLUCIONES

### 1. **Permisos de Scripts en Windows**
```bash
# Ejecutar desde WSL o Git Bash
./scripts/fix-permissions.sh
```

### 2. **N8N ya inicializado**
- El script detecta automáticamente si N8N existe
- Intenta login con credenciales del .env
- Si falla, revisar logs: `docker logs datalive-n8n`

### 3. **Ollama sin GPU**
- Funciona en CPU pero más lento
- Para GPU: descomentar sección en docker-compose.yml

### 4. **N8N Auto-registro Fallando**
- DB_POSTGRESDB_PASSWORD_FILE no funciona correctamente
- Solución: Usar DB_POSTGRESDB_PASSWORD directamente en docker-compose.yml
- Requiere registro manual en http://localhost:5678

### 5. **Redis Authentication en N8N**
- Agregar QUEUE_BULL_REDIS_PASSWORD: ${REDIS_PASSWORD} en environment de N8N

### 6. **Servicios No Accesibles**
- Agregar red 'frontend' a servicios que necesitan acceso externo
- Verificar que no estén solo en redes 'internal'

## 📊 ESTADO DE COMPONENTES (Actualizado: 2025-01-24)

### ✅ Completamente Funcional
- Docker Stack completo levantado (10/10 contenedores)
- Sistema RAG Core 100% operativo:
  - Generación de embeddings: phi4-mini (3072 dims)
  - Búsqueda vectorial: Qdrant con 2 colecciones
  - Generación LLM: Respuestas en español funcionando
  - Pipeline RAG: Búsqueda semántica con score 0.8598
- MinIO operativo (consola en puerto 9001)
- Redis con autenticación configurada (set/get OK)
- Grafana accesible y funcional
- N8N ejecutándose y configurado

### 🟡 Parcialmente Implementado
- PostgreSQL: Conectividad OK pero sin schemas RAG inicializados (0/4)
- Ollama: Funcional pero con timeouts ocasionales en tests simples
- Conectividad inter-contenedor: N8N->PostgreSQL/Redis con problemas
- Tests de salud: 75% éxito (25/33 pruebas pasadas)
- Workflows N8N no importados aún

### ❌ No Implementado
- Schemas PostgreSQL (rag, kag, cag, monitoring) - requiere init.sql
- Auto-registro de N8N (requiere configuración manual)
- Workflows de optimización (Agente 3)
- Integración Google Drive OAuth
- Tests automatizados del pipeline completo
- Webhook de Microsoft Teams (postergado)
- SharePoint/Confluence (postergado)
- Backup automatizado

### 🆕 Añadido en esta sesión
- **test-interface.html**: Interfaz web para probar queries sin Teams
- **query-pattern-optimizer.json**: Workflow del Agente Optimizador completo
- **setup-google-oauth.sh**: Script guiado para configurar Google OAuth
- **Sistema de Testing en Contenedor**: Tests consistentes cross-platform
- **Credenciales Estandarizadas**: admin/adminpassword para todos los servicios

## 🎯 PRÓXIMOS PASOS PRIORITARIOS

### 1. **Inicializar Schemas PostgreSQL** (CRÍTICO)
```bash
# Ejecutar el script SQL que ya existe
docker exec -i datalive-postgres psql -U admin -d datalive_db < postgres-init/init.sql
```

### 2. **Completar Setup N8N**
- Registro manual en http://localhost:5678
- Importar workflows: `./scripts/sync-n8n-workflows.sh`
- Configurar credenciales OAuth

### 3. **Resolver Conectividad Inter-contenedor**
- Verificar configuración de redes en docker-compose.yml
- Posiblemente ajustar hostnames en N8N

### 4. **Testing del Pipeline Completo**
- Subir documentos de prueba a Google Drive
- Ejecutar workflow de ingesta
- Probar queries con test-interface.html

### 5. **Optimización y Monitoreo**
- Configurar dashboards Grafana
- Activar workflow del Agente Optimizador
- Establecer alertas

## 🔄 FLUJO DE TRABAJO ACTUAL

### Ingesta (Funcional)
1. Schedule cada 30 min → 
2. Lista archivos Google Drive →
3. Compara con DB (hash) →
4. Descarga nuevos/modificados →
5. Chunking inteligente →
6. Genera embeddings →
7. Guarda en Qdrant + PostgreSQL

### Query (Funcional)
1. Webhook recibe query →
2. Check cache Redis →
3. Si no está: genera embedding →
4. Busca en Qdrant (similarity) →
5. Construye contexto →
6. LLM genera respuesta →
7. Cachea resultado →
8. Retorna JSON

### Optimización (Pendiente)
- Analizar logs de queries
- Identificar patrones frecuentes
- Pre-computar embeddings
- Calentar cache

## 📝 NOTAS PARA EL SIGUIENTE AGENTE

### Contexto Importante
1. El proyecto sigue el plano conceptual de 3 agentes
2. Usa tecnologías 2025 (Ollama, Qdrant, N8N latest)
3. 100% on-premise por requisitos de privacidad
4. El usuario (Angel) tiene experiencia técnica

### Si el contexto se llena
1. Esta bitácora contiene TODO el estado actual
2. Los archivos críticos son: .env, docker-compose.yml, workflows/*.json
3. El setup está 70% completo y funcional
4. Prioridad: completar integración Teams

### Formato de Respuestas Esperado
- Siempre validar contra últimas versiones
- Proponer mejoras proactivamente
- Generar artefactos listos para usar
- Explicar decisiones técnicas

## 🔗 RECURSOS Y REFERENCIAS

- **Plano Conceptual**: docs/plan.md
- **Explicación Simple**: docs/Explicacion.md
- **README Principal**: README.md
- **GitHub Actions**: .github/workflows/deploy-datalive.yml

---

**IMPORTANTE**: Esta bitácora debe actualizarse con cada cambio significativo. Es la fuente de verdad para cualquier agente que continúe el proyecto.