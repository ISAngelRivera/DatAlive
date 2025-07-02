#!/bin/sh
# Qdrant Vector Database Initialization Script
# Runs as a sidecar container after Qdrant is healthy

set -e

echo "🔷 Qdrant Vector Database Initialization Starting..."

# Configuration
QDRANT_HOST="${QDRANT_HOST:-qdrant}"
QDRANT_PORT="${QDRANT_PORT:-6333}"
QDRANT_URL="http://${QDRANT_HOST}:${QDRANT_PORT}"

# Wait and retry connection to Qdrant
echo "📋 Connecting to Qdrant at ${QDRANT_URL}"

MAX_RETRIES=30
RETRY_DELAY=2
ATTEMPT=1

while [ $ATTEMPT -le $MAX_RETRIES ]; do
    echo "🔄 Connection attempt $ATTEMPT/$MAX_RETRIES..."
    
    if curl -s -f "${QDRANT_URL}/" > /dev/null 2>&1; then
        echo "✅ Qdrant connection successful"
        break
    fi
    
    if [ $ATTEMPT -eq $MAX_RETRIES ]; then
        echo "❌ Failed to connect to Qdrant after $MAX_RETRIES attempts"
        exit 1
    fi
    
    sleep $RETRY_DELAY
    ATTEMPT=$((ATTEMPT + 1))
done

# Check if collections already exist
echo "🔍 Checking existing collections..."

COLLECTIONS_RESPONSE=$(curl -s "${QDRANT_URL}/collections")
echo "📝 Collections response: $COLLECTIONS_RESPONSE"

if echo "$COLLECTIONS_RESPONSE" | grep -q '"documents"'; then
    echo "✅ Collections already exist, skipping initialization"
else
    echo "📊 Creating Qdrant collections..."
    
    # Create documents collection for RAG
    echo "   → Creating 'documents' collection..."
    curl -s -X PUT "${QDRANT_URL}/collections/documents" \
        -H "Content-Type: application/json" \
        -d '{
            "vectors": {
                "size": 384,
                "distance": "Cosine"
            },
            "optimizers_config": {
                "default_segment_number": 2
            },
            "replication_factor": 1
        }' > /dev/null
    
    if [ $? -eq 0 ]; then
        echo "     ✅ 'documents' collection created"
    else
        echo "     ❌ Failed to create 'documents' collection"
        exit 1
    fi
    
    # Create entities collection for knowledge graph embeddings
    echo "   → Creating 'entities' collection..."
    curl -s -X PUT "${QDRANT_URL}/collections/entities" \
        -H "Content-Type: application/json" \
        -d '{
            "vectors": {
                "size": 384,
                "distance": "Cosine"
            },
            "optimizers_config": {
                "default_segment_number": 2
            },
            "replication_factor": 1
        }' > /dev/null
    
    if [ $? -eq 0 ]; then
        echo "     ✅ 'entities' collection created"
    else
        echo "     ❌ Failed to create 'entities' collection"
        exit 1
    fi
    
    # Create cache collection for query cache embeddings
    echo "   → Creating 'cache' collection..."
    curl -s -X PUT "${QDRANT_URL}/collections/cache" \
        -H "Content-Type: application/json" \
        -d '{
            "vectors": {
                "size": 384,
                "distance": "Cosine"
            },
            "optimizers_config": {
                "default_segment_number": 1
            },
            "replication_factor": 1
        }' > /dev/null
    
    if [ $? -eq 0 ]; then
        echo "     ✅ 'cache' collection created"
    else
        echo "     ❌ Failed to create 'cache' collection"
        exit 1
    fi
fi

# Create indexes for better performance
echo "📑 Creating indexes..."

# Create payload indexes for documents collection
echo "   → Creating payload indexes for 'documents'..."
curl -s -X PUT "${QDRANT_URL}/collections/documents/index" \
    -H "Content-Type: application/json" \
    -d '{
        "field_name": "document_id",
        "field_schema": "keyword"
    }' > /dev/null

curl -s -X PUT "${QDRANT_URL}/collections/documents/index" \
    -H "Content-Type: application/json" \
    -d '{
        "field_name": "source_type",
        "field_schema": "keyword"
    }' > /dev/null

# Verify collections
echo "🔍 Verifying Qdrant setup..."

# Get collection info
for collection in documents entities cache; do
    info=$(curl -s "${QDRANT_URL}/collections/${collection}")
    if echo "$info" | grep -q "vectors_count"; then
        vectors_count=$(echo "$info" | grep -o '"vectors_count":[0-9]*' | cut -d: -f2)
        echo "   ✅ Collection '${collection}': ready (${vectors_count} vectors)"
    else
        echo "   ❌ Collection '${collection}': not found"
    fi
done

# Add sample data if requested
if [ "${CREATE_SAMPLE_DATA:-false}" = "true" ]; then
    echo "📊 Adding sample vectors..."
    
    # Add a sample document vector
    curl -s -X PUT "${QDRANT_URL}/collections/documents/points" \
        -H "Content-Type: application/json" \
        -d '{
            "points": [
                {
                    "id": "00000000-0000-0000-0000-000000000001",
                    "vector": [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 0.1, 0.2, 0.3, 0.4],
                    "payload": {
                        "document_id": "sample-001",
                        "source_type": "sample",
                        "content": "DataLive is an advanced RAG system",
                        "title": "Sample Document"
                    }
                }
            ]
        }' > /dev/null
    
    echo "   ✅ Sample data added"
fi

echo "✅ Qdrant initialization completed successfully"
echo "🔷 DataLive Vector Database is ready!"