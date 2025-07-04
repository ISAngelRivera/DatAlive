#!/bin/bash
# Script para validar el DataLive Ultimate Workflow antes del despliegue

set -e

WORKFLOW_FILE="datalive_agent/n8n_workflows/DataLive-Ultimate-Workflow-MCP-Enhanced.json"
VALIDATION_LOG="/tmp/datalive-workflow-validation.log"

echo "🚀 Iniciando validación del DataLive Ultimate Workflow..."
echo "📁 Archivo: $WORKFLOW_FILE"
echo "📋 Log: $VALIDATION_LOG"
echo ""

# Crear log file
echo "=== Validación DataLive Ultimate Workflow ===" > $VALIDATION_LOG
echo "Timestamp: $(date)" >> $VALIDATION_LOG
echo "" >> $VALIDATION_LOG

# Función para logging
log_result() {
    local status=$1
    local message=$2
    local icon="✅"
    
    if [ "$status" != "OK" ]; then
        icon="❌"
    fi
    
    echo "$icon $message"
    echo "$icon $message" >> $VALIDATION_LOG
}

# Función para validación JSON
validate_json() {
    local file=$1
    echo "🔍 Validando estructura JSON..."
    
    if ! jq empty "$file" 2>/dev/null; then
        log_result "ERROR" "JSON inválido en $file"
        return 1
    fi
    
    log_result "OK" "Estructura JSON válida"
    return 0
}

# Función para validar nodos requeridos
validate_required_nodes() {
    echo "🔍 Validando nodos requeridos..."
    
    local required_nodes=(
        "webhook"
        "schedule" 
        "function"
        "httpRequest"
        "postgres"
        "redis"
        "slack"
    )
    
    for node_type in "${required_nodes[@]}"; do
        if jq -r '.nodes[].type' "$WORKFLOW_FILE" | grep -q "$node_type"; then
            log_result "OK" "Nodo $node_type encontrado"
        else
            log_result "ERROR" "Nodo $node_type no encontrado"
        fi
    done
}

# Función para validar conexiones
validate_connections() {
    echo "🔍 Validando conexiones entre nodos..."
    
    local total_nodes=$(jq '.nodes | length' "$WORKFLOW_FILE")
    local total_connections=$(jq '.connections | length' "$WORKFLOW_FILE")
    
    log_result "OK" "Total de nodos: $total_nodes"
    log_result "OK" "Total de conexiones: $total_connections"
    
    if [ "$total_connections" -eq 0 ]; then
        log_result "ERROR" "No hay conexiones definidas"
        return 1
    fi
    
    # Validar que los nodos en connections existen
    jq -r '.connections | keys[]' "$WORKFLOW_FILE" | while read -r node_name; do
        if jq -r '.nodes[].name' "$WORKFLOW_FILE" | grep -q "^$node_name$"; then
            log_result "OK" "Conexión válida para nodo: $node_name"
        else
            log_result "ERROR" "Nodo en conexiones no existe: $node_name"
        fi
    done
}

# Función para validar configuraciones críticas
validate_critical_configs() {
    echo "🔍 Validando configuraciones críticas..."
    
    # Validar webhooks
    local webhook_paths=$(jq -r '.nodes[] | select(.type == "n8n-nodes-base.webhook") | .parameters.path' "$WORKFLOW_FILE" 2>/dev/null)
    if [ -n "$webhook_paths" ]; then
        echo "$webhook_paths" | while read -r path; do
            log_result "OK" "Webhook path configurado: $path"
        done
    fi
    
    # Validar modelos de IA
    if jq -r '.nodes[].parameters.model' "$WORKFLOW_FILE" 2>/dev/null | grep -q "phi4-mini"; then
        log_result "OK" "Modelo Phi-4 mini configurado"
    else
        log_result "WARNING" "Modelo Phi-4 mini no encontrado"
    fi
    
    # Validar URLs de servicios
    local services=("ollama:11434" "qdrant:6333" "neo4j:7474" "postgres:5432" "redis:6379")
    for service in "${services[@]}"; do
        if grep -q "$service" "$WORKFLOW_FILE"; then
            log_result "OK" "Servicio configurado: $service"
        else
            log_result "WARNING" "Servicio no encontrado: $service"
        fi
    done
}

