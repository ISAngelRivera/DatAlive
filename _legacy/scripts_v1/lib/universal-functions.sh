#!/bin/sh
# universal-functions.sh - Funciones 100% portables
# Compatible con: bash 3.2+, sh, dash, zsh, Git Bash, WSL
# NO usa: arrays asociativos, bash 4+ features, sed -i, etc.

# Función para actualizar .env - Método más básico y universal
update_env() {
    local key="$1"
    local value="$2"
    local file="${3:-$PROJECT_ROOT/.env}"
    
    # Método 1: AWK (presente desde 1977, ultra-portable)
    if command -v awk >/dev/null 2>&1; then
        awk -v key="$key" -v value="$value" '
        BEGIN { found = 0 }
        {
            if (match($0, "^" key "=")) {
                print key "=" value
                found = 1
            } else {
                print $0
            }
        }
        END {
            if (!found) {
                print key "=" value
            }
        }
        ' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
        return $?
    fi
    
    # Método 2: Shell puro POSIX (funciona en CUALQUIER shell)
    local temp_file="$file.tmp.$$"
    local found=0
    
    # Usar while read más básico posible
    while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in
            "$key="*)
                echo "${key}=${value}"
                found=1
                ;;
            *)
                echo "$line"
                ;;
        esac
    done < "$file" > "$temp_file"
    
    # Si no se encontró, agregar
    if [ "$found" -eq 0 ]; then
        echo "${key}=${value}" >> "$temp_file"
    fi
    
    # Mover archivo (compatible con cualquier OS)
    cat "$temp_file" > "$file" && rm -f "$temp_file"
}

# Detección de OS super compatible
detect_os() {
    # Método 1: uname (POSIX, existe desde 1970s)
    if command -v uname >/dev/null 2>&1; then
        case "$(uname -s)" in
            Darwin*) echo "macos" ;;
            Linux*)  echo "linux" ;;
            MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
            *) echo "unknown" ;;
        esac
        return
    fi
    
    # Método 2: Variables de entorno (Windows)
    if [ -n "$OS" ] && [ "$OS" = "Windows_NT" ]; then
        echo "windows"
        return
    fi
    
    # Método 3: Verificar archivos del sistema
    if [ -f "/System/Library/CoreServices/SystemVersion.plist" ]; then
        echo "macos"
    elif [ -f "/etc/os-release" ] || [ -f "/proc/version" ]; then
        echo "linux"
    else
        echo "unknown"
    fi
}

# Verificar comando existe (POSIX)
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Hacer archivo ejecutable (portable)
make_executable() {
    if [ -f "$1" ]; then
        chmod +x "$1" 2>/dev/null || true
    fi
}

# Leer valor de .env (sin source, máxima compatibilidad)
get_env_value() {
    local key="$1"
    local file="${2:-$PROJECT_ROOT/.env}"
    
    if [ -f "$file" ]; then
        grep "^${key}=" "$file" 2>/dev/null | cut -d'=' -f2- | tail -1
    fi
}

# Esperar por servicio (compatible)
wait_for_service() {
    local url="$1"
    local max_attempts="${2:-30}"
    local attempt=0
    
    echo "Esperando servicio en $url..."
    
    while [ "$attempt" -lt "$max_attempts" ]; do
        if command_exists curl; then
            curl -sf "$url" >/dev/null 2>&1 && return 0
        elif command_exists wget; then
            wget -q -O- "$url" >/dev/null 2>&1 && return 0
        else
            # Fallback: usar telnet o nc si están disponibles
            if command_exists nc; then
                nc -z "$(echo "$url" | sed 's|http://||' | cut -d: -f1)" "$(echo "$url" | sed 's|.*:||' | cut -d/ -f1)" 2>/dev/null && return 0
            fi
        fi
        
        attempt=$((attempt + 1))
        sleep 1
    done
    
    return 1
}

# Logger universal
log() {
    local level="$1"
    shift
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*"
}

# Crear directorio con padres (compatible)
ensure_dir() {
    if [ ! -d "$1" ]; then
        mkdir -p "$1" 2>/dev/null || {
            # Fallback para sistemas muy antiguos
            local dir="$1"
            local parent
            while [ ! -d "$dir" ]; do
                parent="${dir%/*}"
                [ "$parent" = "$dir" ] && break
                ensure_dir "$parent"
                mkdir "$dir" 2>/dev/null || true
            done
        }
    fi
}

# Función para escapar cadenas para sed (evita sed -i)
escape_for_sed() {
    echo "$1" | sed 's/[[\.*^$()+?{|]/\\&/g'
}

