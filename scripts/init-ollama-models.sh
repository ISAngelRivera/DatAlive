#!/bin/bash
# init-ollama-models.sh - Descarga e inicializa modelos de Ollama
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
OLLAMA_URL="${OLLAMA_URL:-http://localhost:11434}"
OLLAMA_API="${OLLAMA_URL}/api"
LOG_FILE="${PROJECT_ROOT}/logs/ollama-init.log"

# Models from .env
MODELS_TO_INSTALL="${OLLAMA_MODELS_TO_INSTALL}"

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

# Check Ollama health
check_ollama() {
    log "INFO" "Checking Ollama service at ${OLLAMA_URL}..."
    
    local max_attempts=30
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if curl -sf "${OLLAMA_API}/tags" > /dev/null 2>&1; then
            log "INFO" "${GREEN}Ollama is ready!${NC}"
            return 0
        fi
        
        echo -n "."
        sleep 2
        ((attempt++))
    done
    
    log "ERROR" "${RED}Ollama service not responding${NC}"
    return 1
}

# Get list of installed models
get_installed_models() {
    curl -sf "${OLLAMA_API}/tags" | jq -r '.models[].name' 2>/dev/null || echo ""
}

# Pull a model
pull_model() {
    local model=$1
    log "INFO" "Pulling model: ${BLUE}${model}${NC}"
    
    # Start pull request
    local response=$(curl -sf -X POST \
        -H "Content-Type: application/json" \
        -d "{\"name\": \"${model}\"}" \
        "${OLLAMA_API}/pull")
    
    if [ $? -ne 0 ]; then
        log "ERROR" "Failed to start pull for ${model}"
        return 1
    fi
    
    # Monitor progress
    local last_status=""
    while true; do
        local pull_response=$(curl -sf -X POST \
            -H "Content-Type: application/json" \
            -d "{\"name\": \"${model}\"}" \
            "${OLLAMA_API}/pull" 2>/dev/null || echo '{"status":"error"}')
        
        local status=$(echo "$pull_response" | jq -r '.status // "unknown"')
        
        # Only print status if it changed
        if [ "$status" != "$last_status" ]; then
            case "$status" in
                "pulling manifest")
                    echo -ne "\r  → Pulling manifest..."
                    ;;
                "downloading"*)
                    local percent=$(echo "$pull_response" | jq -r '.completed // 0' | awk '{printf "%.1f", $1/1024/1024/1024}')
                    local total=$(echo "$pull_response" | jq -r '.total // 0' | awk '{printf "%.1f", $1/1024/1024/1024}')
                    echo -ne "\r  → Downloading: ${percent}GB / ${total}GB"
                    ;;
                "verifying"*)
                    echo -ne "\r  → Verifying download..."
                    ;;
                "writing"*)
                    echo -ne "\r  → Writing to disk..."
                    ;;
                "success")
                    echo -e "\r  ${GREEN}✓ Successfully pulled ${model}${NC}"
                    return 0
                    ;;
                "error")
                    echo -e "\r  ${RED}✗ Error pulling ${model}${NC}"
                    return 1
                    ;;
            esac
            last_status="$status"
        fi
        
        # Check if model is already present
        if [[ "$status" == *"already up-to-date"* ]] || [[ "$status" == "success" ]]; then
            echo -e "\r  ${GREEN}✓ Model ${model} is ready${NC}"
            return 0
        fi
        
        sleep 1
    done
}

# Test model based on type
test_model() {
    local model=$1
    
    log "INFO" "Testing model: ${model}"
    
    # Determine model type based on name
    if [[ "$model" == *"embed"* ]]; then
        # Test embedding model
        local test_response=$(curl -sf -X POST \
            -H "Content-Type: application/json" \
            -d "{\"model\": \"${model}\", \"prompt\": \"Test embedding\"}" \
            "${OLLAMA_API}/embeddings" 2>/dev/null)
        
        if [ $? -eq 0 ] && [ -n "$(echo "$test_response" | jq -r '.embedding[0]' 2>/dev/null)" ]; then
            log "INFO" "${GREEN}✓ Embedding test passed for ${model}${NC}"
            return 0
        fi
    else
        # Test LLM with generation
        local test_response=$(curl -sf -X POST \
            -H "Content-Type: application/json" \
            -d "{\"model\": \"${model}\", \"prompt\": \"Hello, respond with OK\", \"stream\": false}" \
            "${OLLAMA_API}/generate" 2>/dev/null)
        
        if [ $? -eq 0 ] && echo "$test_response" | jq -r '.response' | grep -q "OK"; then
            log "INFO" "${GREEN}✓ LLM test passed for ${model}${NC}"
            return 0
        fi
    fi
    
    log "WARN" "${YELLOW}Test failed for ${model}${NC}"
    return 1
}

