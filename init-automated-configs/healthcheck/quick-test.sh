#!/bin/bash

# DataLive Quick Test Script
# Simple verification that the system is working

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}🚀 DataLive Quick Test${NC}"
echo "=========================="

# Test 1: API Health
echo -n "📡 API Health Check... "
if curl -s -f http://localhost:8058/status > /dev/null; then
    echo -e "${GREEN}✅ OK${NC}"
else
    echo -e "${RED}❌ FAILED${NC}"
    exit 1
fi

# Test 2: Ingest Document
echo -n "📝 Document Ingestion... "
response=$(curl -s -X POST http://localhost:8058/api/v1/ingest \
    -H 'Content-Type: application/json' \
    -d '{"source_type": "txt", "source": "DataLive quick test document"}')

if echo "$response" | grep -q '"status":"success"'; then
    echo -e "${GREEN}✅ OK${NC}"
else
    echo -e "${RED}❌ FAILED${NC}"
    exit 1
fi

# Test 3: Query System
echo -n "🔍 Query System... "
query_response=$(curl -s -X POST http://localhost:8058/api/v1/query \
    -H 'Content-Type: application/json' \
    -d '{"query": "test", "max_results": 1}')

if echo "$query_response" | grep -q '"answer"'; then
    echo -e "${GREEN}✅ OK${NC}"
else
    echo -e "${RED}❌ FAILED${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}🎉 All tests passed! DataLive is ready.${NC}"
echo ""
echo "📚 Try the full documentation at: http://localhost:8058/docs"
echo "💬 Chat interface: http://localhost:8058/api/v1/chat"
echo "📊 Metrics: http://localhost:8058/metrics"