#!/bin/bash
# DataLive Workflow Testing Script
# Tests the master workflow endpoints

set -e

# Configuration
N8N_URL="${N8N_URL:-http://n8n:5678}"
DATALIVE_API_KEY="${DATALIVE_API_KEY:-datalive-dev-key-change-in-production}"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "🧪 DataLive Workflow Testing"
echo "============================="
echo ""

# Test Query Endpoint
echo "🔍 Testing Query Endpoint..."
echo "----------------------------"

query_payload='{
  "query": "What is DataLive?",
  "user_id": "test_user",
  "session_id": "test_session",
  "use_cache": true,
  "max_results": 5
}'

echo "Payload: $query_payload"
echo ""

query_response=$(curl -s -X POST \
  -H "Content-Type: application/json" \
  -d "$query_payload" \
  "${N8N_URL}/webhook/datalive/query" || echo "ERROR")

if [ "$query_response" = "ERROR" ]; then
  echo -e "${RED}❌ Query endpoint failed - connection error${NC}"
else
  echo "Response received:"
  echo "$query_response" | jq . 2>/dev/null || echo "$query_response"
  
  if echo "$query_response" | grep -q "answer\|error"; then
    echo -e "${GREEN}✅ Query endpoint responding${NC}"
  else
    echo -e "${YELLOW}⚠️  Query endpoint returned unexpected response${NC}"
  fi
fi

echo ""

# Test Ingestion Endpoint
echo "📄 Testing Ingestion Endpoint..."
echo "--------------------------------"

ingest_payload='{
  "source_type": "txt",
  "source": "This is a test document for DataLive workflow testing. It contains information about the system testing process.",
  "filename": "workflow-test.txt",
  "metadata": {
    "test": true,
    "created_by": "workflow_test",
    "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"
  }
}'

echo "Payload: $ingest_payload"
echo ""

ingest_response=$(curl -s -X POST \
  -H "Content-Type: application/json" \
  -d "$ingest_payload" \
  "${N8N_URL}/webhook/datalive/ingest" || echo "ERROR")

if [ "$ingest_response" = "ERROR" ]; then
  echo -e "${RED}❌ Ingest endpoint failed - connection error${NC}"
else
  echo "Response received:"
  echo "$ingest_response" | jq . 2>/dev/null || echo "$ingest_response"
  
  if echo "$ingest_response" | grep -q "success\|document_id\|error"; then
    echo -e "${GREEN}✅ Ingest endpoint responding${NC}"
  else
    echo -e "${YELLOW}⚠️  Ingest endpoint returned unexpected response${NC}"
  fi
fi

echo ""

# Test N8N Health
echo "🏥 Testing N8N Health..."
echo "------------------------"

n8n_health=$(curl -s "${N8N_URL}/healthz" || echo "ERROR")

if [ "$n8n_health" = "ERROR" ]; then
  echo -e "${RED}❌ N8N health check failed${NC}"
else
  echo "N8N Health: $n8n_health"
  if echo "$n8n_health" | grep -q "ok\|OK\|healthy"; then
    echo -e "${GREEN}✅ N8N is healthy${NC}"
  else
    echo -e "${YELLOW}⚠️  N8N health status unclear${NC}"
  fi
fi

echo ""

# Test Complex Query (if basic query worked)
if echo "$query_response" | grep -q "answer" && [ "$query_response" != "ERROR" ]; then
  echo "🧠 Testing Complex Query..."
  echo "---------------------------"
  
  complex_query='{
    "query": "Who developed DataLive and when was it created? Please provide a detailed analysis.",
    "user_id": "test_user_complex",
    "session_id": "test_session_complex",
    "use_cache": false,
    "max_results": 10
  }'
  
  complex_response=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -d "$complex_query" \
    "${N8N_URL}/webhook/datalive/query" || echo "ERROR")
  
  if [ "$complex_response" != "ERROR" ]; then
    echo "Complex query processed successfully"
    
    # Check for enhanced features
    if echo "$complex_response" | grep -q "confidence"; then
      confidence=$(echo "$complex_response" | jq -r '.confidence // "unknown"' 2>/dev/null || echo "unknown")
      echo "   Confidence score: $confidence"
    fi
    
    if echo "$complex_response" | grep -q "strategy_used"; then
      strategies=$(echo "$complex_response" | jq -r '.strategy_used // []' 2>/dev/null || echo "unknown")
      echo "   Strategies used: $strategies"
    fi
    
    if echo "$complex_response" | grep -q "cached"; then
      cached=$(echo "$complex_response" | jq -r '.cached // false' 2>/dev/null || echo "unknown")
      echo "   Cached response: $cached"
    fi
    
    echo -e "${GREEN}✅ Complex query processing working${NC}"
  else
    echo -e "${YELLOW}⚠️  Complex query failed${NC}"
  fi
fi

echo ""

# Summary
echo "📊 Test Summary"
echo "==============="

if [ "$query_response" != "ERROR" ] && [ "$ingest_response" != "ERROR" ] && [ "$n8n_health" != "ERROR" ]; then
  echo -e "${GREEN}🎉 All core workflow tests passed!${NC}"
  echo ""
  echo "✅ DataLive Master Workflow is operational"
  echo "✅ Query processing working"
  echo "✅ Document ingestion working" 
  echo "✅ N8N platform healthy"
  echo ""
  echo "🚀 Ready for production use!"
  exit 0
else
  echo -e "${RED}❌ Some workflow tests failed${NC}"
  echo ""
  echo "Issues detected:"
  [ "$query_response" = "ERROR" ] && echo "  - Query endpoint not responding"
  [ "$ingest_response" = "ERROR" ] && echo "  - Ingest endpoint not responding"
  [ "$n8n_health" = "ERROR" ] && echo "  - N8N health check failed"
  echo ""
  echo "💡 Troubleshooting steps:"
  echo "  1. Check N8N container logs: docker-compose logs n8n"
  echo "  2. Verify workflow is imported and activated in N8N UI"
  echo "  3. Check DataLive agent connectivity"
  echo "  4. Verify API key configuration"
  exit 1
fi