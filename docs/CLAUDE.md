# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

### Core Development
- **Start full system**: `docker-compose up -d` (Golden Path deployment - 100% automated)
- **Build agent**: `cd datalive_agent && poetry install`
- **Run agent locally**: `cd datalive_agent && poetry run python -m src.main`
- **Run tests**: `cd datalive_agent && python tests/run_all_tests.py`
- **Quick tests**: `cd datalive_agent && python tests/run_all_tests.py --quick`
- **Specific test**: `cd datalive_agent && python tests/run_all_tests.py --test=test_unified_agent.py`
- **Lint code**: `cd datalive_agent && poetry run ruff check src/`
- **Format code**: `cd datalive_agent && poetry run ruff format src/`

### System Health & Status  
- **Health check**: `./claude_desktop/scripts/quick-health-check.sh`
- **Full diagnostic**: `./claude_desktop/scripts/infrastructure-diagnostic.sh`
- **API test ingest**: `curl -X POST http://localhost:8058/api/v1/ingest -H 'Content-Type: application/json' -H 'X-API-Key: datalive-dev-key-change-in-production' -d '{"source_type": "txt", "source": "Test content"}'`
- **API test query**: `curl -X POST http://localhost:8058/api/v1/query -H 'Content-Type: application/json' -H 'X-API-Key: datalive-dev-key-change-in-production' -d '{"query": "What is DataLive?"}'`

### Docker & Service Management
- **View logs**: `docker-compose logs [service_name] --tail=50`
- **Restart service**: `docker-compose restart [service_name]`
- **Check all containers**: `docker-compose ps`

## Architecture Overview

DataLive is a sovereign enterprise AI system implementing RAG+KAG+CAG (Retrieval + Knowledge + Contextual Augmented Generation) using a microservices architecture.

### Project Status (per docs/datalive_complete_project.md)
- **Infrastructure**: 100% Complete and Operational  
- **Core Application**: 85% Implemented (APIs, agents, processing)
- **N8N Workflows**: 30% Implemented ⚠️ **CRITICAL ISSUE: Current workflows are non-functional**
- **Documentation**: 95% Complete
- **Testing**: 70% Automated

### Known Critical Issues
1. **N8N Workflows**: Current workflows in `n8n_workflows/` are broken and need complete rewrite
2. **Agent Logic**: RAG/KAG/CAG agents are partially implemented but lack complete routing logic
3. **N8N ↔ Python Integration**: Missing proper API bridge between workflows and DataLive Agent

### Core Components

**DataLive Agent** (`datalive_agent/src/`):
- **Unified Agent** (`agents/unified_agent.py`): Orchestrates RAG, KAG, and CAG strategies
- **RAG Agent**: Vector-based document retrieval using Qdrant
- **KAG Agent**: Knowledge graph analysis using Neo4j
- **CAG Agent**: Contextual/temporal analysis and caching using Redis
- **Orchestrator Agent**: Query analysis and strategy selection

**Core Services** (`src/core/`):
- **Database** (`database.py`): PostgreSQL, Neo4j, Redis connection management
- **Vector Store** (`vector_store.py`): Qdrant vector database operations
- **Knowledge Graph** (`knowledge_graph.py`): Neo4j graph operations
- **LLM Integration** (`llm.py`): Ollama local LLM integration

**Ingestion Pipeline** (`src/ingestion/`):
- **Multi-modal Pipeline** (`pipeline.py`): Processes PDF, Excel, TXT, Markdown, CSV
- **Document Processors** (`processors/`): Format-specific content extraction
- **Entity/Relationship Extractors** (`extractors/`): NLP-based knowledge extraction

**API Layer** (`src/api/routes.py`):
- `/chat` - Conversational interface
- `/query` - Direct knowledge base queries
- `/ingest` - Document ingestion endpoints
- `/search/*` - Individual strategy endpoints (vector, knowledge-graph, temporal)

### Data Flow Architecture

1. **Document Ingestion**: Files → Processors → Entities/Relationships → Vector DB + Knowledge Graph
2. **Query Processing**: Query → Orchestrator → Strategy Selection → Parallel Agent Execution → Response Synthesis
3. **Multi-Strategy Execution**: 
   - **RAG Strategy**: Semantic vector search using Qdrant - best for factual queries ("What is X?")
   - **KAG Strategy**: Knowledge graph analysis using Neo4j - best for relational queries ("How does X relate to Y?")  
   - **CAG Strategy**: Contextual/temporal analysis using PostgreSQL+Redis - best for time-based queries ("What changed recently?")

### Infrastructure Services

**Docker Services** (see `docker-compose.yml`):
- **postgres**: Primary database with pgvector extension
- **neo4j**: Knowledge graph with APOC and GDS plugins
- **qdrant**: Vector database for semantic search
- **redis**: Caching and session management
- **ollama**: Local LLM serving (Phi-4, Llama3 models)
- **n8n**: Workflow automation and integration
- **minio**: S3-compatible object storage
- **prometheus/grafana**: Monitoring and metrics

