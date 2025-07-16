# DataLive N8N Workflows - Edición 2025

## 📋 Descripción General

Este directorio contiene los workflows de N8N modernizados para el sistema DataLive 2025. Los workflows están optimizados para trabajar con la arquitectura RAG+KAG+CAG del proyecto, incorporando las últimas tecnologías y mejores prácticas.

## 🚀 Novedades 2025

- **Reranking Nativo**: Implementación de cross-encoder reranking con Qdrant 1.14
- **Procesamiento Paralelo**: Optimización de performance con procesamiento batch
- **IA Avanzada**: Integración con modelos Phi-4 mini y Phi-3 mini optimizados
- **Validación Mejorada**: Sistema robusto de validación y manejo de errores
- **Deduplicación Inteligente**: Eliminación automática de contenido duplicado
- **Análisis de Entidades**: Extracción automática de emails, URLs, teléfonos y fechas
- **Métricas Avanzadas**: Seguimiento completo de performance y calidad

## 🔄 Workflows Disponibles

### 1. DataLive - Enhanced Ingestion Workflow 2025 (`datalive-enhanced-ingestion-workflow.json`)

**Propósito**: Procesamiento avanzado e ingesta inteligente de documentos con tecnologías 2025.

**Características Principales**:
- ✅ **Webhook Avanzado**: Endpoint `/datalive/ingest/v2` con validación robusta
- ✅ **Soporte Extendido**: 14+ formatos de archivo con procesamiento especializado
- ✅ **Procesamiento Paralelo**: Chunking y embeddings en lotes optimizados
- ✅ **Deduplicación Inteligente**: Eliminación automática de contenido duplicado
- ✅ **Extracción de Entidades**: Análisis automático de emails, URLs, teléfonos, fechas
- ✅ **Generación de Resúmenes**: Resúmenes automáticos con Phi-4 mini
- ✅ **Almacenamiento Dual**: Qdrant (vectores) + PostgreSQL (metadatos)
- ✅ **Métricas Avanzadas**: Estadísticas completas de procesamiento
- ✅ **Manejo de Errores**: Sistema robusto de recuperación y logging

**Formatos Soportados (2025)**:
- **Texto**: `txt`, `md`, `rtf`
- **Documentos**: `pdf`, `docx`, `odt`, `epub`
- **Datos**: `csv`, `json`, `xml`, `yaml`, `xlsx`
- **Web**: `html`
- **Presentaciones**: `pptx`

**Mejoras de Performance**:
- Procesamiento batch de embeddings (10x más rápido)
- Chunking inteligente con detección de contexto
- Validación de contenido hasta 50MB
- Paralelización automática basada en complejidad

### 2. DataLive - Enhanced Query Workflow 2025 (`datalive-enhanced-query-workflow.json`)

**Propósito**: Sistema avanzado de consultas con IA de nueva generación y reranking nativo.

**Características Revolucionarias**:
- ✅ **Router IA Avanzado**: Análisis NLP con 40+ patrones de clasificación
- ✅ **Reranking Cross-Encoder**: Implementación nativa Qdrant 1.14
- ✅ **Modelos Optimizados**: Phi-4 mini (primario) + Phi-3 mini (fallback)
- ✅ **Estrategia Híbrida**: Combinación inteligente RAG+KAG+CAG
- ✅ **Scoring Avanzado**: Confianza, relevancia y métricas de calidad
- ✅ **Procesamiento Paralelo**: Consultas simultáneas a múltiples fuentes
- ✅ **Manejo de Errores**: Sistema robusto con fallbacks automáticos
- ✅ **Métricas Completas**: Seguimiento de performance y calidad

**Estrategias de Consulta (2025)**:
- `auto` - **IA Avanzada**: Clasificación automática con análisis semántico
- `rag` - **Vector Enhanced**: Búsqueda con reranking cross-encoder
- `kag` - **Graph Intelligence**: Consultas Neo4j 2025.01 con GDS
- `cag` - **Context Aware**: PostgreSQL con análisis temporal
- `hybrid` - **Multi-Modal**: Combinación de todas las estrategias

**Análisis de Consultas**:
- **Temporal**: Detección de patrones temporales (20+ indicadores)
- **Relacional**: Identificación de relaciones (15+ patrones)
- **Factual**: Consultas de información (10+ tipos)
- **Complejo**: Análisis y razonamiento (12+ operaciones)

