#!/bin/bash
# Script de diagnóstico para OAuth callback de N8N con compatibilidad multientorno

# Source universal functions for cross-platform compatibility
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/universal-functions.sh"

# Script info
SCRIPT_NAME="diagnose-oauth-callback.sh"
SCRIPT_VERSION="1.0.0"

log "=== DIAGNÓSTICO OAUTH CALLBACK N8N ==="
log "Script: $SCRIPT_NAME v$SCRIPT_VERSION"
log ""

# Check Docker
check_command docker

# Get container name
N8N_CONTAINER=$(get_container_name "n8n")
if [ -z "$N8N_CONTAINER" ]; then
    error "Container N8N no encontrado. ¿Está el stack corriendo?"
    exit 1
fi

# 1. Verificar variables de entorno
log "1. Verificando variables de entorno en N8N:"
log "-------------------------------------------"
for var in N8N_PROTOCOL N8N_HOST N8N_PORT N8N_WEBHOOK_URL WEBHOOK_URL PUBLIC_API_ENDPOINT; do
    value=$(docker exec $N8N_CONTAINER sh -c "echo \$$var" 2>/dev/null)
    if [ -n "$value" ]; then
        success "$var=$value"
    else
        log "$var=(no definido)"
    fi
done
log ""

# 2. Construir URL de callback esperada
log "2. URL de callback esperada:"
log "----------------------------"
WEBHOOK_URL=$(docker exec $N8N_CONTAINER sh -c 'echo $N8N_WEBHOOK_URL' 2>/dev/null)
if [ -z "$WEBHOOK_URL" ]; then
    WEBHOOK_URL=$(docker exec $N8N_CONTAINER sh -c 'echo $WEBHOOK_URL' 2>/dev/null)
fi
if [ -z "$WEBHOOK_URL" ]; then
    # Si no hay WEBHOOK_URL, construirla desde las partes
    PROTOCOL=$(docker exec $N8N_CONTAINER sh -c 'echo ${N8N_PROTOCOL:-http}' 2>/dev/null)
    HOST=$(docker exec $N8N_CONTAINER sh -c 'echo ${N8N_HOST:-localhost}' 2>/dev/null)
    PORT=$(docker exec $N8N_CONTAINER sh -c 'echo ${N8N_PORT:-5678}' 2>/dev/null)
    WEBHOOK_URL="${PROTOCOL}://${HOST}:${PORT}"
fi

log "Base URL: $WEBHOOK_URL"
success "Callback URL completa: ${WEBHOOK_URL}/rest/oauth2-credential/callback"
log ""

# 3. Verificar conectividad
log "3. Verificando conectividad a N8N:"
log "---------------------------------"
if curl -s -o /dev/null -w "%{http_code}" http://localhost:5678/healthz 2>/dev/null | grep -q "200"; then
    success "✓ N8N está respondiendo correctamente en http://localhost:5678"
else
    # Intentar con el contenedor directamente
    if docker exec $N8N_CONTAINER wget -q -O /dev/null http://localhost:5678/healthz 2>/dev/null; then
        success "✓ N8N está respondiendo (verificado desde dentro del contenedor)"
    else
        error "✗ N8N no está respondiendo"
    fi
fi
log ""

# 4. Verificar endpoint de callback
log "4. Verificando endpoint OAuth:"
log "-----------------------------"
OAUTH_RESPONSE=$(curl -s -w "\n%{http_code}" http://localhost:5678/rest/oauth2-credential/callback 2>&1)
HTTP_CODE=$(echo "$OAUTH_RESPONSE" | tail -n1)
if [ "$HTTP_CODE" = "404" ]; then
    error "✗ Endpoint OAuth no encontrado (404)"
elif [ "$HTTP_CODE" = "400" ] || [ "$HTTP_CODE" = "422" ]; then
    success "✓ Endpoint OAuth existe (error $HTTP_CODE esperado sin parámetros)"
else
    log "Código HTTP: $HTTP_CODE"
    log "Respuesta: $(echo "$OAUTH_RESPONSE" | head -n-1)"
fi
log ""

# 5. Verificar logs de N8N
log "5. Últimos logs de N8N relacionados con OAuth:"
log "---------------------------------------------"
OAUTH_LOGS=$(docker logs $N8N_CONTAINER 2>&1 | grep -i "oauth\|callback\|google" | tail -10)
if [ -n "$OAUTH_LOGS" ]; then
    echo "$OAUTH_LOGS"
else
    log "No se encontraron logs relacionados con OAuth"
fi
log ""

# 6. Verificar configuración de red Docker
log "6. Verificando configuración de red:"
log "-----------------------------------"
NETWORKS=$(docker inspect $N8N_CONTAINER --format='{{range $k, $v := .NetworkSettings.Networks}}{{$k}} {{end}}' 2>/dev/null)
log "Redes conectadas: $NETWORKS"

# Verificar si el puerto está expuesto
PORTS=$(docker port $N8N_CONTAINER 5678 2>/dev/null)
if [ -n "$PORTS" ]; then
    success "Puerto 5678 expuesto: $PORTS"
else
    error "Puerto 5678 no está expuesto"
fi
log ""

# 7. Instrucciones y recomendaciones
log "7. CONFIGURACIÓN REQUERIDA EN GOOGLE CONSOLE:"
log "============================================="
log ""
log "La URL de callback en Google Console debe ser EXACTAMENTE:"
success "${WEBHOOK_URL}/rest/oauth2-credential/callback"
log ""
log "Pasos en Google Console:"
log "1. Ve a https://console.cloud.google.com/apis/credentials"
log "2. Selecciona tu proyecto"
log "3. En tu cliente OAuth 2.0, añade a 'URIs de redirección autorizados':"
log "   ${WEBHOOK_URL}/rest/oauth2-credential/callback"
log ""

# 8. Verificar errores comunes
log "8. VERIFICACIÓN DE ERRORES COMUNES:"
log "==================================="

# Check if using localhost but N8N expects different host
if [[ "$WEBHOOK_URL" == *"localhost"* ]]; then
    warn "⚠ Usando localhost. Asegúrate de que:"
    log "  - Estás accediendo a N8N desde la misma máquina"
    log "  - Google Console tiene configurado 'localhost' exactamente"
fi

# Check for HTTPS
if [[ "$WEBHOOK_URL" != *"https"* ]]; then
    warn "⚠ Usando HTTP en lugar de HTTPS"
    log "  Google OAuth funciona con HTTP solo para localhost"
    log "  Para producción, necesitarás HTTPS"
fi

log ""
log "=== FIN DEL DIAGNÓSTICO ==="
log ""
log "Si el problema persiste, revisa:"
log "1. El error exacto en el navegador al intentar autenticar"
log "2. Los logs completos: docker logs -f $N8N_CONTAINER"
log "3. La configuración de tu aplicación OAuth en Google Console"