# Reemplazar en archivo sin sed -i (ultra compatible)
replace_in_file() {
    local file="$1"
    local search="$2"
    local replace="$3"
    local temp_file="$file.tmp.$$"
    
    if [ -f "$file" ]; then
        # Usar sed estándar con archivo temporal
        sed "s|$(escape_for_sed "$search")|$(escape_for_sed "$replace")|g" "$file" > "$temp_file"
        if [ $? -eq 0 ]; then
            cat "$temp_file" > "$file"
            rm -f "$temp_file"
            return 0
        else
            rm -f "$temp_file"
            return 1
        fi
    fi
    return 1
}

# Función para verificar si una cadena contiene otra (sin usar [[)
contains() {
    case "$1" in
        *"$2"*) return 0 ;;
        *) return 1 ;;
    esac
}

# Función para trim whitespace (compatible)
trim() {
    local var="$1"
    # Eliminar espacios al inicio
    while true; do
        case "$var" in
            " "*|"	"*) var="${var#?}" ;;
            *) break ;;
        esac
    done
    # Eliminar espacios al final
    while true; do
        case "$var" in
            *" "|*"	") var="${var%?}" ;;
            *) break ;;
        esac
    done
    echo "$var"
}

# Verificar si archivo tiene contenido específico
file_contains() {
    local file="$1"
    local pattern="$2"
    
    if [ -f "$file" ]; then
        grep -q "$pattern" "$file" 2>/dev/null
        return $?
    fi
    return 1
}

# Agregar línea a archivo si no existe
add_line_if_missing() {
    local file="$1"
    local line="$2"
    
    if [ ! -f "$file" ] || ! file_contains "$file" "$line"; then
        echo "$line" >> "$file"
    fi
}

# Función para unir paths de manera portable
join_path() {
    local result="$1"
    shift
    
    for part in "$@"; do
        case "$result" in
            */) result="$result$part" ;;
            *) result="$result/$part" ;;
        esac
    done
    
    echo "$result"
}

# Función para obtener directorio padre
get_parent_dir() {
    echo "${1%/*}"
}

# Función para obtener nombre de archivo
get_filename() {
    echo "${1##*/}"
}

# Función para verificar si es un número
is_number() {
    case "$1" in
        ''|*[!0-9]*) return 1 ;;
        *) return 0 ;;
    esac
}

# Función para generar ID aleatorio simple
generate_id() {
    local length="${1:-8}"
    local chars="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    local result=""
    local i=0
    
    # Usar date y PID para generar semilla
    local seed="$(date +%s)$$"
    
    while [ "$i" -lt "$length" ]; do
        # Método simple usando módulo
        local pos=$((seed % 62))
        result="$result$(echo "$chars" | cut -c$((pos + 1)))"
        seed=$((seed / 62 + $(date +%N 2>/dev/null || echo 0)))
        i=$((i + 1))
    done
    
    echo "$result"
}

# Función para backup de archivo
backup_file() {
    local file="$1"
    local backup_suffix="${2:-.bak}"
    
    if [ -f "$file" ]; then
        cp "$file" "$file$backup_suffix"
        return $?
    fi
    return 1
}

# Función para validar URL básica
is_valid_url() {
    case "$1" in
        http://*|https://*) return 0 ;;
        *) return 1 ;;
    esac
}

# Función para validar email básica
is_valid_email() {
    case "$1" in
        *@*.*) return 0 ;;
        *) return 1 ;;
    esac
}

# Color codes para output (compatible)
setup_colors() {
    if [ -t 1 ] && command_exists tput; then
        # Terminal soporta colores
        RED="$(tput setaf 1 2>/dev/null || echo '')"
        GREEN="$(tput setaf 2 2>/dev/null || echo '')"
        YELLOW="$(tput setaf 3 2>/dev/null || echo '')"
        BLUE="$(tput setaf 4 2>/dev/null || echo '')"
        MAGENTA="$(tput setaf 5 2>/dev/null || echo '')"
        CYAN="$(tput setaf 6 2>/dev/null || echo '')"
        WHITE="$(tput setaf 7 2>/dev/null || echo '')"
        BOLD="$(tput bold 2>/dev/null || echo '')"
        NC="$(tput sgr0 2>/dev/null || echo '')"
    else
        # No colores
        RED=""
        GREEN=""
        YELLOW=""
        BLUE=""
        MAGENTA=""
        CYAN=""
        WHITE=""
        BOLD=""
        NC=""
    fi
}

# Inicializar colores automáticamente
setup_colors

# Función para verificar dependencias mínimas
check_dependencies() {
    local missing=""
    
    for cmd in "$@"; do
        if ! command_exists "$cmd"; then
            missing="$missing $cmd"
        fi
    done
    
    if [ -n "$missing" ]; then
        log "ERROR" "Comandos requeridos no encontrados:$missing"
        return 1
    fi
    
    return 0
}

# Export de funciones principales para compatibilidad
export -f update_env detect_os command_exists make_executable get_env_value 2>/dev/null || true
export -f wait_for_service log ensure_dir replace_in_file contains trim 2>/dev/null || true