## 🚀 Instalación y Configuración 2025

### Prerrequisitos Optimizados

1. **N8N 1.x** (con soporte para nuevos nodos)
2. **Infraestructura DataLive 2025**:
   - **PostgreSQL 16** con pgvector 0.8.0
   - **Qdrant 1.14+** con reranking nativo
   - **Neo4j 2025.01** con Java 21 y GDS
   - **Ollama** con modelos optimizados:
     - `phi4-mini` (modelo primario - 2.5GB)
     - `phi3:mini` (modelo fallback - 2.2GB)
     - `nomic-embed-text:v1.5` (embeddings - 0.27GB)
   - **Redis 7** para caché avanzado
   - **MinIO** para almacenamiento de archivos

### Importar Workflows

1. Acceder a N8N: http://localhost:5678
2. Ir a "Workflows" → "Add workflow" → "Import from file"
3. Seleccionar los archivos JSON de este directorio
4. Configurar las credenciales necesarias

### Configurar Credenciales Optimizadas

Los workflows 2025 requieren las siguientes credenciales en N8N:

1. **Ollama API** (Optimizada):
   - Name: `ollama-api`
   - Base URL: `http://ollama:11434`
   - Timeout: 60s
   - Retry: 3 intentos

2. **Qdrant API** (Con Reranking):
   - Name: `qdrant-api`
   - URL: `http://qdrant:6333`
   - Collection: `datalive_vectors`
   - Timeout: 30s

3. **PostgreSQL** (Avanzado):
   - Name: `postgres-api`
   - Host: `postgres`
   - Database: `datalive_db`
   - User: `datalive_user`
   - Password: (desde .env)
   - Pool Size: 10

4. **Neo4j** (2025.01):
   - Name: `neo4j-api`
   - URL: `neo4j://neo4j:7687`
   - Database: `neo4j`
   - Username: `neo4j`
   - Password: (desde .env)

## 📡 Uso de los Workflows 2025

### Ingesta Avanzada de Documentos

```bash
# Ingesta básica
curl -X POST http://localhost:5678/webhook/datalive/ingest/v2 \
  -H "Content-Type: application/json" \
  -d '{
    "source_type": "md",
    "source": "# Mi Documento\n\nEste es contenido markdown...",
    "metadata": {
      "title": "Documento Avanzado",
      "author": "Usuario",
      "category": "technical",
      "tags": ["ai", "documentation"]
    },
    "chunk_size": 1500,
    "enable_parallel": true,
    "extract_entities": true,
    "generate_summary": true
  }'

# Ingesta con configuración avanzada
curl -X POST http://localhost:5678/webhook/datalive/ingest/v2 \
  -H "Content-Type: application/json" \
  -d '{
    "source_type": "json",
    "source": "{\"data\": \"contenido\"}",
    "filename": "data.json",
    "metadata": {
      "priority": "high",
      "language": "es"
    },
    "enable_deduplication": true,
    "confidence_threshold": 0.8
  }'
```

### Consultas Inteligentes

```bash
# Consulta automática con IA
curl -X POST http://localhost:5678/webhook/datalive/query/v2 \
  -H "Content-Type: application/json" \
  -d '{
    "query": "¿Cuáles son las relaciones entre los documentos técnicos?",
    "strategy": "auto",
    "max_results": 10,
    "enable_reranking": true,
    "confidence_threshold": 0.75
  }'

# Consulta híbrida avanzada
curl -X POST http://localhost:5678/webhook/datalive/query/v2 \
  -H "Content-Type: application/json" \
  -d '{
    "query": "Analiza y compara los cambios temporales en la documentación",
    "strategy": "hybrid",
    "max_results": 15,
    "filters": {
      "timeWindow": "30 days",
      "category": "technical"
    },
    "enable_parallel": true
  }'
```

## 🔧 Personalización

### Modificar el Chunking

En el nodo "Split Text into Chunks", puedes ajustar:
- Tamaño de chunks (default: 1000 caracteres)
- Overlap (default: 200 caracteres)
- Separadores personalizados

### Cambiar Modelos de IA

