#!/bin/bash
# init-qdrant-collections.sh - Crea colecciones en Qdrant para RAG
# Lee configuración desde .env

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Load environment variables
if [ -f "$PROJECT_ROOT/.env" ]; then
    set -a
    source "$PROJECT_ROOT/.env"
    set +a
else
    echo "ERROR: .env file not found at $PROJECT_ROOT/.env"
    exit 1
fi

# Configuration from .env
QDRANT_URL="${QDRANT_URL:-http://localhost:6333}"
QDRANT_API_KEY="${QDRANT_API_KEY:-}"
COLLECTIONS="${QDRANT_COLLECTIONS:-documents,images,multimodal}"
DEFAULT_DIMENSION="${QDRANT_DEFAULT_DIMENSION:-768}"
DISTANCE_METRIC="${QDRANT_DISTANCE_METRIC:-Cosine}"
REPLICATION_FACTOR="${QDRANT_REPLICATION_FACTOR:-1}"
LOG_FILE="${PROJECT_ROOT}/logs/qdrant-init.log"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging
log() {
    local level=$1
    shift
    echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] [${level}] $*" | tee -a "${LOG_FILE}"
}

# Check Qdrant health
check_qdrant() {
    log "INFO" "Checking Qdrant service at ${QDRANT_URL}..."
    
    local max_attempts=30
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if curl -sf "${QDRANT_URL}/health" > /dev/null 2>&1; then
            log "INFO" "${GREEN}Qdrant is ready!${NC}"
            return 0
        fi
        
        echo -n "."
        sleep 2
        ((attempt++))
    done
    
    log "ERROR" "${RED}Qdrant service not responding${NC}"
    return 1
}

# Get headers for API requests
get_headers() {
    if [ -n "$QDRANT_API_KEY" ]; then
        echo "-H 'api-key: $QDRANT_API_KEY'"
    else
        echo ""
    fi
}

# Check if collection exists
collection_exists() {
    local collection=$1
    local headers=$(get_headers)
    
    local response=$(curl -sf $headers "${QDRANT_URL}/collections/${collection}" 2>/dev/null || echo "")
    
    if [ -n "$response" ] && echo "$response" | jq -e '.status == "ok"' > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Create collection
create_collection() {
    local collection=$1
    local dimension=${2:-$DEFAULT_DIMENSION}
    local on_disk=${3:-false}
    
    log "INFO" "Creating collection: ${collection} (dimension: ${dimension})"
    
    # Collection configuration based on type
    local config=""
    case "$collection" in
        "documents")
            config=$(cat <<EOF
{
    "vectors": {
        "size": ${dimension},
        "distance": "${DISTANCE_METRIC}",
        "on_disk": ${on_disk}
    },
    "shard_number": 2,
    "replication_factor": ${REPLICATION_FACTOR},
    "write_consistency_factor": 1,
    "optimizers_config": {
        "default_segment_number": 5,
        "indexing_threshold": 20000,
        "memmap_threshold": 50000
    },
    "wal_config": {
        "wal_capacity_mb": 32,
        "wal_segments_ahead": 0
    }
}
EOF
)
            ;;
        "images")
            # Images might use different embeddings
            local image_dimension="${OLLAMA_EMBED_IMAGE_DIMENSION:-4096}"
            config=$(cat <<EOF
{
    "vectors": {
        "size": ${image_dimension},
        "distance": "${DISTANCE_METRIC}",
        "on_disk": ${on_disk}
    },
    "shard_number": 1,
    "replication_factor": ${REPLICATION_FACTOR}
}
EOF
)
            ;;
        "multimodal")
            # Multimodal might use concatenated embeddings
            config=$(cat <<EOF
{
    "vectors": {
        "size": ${dimension},
        "distance": "${DISTANCE_METRIC}",
        "on_disk": ${on_disk}
    },
    "sparse_vectors": {
        "text": {}
    },
    "shard_number": 2,
    "replication_factor": ${REPLICATION_FACTOR}
}
EOF
)
            ;;
        *)
            # Default configuration
            config=$(cat <<EOF
{
    "vectors": {
        "size": ${dimension},
        "distance": "${DISTANCE_METRIC}",
        "on_disk": ${on_disk}
    },
    "replication_factor": ${REPLICATION_FACTOR}
}
EOF
)
            ;;
    esac
    
    local headers=$(get_headers)
    local response=$(curl -sf -X PUT \
        $headers \
        -H "Content-Type: application/json" \
        -d "$config" \
        "${QDRANT_URL}/collections/${collection}")
    
    if [ $? -eq 0 ]; then
        log "INFO" "${GREEN}✓ Created collection: ${collection}${NC}"
        return 0
    else
        log "ERROR" "${RED}Failed to create collection: ${collection}${NC}"
        return 1
    fi
}

