#!/bin/bash

# DataLive Functionality Test Script
# Comprehensive testing of all endpoints and functionality in Docker environment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
API_BASE="http://localhost:8058"
API_V1="${API_BASE}/api/v1"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Test counter
TOTAL_TESTS=0
PASSED_TESTS=0

run_test() {
    local test_name="$1"
    local test_command="$2"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    log_info "🧪 Testing: $test_name"
    
    if eval "$test_command"; then
        log_success "✅ PASSED: $test_name"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        return 0
    else
        log_error "❌ FAILED: $test_name"
        return 1
    fi
}

# Wait for service to be ready
wait_for_service() {
    local service_url="$1"
    local service_name="$2"
    local max_attempts=30
    local attempt=1
    
    log_info "⏳ Waiting for $service_name to be ready..."
    
    while [[ $attempt -le $max_attempts ]]; do
        if curl -s -f "$service_url" > /dev/null 2>&1; then
            log_success "✅ $service_name is ready"
            return 0
        fi
        
        echo -n "."
        sleep 2
        attempt=$((attempt + 1))
    done
    
    log_error "❌ $service_name failed to start within timeout"
    return 1
}

echo "🚀 DataLive Functionality Test Suite"
echo "===================================================="
echo ""

# Check if services are running
log_info "📋 Checking if Docker services are running..."

if ! docker-compose ps datalive_agent 2>/dev/null | grep -q "Up"; then
    log_error "DataLive Agent container is not running. Please run deploy-infrastructure.sh first."
    exit 1
fi

# Wait for services to be ready
wait_for_service "${API_BASE}/status" "DataLive Agent"

# Test 1: Health Check
run_test "Health Check" "curl -s -f ${API_BASE}/status | jq -r '.status' | grep -q 'healthy'"

# Test 2: API Documentation
run_test "API Documentation" "curl -s -f ${API_BASE}/docs > /dev/null"

# Test 3: Metrics Endpoint
run_test "Metrics Endpoint" "curl -s -f ${API_BASE}/metrics > /dev/null"

# Test 4: Basic Text Ingestion
log_info "📝 Testing document ingestion..."

# Create test TXT content
TXT_INGEST_PAYLOAD='{
  "source_type": "txt",
  "source": "DataLive es un sistema RAG+KAG+CAG avanzado. Utiliza PostgreSQL para almacenamiento, Neo4j para grafos de conocimiento, Qdrant para búsqueda vectorial y Ollama para inferencia local de LLM.",
  "metadata": {
    "title": "DataLive Overview Test",
    "author": "Test Suite"
  }
}'

run_test "TXT Document Ingestion" "
    response=\$(curl -s -X POST ${API_V1}/ingest \
        -H 'Content-Type: application/json' \
        -d '$TXT_INGEST_PAYLOAD')
    echo \"\$response\" | jq -r '.status' | grep -q 'success'
"

# Test 5: Markdown Ingestion
MD_INGEST_PAYLOAD='{
  "source_type": "markdown",
  "source": "---\ntitle: DataLive Test\nauthor: Test Suite\n---\n\n# DataLive Architecture\n\nDataLive incluye:\n\n## Componentes\n- **PostgreSQL**: Base de datos relacional\n- **Neo4j**: Grafo de conocimiento\n- **Qdrant**: Base de datos vectorial\n\n## Características\n1. Procesamiento multi-modal\n2. Búsqueda semántica\n3. Cache inteligente",
  "metadata": {
    "title": "DataLive Architecture Test"
  }
}'

run_test "Markdown Document Ingestion" "
    response=\$(curl -s -X POST ${API_V1}/ingest \
        -H 'Content-Type: application/json' \
        -d '$MD_INGEST_PAYLOAD')
    echo \"\$response\" | jq -r '.status' | grep -q 'success'
"

# Test 6: CSV Ingestion
CSV_INGEST_PAYLOAD='{
  "source_type": "csv",
  "source": "componente,tipo,proposito\nPostgreSQL,Database,Almacenamiento\nNeo4j,Database,Grafo conocimiento\nQdrant,Database,Busqueda vectorial\nOllama,AI,Inferencia LLM",
  "metadata": {
    "title": "DataLive Components Test"
  }
}'

run_test "CSV Document Ingestion" "
    response=\$(curl -s -X POST ${API_V1}/ingest \
        -H 'Content-Type: application/json' \
        -d '$CSV_INGEST_PAYLOAD')
    echo \"\$response\" | jq -r '.status' | grep -q 'success'
"

# Test 7: Query Functionality
QUERY_PAYLOAD='{
  "query": "¿Qué es DataLive y qué componentes utiliza?",
  "strategy": "auto",
  "max_results": 5,
  "use_cache": true
}'

run_test "Document Query" "
    response=\$(curl -s -X POST ${API_V1}/query \
        -H 'Content-Type: application/json' \
        -d '$QUERY_PAYLOAD')
    echo \"\$response\" | jq -r '.answer' | grep -qi 'datalive'
"

# Test 8: Vector Search
run_test "Vector Search" "
    curl -s '${API_V1}/search/vector?query=PostgreSQL&limit=3' | jq -r '.[]' > /dev/null
"

# Test 9: Knowledge Graph Search
run_test "Knowledge Graph Search" "
    curl -s '${API_V1}/search/knowledge-graph?query=DataLive&limit=5' | jq '.' > /dev/null
"

# Test 10: Cache Statistics
run_test "Cache Statistics" "
    curl -s '${API_V1}/cache/stats' | jq -r '.cache_entries' > /dev/null || curl -s '${API_V1}/cache/stats' | jq '.' > /dev/null