1. **Embeddings**: Cambiar el modelo en "Generate Embeddings"
2. **LLM**: Cambiar el modelo en "LLM Synthesizer"

### Añadir Nuevas Fuentes

Para añadir Google Drive, GitHub u otras fuentes:
1. Añadir nodo trigger correspondiente
2. Conectarlo al nodo "Validate Input"
3. Adaptar la extracción según el tipo de fuente

## 🐛 Troubleshooting

### Error: "Webhook not found"
- Verificar que los workflows estén activos
- Comprobar que las URLs de webhook sean correctas

### Error: "Model not found"
- Verificar que Ollama tenga los modelos descargados:
  ```bash
  docker exec datalive-ollama ollama list
  ```

### Error: "Connection refused"
- Verificar que todos los servicios estén corriendo:
  ```bash
  docker-compose ps
  ```

## 📊 Métricas y Monitoreo

Los workflows incluyen información de métricas en las respuestas:
- `processing_time`: Tiempo de procesamiento en segundos
- `confidence`: Nivel de confianza de la respuesta
- `chunks`: Número de chunks procesados (ingesta)
- `sources`: Fuentes utilizadas para la respuesta

## 🔒 Seguridad

- Los webhooks deben protegerse con autenticación en producción
- Validación de entrada en todos los puntos de entrada
- Sanitización de contenido antes del procesamiento
- Logs de auditoría para todas las operaciones

## 🎯 Casos de Uso Avanzados

### 1. Procesamiento de Documentos Corporativos
```bash
# Ingesta masiva con categorización automática
for file in documents/*.pdf; do
  curl -X POST http://localhost:5678/webhook/datalive/ingest/v2 \
    -H "Content-Type: application/json" \
    -d '{
      "source_type": "pdf",
      "source": "'$(base64 -i "$file")'",
      "metadata": {
        "category": "corporate",
        "auto_categorize": true
      }
    }'
done
```

### 2. Análisis de Sentimientos y Tendencias
```json
{
  "query": "Analiza las tendencias de satisfacción del cliente en los últimos 6 meses",
  "strategy": "hybrid",
  "filters": {
    "timeWindow": "6 months",
    "category": "customer_feedback"
  },
  "enable_sentiment_analysis": true
}
```

### 3. Consultas Multi-idioma
```json
{
  "query": "What are the main technical challenges mentioned in Spanish documents?",
  "strategy": "auto",
  "language_detection": true,
  "cross_language_search": true
}
```

## 📊 Métricas y Monitoreo Avanzado 2025

### Métricas de Ingesta
```json
{
  "processingStats": {
    "documentsProcessed": 1,
    "chunksCreated": 15,
    "originalContentLength": 5420,
    "processedContentLength": 5200,
    "entitiesExtracted": 8,
    "deduplicationApplied": true,
    "summaryGenerated": true,
    "processingTimeMs": 2340,
    "averageChunkSize": 347
  }
}
```

### Métricas de Consultas
```json
{
  "metadata": {
    "totalSources": 10,
    "averageConfidence": 0.87,
    "processingTimeMs": 1250,
    "model": "phi4-mini",
    "rerankingEnabled": true,
    "parallelProcessing": true,
    "patternScores": {
      "temporal": 2,
      "relational": 0,
      "factual": 3,
      "complex": 1
    }
  }
}
```

### Dashboard de Monitoreo
- **Grafana**: Métricas en tiempo real
- **Prometheus**: Recolección de métricas
- **Logs estructurados**: Seguimiento detallado
- **Alertas automáticas**: Notificaciones de problemas

## 🔧 Personalización Avanzada 2025

### Configuración de Chunking Inteligente

En el nodo "Intelligent Text Chunking":
- **Tamaño dinámico**: 1000-2000 caracteres (según tipo de contenido)
- **Overlap inteligente**: 200-400 caracteres (basado en contexto)
- **Separadores avanzados**: Detección automática de estructura
- **Preservación de contexto**: Mantiene párrafos y secciones completas

### Modelos IA Optimizados

1. **Embeddings Avanzados**:
   - `nomic-embed-text:v1.5` (optimizado para multilingual)
   - Batch processing para mayor velocidad
   - Cache inteligente para embeddings repetidos

