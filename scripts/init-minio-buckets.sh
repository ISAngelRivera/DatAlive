#!/bin/bash
# init-minio-buckets.sh - Configura buckets y políticas en MinIO
# Lee toda la configuración desde el archivo .env

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
MINIO_URL="${MINIO_URL:-http://localhost:9000}"
MINIO_ALIAS="datalive"
MINIO_ROOT_USER="${MINIO_ROOT_USER}"
MINIO_ROOT_PASSWORD="$(cat "$PROJECT_ROOT/secrets/minio_secret_key.txt")"
MINIO_DEFAULT_BUCKETS="${MINIO_DEFAULT_BUCKETS:-documents,images,embeddings,backups}"
MINIO_REGION="${MINIO_REGION:-us-east-1}"
LOG_FILE="${PROJECT_ROOT}/logs/minio-init.log"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging function
log() {
    local level=$1
    shift
    echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] [${level}] $*" | tee -a "${LOG_FILE}"
}

# Check if MinIO client is installed
check_mc_installed() {
    if ! command -v mc &> /dev/null; then
        log "INFO" "MinIO client (mc) not found. Installing..."
        
        # Download and install mc
        local mc_url="https://dl.min.io/client/mc/release/linux-amd64/mc"
        if command -v wget &> /dev/null; then
            wget -q "$mc_url" -O /tmp/mc
        elif command -v curl &> /dev/null; then
            curl -s "$mc_url" -o /tmp/mc
        else
            log "ERROR" "Neither wget nor curl found. Cannot download mc."
            return 1
        fi
        
        chmod +x /tmp/mc
        # Use local mc for this script
        MC_CMD="/tmp/mc"
    else
        MC_CMD="mc"
    fi
    
    log "INFO" "Using MinIO client: $MC_CMD"
    return 0
}

# Wait for MinIO to be ready
wait_for_minio() {
    log "INFO" "Waiting for MinIO to be ready at ${MINIO_URL}..."
    local count=0
    local max_attempts=60
    
    while [ $count -lt $max_attempts ]; do
        if curl -sf "${MINIO_URL}/minio/health/ready" > /dev/null 2>&1; then
            log "INFO" "${GREEN}MinIO is ready!${NC}"
            return 0
        fi
        
        echo -n "."
        sleep 1
        ((count++))
    done
    
    log "ERROR" "${RED}Timeout waiting for MinIO${NC}"
    return 1
}

# Configure MinIO client
configure_mc() {
    log "INFO" "Configuring MinIO client..."
    
    # Add MinIO server to mc config
    $MC_CMD alias set ${MINIO_ALIAS} ${MINIO_URL} ${MINIO_ROOT_USER} ${MINIO_ROOT_PASSWORD} > /dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        log "INFO" "${GREEN}MinIO client configured successfully${NC}"
        return 0
    else
        log "ERROR" "${RED}Failed to configure MinIO client${NC}"
        return 1
    fi
}

# Create bucket with policy
create_bucket() {
    local bucket_name=$1
    local policy=${2:-"private"} # Default to private
    
    log "INFO" "Creating bucket: ${bucket_name}"
    
    # Check if bucket exists
    if $MC_CMD ls ${MINIO_ALIAS}/${bucket_name} > /dev/null 2>&1; then
        log "WARN" "${YELLOW}Bucket ${bucket_name} already exists${NC}"
        return 0
    fi
    
    # Create bucket
    if $MC_CMD mb ${MINIO_ALIAS}/${bucket_name} --region ${MINIO_REGION} > /dev/null 2>&1; then
        log "INFO" "${GREEN}Created bucket: ${bucket_name}${NC}"
        
        # Set bucket policy if not private
        if [ "$policy" != "private" ]; then
            if $MC_CMD anonymous set ${policy} ${MINIO_ALIAS}/${bucket_name} > /dev/null 2>&1; then
                log "INFO" "Set ${policy} policy on bucket: ${bucket_name}"
            else
                log "WARN" "Failed to set policy on bucket: ${bucket_name}"
            fi
        fi
        
        return 0
    else
        log "ERROR" "${RED}Failed to create bucket: ${bucket_name}${NC}"
        return 1
    fi
}

