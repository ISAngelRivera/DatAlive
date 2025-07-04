# DataLive N8N Workflows

## 📋 Descripción General

Este directorio contiene los workflows de N8N para el sistema DataLive. Los workflows están diseñados para trabajar con la arquitectura RAG+KAG+CAG del proyecto.

## 🔄 Workflows Disponibles

### 1. DataLive - Ingestion Workflow (`datalive-ingestion-workflow.json`)

**Propósito**: Procesar e ingestar documentos en el sistema DataLive.

**Características**:
- ✅ Webhook endpoint para ingesta manual (`/datalive/ingest`)
- ✅ Validación de entrada y tipos de archivo soportados
- ✅ Chunking inteligente de documentos usando Recursive Character Text Splitter
- ✅ Generación de embeddings con Ollama (nomic-embed-text:v1.5)
- ✅ Almacenamiento vectorial en Qdrant
- ✅ Almacenamiento de metadatos en PostgreSQL
- ✅ Extracción básica de entidades (emails, URLs)
- ✅ Respuesta estructurada con información del procesamiento

**Tipos de archivo soportados**:
- `txt` - Texto plano
- `pdf` - Documentos PDF
- `docx` - Documentos Word
- `md` - Markdown
- `csv` - Datos tabulares
- `json` - Datos estructurados

### 2. DataLive - Query Workflow (`datalive-query-workflow.json`)

**Propósito**: Procesar consultas y generar respuestas usando las estrategias RAG, KAG y CAG.

**Características**:
- ✅ Webhook endpoint para consultas (`/datalive/query`)
- ✅ Router inteligente de estrategias (auto, rag, kag, cag)
- ✅ Búsqueda vectorial en Qdrant (RAG)
- ✅ Consultas a PostgreSQL para contexto temporal (CAG)
- ✅ Preparación para consultas de grafo en Neo4j (KAG)
- ✅ Síntesis de respuestas con LLM (phi3:medium)
- ✅ Respuesta estructurada con fuentes y métricas

**Estrategias de consulta**:
- `auto` - Selección automática basada en el análisis de la consulta
- `rag` - Retrieval Augmented Generation para consultas factuales
- `kag` - Knowledge Augmented Generation para relaciones
- `cag` - Contextual Augmented Generation para consultas temporales

## 🚀 Instalación y Configuración

### Prerrequisitos

1. **N8N instalado y funcionando**
2. **Servicios de DataLive activos**:
   - PostgreSQL
   - Qdrant
   - Ollama con modelos:
     - `phi3:medium`
     - `nomic-embed-text:v1.5`
   - Neo4j (para KAG completo)

### Importar Workflows

1. Acceder a N8N: http://localhost:5678
2. Ir a "Workflows" → "Add workflow" → "Import from file"
3. Seleccionar los archivos JSON de este directorio
4. Configurar las credenciales necesarias

### Configurar Credenciales

Los workflows requieren las siguientes credenciales en N8N:

1. **Ollama**:
   - Name: `Ollama`
   - Base URL: `http://ollama:11434`

2. **Qdrant**:
   - Name: `Qdrant`
   - URL: `http://qdrant:6333`

3. **PostgreSQL**:
   - Name: `PostgreSQL`
   - Host: `postgres`
   - Database: `datalive`
   - User: `datalive`
   - Password: (desde .env)

## 📡 Uso de los Workflows

### Ingesta de Documentos

```bash
curl -X POST http://localhost:5678/webhook/datalive/ingest \
  -H "Content-Type: application/json" \
  -d '{
    "source_type": "txt",
    "source": "Este es el contenido del documento a ingestar...",
    "metadata": {
      "title": "Mi Documento",
      "author": "Usuario"
    }
  }'
```

### Realizar Consultas

```bash
curl -X POST http://localhost:5678/webhook/datalive/query \
  -H "Content-Type: application/json" \
  -d '{
    "query": "¿Qué dice el documento sobre X?",
    "strategy": "auto",
    "max_results": 5
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

## 🤝 Contribuir

Para mejorar estos workflows:
1. Hacer fork del repositorio
2. Crear una rama para tu feature
3. Probar exhaustivamente los cambios
4. Crear un PR con descripción detallada