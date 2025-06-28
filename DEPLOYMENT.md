# 🚀 DataLive Unified RAG+KAG+CAG - Deployment Guide

## 📋 Overview

DataLive has been transformed into a unified enterprise system that combines:
- **RAG** (Retrieval-Augmented Generation) for semantic search
- **KAG** (Knowledge-Augmented Generation) using Neo4j + Graphiti
- **CAG** (Cache-Augmented Generation) for intelligent caching

## 🏗️ Architecture

```
┌─────────────┐    ┌─────────────────────────────────────┐
│   N8N       │────│         UNIFIED AGENT               │
│ Enhanced    │    │  ┌─────┐ ┌─────┐ ┌─────┐ ┌──────────┐│
│ Workflows   │    │  │ RAG │ │ KAG │ │ CAG │ │Orchestrat││
└─────────────┘    │  │Agent│ │Agent│ │Agent│ │or Agent  ││
                   │  └─────┘ └─────┘ └─────┘ └──────────┘│
┌─────────────┐    └─────────────────────────────────────┘
│Multi-Modal  │            │           │           │
│Ingestion    │    ┌───────▼───┐ ┌─────▼─────┐ ┌─▼──┐
│Pipeline     │    │PostgreSQL │ │   Neo4j   │ │Redis│
└─────────────┘    │+ pgvector │ │Knowledge  │ │Cache│
                   │Vector DB  │ │  Graph    │ │     │
                   └───────────┘ └───────────┘ └────┘
```

## 🛠️ Prerequisites

### System Requirements
- Docker & Docker Compose
- Python 3.9+
- 8GB+ RAM
- 50GB+ storage

### Environment Setup
```bash
# Clone repository
cd DataLive

# Copy environment template
cp .env.example .env

# Edit configuration
nano .env
```

## 🚀 Quick Start Deployment

### 1. Enhanced Infrastructure
```bash
# Start enhanced stack with Neo4j
cd docker
docker-compose -f docker-compose-enhanced.yml up -d
```

### 2. Install Agent Dependencies
```bash
cd agents
pip install -r requirements.txt

# Download spaCy model
python -m spacy download en_core_web_sm
```

### 3. Initialize Services
```bash
# Run setup script (if available)
./scripts/setup-datalive.sh

# Or manually:
docker-compose -f docker-compose-enhanced.yml up -d
```

### 4. Verify Deployment
```bash
# Check service health
curl http://localhost:8058/health

# Access services
echo "N8N: http://localhost:5678"
echo "Neo4j: http://localhost:7474"
echo "Unified Agent: http://localhost:8058/docs"
echo "Prometheus: http://localhost:9090"
```

## 📊 Service Endpoints

| Service | Port | URL | Purpose |
|---------|------|-----|---------|
| N8N | 5678 | http://localhost:5678 | Workflow orchestration |
| Neo4j | 7474 | http://localhost:7474 | Knowledge graph browser |
| Unified Agent | 8058 | http://localhost:8058 | Main API |
| Prometheus | 9090 | http://localhost:9090 | Metrics |
| Grafana | 3000 | http://localhost:3000 | Dashboards |

## 🔧 Configuration

### Core Environment Variables
```bash
# API Configuration
API_HOST=0.0.0.0
API_PORT=8058

# Database URLs
POSTGRES_URL=postgresql://postgres:adminpassword@localhost:5432/datalive
NEO4J_URL=neo4j://neo4j:adminpassword@localhost:7687
REDIS_URL=redis://localhost:6379

# LLM Configuration
LLM_PROVIDER=ollama
LLM_MODEL=phi-4:latest
LLM_BASE_URL=http://localhost:11434

# Feature Flags
ENABLE_GRAPHITI=true
ENABLE_TEMPORAL_ANALYSIS=true
ENABLE_CACHING=true
```

### Enhanced Docker Compose
Key changes in `docker-compose-enhanced.yml`:
- ✅ Neo4j Enterprise with graph-data-science plugin
- ✅ Unified Agent service (port 8058)
- ✅ N8N execution mode fixed to 'regular'
- ✅ Enhanced networking and dependencies

## 🔄 Workflow Integration

### Enhanced N8N Workflow
Import the unified workflow:
```bash
# Import via N8N UI
curl -X POST http://localhost:5678/api/v1/workflows/import \
  -H "Content-Type: application/json" \
  -d @workflows/enhanced/unified-rag-workflow.json
```

### API Usage
```bash
# Basic query
curl -X POST http://localhost:8058/api/v1/chat \
  -H "Content-Type: application/json" \
  -d '{
    "message": "What is DataLive?",
    "user_id": "test_user"
  }'

# Relationship query
curl -X POST http://localhost:8058/api/v1/chat \
  -H "Content-Type: application/json" \
  -d '{
    "message": "Who works on DataLive and what technologies are used?",
    "context": {"prefer_relationships": true}
  }'

# Temporal query
curl -X POST http://localhost:8058/api/v1/chat \
  -H "Content-Type: application/json" \
  -d '{
    "message": "How has DataLive evolved over time?",
    "context": {"temporal_analysis": true}
  }'
```

## 📥 Document Ingestion

### Multi-Modal Pipeline
The system supports:
- **PDF documents** (with tables and metadata)
- **Word documents** (.docx with formatting)
- **Excel spreadsheets** (with formulas and charts)
- **Confluence pages** (with attachments and comments)

