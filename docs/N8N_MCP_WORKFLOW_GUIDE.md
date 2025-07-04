# 🔧 Guía de Desarrollo de Workflows DataLive con n8n-MCP

## 🚀 Inicio Rápido

### 1. Verificar que DataLive esté corriendo
```bash
docker-compose up -d
docker-compose ps  # Verificar que todos los servicios estén healthy
```

### 2. Ejecutar n8n-MCP
```bash
./scripts/use-n8n-mcp.sh
```

## 📚 Workflows Clave para DataLive

### 1. Workflow de Ingesta Inteligente

**Objetivo**: Procesar documentos de múltiples fuentes y almacenarlos en RAG+KAG+CAG.

**Nodos Necesarios**:
- `n8n-nodes-base.webhook` - Recibir documentos
- `n8n-nodes-base.googleDrive` - Sincronizar con Google Drive
- `n8n-nodes-base.github` - Clonar repositorios
- `n8n-nodes-base.httpRequest` - Llamar a DataLive API
- `n8n-nodes-base.qdrant` - Almacenar vectores
- `n8n-nodes-base.postgres` - Guardar metadatos

**Comandos n8n-MCP**:
```javascript
// Buscar nodos necesarios
search_nodes({query: "google drive"})
search_nodes({query: "qdrant vector"})

// Obtener configuración esencial
get_node_essentials("n8n-nodes-base.googleDrive")
get_node_essentials("n8n-nodes-base.qdrant")

// Validar configuración antes de construir
validate_node_minimal("n8n-nodes-base.qdrant", {
  operation: "insert",
  collection: "datalive_documents"
})
```

### 2. Workflow de Query Processing

**Objetivo**: Procesar consultas usando estrategia híbrida RAG+KAG+CAG.

**Nodos Necesarios**:
- `n8n-nodes-base.webhook` - Recibir queries
- `n8n-nodes-base.httpRequest` - Llamar a DataLive Agent
- `n8n-nodes-langchain.lmChatOllama` - Procesamiento con Phi-4
- `n8n-nodes-base.if` - Router de estrategias
- `n8n-nodes-base.slack` - Responder al usuario

**Estrategia de Implementación**:
```javascript
// Obtener nodo de Ollama para Phi-4
search_nodes({query: "ollama chat"})
get_node_essentials("n8n-nodes-langchain.lmChatOllama")

// Configurar con Phi-4 mini
validate_node_operation("n8n-nodes-langchain.lmChatOllama", {
  modelName: "phi4-mini",
  baseUrl: "http://ollama:11434"
})
```

### 3. Workflow de Monitoreo y Métricas

**Objetivo**: Recolectar métricas y enviarlas a Prometheus/Grafana.

**Nodos Necesarios**:
- `n8n-nodes-base.schedule` - Ejecutar cada minuto
- `n8n-nodes-base.postgres` - Leer estadísticas
- `n8n-nodes-base.httpRequest` - Enviar a Prometheus
- `n8n-nodes-base.errorTrigger` - Manejo de errores

## 🎯 Mejores Prácticas para DataLive

### 1. Validación Temprana
```javascript
// SIEMPRE validar antes de desplegar
validate_workflow(workflowJson)
validate_workflow_connections(workflowJson)
validate_workflow_expressions(workflowJson)
```

### 2. Manejo de Errores Robusto
- Usar `errorTrigger` en todos los workflows
- Implementar reintentos con backoff exponencial
- Registrar errores en PostgreSQL para análisis

### 3. Optimización de Rendimiento
- Usar `splitInBatches` para grandes volúmenes
- Implementar caché con Redis
- Paralelizar operaciones cuando sea posible

### 4. Seguridad
- Usar credenciales cifradas de n8n
- Validar entrada con `if` nodes
- Sanitizar datos antes de almacenar

## 🔄 Workflows Específicos de DataLive

### Ingesta desde Google Drive
```javascript
// Buscar plantilla
get_node_for_task("sync_google_drive_files")

// Adaptar para DataLive
const googleDriveConfig = {
  resource: "file",
  operation: "list",
  queryString: "mimeType != 'application/vnd.google-apps.folder'",
  fields: ["id", "name", "mimeType", "modifiedTime"]
}
```

