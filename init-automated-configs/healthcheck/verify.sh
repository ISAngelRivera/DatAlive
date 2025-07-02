#!/bin/sh
# DataLive Final Health Check Script
# Runs after all services are initialized

set -e

echo "🔍 DataLive System Health Check Starting..."
echo "=================================================="

# Configuration
POSTGRES_HOST="${POSTGRES_HOST:-postgres}"
NEO4J_HOST="${NEO4J_HOST:-neo4j}"
QDRANT_HOST="${QDRANT_HOST:-qdrant}"
MINIO_HOST="${MINIO_HOST:-minio}"
OLLAMA_HOST="${OLLAMA_HOST:-ollama}"
N8N_HOST="${N8N_HOST:-n8n}"
AGENT_HOST="${DATALIVE_AGENT_HOST:-datalive_agent}"

# Colors for output (if terminal supports it)
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Counters
TOTAL_CHECKS=0
PASSED_CHECKS=0

# Helper function for service checks
check_service() {
    local service_name="$1"
    local check_command="$2"
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    echo -n "   $service_name: "
    
    if eval "$check_command" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Healthy${NC}"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
        return 0
    else
        echo -e "${RED}❌ Unhealthy${NC}"
        return 1
    fi
}

echo "📊 Checking Core Services..."
echo "----------------------------"

# 1. PostgreSQL
check_service "PostgreSQL" "nc -z $POSTGRES_HOST 5432"

# 2. Neo4j
check_service "Neo4j" "curl -s -f http://$NEO4J_HOST:7474"

# 3. Qdrant  
check_service "Qdrant" "curl -s -f http://$QDRANT_HOST:6333/"

# 4. MinIO
check_service "MinIO" "curl -s -f http://$MINIO_HOST:9000/minio/health/live"

# 5. Ollama
check_service "Ollama" "curl -s -f http://$OLLAMA_HOST:11434/api/version"

# 6. N8N
check_service "N8N" "curl -s -f http://$N8N_HOST:5678/healthz"

# 7. DataLive Agent
check_service "DataLive Agent" "curl -s -f http://$AGENT_HOST:8058/health"

echo ""
echo "🔌 Checking API Endpoints..."
echo "----------------------------"

# Check DataLive API endpoints
check_service "API Health" "curl -s -f http://$AGENT_HOST:8058/health"
check_service "API Docs" "curl -s -f http://$AGENT_HOST:8058/docs"
check_service "API Metrics" "curl -s -f http://$AGENT_HOST:8058/metrics"

echo ""
echo "🧪 Testing Core Functionality..."
echo "--------------------------------"

# Test document ingestion
echo -n "   Document Ingestion: "
if curl -s -X POST "http://$AGENT_HOST:8058/api/v1/ingest" \
    -H "Content-Type: application/json" \
    -d '{"source_type": "txt", "source": "Health check test document"}' \
    | grep -q "success"; then
    echo -e "${GREEN}✅ Working${NC}"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
else
    echo -e "${RED}❌ Failed${NC}"
fi
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

# Test query functionality
echo -n "   Query System: "
if curl -s -X POST "http://$AGENT_HOST:8058/api/v1/query" \
    -H "Content-Type: application/json" \
    -d '{"query": "test", "max_results": 1}' \
    | grep -q "answer"; then
    echo -e "${GREEN}✅ Working${NC}"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
else
    echo -e "${RED}❌ Failed${NC}"
fi
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

echo ""
echo "📋 System Information..."
echo "------------------------"

# Get Ollama model info
echo -n "   LLM Model: "
if ollama_models=$(curl -s "http://$OLLAMA_HOST:11434/api/tags" 2>/dev/null | grep -o '"name":"[^"]*"' | head -1); then
    model_name=$(echo "$ollama_models" | cut -d'"' -f4)
    if [ -n "$model_name" ]; then
        echo "$model_name"
    else
        echo "No models loaded"
    fi
else
    echo "Unable to retrieve"
fi

# Get Qdrant collections
echo -n "   Vector Collections: "
if collections=$(curl -s "http://$QDRANT_HOST:6333/collections" 2>/dev/null | grep -o '"result":\[[^]]*\]'); then
    collection_count=$(echo "$collections" | grep -o '"[^"]*"' | grep -v "result" | wc -l)
    echo "$collection_count collections"
else
    echo "Unable to retrieve"
fi

echo ""
echo "=================================================="
echo "🏆 HEALTH CHECK SUMMARY"
echo "=================================================="
echo ""

SUCCESS_RATE=$((PASSED_CHECKS * 100 / TOTAL_CHECKS))

echo "   Total Checks: $TOTAL_CHECKS"
echo "   Passed: $PASSED_CHECKS"
echo "   Failed: $((TOTAL_CHECKS - PASSED_CHECKS))"
echo "   Success Rate: ${SUCCESS_RATE}%"
echo ""

if [ $SUCCESS_RATE -eq 100 ]; then
    echo -e "${GREEN}✅ ALL SYSTEMS OPERATIONAL!${NC}"
    echo ""
    echo "🎉 DataLive is ready for use!"
    echo ""
    echo "📡 Access Points:"
    echo "   • API Documentation: http://localhost:8058/docs"
    echo "   • N8N Automation: http://localhost:5678"
    echo "   • Neo4j Browser: http://localhost:7474"
    echo "   • Qdrant Dashboard: http://localhost:6333/dashboard"
    echo "   • MinIO Console: http://localhost:9001"
    echo ""
    echo "🚀 Quick Start:"
    echo "   curl -X POST http://localhost:8058/api/v1/ingest \\"
    echo "     -H 'Content-Type: application/json' \\"
    echo "     -d '{\"source_type\": \"txt\", \"source\": \"Your first document\"}'"
    echo ""
    exit 0
elif [ $SUCCESS_RATE -ge 80 ]; then
    echo -e "${YELLOW}⚠️  MOSTLY OPERATIONAL (${SUCCESS_RATE}%)${NC}"
    echo ""
    echo "Some non-critical services may need attention."
    echo "Check the logs for more details:"
    echo "   docker-compose logs"
    echo ""
    exit 0
else
    echo -e "${RED}❌ SYSTEM UNHEALTHY (${SUCCESS_RATE}%)${NC}"
    echo ""
    echo "Multiple services are not responding correctly."
    echo "Please check the logs:"
    echo "   docker-compose logs"
    echo ""
    exit 1
fi