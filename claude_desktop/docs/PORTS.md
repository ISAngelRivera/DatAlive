# DataLive System Ports Documentation

## Overview

This document provides a comprehensive overview of all ports used in the DataLive infrastructure. Each service exposes specific ports for different purposes including APIs, management interfaces, and inter-service communication.

## Port Allocation Table

| Service | Port(s) | Protocol | Type | Description | Access Level |
|---------|---------|----------|------|-------------|--------------|
| **Neo4j** | 7474 | HTTP | Web UI | Neo4j Browser interface | Internal/External |
| **Neo4j** | 7687 | Bolt | Database | Neo4j database protocol | Internal |
| **PostgreSQL** | 5432 | TCP | Database | PostgreSQL database connection | Internal |
| **Redis** | 6379 | TCP | Cache | Redis key-value store | Internal |
| **Qdrant** | 6333 | HTTP | API | Vector database REST API | Internal |
| **Ollama** | 11434 | HTTP | API | LLM inference API | Internal |
| **DataLive Agent** | 8058 | HTTP | API | Main application API | Internal/External |
| **N8N** | 5678 | HTTP | Web UI | Workflow automation interface | Internal/External |
| **Prometheus** | 9090 | HTTP | Web UI | Metrics collection and monitoring | Internal |
| **Grafana** | 3000 | HTTP | Web UI | Analytics and monitoring dashboards | Internal/External |
| **MinIO** | 9000 | HTTP | API | Object storage API | Internal |
| **MinIO Console** | 9001 | HTTP | Web UI | MinIO management console | Internal |

## Service Details

### Neo4j (Graph Database)
- **Port 7474**: Neo4j Browser web interface for query development and database exploration
- **Port 7687**: Bolt protocol for database connections from applications
- **Security**: Authentication required, uses encrypted connections
- **Health Check**: `curl http://localhost:7474/db/data/`

### PostgreSQL (Relational Database)
- **Port 5432**: Standard PostgreSQL connection port
- **Usage**: RAG metadata, CAG cache, monitoring data
- **Security**: Username/password authentication
- **Health Check**: `pg_isready -h localhost -p 5432`

### Redis (Cache & Session Store)
- **Port 6379**: Redis protocol for cache operations
- **Usage**: Query cache, session storage, temporary data
- **Security**: Optional AUTH password
- **Health Check**: `redis-cli ping`

### Qdrant (Vector Database)
- **Port 6333**: REST API for vector operations
- **Usage**: Document embeddings, similarity search
- **Security**: Optional API key authentication
- **Health Check**: `curl http://localhost:6333/`

### Ollama (LLM Service)
- **Port 11434**: REST API for LLM inference
- **Usage**: Text generation, embeddings, chat completions
- **Security**: Internal network only
- **Health Check**: `curl http://localhost:11434/api/tags`

### DataLive Agent (Core API)
- **Port 8058**: FastAPI application
- **Usage**: Main application logic, RAG+KAG+CAG orchestration
- **Security**: API key authentication, CORS configured
- **Health Check**: `curl http://localhost:8058/health`

### N8N (Workflow Automation)
- **Port 5678**: Web interface and webhook endpoints
- **Usage**: Workflow execution, integrations, automation
- **Security**: Login required, webhook authentication
- **Health Check**: `curl http://localhost:5678/healthz`

### Prometheus (Metrics Collection)
- **Port 9090**: Web UI and metrics API
- **Usage**: System monitoring, metrics collection
- **Security**: Internal access only
- **Health Check**: `curl http://localhost:9090/-/healthy`

### Grafana (Analytics Dashboard)
- **Port 3000**: Web dashboard interface
- **Usage**: Monitoring dashboards, alerting
- **Security**: Admin login required
- **Health Check**: `curl http://localhost:3000/api/health`

### MinIO (Object Storage)
- **Port 9000**: S3-compatible API
- **Port 9001**: Management console
- **Usage**: File storage, document assets, media files
- **Security**: Access/secret key authentication
- **Health Check**: `curl http://localhost:9000/minio/health/live`

## Network Configuration

### Docker Network
All services run within a custom Docker network enabling:
- Service discovery by name (e.g., `http://neo4j:7474`)
- Automatic DNS resolution
- Network isolation from external traffic

### Internal vs External Access

**Internal Only** (Docker network):
- PostgreSQL (5432)
- Redis (6379)
- Qdrant (6333)
- Ollama (11434)
- MinIO API (9000)
- Prometheus (9090)

**External Access Available**:
- Neo4j Browser (7474)
- DataLive Agent API (8058)
- N8N Interface (5678)
- Grafana Dashboard (3000)
- MinIO Console (9001)

## Security Considerations

### Firewall Rules
- External ports should be restricted to trusted networks
- Consider VPN access for management interfaces
- Use reverse proxy (nginx/traefik) for production deployments

### Authentication
- All external services require authentication
- API keys used for service-to-service communication
- Database connections use dedicated service accounts

### SSL/TLS
- Production deployments should use HTTPS
- Internal communication can use HTTP within Docker network
- Neo4j supports encrypted Bolt connections

## Troubleshooting

### Port Conflicts
If ports are already in use:
```bash
# Check what's using a port
lsof -i :5678
netstat -tulpn | grep :5678

# Change ports in docker-compose.yml
services:
  n8n:
    ports:
      - "5679:5678"  # Use 5679 externally instead
```

### Connection Issues
```bash
# Test port connectivity
nc -zv localhost 5432
telnet localhost 6379

# Check Docker network
docker network ls
docker network inspect datalive_default
```

### Service Discovery
Within Docker network, services are accessible by name:
```bash
# From any container
curl http://neo4j:7474/db/data/
curl http://qdrant:6333/collections
curl http://datalive-agent:8058/health
```

## Monitoring and Health Checks

### Automated Health Checks
Use the provided scripts:
```bash
# Quick status check
./quick-health-check.sh

# Comprehensive diagnostics
./infrastructure-diagnostic.sh
```

### Manual Health Checks
```bash
# Check all services are running
docker-compose ps

# Test all HTTP endpoints
for port in 7474 8058 5678 3000 6333 9090 9000; do
  echo "Testing port $port..."
  curl -f "http://localhost:$port/" || echo "Failed"
done
```

## Development vs Production

### Development Setup
- All ports exposed to localhost
- HTTP connections acceptable
- Default passwords/keys

### Production Recommendations
- Use reverse proxy (nginx/traefik)
- Enable HTTPS with proper certificates
- Restrict external port access
- Use strong passwords and rotate keys
- Enable audit logging
- Implement proper backup strategies

## Port Range Summary

| Range | Usage |
|-------|-------|
| 3000-3999 | Web interfaces (Grafana) |
| 5000-5999 | Application APIs (N8N) |
| 6000-6999 | Databases (Redis, Qdrant) |
| 7000-7999 | Graph databases (Neo4j) |
| 8000-8999 | Application services (DataLive Agent) |
| 9000-9999 | Storage & monitoring (MinIO, Prometheus) |
| 11000-11999 | AI services (Ollama) |

This organization helps avoid conflicts and makes the architecture easier to understand and maintain.