# Create indexes for better performance
create_indexes() {
    local collection=$1
    
    log "INFO" "Creating indexes for ${collection}..."
    
    # Create payload index for common fields
    local indexes=""
    case "$collection" in
        "documents"|"multimodal")
            indexes=$(cat <<EOF
{
    "field_name": "document_id",
    "field_schema": "keyword"
}
EOF
)
            ;;
        "images")
            indexes=$(cat <<EOF
{
    "field_name": "image_hash",
    "field_schema": "keyword"
}
EOF
)
            ;;
    esac
    
    if [ -n "$indexes" ]; then
        local headers=$(get_headers)
        curl -sf -X PUT \
            $headers \
            -H "Content-Type: application/json" \
            -d "$indexes" \
            "${QDRANT_URL}/collections/${collection}/index" > /dev/null 2>&1 || true
    fi
}

# Configure collection aliases
create_aliases() {
    log "INFO" "Creating collection aliases..."
    
    # Create aliases for versioning
    local aliases=(
        "documents:documents_latest"
        "images:images_latest"
        "multimodal:multimodal_latest"
    )
    
    for alias_mapping in "${aliases[@]}"; do
        IFS=':' read -r collection alias <<< "$alias_mapping"
        
        if collection_exists "$collection"; then
            local headers=$(get_headers)
            local alias_config=$(cat <<EOF
{
    "actions": [
        {
            "create_alias": {
                "collection_name": "${collection}",
                "alias_name": "${alias}"
            }
        }
    ]
}
EOF
)
            
            curl -sf -X POST \
                $headers \
                -H "Content-Type: application/json" \
                -d "$alias_config" \
                "${QDRANT_URL}/collections/aliases" > /dev/null 2>&1 || true
        fi
    done
}

# Get collection info
get_collection_info() {
    local collection=$1
    local headers=$(get_headers)
    
    local response=$(curl -sf $headers "${QDRANT_URL}/collections/${collection}" 2>/dev/null || echo "{}")
    
    if [ -n "$response" ]; then
        echo "$response" | jq -r '.result | "  Points: \(.points_count // 0), Segments: \(.segments_count // 0), Status: \(.status // "unknown")"'
    fi
}

# Main function
main() {
    log "INFO" "${BLUE}Starting Qdrant collection initialization${NC}"
    
    # Create log directory
    mkdir -p "$(dirname "$LOG_FILE")"
    
    # Check Qdrant service
    if ! check_qdrant; then
        exit 1
    fi
    
    # Parse collection list
    IFS=',' read -ra COLLECTION_ARRAY <<< "$COLLECTIONS"
    
    # Statistics
    local total=${#COLLECTION_ARRAY[@]}
    local success=0
    local skipped=0
    local failed=0
    
    # Create each collection
    for collection in "${COLLECTION_ARRAY[@]}"; do
        collection=$(echo "$collection" | tr -d ' ') # Remove spaces
        
        if collection_exists "$collection"; then
            log "INFO" "${YELLOW}Collection ${collection} already exists - skipping${NC}"
            ((skipped++))
        else
            if create_collection "$collection"; then
                create_indexes "$collection"
                ((success++))
            else
                ((failed++))
            fi
        fi
    done
    
    # Create aliases
    create_aliases
    
    # Show summary
    log "INFO" "================================================"
    log "INFO" "${BLUE}Qdrant initialization complete${NC}"
    log "INFO" "Total collections: ${total}"
    log "INFO" "${GREEN}Created: ${success}${NC}"
    log "INFO" "${YELLOW}Skipped: ${skipped}${NC}"
    if [ $failed -gt 0 ]; then
        log "WARN" "${RED}Failed: ${failed}${NC}"
    fi
    
    # List all collections
    log "INFO" "Current collections:"
    local headers=$(get_headers)
    local collections=$(curl -sf $headers "${QDRANT_URL}/collections" | jq -r '.result.collections[].name' 2>/dev/null || echo "")
    
    for col in $collections; do
        log "INFO" "- ${col}"
        get_collection_info "$col"
    done
    
    # Save configuration
    cat > "${PROJECT_ROOT}/config/qdrant/collections.json" <<EOF
{
    "collections": {
        "documents": {
            "dimension": ${DEFAULT_DIMENSION},
            "distance": "${DISTANCE_METRIC}",
            "model": "${OLLAMA_EMBED_TEXT_PRIMARY}"
        },
        "images": {
            "dimension": ${OLLAMA_EMBED_IMAGE_DIMENSION:-4096},
            "distance": "${DISTANCE_METRIC}",
            "model": "${OLLAMA_MULTIMODAL_PRIMARY}"
        },
        "multimodal": {
            "dimension": ${DEFAULT_DIMENSION},
            "distance": "${DISTANCE_METRIC}",
            "models": {
                "text": "${OLLAMA_EMBED_TEXT_PRIMARY}",
                "image": "${OLLAMA_MULTIMODAL_PRIMARY}"
            }
        }
    },
    "updated": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF
    
    log "INFO" "Configuration saved to: ${PROJECT_ROOT}/config/qdrant/collections.json"
    log "INFO" "Access Qdrant dashboard at: ${QDRANT_URL}/dashboard"
}

# Error handling
trap 'log "ERROR" "Script failed at line $LINENO"; exit 1' ERR

# Run main
main "$@"