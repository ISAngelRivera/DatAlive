#!/bin/sh
# N8N Setup Script - Simplified and modular
# Runs as a sidecar container after N8N is healthy

set -e

echo "🔄 N8N Setup Starting..."

# Configuration
N8N_URL="${N8N_URL:-http://n8n:5678}"
REST_URL="${N8N_URL}/rest"
COOKIE_FILE="/tmp/n8n_cookie.txt"

# Wait for N8N to be fully ready
echo "⏳ Waiting for N8N to be ready..."
sleep 10

# Check if N8N is accessible
if ! curl -s -f "${N8N_URL}/healthz" > /dev/null; then
    echo "❌ N8N is not accessible at ${N8N_URL}"
    exit 1
fi

echo "✅ N8N is ready"

# Check if owner is already registered
echo "🔍 Checking N8N setup status..."
response=$(curl -s -o /dev/null -w "%{http_code}" "${REST_URL}/settings")

echo "   Status response: $response"

if [ "$response" -eq 401 ]; then
    echo "✅ N8N is already configured (authentication required)"
    echo "   Please use the UI to complete any additional setup"
    exit 0
elif [ "$response" -eq 200 ]; then
    echo "ℹ️  N8N settings accessible - checking if setup needed"
else
    echo "⚠️  Unexpected response: $response"
fi

# Register owner if needed
echo "👤 Setting up N8N owner..."
owner_data=$(cat <<EOF
{
    "email": "${N8N_USER_EMAIL}",
    "firstName": "${N8N_USER_FIRSTNAME}",
    "lastName": "${N8N_USER_LASTNAME}",
    "password": "${N8N_USER_PASSWORD}"
}
EOF
)

# Try to register owner
echo "   Attempting owner registration..."
owner_response=$(curl -s -X POST -H "Content-Type: application/json" -d "$owner_data" "${REST_URL}/owner/setup")
echo "   Owner response: $owner_response"

if echo "$owner_response" | grep -q "email"; then
    echo "✅ Owner registered successfully"
elif echo "$owner_response" | grep -q "User management setup"; then
    echo "ℹ️  Owner registration not needed - already completed"
else
    echo "⚠️  Owner registration failed or unexpected response"
fi

# Login to get session cookie
echo "🔐 Authenticating with N8N..."
rm -f "$COOKIE_FILE"

login_data=$(cat <<EOF
{
    "emailOrLdapLoginId": "${N8N_USER_EMAIL}",
    "password": "${N8N_USER_PASSWORD}"
}
EOF
)

login_response=$(curl -s -c "$COOKIE_FILE" -X POST -H "Content-Type: application/json" -d "$login_data" "${REST_URL}/login")
echo "   Login response: $(echo "$login_response" | head -c 100)..."

if [ -f "$COOKIE_FILE" ] && grep -q "n8n-auth" "$COOKIE_FILE" 2>/dev/null; then
    echo "✅ Authentication successful"
elif echo "$login_response" | grep -q "\"loggedIn\":true"; then
    echo "✅ Authentication successful (alternate method)"
else
    echo "⚠️  Authentication failed - N8N may need manual setup"
    echo "   Please visit: ${N8N_URL} and complete setup manually"
    echo "   Use credentials from .env file"
    exit 0
fi

# Register license if provided
if [ -n "${N8N_LICENSE_KEY}" ]; then
    echo "📄 Registering N8N license..."
    
    license_data=$(cat <<EOF
{
    "activationKey": "${N8N_LICENSE_KEY}"
}
EOF
)
    
    license_response=$(curl -s -b "$COOKIE_FILE" -X POST \
        -H "Content-Type: application/json" \
        -d "$license_data" \
        "${REST_URL}/license/activate")
    
    if echo "$license_response" | grep -q '"validLicense":true'; then
        echo "   ✅ License activated successfully"
    else
        echo "   ⚠️  License activation failed or already active"
        echo "   Response: $(echo "$license_response" | head -c 100)..."
    fi
else
    echo "ℹ️  No license key provided - using community edition"
fi

# Install community nodes first (before creating credentials)
echo "📦 Installing community nodes..."

# Install Neo4j community node
echo "   → Installing @kurea/n8n-nodes-neo4j..."
install_response=$(curl -s -b "$COOKIE_FILE" -X POST \
    -H "Content-Type: application/json" \
    -d '{"name": "@kurea/n8n-nodes-neo4j"}' \
    "${REST_URL}/community-packages")

if echo "$install_response" | grep -q '"installedVersion"'; then
    installed_version=$(echo "$install_response" | grep -o '"installedVersion":"[^"]*"' | cut -d'"' -f4)
    echo "     ✅ Installed version: $installed_version"
elif echo "$install_response" | grep -q 'Package is already installed'; then
    echo "     ✅ Already installed"
else
    echo "     ⚠️  Installation failed or pending"
    echo "     Response: $(echo "$install_response" | head -c 200)..."
fi

echo "✅ Community nodes installation completed"
echo "⏳ Waiting 10 seconds for nodes to be available..."
sleep 10

# Clean existing DataLive credentials
echo "🧹 Cleaning existing DataLive credentials..."

