#!/bin/bash
# clean-workflow-for-import.sh - Limpia workflows para importación en N8N

set -euo pipefail

# Función para limpiar un workflow
clean_workflow() {
    local input_file=$1
    
    # Extraer solo las propiedades necesarias para N8N
    jq '{
        name: .name,
        nodes: .nodes,
        connections: .connections,
        settings: (.settings // {}),
        staticData: (.staticData // {})
    }' "$input_file"
}

# Si se pasa un archivo como argumento
if [ $# -eq 1 ]; then
    clean_workflow "$1"
else
    echo "Usage: $0 <workflow-file.json>"
    exit 1
fi