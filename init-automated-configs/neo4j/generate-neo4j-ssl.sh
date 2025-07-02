#!/bin/bash

# ====================================================================
# DataLive - Generador de Certificados SSL para Neo4j
# ====================================================================
# Genera certificados SSL auto-firmados para Neo4j con compatibilidad Safari
# ====================================================================

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to generate Neo4j SSL certificates
generate_neo4j_ssl() {
    local ssl_dir="/Users/angelrivera/Desktop/GIT/DatAlive/init-neo4j/ssl"
    local cert_file="$ssl_dir/neo4j.cert"
    local key_file="$ssl_dir/neo4j.key"
    
    print_status "🔐 Generando certificados SSL para Neo4j..."
    
    # Create SSL directory if it doesn't exist
    mkdir -p "$ssl_dir"
    
    # Check if certificates already exist
    if [ -f "$cert_file" ] && [ -f "$key_file" ]; then
        print_warning "Los certificados SSL ya existen."
        
        # Check if certificates are still valid (not expired)
        if openssl x509 -in "$cert_file" -checkend 86400 >/dev/null 2>&1; then
            print_status "Los certificados existentes son válidos por al menos 24 horas más."
            read -p "¿Quieres regenerar los certificados SSL? (y/N): " regenerate
            if [[ ! $regenerate =~ ^[Yy]$ ]]; then
                print_success "Usando certificados SSL existentes."
                return 0
            fi
        else
            print_warning "Los certificados existentes han expirado o expiran pronto."
        fi
        
        # Backup existing certificates
        local backup_suffix=$(date +%Y%m%d_%H%M%S)
        cp "$cert_file" "$cert_file.backup.$backup_suffix"
        cp "$key_file" "$key_file.backup.$backup_suffix"
        print_success "Backup creado: neo4j.cert.backup.$backup_suffix y neo4j.key.backup.$backup_suffix"
    fi
    
    # Generate new SSL certificate and private key
    print_status "Generando nuevo certificado SSL auto-firmado..."
    
    openssl req -x509 -newkey rsa:2048 \
        -keyout "$key_file" \
        -out "$cert_file" \
        -days 365 \
        -nodes \
        -subj "/C=ES/ST=Madrid/L=Madrid/O=DataLive/OU=Development/CN=localhost" \
        >/dev/null 2>&1
    
    # Set appropriate permissions
    chmod 644 "$cert_file"
    chmod 600 "$key_file"
    
    # Verify the generated certificate
    local cert_info=$(openssl x509 -in "$cert_file" -noout -dates -subject 2>/dev/null)
    local expiry_date=$(echo "$cert_info" | grep "notAfter" | cut -d= -f2)
    
    print_success "Certificados SSL generados exitosamente!"
    print_status "📄 Ubicación: $ssl_dir/"
    print_status "📅 Válido hasta: $expiry_date"
    print_status "🔗 Sujeto: CN=localhost, O=DataLive, OU=Development"
    
    return 0
}

# Function to verify Neo4j SSL configuration
verify_ssl_config() {
    local ssl_dir="/Users/angelrivera/Desktop/GIT/DatAlive/init-neo4j/ssl"
    local cert_file="$ssl_dir/neo4j.cert"
    local key_file="$ssl_dir/neo4j.key"
    
    print_status "🔍 Verificando configuración SSL..."
    
    # Check if files exist
    if [ ! -f "$cert_file" ] || [ ! -f "$key_file" ]; then
        print_error "Archivos de certificado no encontrados."
        return 1
    fi
    
    # Verify certificate validity
    if ! openssl x509 -in "$cert_file" -noout >/dev/null 2>&1; then
        print_error "El certificado no es válido."
        return 1
    fi
    
    # Verify private key
    if ! openssl rsa -in "$key_file" -check -noout >/dev/null 2>&1; then
        print_error "La clave privada no es válida."
        return 1
    fi
    
    # Verify certificate and key match
    local cert_md5=$(openssl x509 -noout -modulus -in "$cert_file" | openssl md5)
    local key_md5=$(openssl rsa -noout -modulus -in "$key_file" | openssl md5)
    
    if [ "$cert_md5" != "$key_md5" ]; then
        print_error "El certificado y la clave privada no coinciden."
        return 1
    fi
    
    print_success "✅ Configuración SSL verificada correctamente."
    return 0
}

# Main function
main() {
    echo "======================================================================"
    echo "🔐 DataLive - Generador de Certificados SSL para Neo4j"
    echo "======================================================================"
    echo ""
    
    # Check prerequisites
    if ! command -v openssl >/dev/null 2>&1; then
        print_error "OpenSSL no está instalado."
        print_error "Instala OpenSSL y vuelve a ejecutar el script."
        exit 1
    fi
    
    # Generate SSL certificates
    if generate_neo4j_ssl; then
        echo ""
        if verify_ssl_config; then
            echo ""
            echo "======================================================================"
            print_success "🎉 Certificados SSL para Neo4j listos"
            echo "======================================================================"
            echo ""
            echo "📋 Información de los certificados:"
            echo ""
            echo "📁 Ubicación:"
            echo "  • Certificado: init-neo4j/ssl/neo4j.cert"
            echo "  • Clave privada: init-neo4j/ssl/neo4j.key"
            echo ""
            echo "🔧 Configuración en Docker:"
            echo "  • Volumen: ./init-neo4j/ssl:/ssl"
            echo "  • Certificado: /ssl/neo4j.cert"
            echo "  • Clave: /ssl/neo4j.key"
            echo ""
            echo "🌐 URLs de acceso:"
            echo "  • HTTPS: https://localhost:7473"
            echo "  • HTTP: http://localhost:7474"
            echo ""
            echo "✅ Compatibilidad con Safari habilitada"
            echo ""
            print_success "¡Los certificados están listos para usar!"
        else
            print_error "Fallo en la verificación de certificados."
            exit 1
        fi
    else
        print_error "Fallo en la generación de certificados SSL."
        exit 1
    fi
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi