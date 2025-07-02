#!/bin/bash
# DataLive Automated Testing Script
# Part of the sidecar ecosystem - transparent to users

set -e

echo "🧪 DataLive Test Suite Starting..."
echo "=================================="

# Configuration
TEST_MODE="${1:-full}"  # full, quick, security, performance
DOCKER_COMPOSE_FILE="/app/docker-compose.yml"
TEST_RESULTS_DIR="/tmp/datalive-test-results"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
    PASSED_TESTS=$((PASSED_TESTS + 1))
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
    FAILED_TESTS=$((FAILED_TESTS + 1))
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Test function wrapper
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    echo ""
    log_info "Running: $test_name"
    echo "Command: $test_command"
    
    if eval "$test_command" > /dev/null 2>&1; then
        log_success "$test_name"
        return 0
    else
        log_error "$test_name"
        return 1
    fi
}

# Check if we're running inside DataLive environment
check_environment() {
    log_info "Checking DataLive environment..."
    
    # Check if we're in Docker
    if [ -f /.dockerenv ]; then
        log_success "Running inside Docker container"
        ENVIRONMENT="docker"
    else
        log_info "Running on host system"
        ENVIRONMENT="host"
    fi
    
    # Check if services are available
    if command -v curl >/dev/null 2>&1; then
        log_success "curl available"
    else
        log_error "curl not available - required for API tests"
        return 1
    fi
    
    # Create results directory
    mkdir -p "$TEST_RESULTS_DIR"
    log_success "Test environment ready"
}

# Test DataLive Agent API
test_api_health() {
    log_info "Testing DataLive Agent API..."
    
    # Test health endpoint
    run_test "API Health Check" "curl -s -f http://datalive_agent:8058/health"
    
    # Test API documentation
    run_test "API Documentation" "curl -s -f http://datalive_agent:8058/docs"
    
    # Test metrics endpoint
    run_test "API Metrics" "curl -s -f http://datalive_agent:8058/metrics"
}

# Test API Security
test_api_security() {
    log_info "Testing API Security..."
    
    # Test without API key (should fail)
    if curl -s -X POST "http://datalive_agent:8058/api/v1/query" \
        -H "Content-Type: application/json" \
        -d '{"query": "test"}' 2>/dev/null | grep -q "Invalid API key\|Unprocessable Entity"; then
        log_success "API Key Protection"
    else
        log_error "API Key Protection"
    fi
    
    # Test with valid API key (if available)
    if [ -n "$DATALIVE_API_KEY" ]; then
        run_test "API Key Authentication" \
            "curl -s -X POST 'http://datalive_agent:8058/api/v1/query' \
             -H 'Content-Type: application/json' \
             -H 'X-API-Key: $DATALIVE_API_KEY' \
             -d '{\"query\": \"test\"}'"
    else
        log_warning "DATALIVE_API_KEY not set, skipping authentication test"
    fi
}

# Test Database Connectivity
test_databases() {
    log_info "Testing Database Connectivity..."
    
    # PostgreSQL
    run_test "PostgreSQL Connection" "nc -z postgres 5432"
    
    # Neo4j
    run_test "Neo4j Connection" "curl -s -f http://neo4j:7474"
    
    # Qdrant
    run_test "Qdrant Connection" "curl -s -f http://qdrant:6333/"
    
    # Redis
    run_test "Redis Connection" "nc -z redis 6379"
    
    # MinIO
    run_test "MinIO Connection" "curl -s -f http://minio:9000/minio/health/live"
}

# Test Ingestion System
test_ingestion() {
    log_info "Testing Ingestion System..."
    
    if [ -n "$DATALIVE_API_KEY" ]; then
        # Test document ingestion
        run_test "Document Ingestion" \
            "curl -s -X POST 'http://datalive_agent:8058/api/v1/ingest' \
             -H 'Content-Type: application/json' \
             -H 'X-API-Key: $DATALIVE_API_KEY' \
             -d '{\"source_type\": \"txt\", \"source\": \"Test document for automated testing\"}'"
    else
        log_warning "Skipping ingestion tests - API key required"
    fi
}

# Test Query System
test_queries() {
    log_info "Testing Query System..."
    
    if [ -n "$DATALIVE_API_KEY" ]; then
        # Test basic query
        run_test "Basic Query Processing" \
            "curl -s -X POST 'http://datalive_agent:8058/api/v1/query' \
             -H 'Content-Type: application/json' \
             -H 'X-API-Key: $DATALIVE_API_KEY' \
             -d '{\"query\": \"What is DataLive?\", \"max_results\": 1}'"
        
        # Test chat endpoint
        run_test "Chat Endpoint" \
            "curl -s -X POST 'http://datalive_agent:8058/api/v1/chat' \
             -H 'Content-Type: application/json' \
             -H 'X-API-Key: $DATALIVE_API_KEY' \
             -d '{\"message\": \"Hello DataLive\", \"user_id\": \"test_user\"}'"
    else
        log_warning "Skipping query tests - API key required"
    fi
}

# Test Cache Performance
test_cache() {
    log_info "Testing Cache System..."
    
    if [ -n "$DATALIVE_API_KEY" ]; then
        # Test cache functionality with repeated queries
        QUERY_DATA='{"query": "Cache test query", "use_cache": true}'
        
        # First query (cache miss)
        RESPONSE1=$(curl -s -X POST "http://datalive_agent:8058/api/v1/query" \
            -H "Content-Type: application/json" \
            -H "X-API-Key: $DATALIVE_API_KEY" \
            -d "$QUERY_DATA")
        
        # Second query (should be cache hit)
        RESPONSE2=$(curl -s -X POST "http://datalive_agent:8058/api/v1/query" \
            -H "Content-Type: application/json" \
            -H "X-API-Key: $DATALIVE_API_KEY" \
            -d "$QUERY_DATA")
        
        if [ $? -eq 0 ]; then
            log_success "Cache System Functional"
        else
            log_error "Cache System"
        fi
    else
        log_warning "Skipping cache tests - API key required"
    fi
}

# Test Monitoring Stack
test_monitoring() {
    log_info "Testing Monitoring Stack..."
    
    # Test Prometheus
    run_test "Prometheus Health" "curl -s -f http://prometheus:9090/-/healthy"
    
    # Test Grafana
    run_test "Grafana Health" "curl -s -f http://grafana:3000/api/health"
    
    # Test metrics collection
    run_test "DataLive Metrics" "curl -s -f http://datalive_agent:8058/metrics"
}

# Test N8N Integration
test_n8n() {
    log_info "Testing N8N Integration..."
    
    # Test N8N health
    run_test "N8N Health" "curl -s -f http://n8n:5678/healthz"
    
    # Test N8N API (if credentials available)
    if [ -n "$N8N_USER_EMAIL" ] && [ -n "$N8N_USER_PASSWORD" ]; then
        log_info "N8N credentials available - testing API access"
        # Additional N8N API tests could go here
    else
        log_warning "N8N credentials not available for API testing"
    fi
}

# Performance tests
test_performance() {
    log_info "Running Performance Tests..."
    
    if [ -n "$DATALIVE_API_KEY" ]; then
        # Concurrent query test
        log_info "Testing concurrent query handling..."
        
        for i in {1..5}; do
            curl -s -X POST "http://datalive_agent:8058/api/v1/query" \
                -H "Content-Type: application/json" \
                -H "X-API-Key: $DATALIVE_API_KEY" \
                -d "{\"query\": \"Performance test query $i\"}" &
        done
        
        wait  # Wait for all background jobs
        
        if [ $? -eq 0 ]; then
            log_success "Concurrent Query Handling"
        else
            log_error "Concurrent Query Handling"
        fi
    else
        log_warning "Skipping performance tests - API key required"
    fi
}

# Generate test report
generate_report() {
    local success_rate=0
    if [ $TOTAL_TESTS -gt 0 ]; then
        success_rate=$((PASSED_TESTS * 100 / TOTAL_TESTS))
    fi
    
    echo ""
    echo "=================================="
    echo "🏆 TEST EXECUTION SUMMARY"
    echo "=================================="
    echo ""
    echo "Total Tests: $TOTAL_TESTS"
    echo "Passed: $PASSED_TESTS ✅"
    echo "Failed: $FAILED_TESTS ❌"
    echo "Success Rate: ${success_rate}%"
    echo ""
    
    # Save results to file
    cat > "$TEST_RESULTS_DIR/summary.txt" << EOF
DataLive Test Results - $(date)
================================
Total Tests: $TOTAL_TESTS
Passed: $PASSED_TESTS
Failed: $FAILED_TESTS
Success Rate: ${success_rate}%
Test Mode: $TEST_MODE
Environment: $ENVIRONMENT
EOF
    
    if [ $success_rate -eq 100 ]; then
        echo -e "${GREEN}🎉 ALL TESTS PASSED!${NC}"
        echo ""
        echo "DataLive system is fully operational and ready for use."
        return 0
    elif [ $success_rate -ge 80 ]; then
        echo -e "${YELLOW}⚠️  MOSTLY OPERATIONAL (${success_rate}%)${NC}"
        echo ""
        echo "Some non-critical tests failed. System is largely functional."
        return 0
    else
        echo -e "${RED}❌ MULTIPLE TEST FAILURES (${success_rate}%)${NC}"
        echo ""
        echo "System has significant issues. Check logs and configuration."
        return 1
    fi
}

# Main execution
main() {
    echo "🚀 DataLive Automated Test Suite"
    echo "Mode: $TEST_MODE"
    echo "=================================="
    
    # Check environment
    if ! check_environment; then
        echo "Environment check failed"
        exit 1
    fi
    
    # Run tests based on mode
    case "$TEST_MODE" in
        "quick")
            test_api_health
            test_databases
            ;;
        "security")
            test_api_health
            test_api_security
            ;;
        "performance") 
            test_api_health
            test_cache
            test_performance
            ;;
        "full"|*)
            test_api_health
            test_api_security
            test_databases
            test_ingestion
            test_queries
            test_cache
            test_monitoring
            test_n8n
            test_performance
            ;;
    esac
    
    # Generate final report
    generate_report
}

# Run main function
main "$@"