# Función para validar credenciales
validate_credentials() {
    echo "🔍 Validando referencias a credenciales..."
    
    local cred_types=("postgres" "redis" "googleApi" "githubApi" "slackApi")
    for cred in "${cred_types[@]}"; do
        if grep -q "\"$cred\"" "$WORKFLOW_FILE"; then
            log_result "OK" "Credencial referenciada: $cred"
        else
            log_result "INFO" "Credencial opcional no usada: $cred"
        fi
    done
}

# Función para validar seguridad
validate_security() {
    echo "🔍 Validando configuraciones de seguridad..."
    
    # Verificar que no hay secretos hardcodeados
    if grep -i "password\|secret\|key.*:" "$WORKFLOW_FILE" | grep -v "\\$env\\|\\$\\{" | grep -q "\".*\""; then
        log_result "ERROR" "Posibles secretos hardcodeados encontrados"
    else
        log_result "OK" "No se encontraron secretos hardcodeados"
    fi
    
    # Verificar uso de variables de entorno
    if grep -q "\\$env\\." "$WORKFLOW_FILE"; then
        log_result "OK" "Variables de entorno utilizadas correctamente"
    else
        log_result "WARNING" "No se encontraron variables de entorno"
    fi
    
    # Verificar validación de entrada
    if grep -q "security_checks\\|validation" "$WORKFLOW_FILE"; then
        log_result "OK" "Validación de seguridad implementada"
    else
        log_result "WARNING" "Validación de seguridad no encontrada"
    fi
}

# Función para validar optimizaciones
validate_optimizations() {
    echo "🔍 Validando optimizaciones de rendimiento..."
    
    # Verificar paralelización
    if jq '.connections' "$WORKFLOW_FILE" | grep -q "\\[\\[.*,.*\\]\\]"; then
        log_result "OK" "Procesamiento paralelo configurado"
    else
        log_result "INFO" "Procesamiento secuencial detectado"
    fi
    
    # Verificar cache
    if grep -q "redis\\|cache" "$WORKFLOW_FILE"; then
        log_result "OK" "Sistema de cache implementado"
    else
        log_result "WARNING" "Sistema de cache no encontrado"
    fi
    
    # Verificar manejo de errores
    if grep -q "error\\|retry\\|timeout" "$WORKFLOW_FILE"; then
        log_result "OK" "Manejo de errores implementado"
    else
        log_result "WARNING" "Manejo de errores limitado"
    fi
}

# Función para generar reporte final
generate_report() {
    echo ""
    echo "📊 Generando reporte final..."
    
    local total_checks=$(grep -c "✅\\|❌" $VALIDATION_LOG)
    local passed_checks=$(grep -c "✅" $VALIDATION_LOG)
    local failed_checks=$(grep -c "❌" $VALIDATION_LOG)
    local warnings=$(grep -c "WARNING" $VALIDATION_LOG || echo "0")
    
    echo ""
    echo "📋 REPORTE DE VALIDACIÓN"
    echo "========================"
    echo "✅ Checks exitosos: $passed_checks"
    echo "❌ Checks fallidos: $failed_checks"
    echo "⚠️  Warnings: $warnings"
    echo "📊 Total checks: $total_checks"
    echo ""
    
    if [ "$failed_checks" -eq 0 ]; then
        echo "🎉 ¡Workflow validado exitosamente!"
        echo "🚀 Listo para despliegue en DataLive"
        return 0
    else
        echo "💥 Workflow tiene errores críticos"
        echo "🔧 Revisa el log para detalles: $VALIDATION_LOG"
        return 1
    fi
}

# Función principal
main() {
    # Verificar que existe el archivo
    if [ ! -f "$WORKFLOW_FILE" ]; then
        log_result "ERROR" "Archivo de workflow no encontrado: $WORKFLOW_FILE"
        exit 1
    fi
    
    # Ejecutar validaciones
    validate_json "$WORKFLOW_FILE" || exit 1
    validate_required_nodes
    validate_connections
    validate_critical_configs
    validate_credentials
    validate_security
    validate_optimizations
    
    # Generar reporte
    generate_report
    local exit_code=$?
    
    echo ""
    echo "📋 Log completo disponible en: $VALIDATION_LOG"
    echo ""
    
    exit $exit_code
}

# Ejecutar validación
main "$@"