# Create lifecycle policy for backups
create_lifecycle_policy() {
    local bucket_name=$1
    local retention_days=${2:-${BACKUP_RETENTION_DAYS:-30}}
    
    log "INFO" "Creating lifecycle policy for ${bucket_name} (${retention_days} days retention)"
    
    # Create lifecycle configuration file
    cat > /tmp/lifecycle.json <<EOF
{
    "Rules": [
        {
            "ID": "expire-old-backups",
            "Status": "Enabled",
            "Expiration": {
                "Days": ${retention_days}
            },
            "Filter": {
                "Prefix": ""
            }
        }
    ]
}
EOF
    
    # Apply lifecycle policy
    if $MC_CMD ilm import ${MINIO_ALIAS}/${bucket_name} < /tmp/lifecycle.json > /dev/null 2>&1; then
        log "INFO" "${GREEN}Lifecycle policy applied to ${bucket_name}${NC}"
    else
        log "WARN" "${YELLOW}Failed to apply lifecycle policy to ${bucket_name}${NC}"
    fi
    
    rm -f /tmp/lifecycle.json
}

# Create versioning for important buckets
enable_versioning() {
    local bucket_name=$1
    
    log "INFO" "Enabling versioning for ${bucket_name}"
    
    if $MC_CMD version enable ${MINIO_ALIAS}/${bucket_name} > /dev/null 2>&1; then
        log "INFO" "${GREEN}Versioning enabled for ${bucket_name}${NC}"
    else
        log "WARN" "${YELLOW}Failed to enable versioning for ${bucket_name}${NC}"
    fi
}

# Set up bucket notifications (webhook)
setup_bucket_notifications() {
    local bucket_name=$1
    local webhook_url=${2:-""}
    
    if [ -z "$webhook_url" ]; then
        return 0
    fi
    
    log "INFO" "Setting up notifications for ${bucket_name}"
    
    # Configure webhook notification
    $MC_CMD event add ${MINIO_ALIAS}/${bucket_name} \
        arn:minio:sqs::_:webhook \
        --event put,delete \
        --suffix ".pdf,.docx,.txt,.md" > /dev/null 2>&1
}

# Create default folder structure
create_folder_structure() {
    local bucket_name=$1
    
    log "INFO" "Creating folder structure in ${bucket_name}"
    
    case "$bucket_name" in
        "documents")
            # Create folders for document organization
            echo "" | $MC_CMD pipe ${MINIO_ALIAS}/${bucket_name}/raw/.keep
            echo "" | $MC_CMD pipe ${MINIO_ALIAS}/${bucket_name}/processed/.keep
            echo "" | $MC_CMD pipe ${MINIO_ALIAS}/${bucket_name}/archived/.keep
            ;;
        "images")
            # Create folders for image types
            echo "" | $MC_CMD pipe ${MINIO_ALIAS}/${bucket_name}/diagrams/.keep
            echo "" | $MC_CMD pipe ${MINIO_ALIAS}/${bucket_name}/charts/.keep
            echo "" | $MC_CMD pipe ${MINIO_ALIAS}/${bucket_name}/screenshots/.keep
            echo "" | $MC_CMD pipe ${MINIO_ALIAS}/${bucket_name}/extracted/.keep
            ;;
        "embeddings")
            # Create folders for embedding types
            echo "" | $MC_CMD pipe ${MINIO_ALIAS}/${bucket_name}/text/.keep
            echo "" | $MC_CMD pipe ${MINIO_ALIAS}/${bucket_name}/image/.keep
            echo "" | $MC_CMD pipe ${MINIO_ALIAS}/${bucket_name}/multimodal/.keep
            ;;
        "backups")
            # Create folders for backup organization
            echo "" | $MC_CMD pipe ${MINIO_ALIAS}/${bucket_name}/postgres/.keep
            echo "" | $MC_CMD pipe ${MINIO_ALIAS}/${bucket_name}/qdrant/.keep
            echo "" | $MC_CMD pipe ${MINIO_ALIAS}/${bucket_name}/n8n/.keep
            echo "" | $MC_CMD pipe ${MINIO_ALIAS}/${bucket_name}/configs/.keep
            ;;
    esac
}

# Generate access keys for services
generate_service_keys() {
    log "INFO" "Generating service access keys..."
    
    # Create access key for N8N
    local n8n_key=$($MC_CMD admin user svcacct add ${MINIO_ALIAS} ${MINIO_ROOT_USER} \
        --access-key "n8n-access-key" \
        --secret-key "$(openssl rand -hex 32)" 2>/dev/null | grep -oP '(?<=Secret Key: ).*')
    
    if [ -n "$n8n_key" ]; then
        echo "N8N_MINIO_ACCESS_KEY=n8n-access-key" >> "${PROJECT_ROOT}/config/minio/service-keys.env"
        echo "N8N_MINIO_SECRET_KEY=${n8n_key}" >> "${PROJECT_ROOT}/config/minio/service-keys.env"
        log "INFO" "${GREEN}Generated access key for N8N${NC}"
    fi
}

