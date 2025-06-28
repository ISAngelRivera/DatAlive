#!/bin/bash
# deploy-complete.sh - Complete deployment script for DataLive

set -e

echo "=== DataLive Complete Deployment Script ==="
echo "This will deploy the entire optimized system"
echo ""

# 1. Check prerequisites
echo "Checking prerequisites..."
command -v docker >/dev/null 2>&1 || { echo "Docker required but not installed. Aborting." >&2; exit 1; }
command -v docker-compose >/dev/null 2>&1 || { echo "Docker Compose required but not installed. Aborting." >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "Python 3 required but not installed. Aborting." >&2; exit 1; }

# 2. Clean old files
echo "Cleaning obsolete files..."
bash -c "$(cat << 'EOF'
rm -f scripts/test-*.sh
rm -f scripts/init-ollama-models.sh scripts/init-minio-buckets.sh
rm -f scripts/init-n8n-setup.sh scripts/init-qdrant-collections.sh
rm -rf workflows/optimization/
rm -f workflows/query/rag-query-router.json
rm -f workflows/ingestion/document-sync-deletion.json
rm -f postgres-init/init-old.sql
rm -rf config/legacy/
rm -f docker/docker-compose-old.yml
find logs/ -name "*.log" -mtime +7 -delete 2>/dev/null || true
EOF
)"

# 3. Create required directories
echo "Creating directory structure..."
mkdir -p docker/backups/{postgres,neo4j,redis,minio,config}
mkdir -p docker/logs
mkdir -p agents/models
mkdir -p docker/config/grafana/dashboards
mkdir -p agents/{tests,src/core,src/agents,src/ingestion}

# 4. Install Python dependencies
echo "Installing Python dependencies..."
cd agents
pip install -r requirements.txt
python -m spacy download en_core_web_sm || echo "spaCy model download can be done manually"
cd ..

# 5. Generate secrets if not exist
echo "Generating secrets..."
[ -f docker/secrets/postgres_password.txt ] || echo "adminpassword" > docker/secrets/postgres_password.txt
[ -f docker/secrets/neo4j_password.txt ] || echo "adminpassword" > docker/secrets/neo4j_password.txt
[ -f docker/secrets/minio_secret_key.txt ] || openssl rand -base64 32 > docker/secrets/minio_secret_key.txt
[ -f docker/secrets/n8n_encryption_key.txt ] || openssl rand -base64 32 > docker/secrets/n8n_encryption_key.txt
[ -f docker/secrets/grafana_password.txt ] || echo "admin123" > docker/secrets/grafana_password.txt

# 6. Update environment variables
echo "Updating environment variables..."
cat > .env << EOF
# Database
POSTGRES_USER=datalive_user
POSTGRES_DB=datalive_db
POSTGRES_PASSWORD=adminpassword

# Neo4j
NEO4J_USER=neo4j
NEO4J_PASSWORD=adminpassword

# Redis
REDIS_PASSWORD=change_this_redis_password

# N8N
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=adminpassword

# MinIO
MINIO_ROOT_USER=datalive_admin
MINIO_ROOT_PASSWORD=change_this_minio_password

# Grafana
GRAFANA_USER=admin
GRAFANA_PASSWORD=admin123

# Feature flags
ENABLE_GRAPHITI=true
USE_GPU=false
EOF

# 7. Stop existing services
echo "Stopping existing services..."
cd docker
docker-compose down || true
cd ..

# 8. Build and start services
echo "Building and starting services..."
cd docker
docker-compose build
docker-compose up -d
cd ..

# 9. Wait for services to be ready
echo "Waiting for services to be ready..."
sleep 60

# 10. Initialize Graphiti (if unified agent is available)
echo "Initializing Graphiti..."
docker exec datalive-unified-agent python -c "
import asyncio
from src.core.graphiti_integration import GraphitiManager
async def init():
    gm = GraphitiManager('neo4j://neo4j:7687', ('neo4j', 'adminpassword'))
    await gm.initialize()
asyncio.run(init())
" || echo "Graphiti initialization will be done later"

# 11. Run tests (if available)
echo "Running tests..."
cd agents
pytest tests/ -v --maxfail=1 || echo "Some tests failed, but continuing..."
cd ..

# 12. Setup cron jobs for backup
echo "Setting up backup cron jobs..."
(crontab -l 2>/dev/null; echo "0 2 * * * $(pwd)/scripts/backup-all.sh") | crontab - || echo "Cron setup can be done manually"

# 13. Display status
echo ""
echo "=== Deployment Complete ==="
echo ""
echo "Services available at:"
echo "- N8N: http://localhost:5678 (admin/adminpassword)"
echo "- Neo4j: http://localhost:7474 (neo4j/adminpassword)"
echo "- Unified Agent API: http://localhost:8058/docs"
echo "- Prometheus: http://localhost:9090"
echo "- Grafana: http://localhost:3000 (admin/admin123)"
echo "- MinIO Console: http://localhost:9001"
echo "- Qdrant Dashboard: http://localhost:6333/dashboard"
echo ""
echo "To view logs: docker-compose -f docker/docker-compose.yml logs -f"
echo "To stop: docker-compose -f docker/docker-compose.yml down"
echo ""
echo "Next steps:"
echo "1. Import Grafana dashboards from docker/config/grafana/dashboards/"
echo "2. Configure N8N workflows"
echo "3. Start ingesting documents"
echo "4. Test the unified agent API at http://localhost:8058/docs"
echo ""