### Usage Examples
```python
from agents.src.ingestion.pipeline import MultiModalIngestionPipeline

# Initialize pipeline
pipeline = MultiModalIngestionPipeline(
    vector_store=vector_store,
    knowledge_graph=knowledge_graph
)

# Process PDF
result = await pipeline.process_document(
    source="path/to/document.pdf",
    source_type="pdf"
)

# Process Confluence space
results = await pipeline.ingest_confluence_space(
    space_key="DATALIVE",
    base_url="https://your-company.atlassian.net",
    credentials={
        "token": "your-api-token"
    }
)

# Process directory
results = await pipeline.ingest_directory(
    directory_path=Path("documents/"),
    file_patterns=["*.pdf", "*.docx", "*.xlsx"]
)
```

## 🧠 Agent System

### Orchestrator Decision Logic
The system intelligently routes queries:

```python
# Query types and strategies
query_patterns = {
    "factual": {"use_rag": True, "use_kag": False},
    "relationships": {"use_rag": True, "use_kag": True},  
    "temporal": {"use_rag": True, "use_kag": True, "use_temporal": True},
    "complex": {"use_rag": True, "use_kag": True, "use_temporal": True}
}
```

### Cache Strategy
Intelligent TTL based on query type:
```python
cache_ttl = {
    'factual': 86400,     # 24h - static information
    'analytical': 14400,  # 4h - analysis that changes
    'temporal': 3600,     # 1h - time-sensitive data
    'personal': 1800      # 30min - user-specific queries
}
```

## 📊 Monitoring & Metrics

### Prometheus Metrics
Available at `http://localhost:9090`:
- `datalive_queries_total` - Query count by strategy
- `datalive_cache_hit_rate` - Cache effectiveness  
- `datalive_kg_nodes_total` - Knowledge graph size
- `datalive_query_duration_seconds` - Response times

### Health Checks
```bash
# Overall health
curl http://localhost:8058/health

# Individual components
curl http://localhost:8058/api/v1/status
curl http://localhost:8058/api/v1/cache/stats
```

## 🔍 Troubleshooting

### Common Issues

#### 1. Services Not Starting
```bash
# Check logs
docker logs datalive-unified-agent
docker logs datalive-neo4j

# Restart services
docker-compose -f docker-compose-enhanced.yml restart
```

#### 2. Import Errors
```bash
# Install dependencies
cd agents
pip install -r requirements.txt

# Check Python path
export PYTHONPATH=$PWD/src:$PYTHONPATH
```

#### 3. Neo4j Connection Issues
```bash
# Verify Neo4j is running
docker logs datalive-neo4j

# Check credentials in .env
NEO4J_URL=neo4j://neo4j:adminpassword@localhost:7687
```

#### 4. N8N Webhook Issues
The execution mode has been fixed to 'regular':
```yaml
n8n:
  environment:
    - EXECUTIONS_MODE=regular  # Fixed from 'queue'
```

### Debug Mode
```bash
# Enable debug logging
export LOG_LEVEL=DEBUG

# Start with debug
docker-compose -f docker-compose-enhanced.yml up
```

## 🧪 Testing

### System Validation
```bash
cd agents
python test_runner_simple.py
```

### API Testing
```bash
# Test basic functionality
curl -X GET http://localhost:8058/
curl -X GET http://localhost:8058/health
curl -X GET http://localhost:8058/metrics
```

### Integration Testing
```bash
# Run comprehensive tests
cd agents
python -m pytest tests/ -v
```

## 🔄 Updates & Maintenance

### Updating the System
```bash
# Pull latest changes
git pull origin main

# Update dependencies
cd agents
pip install -r requirements.txt --upgrade

# Restart services
docker-compose -f docker-compose-enhanced.yml restart
```

### Database Maintenance
```bash
# Backup Neo4j
docker exec datalive-neo4j neo4j-admin database dump neo4j

# Backup PostgreSQL
docker exec datalive-postgres pg_dump -U postgres datalive > backup.sql
```

## 🎯 Performance Optimization

### Recommended Settings
```bash
# For production workloads
NEO4J_PLUGINS='["graph-data-science", "apoc"]'
NEO4J_dbms_memory_heap_max__size=4G
NEO4J_dbms_memory_pagecache_size=2G

# Vector search optimization
QDRANT_HNSW_EF_CONSTRUCT=200
QDRANT_HNSW_M=16
```

### Scaling
- **Horizontal**: Multiple unified agent instances behind load balancer
- **Vertical**: Increase memory allocation for Neo4j and PostgreSQL
- **Caching**: Redis cluster for distributed caching

## 📈 Production Checklist

- [ ] Environment variables configured
- [ ] SSL/TLS certificates installed
- [ ] Database backups scheduled
- [ ] Monitoring alerts configured
- [ ] Log aggregation setup
- [ ] Security scanning completed
- [ ] Performance testing done
- [ ] Documentation updated

## 🆘 Support

### Log Locations
- Agent logs: `docker logs datalive-unified-agent`
- Neo4j logs: `docker logs datalive-neo4j`
- N8N logs: `docker logs datalive-n8n`

### Key Configuration Files
- `docker/docker-compose-enhanced.yml` - Infrastructure
- `agents/src/config/settings.py` - Application config
- `workflows/enhanced/unified-rag-workflow.json` - N8N workflow
- `neo4j-init/001-knowledge-graph-schema.cypher` - Graph schema

---

**🏆 DataLive Unified RAG+KAG+CAG System - Enterprise Ready!**

The system is now deployed and ready for enterprise document intelligence with advanced relationship analysis, temporal reasoning, and intelligent caching.