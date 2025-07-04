#!/bin/bash
# Script para usar n8n-mcp en desarrollo de workflows DataLive

set -e

echo "🚀 Configurando n8n-MCP para desarrollo de workflows DataLive..."

# Verificar que Docker esté corriendo
if ! docker info >/dev/null 2>&1; then
    echo "❌ Docker no está corriendo. Por favor inicia Docker primero."
    exit 1
fi

# Verificar que DataLive esté corriendo
if ! docker ps | grep -q "datalive-n8n"; then
    echo "❌ DataLive no está corriendo. Ejecuta 'docker-compose up -d' primero."
    exit 1
fi

# Obtener el API key de n8n si existe
N8N_API_KEY=$(docker exec datalive-n8n cat /home/node/.n8n/n8n_api_key 2>/dev/null || echo "")

if [ -z "$N8N_API_KEY" ]; then
    echo "⚠️  No se encontró API key de n8n. Ejecutando sin capacidades de gestión."
    echo ""
    echo "📚 Ejecutando n8n-MCP (modo documentación)..."
    docker run -it --rm \
        -e MCP_MODE=stdio \
        -e LOG_LEVEL=info \
        ghcr.io/czlonkowski/n8n-mcp:latest
else
    echo "✅ API key de n8n encontrada. Habilitando todas las capacidades."
    echo ""
    echo "🔧 Ejecutando n8n-MCP (modo completo)..."
    docker run -it --rm \
        -e MCP_MODE=stdio \
        -e LOG_LEVEL=info \
        -e N8N_API_URL=http://n8n:5678 \
        -e N8N_API_KEY="$N8N_API_KEY" \
        --network datalive_datalive-net \
        ghcr.io/czlonkowski/n8n-mcp:latest
fi

echo ""
echo "📖 Comandos útiles de n8n-MCP:"
echo "  - start_here_workflow_guide() - Guía de mejores prácticas"
echo "  - search_nodes({query: 'qdrant'}) - Buscar nodos"
echo "  - get_node_essentials('n8n-nodes-base.qdrant') - Info esencial del nodo"
echo "  - validate_workflow(workflow) - Validar workflow completo"
echo ""
echo "💡 Para más información: https://github.com/czlonkowski/n8n-mcp"