### Procesamiento con Ollama + Phi-4
```javascript
// Configuración para Phi-4 mini
const ollamaConfig = {
  modelName: "phi4-mini",
  temperature: 0.7,
  maxTokens: 2048,
  systemMessage: "Eres un asistente de IA empresarial especializado en análisis de documentos."
}

// Validar antes de usar
validate_node_operation("n8n-nodes-langchain.lmChatOllama", ollamaConfig)
```

### Almacenamiento en Qdrant
```javascript
// Configuración para vectores
const qdrantConfig = {
  operation: "insert",
  collection: "datalive_documents",
  vector: "={{$json.embedding}}",
  payload: {
    text: "={{$json.content}}",
    metadata: "={{$json.metadata}}",
    timestamp: "={{new Date().toISOString()}}"
  }
}
```

## 📊 Ejemplos de Workflows Completos

### 1. Workflow de Ingesta Completa
```javascript
const ingestWorkflow = {
  name: "DataLive Document Ingestion v2",
  nodes: [
    {
      name: "Webhook",
      type: "n8n-nodes-base.webhook",
      position: [250, 300],
      parameters: {
        path: "datalive/ingest",
        responseMode: "onReceived",
        options: {}
      }
    },
    {
      name: "Process Document",
      type: "n8n-nodes-base.httpRequest",
      position: [450, 300],
      parameters: {
        url: "http://datalive-agent:8058/api/v1/ingest",
        method: "POST",
        authentication: "genericCredentialType",
        genericAuthType: "httpHeaderAuth",
        sendBody: true,
        bodyParameters: {
          parameters: [
            {
              name: "source_type",
              value: "={{$json.source_type}}"
            },
            {
              name: "source",
              value: "={{$json.source}}"
            }
          ]
        }
      }
    }
  ],
  connections: {
    "Webhook": {
      "main": [[{"node": "Process Document", "type": "main", "index": 0}]]
    }
  }
}

// Validar workflow completo
validate_workflow(ingestWorkflow)
```

### 2. Workflow de Query Inteligente
```javascript
const queryWorkflow = {
  name: "DataLive Intelligent Query v2",
  nodes: [
    // ... configuración de nodos
  ]
}

// Usar diff para actualizaciones
n8n_update_partial_workflow({
  workflowId: "existing-id",
  operations: [
    {
      type: "updateNode",
      nodeId: "Ollama Chat",
      changes: {
        parameters: {
          modelName: "phi4-mini"
        }
      }
    }
  ]
})
```

## 🛠️ Comandos Útiles de n8n-MCP

### Búsqueda y Descubrimiento
```javascript
// Buscar nodos por funcionalidad
search_nodes({query: "vector database"})
search_nodes({query: "ollama phi4"})
list_ai_tools()  // Ver todos los nodos con capacidades de IA

// Buscar propiedades específicas
search_node_properties("n8n-nodes-base.postgres", "ssl")
```

### Validación
```javascript
// Validación rápida
validate_node_minimal(nodeType, {resource: "x", operation: "y"})

// Validación completa
validate_node_operation(nodeType, fullConfig, "runtime")

// Validar workflow completo
validate_workflow(workflowJson)
```

### Gestión de Workflows (si API configurada)
```javascript
// Crear workflow
n8n_create_workflow(validatedWorkflow)

// Actualizar con diffs (ahorra 80-90% tokens)
n8n_update_partial_workflow({
  workflowId: "123",
  operations: [/* cambios */]
})

// Validar workflow en n8n
n8n_validate_workflow({id: "workflow-id"})
```

## 🚨 Troubleshooting

### Problema: Nodo no encontrado
```javascript
// Buscar el nombre correcto
search_nodes({query: "nombre parcial"})
list_nodes({category: "data"})
```

### Problema: Configuración inválida
```javascript
// Obtener configuración mínima
get_node_essentials(nodeType)

// Validar paso a paso
validate_node_minimal(nodeType, minimalConfig)
validate_node_operation(nodeType, fullConfig)
```

### Problema: Workflow no funciona
```javascript
// Validar estructura
validate_workflow_connections(workflow)
validate_workflow_expressions(workflow)

// Verificar en n8n
n8n_validate_workflow({id: workflowId})
```

## 📚 Recursos Adicionales

- [n8n-MCP Documentation](https://github.com/czlonkowski/n8n-mcp)
- [DataLive Technical Docs](./DOCUMENTACION_TECNICA.md)
- [n8n Official Docs](https://docs.n8n.io)
- [Phi-4 Model Info](https://ollama.com/library/phi4-mini)