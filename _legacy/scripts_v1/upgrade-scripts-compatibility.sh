#!/bin/sh
# upgrade-scripts-compatibility.sh - Actualiza todos los scripts a formato compatible
# Este script convierte automáticamente los scripts existentes para usar funciones universales

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

printf "%s\n" "${CYAN}=== Actualizando Scripts para Compatibilidad Universal ===${NC}"
printf "\n"

# Función para actualizar header de script
upgrade_script_header() {
    local script_file="$1"
    local script_name="$(get_filename "$script_file")"
    
    printf "Actualizando %s... " "$script_name"
    
    # Crear backup
    backup_file "$script_file"
    
    # Crear header universal
    local temp_file="$script_file.upgrade.$$"
    
    cat > "$temp_file" << 'EOF'
#!/bin/sh
# SCRIPT_NAME - SCRIPT_DESCRIPTION
# Compatible con: bash 3.2+, sh, dash, zsh, Git Bash, WSL

set -e

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
EOF
    
    # Extraer contenido después del header original
    awk '
    BEGIN { in_header = 1; content_started = 0 }
    /^#!/ && NR == 1 { next }
    /^#/ && in_header { next }
    /^set -/ && in_header { next }
    /^SCRIPT_DIR=/ && in_header { next }
    /^PROJECT_ROOT=/ && in_header { next }
    /^$/ && in_header { next }
    {
        in_header = 0
        content_started = 1
        print
    }' "$script_file" >> "$temp_file"
    
    # Reemplazar archivo original
    cat "$temp_file" > "$script_file"
    rm -f "$temp_file"
    
    # Actualizar nombre y descripción del script
    script_desc="$(grep -m 1 "^#.*$script_name" "$script_file.bak" 2>/dev/null | sed "s/.*$script_name//" | sed 's/^[[:space:]]*-[[:space:]]*//' || echo "Script de DataLive")"
    if [ -z "$script_desc" ]; then
        script_desc="Script de DataLive"
    fi
    
    replace_in_file "$script_file" "SCRIPT_NAME" "$script_name"
    replace_in_file "$script_file" "SCRIPT_DESCRIPTION" "$script_desc"
    
    printf "%s\n" "${GREEN}✓${NC}"
}

# Función para modernizar bashisms comunes
fix_bashisms() {
    local script_file="$1"
    local script_name="$(get_filename "$script_file")"
    
    printf "Arreglando bashisms en %s... " "$script_name"
    
    # Reemplazos comunes de bashisms
    replace_in_file "$script_file" 'echo -e' 'printf'
    replace_in_file "$script_file" '\[\[' '['
    replace_in_file "$script_file" '\]\]' ']'
    replace_in_file "$script_file" 'source ' '. '
    replace_in_file "$script_file" '((' 'expr'
    replace_in_file "$script_file" '))' ''
    
    printf "%s\n" "${GREEN}✓${NC}"
}

# Lista de scripts a actualizar (excluyendo los ya actualizados)
scripts_to_upgrade=""

# Buscar todos los scripts .sh
for script in "$PROJECT_ROOT/scripts"/*.sh; do
    if [ -f "$script" ]; then
        script_name="$(get_filename "$script")"
        
        # Saltar scripts ya modernizados
        case "$script_name" in
            "universal-functions.sh"|"test-compatibility.sh"|"upgrade-scripts-compatibility.sh"|"google-oauth-setup.sh")
                continue
                ;;
        esac
        
        # Verificar si el script necesita actualización
        if grep -q "#!/bin/bash" "$script" || grep -q "set -euo pipefail" "$script"; then
            scripts_to_upgrade="$scripts_to_upgrade $script"
        fi
    fi
done

if [ -z "$scripts_to_upgrade" ]; then
    printf "%s\n" "${GREEN}Todos los scripts ya están actualizados.${NC}"
    exit 0
fi

printf "Scripts encontrados para actualizar:\n"
for script in $scripts_to_upgrade; do
    printf "  - %s\n" "$(get_filename "$script")"
done
printf "\n"

printf "¿Continuar con la actualización? (s/N): "
read confirm

case "$confirm" in
    [Ss]|[Ss][Ii]|[Yy]|[Yy][Ee][Ss])
        printf "\nIniciando actualización...\n\n"
        ;;
    *)
        printf "Actualización cancelada.\n"
        exit 0
        ;;
esac

# Actualizar cada script
update_count=0
for script in $scripts_to_upgrade; do
    if [ -f "$script" ]; then
        upgrade_script_header "$script"
        fix_bashisms "$script"
        make_executable "$script"
        update_count=$((update_count + 1))
    fi
done

printf "\n%s\n" "${GREEN}=== Actualización Completada ===${NC}"
printf "Scripts actualizados: %d\n" "$update_count"
printf "\nCambios realizados:\n"
printf "  ✓ Shebang cambiado a #!/bin/sh\n"
printf "  ✓ Headers estandarizados\n"
printf "  ✓ Funciones universales incluidas\n"
printf "  ✓ Bashisms básicos corregidos\n"
printf "  ✓ Archivos de respaldo creados (.bak)\n"

printf "\n%s\n" "${YELLOW}Próximos pasos:${NC}"
printf "1. Prueba los scripts actualizados\n"
printf "2. Ejecuta: ./scripts/test-compatibility.sh\n"
printf "3. Si hay problemas, restaura desde archivos .bak\n"
printf "4. Elimina archivos .bak cuando esté todo correcto\n"

# Crear reporte de actualización
cat > "$PROJECT_ROOT/script-upgrade-report.txt" << EOF
Script Upgrade Report
====================
Date: $(date)
Scripts updated: $update_count

Changes made:
- Shebang changed to #!/bin/sh for maximum compatibility
- Standardized headers with universal functions
- Basic bashism fixes applied
- Backup files created with .bak extension

Updated scripts:
EOF

for script in $scripts_to_upgrade; do
    echo "- $(get_filename "$script")" >> "$PROJECT_ROOT/script-upgrade-report.txt"
done

printf "\nReporte guardado en: script-upgrade-report.txt\n"