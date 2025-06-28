# DataLive Architecture Documentation

## System Overview

DataLive is an enterprise-grade RAG+KAG+CAG unified system that combines:
- **RAG (Retrieval Augmented Generation)**: Vector-based document search
- **KAG (Knowledge Augmented Generation)**: Graph-based relationship queries  
- **CAG (Cache Augmented Generation)**: Intelligent caching for performance

## Architecture Components

### 1. Core Services

#### PostgreSQL + pgvector
- Stores document chunks and embeddings
- Handles metadata and system configuration
- Optimized indexes for vector similarity search

#### Neo4j Enterprise
- Knowledge graph for entities and relationships
- Temporal data with Graphiti integration
- Graph algorithms for advanced analytics

#### Redis
- Semantic cache for frequent queries
- Session management
- Real-time metrics aggregation

### 2. Processing Pipeline

#### Ingestion Pipeline
```
Document → Parser → Chunker → Entity Extractor → Embedder → Storage
↓
Knowledge Graph
```

#### Query Pipeline
```
Query → Intent Detection → Router → Strategy Selection → Execution → Response
↓
[RAG|KAG|CAG]
```

### 3. Integration Points

- **N8N**: Workflow orchestration
- **Prometheus/Grafana**: Monitoring
- **MinIO**: Object storage
- **Ollama**: LLM inference

## Performance Optimizations

1. **Hybrid Search**: Combines vector + keyword + graph
2. **Smart Caching**: TTL based on query type
3. **Batch Processing**: Concurrent document processing
4. **Connection Pooling**: Optimized database connections

## Security Considerations

- All secrets in Docker secrets
- Network segmentation (frontend/backend)
- Authentication on all services
- Encrypted data at rest and in transit

## Scaling Strategy

### Horizontal Scaling
- Multiple unified agent instances
- Redis cluster for distributed cache
- Neo4j causal cluster for HA

### Vertical Scaling
- Increase memory for Neo4j (8GB minimum)
- GPU acceleration for embeddings
- SSD storage for vector indexes