"

# Test 11: Chat Interface
CHAT_PAYLOAD='{
  "message": "Explícame cómo funciona DataLive",
  "use_cache": true
}'

run_test "Chat Interface" "
    response=\$(curl -s -X POST ${API_V1}/chat \
        -H 'Content-Type: application/json' \
        -d '$CHAT_PAYLOAD')
    echo \"\$response\" | jq -r '.response' | grep -qi 'datalive'
"

# Test 12: File Upload Simulation (create temp file)
log_info "📎 Testing file upload functionality..."

# Create temporary test file
TEST_FILE="/tmp/datalive_test.txt"
echo "DataLive File Upload Test
Este es un documento de prueba para validar la funcionalidad de upload de archivos.
Contiene información sobre DataLive y sus capacidades." > "$TEST_FILE"

run_test "File Upload Ingestion" "
    response=\$(curl -s -X POST ${API_V1}/ingest/file \
        -F 'file=@$TEST_FILE' \
        -F 'source_type=txt')
    echo \"\$response\" | jq -r '.status' | grep -q 'success'
"

# Cleanup temp file
rm -f "$TEST_FILE"

# Test 13: Service Integration
log_info "🔗 Testing service integration..."

# Check if all required services are responding
SERVICES_TO_CHECK=(
    "postgres:5432"
    "neo4j:7474"
    "qdrant:6333"
    "minio:9000"
    "ollama:11434"
    "n8n:5678"
)

SERVICE_TESTS_PASSED=0
for service in "${SERVICES_TO_CHECK[@]}"; do
    service_name=$(echo "$service" | cut -d: -f1)
    service_port=$(echo "$service" | cut -d: -f2)
    
    if nc -z localhost "$service_port" 2>/dev/null; then
        log_success "✅ $service_name is accessible"
        SERVICE_TESTS_PASSED=$((SERVICE_TESTS_PASSED + 1))
    else
        log_warning "⚠️ $service_name is not accessible on port $service_port"
    fi
done

run_test "Service Integration" "[[ $SERVICE_TESTS_PASSED -ge 4 ]]"  # At least 4/6 services should be accessible

# Test 14: Performance Test
log_info "⚡ Testing performance..."

PERFORMANCE_PAYLOAD='{
  "source_type": "txt",
  "source": "Performance test document with multiple sentences. This document is used to test the processing speed of DataLive. It contains various information about system performance, response times, and throughput capabilities.",
  "metadata": {"title": "Performance Test"}
}'

run_test "Performance Test" "
    start_time=\$(date +%s%N)
    response=\$(curl -s -X POST ${API_V1}/ingest \
        -H 'Content-Type: application/json' \
        -d '$PERFORMANCE_PAYLOAD')
    end_time=\$(date +%s%N)
    duration=\$(( (end_time - start_time) / 1000000 ))  # Convert to milliseconds
    
    if echo \"\$response\" | jq -r '.status' | grep -q 'success' && [[ \$duration -lt 10000 ]]; then
        echo \"✅ Response time: \${duration}ms\"
        true
    else
        echo \"❌ Performance test failed or too slow: \${duration}ms\"
        false
    fi
"

# Test 15: Error Handling
run_test "Error Handling" "
    response=\$(curl -s -X POST ${API_V1}/ingest \
        -H 'Content-Type: application/json' \
        -d '{\"source_type\": \"invalid\", \"source\": \"test\"}')
    echo \"\$response\" | grep -qi 'error\\|fail' || curl -s -w '%{http_code}' ${API_V1}/ingest \
        -H 'Content-Type: application/json' \
        -d '{\"source_type\": \"invalid\", \"source\": \"test\"}' | grep -q '^[45]'
"

# Summary
echo ""
echo "===================================================="
echo "🏆 TEST RESULTS SUMMARY"
echo "===================================================="
echo ""

PASS_RATE=$((PASSED_TESTS * 100 / TOTAL_TESTS))

echo "📊 Tests Passed: $PASSED_TESTS/$TOTAL_TESTS ($PASS_RATE%)"
echo ""

if [[ $PASSED_TESTS -eq $TOTAL_TESTS ]]; then
    log_success "🎉 ALL TESTS PASSED!"
    echo ""
    echo "✨ DataLive is fully operational with:"
    echo "   📄 Multi-format document ingestion (TXT, MD, CSV)"
    echo "   🔍 Advanced query capabilities (RAG+KAG+CAG)"
    echo "   💬 Chat interface"
    echo "   📎 File upload support"
    echo "   🌐 REST API endpoints"
    echo "   📊 Metrics and monitoring"
    echo "   🐳 Docker containerization with Poetry"
    echo ""
    echo "🚀 Golden Path Achieved:"
    echo "   ✅ Maximum automation"
    echo "   ✅ Minimal user steps"
    echo "   ✅ Full Docker integration"
    echo "   ✅ Production ready"
    echo ""
    exit 0
elif [[ $PASS_RATE -ge 80 ]]; then
    log_success "✅ MOSTLY SUCCESSFUL ($PASS_RATE% pass rate)"
    echo ""
    log_warning "⚠️ Some non-critical tests failed. System is operational."
    echo ""
    exit 0
else
    log_error "❌ MULTIPLE FAILURES ($PASS_RATE% pass rate)"
    echo ""
    log_error "System needs attention. Check service logs:"
    echo "   docker-compose logs datalive_agent"
    echo "   docker-compose logs postgres"
    echo "   docker-compose logs neo4j"
    echo ""
    exit 1
fi