**Initialization Sidecars**: Automated setup containers that configure databases, download models, and establish N8N workflows on first deployment.

### Current LLM Models (per docs)
- **Primary LLM**: `phi4-mini` or `phi3:medium` (Ollama)
- **Embeddings**: `nomic-embed-text:v1.5` (384 dimensions) or `all-MiniLM-L6-v2` 
- **Fallback**: System will attempt model download on first startup

## Key Implementation Patterns

### Agent Orchestration
The `UnifiedAgent` uses an orchestrator to analyze queries and determine optimal strategy combinations:
- **Factual queries** → RAG-heavy
- **Relationship queries** → KAG-focused  
- **Historical queries** → CAG temporal analysis
- **Complex queries** → Multi-strategy parallel execution

### Async Processing
All agents use async/await patterns with:
- Connection pooling for databases
- Concurrent task execution via `asyncio.gather()`
- Background processing for large document ingestion

### Metrics & Monitoring
Prometheus metrics integrated throughout:
- Query performance (`query_duration`, `query_counter`)
- Agent usage (`agent_usage_counter`)
- Cache efficiency (`cache_hit_counter`, `cache_miss_counter`)
- Knowledge graph growth (`kg_nodes_count`, `kg_relationships_count`)

### Configuration Management
- **Settings**: Environment-based configuration via Pydantic Settings
- **API Security**: API key authentication (X-API-Key header)
- **Poetry**: Dependency management and virtual environments
- **Docker**: Containerized deployment with health checks

## Development Notes

### Testing Strategy
- **Unit tests**: Individual component testing
- **Integration tests**: Cross-service communication
- **Performance tests**: Agent response times and throughput
- **Security tests**: API authentication and input validation
- **Health tests**: Service availability and connectivity

### Code Organization
- Follow async patterns for all I/O operations
- Use Pydantic models for request/response validation
- Implement proper error handling and logging
- Maintain separation between agents, core services, and API layers

### Environment Setup - Golden Path Deployment
The system uses a "Golden Path" deployment where `docker-compose up -d` automatically:
1. Initializes all databases with proper schemas (PostgreSQL, Neo4j, Qdrant)
2. Downloads and configures LLM models via `ollama-pull` sidecar
3. Sets up N8N workflows with encrypted credentials via `n8n-setup` sidecar
4. Establishes monitoring dashboards (Prometheus + Grafana)
5. Runs comprehensive health verification via `healthcheck` sidecar

⚠️ **Important**: Despite automation, N8N workflows currently require manual fixing due to architectural issues.

### API Key Management
- **Development**: `datalive-dev-key-change-in-production` (default)
- **Production**: Override via `DATALIVE_API_KEY` environment variable
- **N8N Integration**: Uses same API key for workflow authentication

### Database Schemas (per docs)
- **PostgreSQL**: Separate schemas for `rag`, `cag`, and `monitoring` with optimized indexes
- **Qdrant**: Collections for `documents`, `entities`, and `cache` (384-dim vectors)
- **Neo4j**: Constraints for `Document`, `Person`, `Organization` entities

## Service Ports

- **DataLive Agent**: 8058 (main API)
- **N8N**: 5678 (workflow automation)
- **Neo4j**: 7474 (browser), 7687 (bolt)
- **Qdrant**: 6333 (API and dashboard)
- **PostgreSQL**: 5432
- **Redis**: 6379
- **Ollama**: 11434
- **Prometheus**: 9090
- **Grafana**: 3000

All services communicate via the `datalive-net` Docker network with automatic service discovery.

## Critical Development Notes

### Workflow Issues (from docs/datalive_complete_project.md)
1. **N8N Workflows are BROKEN**: Current workflows in `datalive_agent/n8n_workflows/` are non-functional and need complete rewrite
2. **Missing Workflows**: Need to create `DataLive-Ingestion-Workflow.json` and `DataLive-Query-Workflow.json` from scratch
3. **Credential Automation**: N8N credentials are not properly auto-created during setup
4. **Integration Gap**: No proper API bridge between N8N workflows and DataLive Agent endpoints

### Agent Implementation Status
- **UnifiedAgent**: Structure complete, orchestration logic needs implementation
- **RAGAgent**: Basic vector search implemented, needs refinement  
- **KAGAgent**: Neo4j interface ready, relationship analysis logic incomplete
- **CAGAgent**: Cache structure ready, temporal analysis needs implementation
- **Orchestrator**: Query routing logic needs complete implementation

### Next Priority Tasks
1. **Fix N8N workflows** - recreate functional ingestion and query workflows
2. **Complete agent routing logic** - implement intelligent strategy selection
3. **Add missing API endpoints** - create N8N-specific endpoints for workflow integration
4. **Test end-to-end** - ensure document ingestion → query → response pipeline works

### Testing Strategy
The `run_all_tests.py` script provides comprehensive testing including:
- Unit tests, integration tests, performance tests, security tests
- Coverage reporting with HTML output
- Individual test execution: `python tests/run_all_tests.py --test=test_unified_agent.py`
- Quick mode: `python tests/run_all_tests.py --quick`