2. **LLMs con Fallback**:
   - **Primario**: `phi4-mini` (razonamiento avanzado)
   - **Fallback**: `phi3:mini` (velocidad optimizada)
   - **Selección automática** basada en complejidad de consulta

### Configuración de Reranking

- **Cross-Encoder nativo** con Qdrant 1.14
- **Scoring multi-factor**: relevancia + contexto + posición
- **Threshold dinámico** basado en tipo de consulta
- **Boost por entidades** para contenido con datos estructurados

## 🐛 Troubleshooting 2025

### Errores Comunes y Soluciones

#### Webhook Issues
```bash
# Verificar workflows activos
curl -I http://localhost:5678/webhook/datalive/query/v2

# Reiniciar N8N si es necesario
docker-compose restart n8n
```

#### Modelos IA
```bash
# Verificar modelos disponibles
docker exec datalive-ollama ollama list

# Descargar modelos faltantes
docker exec datalive-ollama ollama pull phi4-mini
docker exec datalive-ollama ollama pull phi3:mini
```

#### Conectividad de Servicios
```bash
# Health check completo
docker-compose ps
docker-compose logs --tail=50 datalive-agent

# Test específico de servicios
curl http://localhost:6333/collections  # Qdrant
curl http://localhost:11434/api/tags    # Ollama
```

#### Performance Issues
```bash
# Monitoreo de recursos
docker stats datalive-ollama datalive-qdrant

# Optimización de memoria
# Ajustar LLM_MEMORY_THRESHOLD_GB en .env
```

#### Problemas de Reranking
- Verificar que `enable_reranking: true` en las consultas
- Comprobar que Qdrant 1.14+ está funcionando
- Revisar logs de cross-encoder en el workflow

## 🔒 Seguridad Avanzada 2025

### Protección de Endpoints
- **Autenticación robusta**: API keys + JWT tokens
- **Rate limiting**: Prevención de ataques DDoS
- **Validación estricta**: Sanitización avanzada de entrada
- **CORS configurado**: Dominios permitidos específicos

### Seguridad de Datos
- **Cifrado en tránsito**: TLS 1.3 para todas las comunicaciones
- **Sanitización de contenido**: Eliminación de scripts maliciosos
- **Validación de tamaño**: Límites estrictos para prevenir ataques
- **Logs de auditoría**: Seguimiento completo de todas las operaciones

### Privacidad
- **Anonimización automática**: Detección y enmascaramiento de PII
- **Retención de datos**: Políticas configurables de eliminación
- **Acceso controlado**: Permisos granulares por usuario
- **Compliance**: Cumplimiento GDPR y normativas locales

## 🚀 Roadmap 2025

### Q1 2025 - IA Avanzada
- [ ] Integración con modelos multimodales
- [ ] Soporte para imágenes y audio
- [ ] Reasoning chains avanzados
- [ ] Auto-optimización de parámetros

### Q2 2025 - Escalabilidad
- [ ] Clustering automático de Qdrant
- [ ] Sharding inteligente de Neo4j
- [ ] Load balancing dinámico
- [ ] Auto-scaling basado en carga

### Q3 2025 - Inteligencia
- [ ] Aprendizaje continuo
- [ ] Feedback loops automáticos
- [ ] Optimización de queries
- [ ] Predicción de patrones

## 🔄 Migración desde Versiones Anteriores

### Actualización de Workflows Existentes
1. **Backup de workflows actuales**
2. **Importar nuevos workflows 2025**
3. **Migrar credenciales a nuevos formatos**
4. **Actualizar webhooks en aplicaciones**
5. **Validar funcionamiento completo**

### Compatibilidad
- ✅ Endpoints v1 mantienen compatibilidad
- ✅ Respuestas incluyen ambos formatos
- ✅ Migración gradual soportada
- ⚠️ Funciones avanzadas solo en v2

## 🤝 Contribuir

Para mejorar estos workflows 2025:
1. **Fork del repositorio** con rama feature/workflow-enhancement
2. **Testing exhaustivo** con datos reales
3. **Documentación completa** de cambios
4. **PR con métricas** de mejora de performance
5. **Validación de seguridad** y compliance

### Estándares de Calidad
- Cobertura de tests > 80%
- Performance benchmarks incluidos
- Documentación actualizada
- Validación de seguridad completada