existing_creds=$(curl -s -b "$COOKIE_FILE" "${REST_URL}/credentials")
if echo "$existing_creds" | grep -q "DataLive"; then
    echo "$existing_creds" | grep -o '"id":"[^"]*","name":"DataLive[^"]*"' | while read -r line; do
        cred_id=$(echo "$line" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)
        cred_name=$(echo "$line" | grep -o '"name":"[^"]*"' | cut -d'"' -f4)
        echo "   🗑️  Deleting: $cred_name (ID: $cred_id)"
        curl -s -b "$COOKIE_FILE" -X DELETE "${REST_URL}/credentials/$cred_id" > /dev/null
    done
else
    echo "   ℹ️  No existing DataLive credentials found"
fi

# Create essential credentials (after community nodes are installed)
echo "🔑 Creating DataLive credentials..."

# Helper function to create credential
create_credential() {
    local name="$1"
    local type="$2"
    local data="$3"
    
    echo "   → Creating: $name"
    
    response=$(curl -s -b "$COOKIE_FILE" -X POST \
        -H "Content-Type: application/json" \
        -d "{\"name\":\"$name\",\"type\":\"$type\",\"data\":$data}" \
        "${REST_URL}/credentials")
    
    if echo "$response" | grep -q "\"id\""; then
        cred_id=$(echo "$response" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)
        echo "     ✅ Created (ID: $cred_id)"
    else
        echo "     ❌ Failed"
        echo "     Response: $(echo "$response" | head -c 200)..."
    fi
}

# 1. PostgreSQL (exact name for workflows)
create_credential "PostgreSQL" "postgres" '{
    "host": "postgres",
    "port": 5432,
    "database": "'${POSTGRES_DB:-datalive_db}'",
    "user": "'${POSTGRES_USER:-datalive_user}'",
    "password": "'${POSTGRES_PASSWORD}'",
    "allowUnauthorizedCerts": false,
    "ssl": "disable"
}'

# 2. Neo4j (exact name for workflows) 
create_credential "Neo4j" "neo4j" '{
    "connectionUri": "bolt://neo4j:7687",
    "username": "'${NEO4J_AUTH%/*}'",
    "password": "'${NEO4J_AUTH#*/}'",
    "database": "neo4j"
}'

# 3. Qdrant API (exact name for workflows)
create_credential "Qdrant API" "qdrantApi" '{
    "qdrantUrl": "http://qdrant:6333",
    "apiKey": "'${QDRANT_API_KEY:-}'"
}'

# 4. Ollama API (exact name for workflows)
create_credential "Ollama API" "ollamaApi" '{
    "baseUrl": "http://ollama:11434"
}'

# 5. MinIO S3 (for file storage)
create_credential "DataLive MinIO S3" "aws" '{
    "region": "us-east-1",
    "accessKeyId": "'${MINIO_ROOT_USER}'",
    "secretAccessKey": "'${MINIO_ROOT_PASSWORD}'",
    "customEndpoints": true,
    "s3Endpoint": "http://minio:9000",
    "forcePathStyle": true
}'

# 6. DataLive Agent API (HTTP Request with Header Auth - SECURE)
create_credential "DataLive Agent API" "httpRequestAuth" '{
    "authentication": "headerAuth",
    "headerAuth": {
        "name": "X-API-Key",
        "value": "'${DATALIVE_API_KEY:-datalive-dev-key-change-in-production}'"
    }
}'

# 7. Google Drive (OAuth2) - if configured
if [ -n "${GOOGLE_CLIENT_ID}" ] && [ -n "${GOOGLE_CLIENT_SECRET}" ]; then
    create_credential "DataLive Google Drive" "googleOAuth2Api" '{
        "clientId": "'${GOOGLE_CLIENT_ID}'",
        "clientSecret": "'${GOOGLE_CLIENT_SECRET}'",
        "scope": "https://www.googleapis.com/auth/drive"
    }'
    echo "     ⚠️  Google Drive credential created but requires manual OAuth authorization"
else
    echo "   ℹ️  Google Drive: OAuth credentials not configured (optional)"
fi

# 8. OpenAI API (if configured for comparison/testing)
if [ -n "${OPENAI_API_KEY}" ]; then
    create_credential "OpenAI API" "openAiApi" '{
        "apiKey": "'${OPENAI_API_KEY}'"
    }'
else
    echo "   ℹ️  OpenAI API: Not configured (optional)"
fi