# Create model configuration
create_model_config() {
    log "INFO" "Creating model configuration..."
    
    local config_file="${PROJECT_ROOT}/config/ollama/models.json"
    mkdir -p "$(dirname "$config_file")"
    
    cat > "$config_file" <<EOF
{
  "models": {
    "llm": {
      "primary": "${OLLAMA_LLM_PRIMARY}",
      "fallback": "${OLLAMA_LLM_FALLBACK}",
      "options": {
        "temperature": ${OLLAMA_LLM_TEMPERATURE},
        "top_p": ${OLLAMA_LLM_TOP_P},
        "max_tokens": ${OLLAMA_LLM_MAX_TOKENS}
      }
    },
    "embeddings": {
      "text": {
        "primary": "${OLLAMA_EMBED_TEXT_PRIMARY}",
        "fallback": "${OLLAMA_EMBED_TEXT_FALLBACK}",
        "dimension": ${OLLAMA_EMBED_TEXT_DIMENSION}
      },
      "multimodal": {
        "primary": "${OLLAMA_MULTIMODAL_PRIMARY}",
        "fallback": "${OLLAMA_MULTIMODAL_FALLBACK}"
      }
    },
    "performance": {
      "num_parallel": ${OLLAMA_NUM_PARALLEL},
      "max_loaded_models": ${OLLAMA_MAX_LOADED_MODELS},
      "max_queue": ${OLLAMA_MAX_QUEUE}
    }
  },
  "updated": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF
    
    log "INFO" "Model configuration saved to: $config_file"
}

# Optimize models for performance
optimize_models() {
    log "INFO" "Optimizing model loading..."
    
    # Pre-load primary models
    local primary_models="${OLLAMA_LLM_PRIMARY} ${OLLAMA_EMBED_TEXT_PRIMARY}"
    
    for model in $primary_models; do
        log "INFO" "Pre-loading model: ${model}"
        
        curl -sf -X POST \
            -H "Content-Type: application/json" \
            -d "{\"model\": \"${model}\", \"keep_alive\": \"10m\"}" \
            "${OLLAMA_API}/generate" > /dev/null 2>&1 || true
    done
}

# Main function
main() {
    log "INFO" "${BLUE}Starting Ollama model initialization${NC}"
    log "INFO" "Models to install: ${MODELS_TO_INSTALL}"
    
    # Create log directory
    mkdir -p "$(dirname "$LOG_FILE")"
    
    # Check Ollama service
    if ! check_ollama; then
        exit 1
    fi
    
    # Get currently installed models
    local installed_models=$(get_installed_models)
    log "INFO" "Currently installed models: $(echo "$installed_models" | tr '\n' ' ')"
    
    # Statistics
    local total=0
    local success=0
    local skipped=0
    local failed=0
    
    # Convert space-separated list to array
    IFS=' ' read -ra MODEL_ARRAY <<< "$MODELS_TO_INSTALL"
    
    # Install each model
    for model in "${MODEL_ARRAY[@]}"; do
        ((total++))
        if echo "$installed_models" | grep -q "^${model}$"; then
            log "INFO" "${YELLOW}Model ${model} already installed - skipping${NC}"
            ((skipped++))
        else
            if pull_model "$model"; then
                if test_model "$model"; then
                    ((success++))
                else
                    ((failed++))
                fi
            else
                ((failed++))
            fi
        fi
    done
    
    # Create configuration
    create_model_config
    
    # Optimize models
    optimize_models
    
    # Summary
    log "INFO" "================================================"
    log "INFO" "${BLUE}Ollama initialization complete${NC}"
    log "INFO" "Total models: ${total}"
    log "INFO" "${GREEN}Successfully installed: ${success}${NC}"
    log "INFO" "${YELLOW}Skipped (already installed): ${skipped}${NC}"
    if [ $failed -gt 0 ]; then
        log "WARN" "${RED}Failed: ${failed}${NC}"
    fi
    
    # List final models
    log "INFO" "Available models:"
    curl -sf "${OLLAMA_API}/tags" | jq -r '.models[] | "  - \(.name) (\(.size | tonumber / 1024 / 1024 / 1024 | tostring | .[0:4])GB)"' 2>/dev/null || echo "  Unable to list models"
    
    # Save summary
    cat > "${PROJECT_ROOT}/config/ollama/init-summary.txt" <<EOF
Ollama Model Initialization Summary
===================================
Date: $(date)
Successfully installed: ${success}
Skipped: ${skipped}
Failed: ${failed}

Primary Models:
- LLM: ${OLLAMA_LLM_PRIMARY}
- Text Embeddings: ${OLLAMA_EMBED_TEXT_PRIMARY}
- Vision: ${OLLAMA_MULTIMODAL_PRIMARY}

Configuration:
- Temperature: ${OLLAMA_LLM_TEMPERATURE}
- Max Tokens: ${OLLAMA_LLM_MAX_TOKENS}
- Parallel Workers: ${OLLAMA_NUM_PARALLEL}

Configuration saved to: ${PROJECT_ROOT}/config/ollama/models.json
EOF
    
    if [ $failed -eq 0 ] || [ $success -gt 0 ]; then
        log "INFO" "${GREEN}✓ Ollama models ready for use${NC}"
        exit 0
    else
        log "ERROR" "${RED}Failed to install required models${NC}"
        exit 1
    fi
}

# Run main
main "$@"