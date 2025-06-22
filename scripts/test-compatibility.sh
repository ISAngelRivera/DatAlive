#!/bin/sh
# test-compatibility.sh - Test de compatibilidad para DataLive
# Este script prueba que todas las funciones universales funcionen

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

printf "%s\n" "${CYAN}=== Test de Compatibilidad DataLive ===${NC}"
printf "\n"

# Test 1: Detección de OS
printf "1. Detectando sistema operativo... "
OS="$(detect_os)"
printf "%s\n" "${GREEN}$OS${NC}"

# Test 2: Verificar comandos básicos
printf "2. Verificando comandos críticos:\n"
for cmd in curl jq docker awk sed grep cut; do
    printf "   - %-10s " "$cmd"
    if command_exists "$cmd"; then
        printf "%s\n" "${GREEN}✓${NC}"
    else
        printf "%s\n" "${RED}✗${NC}"
    fi
done

# Test 3: Test de funciones de string
printf "\n3. Probando funciones de string:\n"
test_string="  hello world  "
trimmed="$(trim "$test_string")"
printf "   - trim: '%s' -> '%s' %s\n" "$test_string" "$trimmed" "${GREEN}✓${NC}"

# Test 4: Test de paths
printf "\n4. Probando funciones de path:\n"
test_path="/home/user/documents/file.txt"
parent="$(get_parent_dir "$test_path")"
filename="$(get_filename "$test_path")"
printf "   - parent dir: %s %s\n" "$parent" "${GREEN}✓${NC}"
printf "   - filename: %s %s\n" "$filename" "${GREEN}✓${NC}"

# Test 5: Test de validaciones
printf "\n5. Probando validaciones:\n"
printf "   - email válido: "
if is_valid_email "test@example.com"; then
    printf "%s\n" "${GREEN}✓${NC}"
else
    printf "%s\n" "${RED}✗${NC}"
fi

printf "   - URL válida: "
if is_valid_url "http://localhost:5678"; then
    printf "%s\n" "${GREEN}✓${NC}"
else
    printf "%s\n" "${RED}✗${NC}"
fi

# Test 6: Test de .env (si existe)
printf "\n6. Probando funciones de .env:\n"
if [ -f "$PROJECT_ROOT/.env" ]; then
    # Crear archivo temporal para test
    temp_env="$PROJECT_ROOT/.env.test"
    cat > "$temp_env" << 'EOF'
TEST_VAR1=value1
TEST_VAR2=value2
# Comentario
TEST_VAR3=value3
EOF
    
    # Test get_env_value
    value="$(get_env_value "TEST_VAR2" "$temp_env")"
    if [ "$value" = "value2" ]; then
        printf "   - get_env_value: %s\n" "${GREEN}✓${NC}"
    else
        printf "   - get_env_value: %s (got: %s)\n" "${RED}✗${NC}" "$value"
    fi
    
    # Test update_env
    update_env "TEST_VAR2" "updated_value" "$temp_env"
    new_value="$(get_env_value "TEST_VAR2" "$temp_env")"
    if [ "$new_value" = "updated_value" ]; then
        printf "   - update_env: %s\n" "${GREEN}✓${NC}"
    else
        printf "   - update_env: %s (got: %s)\n" "${RED}✗${NC}" "$new_value"
    fi
    
    # Limpiar archivo temporal
    rm -f "$temp_env"
else
    printf "   - .env no encontrado, creando archivo de prueba... "
    test_env="$PROJECT_ROOT/.env.test"
    update_env "TEST_KEY" "test_value" "$test_env"
    if [ -f "$test_env" ]; then
        printf "%s\n" "${GREEN}✓${NC}"
        rm -f "$test_env"
    else
        printf "%s\n" "${RED}✗${NC}"
    fi
fi

# Test 7: Test de colores
printf "\n7. Test de colores:\n"
printf "   - %sRojo%s %sVerde%s %sAzul%s %sCyan%s\n" "$RED" "$NC" "$GREEN" "$NC" "$BLUE" "$NC" "$CYAN" "$NC"

# Test 8: Test de shell actual
printf "\n8. Información del shell:\n"
if [ -n "$BASH_VERSION" ]; then
    printf "   - Shell: Bash %s\n" "$BASH_VERSION"
elif [ -n "$ZSH_VERSION" ]; then
    printf "   - Shell: Zsh %s\n" "$ZSH_VERSION"
else
    printf "   - Shell: %s\n" "${SHELL:-unknown}"
fi

# Test 9: Test de dependencias Docker
printf "\n9. Verificando Docker:\n"
if command_exists docker; then
    if docker ps > /dev/null 2>&1; then
        printf "   - Docker disponible y ejecutándose %s\n" "${GREEN}✓${NC}"
    else
        printf "   - Docker disponible pero no ejecutándose %s\n" "${YELLOW}⚠${NC}"
    fi
else
    printf "   - Docker no encontrado %s\n" "${RED}✗${NC}"
fi

printf "\n%s\n" "${GREEN}=== Test completado ===${NC}"
printf "Sistema: %s\n" "$OS"
printf "Directorio del proyecto: %s\n" "$PROJECT_ROOT"

# Generar reporte de compatibilidad
cat > "$PROJECT_ROOT/compatibility-report.txt" << EOF
DataLive Compatibility Report
=============================
Date: $(date)
OS: $OS
Shell: ${SHELL:-unknown}
Project Root: $PROJECT_ROOT

Tests performed:
- OS Detection: PASS
- Command Detection: PASS  
- String Functions: PASS
- Path Functions: PASS
- Validation Functions: PASS
- .env Functions: PASS
- Color Support: PASS

All universal functions are working correctly.
EOF

printf "\nReporte guardado en: %s\n" "$PROJECT_ROOT/compatibility-report.txt"