# Import workflows if directory exists
if [ -d "/workflows" ]; then
    echo "📋 Importing DataLive 2025 workflows..."
    
    workflow_count=0
    
    # Import Enhanced Query Workflow 2025
    query_workflow="/workflows/datalive-enhanced-query-workflow.json"
    if [ -f "$query_workflow" ]; then
        echo "   🎯 Importing DataLive Enhanced Query Workflow 2025..."
        
        workflow_response=$(curl -s -b "$COOKIE_FILE" -X POST \
            -H "Content-Type: application/json" \
            -d "@$query_workflow" \
            "${REST_URL}/workflows")
        
        if echo "$workflow_response" | grep -q "\"id\""; then
            workflow_id=$(echo "$workflow_response" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)
            echo "     ✅ Query Workflow imported (ID: $workflow_id)"
            workflow_count=$((workflow_count + 1))
            
            # Activate the query workflow
            if curl -s -b "$COOKIE_FILE" -X PATCH \
                -H "Content-Type: application/json" \
                -d '{"active": true}' \
                "${REST_URL}/workflows/${workflow_id}" > /dev/null; then
                echo "     🟢 Query Workflow activated"
                echo "     📡 Query endpoint: POST /webhook/datalive/query/v2"
            else
                echo "     ⚠️  Failed to activate query workflow"
            fi
        else
            echo "     ❌ Failed to import query workflow"
            echo "     Response: $(echo "$workflow_response" | head -c 200)..."
        fi
    else
        echo "     ⚠️  Query workflow not found: $query_workflow"
    fi
    
    # Import Enhanced Ingestion Workflow 2025
    ingestion_workflow="/workflows/datalive-enhanced-ingestion-workflow.json"
    if [ -f "$ingestion_workflow" ]; then
        echo "   📥 Importing DataLive Enhanced Ingestion Workflow 2025..."
        
        workflow_response=$(curl -s -b "$COOKIE_FILE" -X POST \
            -H "Content-Type: application/json" \
            -d "@$ingestion_workflow" \
            "${REST_URL}/workflows")
        
        if echo "$workflow_response" | grep -q "\"id\""; then
            workflow_id=$(echo "$workflow_response" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)
            echo "     ✅ Ingestion Workflow imported (ID: $workflow_id)"
            workflow_count=$((workflow_count + 1))
            
            # Activate the ingestion workflow
            if curl -s -b "$COOKIE_FILE" -X PATCH \
                -H "Content-Type: application/json" \
                -d '{"active": true}' \
                "${REST_URL}/workflows/${workflow_id}" > /dev/null; then
                echo "     🟢 Ingestion Workflow activated"
                echo "     📡 Ingestion endpoint: POST /webhook/datalive/ingest/v2"
            else
                echo "     ⚠️  Failed to activate ingestion workflow"
            fi
        else
            echo "     ❌ Failed to import ingestion workflow"
            echo "     Response: $(echo "$workflow_response" | head -c 200)..."
        fi
    else
        echo "     ⚠️  Ingestion workflow not found: $ingestion_workflow"
    fi
    
    # Import test workflows (if they exist)
    if [ -d "/workflows/test" ]; then
        echo "   🧪 Importing test workflows..."
        for workflow_file in /workflows/test/*.json; do
            if [ -f "$workflow_file" ]; then
                workflow_name=$(basename "$workflow_file" .json)
                echo "   → Importing test: $workflow_name"
                
                workflow_response=$(curl -s -b "$COOKIE_FILE" -X POST \
                    -H "Content-Type: application/json" \
                    -d "@$workflow_file" \
                    "${REST_URL}/workflows")
                
                if echo "$workflow_response" | grep -q "\"id\""; then
                    workflow_id=$(echo "$workflow_response" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)
                    echo "     ✅ Test imported (ID: $workflow_id)"
                    workflow_count=$((workflow_count + 1))
                    
                    # Note: Test workflows are imported but not auto-activated
                    echo "     ℹ️  Test workflow ready (manual activation required)"
                else
                    echo "     ⚠️  Failed to import test workflow: $workflow_name"
                fi
            fi
        done
    fi
    
    echo "✅ Imported $workflow_count workflows"
    
    if [ $workflow_count -gt 0 ]; then
        echo ""
        echo "🎉 DataLive N8N 2025 Setup Complete!"
        echo ""
        echo "📡 Available Endpoints (2025 Enhanced):"
        echo "   • Query API v2: ${N8N_URL}/webhook/datalive/query/v2"
        echo "   • Ingest API v2: ${N8N_URL}/webhook/datalive/ingest/v2"
        echo ""
        echo "🔧 Management:"
        echo "   • N8N UI: ${N8N_URL}"
        echo "   • Credentials: Auto-configured (2025 optimized)"
        echo "   • Workflows: Auto-activated (Enhanced versions)"
        echo ""
        echo "🚀 Features 2025:"
        echo "   • Cross-Encoder Reranking (Qdrant 1.14)"
        echo "   • Parallel Processing"
        echo "   • Phi-4/Phi-3 Mini Models"
        echo "   • Advanced Entity Extraction"
        echo "   • Intelligent Deduplication"
    fi
else
    echo "ℹ️  No workflows directory found"
fi

# Cleanup
rm -f "$COOKIE_FILE"

echo "✅ N8N setup completed!"
echo "🔄 Access N8N at: ${N8N_URL}"
echo "   User: ${N8N_USER_EMAIL}"
echo "   Password: Configured in .env"
echo ""
echo "📦 NEXT STEP: Install Neo4j Community Node"
echo "   1. Go to Settings > Community Nodes"
echo "   2. Install: @Kurea/n8n-nodes-neo4j"
echo "   3. Neo4j credential will become available"
echo "   4. DataLive Agent API is secured with X-API-Key header"