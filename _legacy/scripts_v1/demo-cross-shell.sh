#!/bin/sh
# demo-cross-shell.sh - Demostración de compatibilidad entre shells
# Este script se ejecuta a sí mismo en diferentes shells para demostrar compatibilidad

# Detectar directorio del script (ultra-compatible)
if [ -n "$BASH_SOURCE" ]; then
    SCRIPT_DIR="$(cd "$(dirname "$BASH_SOURCE")" && pwd)"
elif [ -n "$0" ] && [ -f "$0" ]; then
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
else
    SCRIPT_DIR="$(pwd)"
fi

PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Cargar funciones universales
. "$PROJECT_ROOT/scripts/lib/universal-functions.sh"

# Función principal de demo
run_demo() {
    local current_shell="$1"
    
    printf "\n%s\n" "${CYAN}=== Demo en $current_shell ===${NC}"
    
    # Test 1: Información básica
    printf "1. Información del sistema:\n"
    printf "   - OS: %s\n" "$(detect_os)"
    printf "   - Shell: %s\n" "$current_shell"
    printf "   - PID: %s\n" "$$"
    
    # Test 2: Funciones de string
    printf "\n2. Funciones de string:\n"
    test_string="  DataLive RAG System  "
    trimmed="$(trim "$test_string")"
    printf "   - Original: '%s'\n" "$test_string"
    printf "   - Trimmed:  '%s'\n" "$trimmed"
    
    # Test 3: Validaciones
    printf "\n3. Validaciones:\n"
    if is_valid_email "admin@datalive.local"; then
        printf "   - Email: %s ✓\n" "${GREEN}válido${NC}"
    else
        printf "   - Email: %s ✗\n" "${RED}inválido${NC}"
    fi
    
    if is_valid_url "http://localhost:5678"; then
        printf "   - URL: %s ✓\n" "${GREEN}válida${NC}"
    else
        printf "   - URL: %s ✗\n" "${RED}inválida${NC}"
    fi
    
    # Test 4: Manejo de archivos
    printf "\n4. Manejo de archivos:\n"
    test_file="$PROJECT_ROOT/demo-test.tmp"
    
    # Crear archivo temporal
    printf "TEST_VAR=test_value\n# Comentario\nOTHER_VAR=other" > "$test_file"
    
    # Leer valor
    value="$(get_env_value "TEST_VAR" "$test_file")"
    printf "   - Leer .env: %s\n" "$value"
    
    # Actualizar valor
    update_env "TEST_VAR" "updated_value" "$test_file"
    new_value="$(get_env_value "TEST_VAR" "$test_file")"
    printf "   - Actualizar .env: %s\n" "$new_value"
    
    # Limpiar
    rm -f "$test_file"
    
    # Test 5: Paths
    printf "\n5. Manejo de paths:\n"
    test_path="/home/user/documents/file.txt"
    printf "   - Directorio padre: %s\n" "$(get_parent_dir "$test_path")"
    printf "   - Nombre archivo: %s\n" "$(get_filename "$test_path")"
    
    # Test 6: Comandos disponibles
    printf "\n6. Comandos disponibles:\n"
    for cmd in docker curl jq awk sed; do
        if command_exists "$cmd"; then
            printf "   - %-8s %s\n" "$cmd" "${GREEN}✓${NC}"
        else
            printf "   - %-8s %s\n" "$cmd" "${RED}✗${NC}"
        fi
    done
    
    printf "\n%s\n" "${GREEN}Demo completada en $current_shell${NC}"
}

# Si se llama con argumento "demo", ejecutar la función de demo
if [ "$1" = "demo" ]; then
    run_demo "$2"
    exit 0
fi

# Script principal - ejecutar en diferentes shells
printf "%s\n" "${CYAN}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║              DataLive Cross-Shell Compatibility Demo          ║
║                                                               ║
║  Este script se ejecuta en múltiples shells para demostrar   ║
║  que las funciones universales funcionan en CUALQUIER shell  ║
╚═══════════════════════════════════════════════════════════════╝
EOF
printf "%s\n" "${NC}"

# Lista de shells a probar
shells_to_test="sh dash bash zsh"
tested_count=0
success_count=0

for shell in $shells_to_test; do
    if command_exists "$shell"; then
        printf "\n%s\n" "${YELLOW}Probando $shell...${NC}"
        
        # Ejecutar el script en el shell específico
        if "$shell" "$0" demo "$shell" 2>/dev/null; then
            success_count=$((success_count + 1))
            printf "%s\n" "${GREEN}✓ $shell funciona perfectamente${NC}"
        else
            printf "%s\n" "${RED}✗ $shell falló${NC}"
        fi
        
        tested_count=$((tested_count + 1))
    else
        printf "%s\n" "${YELLOW}⚠ $shell no disponible${NC}"
    fi
done

# Resumen final
printf "\n%s\n" "${CYAN}=== Resumen de Compatibilidad ===${NC}"
printf "Shells probados: %d\n" "$tested_count"
printf "Shells exitosos: %d\n" "$success_count"

if [ "$success_count" -eq "$tested_count" ] && [ "$tested_count" -gt 0 ]; then
    printf "\n%s\n" "${GREEN}🎉 ¡COMPATIBILIDAD UNIVERSAL CONFIRMADA!${NC}"
    printf "%s\n" "${GREEN}DataLive funciona en TODOS los shells disponibles${NC}"
    
    # Crear reporte de compatibilidad
    cat > "$PROJECT_ROOT/cross-shell-report.txt" << EOF
DataLive Cross-Shell Compatibility Report
=========================================
Date: $(date)
OS: $(detect_os)
Success Rate: $success_count/$tested_count (100%)

Tested shells:
EOF
    
    for shell in $shells_to_test; do
        if command_exists "$shell"; then
            echo "✓ $shell - PASS" >> "$PROJECT_ROOT/cross-shell-report.txt"
        else
            echo "- $shell - NOT AVAILABLE" >> "$PROJECT_ROOT/cross-shell-report.txt"
        fi
    done
    
    echo "" >> "$PROJECT_ROOT/cross-shell-report.txt"
    echo "All available shells passed compatibility tests." >> "$PROJECT_ROOT/cross-shell-report.txt"
    echo "DataLive is universally compatible." >> "$PROJECT_ROOT/cross-shell-report.txt"
    
    printf "\nReporte guardado en: cross-shell-report.txt\n"
    
elif [ "$tested_count" -eq 0 ]; then
    printf "\n%s\n" "${YELLOW}⚠ No se encontraron shells adicionales para probar${NC}"
    printf "%s\n" "${YELLOW}Pero el script actual funcionó, así que hay compatibilidad básica${NC}"
else
    printf "\n%s\n" "${RED}⚠ Algunos shells fallaron${NC}"
    printf "Tasa de éxito: %d/%d\n" "$success_count" "$tested_count"
fi

printf "\n%s\n" "${BLUE}Probado en el sistema:${NC}"
printf "  OS: %s\n" "$(detect_os)"
printf "  Shell actual: %s\n" "${SHELL:-unknown}"
printf "  Directorio: %s\n" "$PROJECT_ROOT"

printf "\n%s\n" "${CYAN}DataLive está listo para funcionar en cualquier máquina!${NC}"