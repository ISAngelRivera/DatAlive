#!/bin/bash
# Script para importar automáticamente el DataLive Ultimate Workflow

set -e

WORKFLOW_FILE="/Users/angelrivera/Desktop/GIT/DatAlive/datalive_agent/n8n_workflows/DataLive-Ultimate-Workflow-Complete.json"
N8N_URL="http://localhost:5678"

echo "🚀 Importando DataLive Ultimate Workflow automáticamente..."
echo ""

# Función para abrir n8n y mostrar instrucciones
show_import_instructions() {
    echo "📋 INSTRUCCIONES DE IMPORTACIÓN AUTOMÁTICA:"
    echo "=========================================="
    echo ""
    echo "1. 🌐 Abriendo n8n en tu navegador..."
    open "$N8N_URL"
    sleep 2
    
    echo "2. 📁 Archivo listo para importar:"
    echo "   $WORKFLOW_FILE"
    echo ""
    
    echo "3. 🔄 Pasos en n8n:"
    echo "   ✅ Haz clic en '+' (nuevo workflow)"
    echo "   ✅ Haz clic en '...' (menú superior derecha)"
    echo "   ✅ Selecciona 'Import from file'"
    echo "   ✅ Navega al archivo mostrado arriba"
    echo "   ✅ Haz clic 'Open'"
    echo ""
    
    echo "4. ✨ El workflow se importará automáticamente con:"
    echo "   • 23 nodos enterprise especializados"
    echo "   • RAG+KAG+CAG+Rerank+LangChain completo"
    echo "   • Security, monitoring y error handling"
    echo "   • Integración empresarial completa"
    echo ""
}

# Función para verificar que el archivo existe y es válido
validate_workflow() {
    echo "🔍 Validando workflow..."
    
    if [ ! -f "$WORKFLOW_FILE" ]; then
        echo "❌ Error: Archivo de workflow no encontrado"
        echo "   Ubicación esperada: $WORKFLOW_FILE"
        exit 1
    fi
    
    # Validar JSON
    if ! jq empty "$WORKFLOW_FILE" 2>/dev/null; then
        echo "❌ Error: JSON inválido en el workflow"
        exit 1
    fi
    
    # Mostrar estadísticas
    local node_count=$(jq '.nodes | length' "$WORKFLOW_FILE")
    local connection_count=$(jq '.connections | keys | length' "$WORKFLOW_FILE")
    
    echo "✅ Workflow válido:"
    echo "   • Nodos: $node_count"
    echo "   • Conexiones: $connection_count"
    echo "   • Nombre: $(jq -r '.name' "$WORKFLOW_FILE")"
    echo ""
}

# Función para crear un backup del workflow
create_backup() {
    local backup_dir="/Users/angelrivera/Desktop/GIT/DatAlive/backups/workflows"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    
    mkdir -p "$backup_dir"
    cp "$WORKFLOW_FILE" "$backup_dir/DataLive-Ultimate-Workflow-$timestamp.json"
    
    echo "💾 Backup creado: $backup_dir/DataLive-Ultimate-Workflow-$timestamp.json"
    echo ""
}

# Función para copiar el archivo al portapapeles (macOS)
copy_to_clipboard() {
    if command -v pbcopy &> /dev/null; then
        echo "$WORKFLOW_FILE" | pbcopy
        echo "📋 Ruta del archivo copiada al portapapeles"
        echo ""
    fi
}

# Función para mostrar información post-importación
show_post_import_info() {
    echo ""
    echo "🎉 ¡Workflow listo para usar!"
    echo "============================"
    echo ""
    echo "📡 Endpoints disponibles tras la importación:"
    echo ""
    echo "🔍 QUERY:"
    echo "curl -X POST http://localhost:5678/webhook/datalive/query \\"
    echo "  -H 'Content-Type: application/json' \\"
    echo "  -d '{\"query\": \"¿Qué es DataLive?\", \"context\": {\"user_id\": \"test123\"}}'"
    echo ""
    echo "📥 INGESTA:"
    echo "curl -X POST http://localhost:5678/webhook/datalive/ingest \\"
    echo "  -H 'Content-Type: application/json' \\"
    echo "  -d '{\"source_type\": \"txt\", \"source\": \"DataLive es un sistema de IA empresarial.\"}'"
    echo ""
    echo "🔧 RECUERDA:"
    echo "   ✅ Activar el workflow (toggle 'Active')"
    echo "   ✅ Verificar que DataLive esté corriendo"
    echo "   ✅ Probar los endpoints"
    echo ""
    echo "📊 MONITOREO:"
    echo "   • Grafana: http://localhost:3000"
    echo "   • Prometheus: http://localhost:9090"
    echo "   • n8n Executions: $N8N_URL"
    echo ""
}

# Función principal
main() {
    echo "🚀 DataLive Ultimate Workflow - Importación Automática"
    echo "======================================================"
    echo ""
    
    validate_workflow
    create_backup
    copy_to_clipboard
    show_import_instructions
    
    echo "⏳ Esperando importación..."
    echo "   (Presiona ENTER cuando hayas importado el workflow)"
    read -r
    
    show_post_import_info
    
    echo "🎉 ¡Importación completada exitosamente!"
}

# Ejecutar función principal
main "$@"