# Create bucket policies
create_bucket_policies() {
    log "INFO" "Creating bucket policies..."
    
    # Policy for documents bucket (read/write for authenticated users)
    cat > /tmp/documents-policy.json <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {"AWS": ["*"]},
            "Action": [
                "s3:GetObject",
                "s3:PutObject",
                "s3:DeleteObject",
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::documents/*",
                "arn:aws:s3:::documents"
            ],
            "Condition": {
                "StringEquals": {
                    "s3:x-amz-server-side-encryption": "AES256"
                }
            }
        }
    ]
}
EOF
    
    # Apply policy
    $MC_CMD admin policy create ${MINIO_ALIAS} documents-policy /tmp/documents-policy.json > /dev/null 2>&1
    rm -f /tmp/documents-policy.json
}

# Main function
main() {
    log "INFO" "${BLUE}Starting MinIO initialization${NC}"
    
    # Create necessary directories
    mkdir -p "${PROJECT_ROOT}/logs" "${PROJECT_ROOT}/config/minio"
    
    # Check and install mc if needed
    if ! check_mc_installed; then
        exit 1
    fi
    
    # Wait for MinIO to be ready
    if ! wait_for_minio; then
        exit 1
    fi
    
    # Configure MinIO client
    if ! configure_mc; then
        exit 1
    fi
    
    # Parse bucket list from environment
    IFS=',' read -ra BUCKETS <<< "$MINIO_DEFAULT_BUCKETS"
    
    # Statistics
    local total=${#BUCKETS[@]}
    local success=0
    local failed=0
    
    # Create each bucket
    for bucket in "${BUCKETS[@]}"; do
        bucket=$(echo "$bucket" | tr -d ' ') # Remove spaces
        
        if create_bucket "$bucket"; then
            # Set up bucket based on type
            case "$bucket" in
                "documents")
                    enable_versioning "$bucket"
                    create_folder_structure "$bucket"
                    ((success++))
                    ;;
                "images")
                    create_folder_structure "$bucket"
                    ((success++))
                    ;;
                "embeddings")
                    create_folder_structure "$bucket"
                    ((success++))
                    ;;
                "backups")
                    create_lifecycle_policy "$bucket" "${BACKUP_RETENTION_DAYS:-30}"
                    create_folder_structure "$bucket"
                    ((success++))
                    ;;
                *)
                    ((success++))
                    ;;
            esac
        else
            ((failed++))
        fi
    done
    
    # Create bucket policies
    create_bucket_policies
    
    # Generate service access keys
    generate_service_keys
    
    # Create MinIO configuration summary
    log "INFO" "Creating MinIO configuration summary..."
    
    # List all buckets and their sizes
    local bucket_list=$($MC_CMD ls ${MINIO_ALIAS} | grep -oP '(?<=\s)[^\s]+(?=/$)')
    
    cat > "${PROJECT_ROOT}/config/minio/setup-summary.txt" <<EOF
MinIO Setup Summary
===================
Date: $(date)
URL: ${MINIO_URL}
Alias: ${MINIO_ALIAS}
Region: ${MINIO_REGION}

Buckets Created:
EOF
    
    for bucket in $bucket_list; do
        local size=$($MC_CMD du ${MINIO_ALIAS}/${bucket} --depth 1 2>/dev/null | tail -1 | awk '{print $1}' || echo "0B")
        echo "  - ${bucket} (${size})" >> "${PROJECT_ROOT}/config/minio/setup-summary.txt"
    done
    
    cat >> "${PROJECT_ROOT}/config/minio/setup-summary.txt" <<EOF

Configuration:
- Versioning enabled: documents
- Lifecycle policies: backups (${BACKUP_RETENTION_DAYS} days)
- Service keys generated: ${PROJECT_ROOT}/config/minio/service-keys.env

Access MinIO Console: ${MINIO_URL}:9001
Username: ${MINIO_ROOT_USER}
EOF
    
    # Summary
    log "INFO" "================================================"
    log "INFO" "${BLUE}MinIO initialization complete${NC}"
    log "INFO" "Total buckets: ${total}"
    log "INFO" "${GREEN}Successful: ${success}${NC}"
    if [ $failed -gt 0 ]; then
        log "WARN" "${RED}Failed: ${failed}${NC}"
    fi
    
    log "INFO" "MinIO Console URL: ${MINIO_URL}:9001"
    log "INFO" "Summary saved to: ${PROJECT_ROOT}/config/minio/setup-summary.txt"
    
    # Cleanup
    if [ -f /tmp/mc ]; then
        rm -f /tmp/mc
    fi
}

# Error handling
trap 'log "ERROR" "Script failed at line $LINENO"; exit 1' ERR

# Run main function
main "$@"