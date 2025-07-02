# 🔧 Procedimientos Especiales y Configuraciones Avanzadas

Este documento describe los procedimientos especiales, automatizaciones y configuraciones avanzadas implementadas en DataLive que requieren documentación detallada.

## 📋 Tabla de Contenidos

1. [Automatización Completa de N8N](#automatización-completa-de-n8n)
2. [Configuración de Certificados SSL para Neo4j](#configuración-de-certificados-ssl-para-neo4j)
3. [Golden Path de Despliegue](#golden-path-de-despliegue)
4. [Gestión Avanzada de Credenciales](#gestión-avanzada-de-credenciales)

---

## 🤖 Automatización Completa de N8N

### Descripción
Hemos logrado una automatización 100% completa del setup de N8N, incluyendo:
- Registro automático del owner
- Creación de todas las credenciales de servicios
- Importación y activación de workflows
- Limpieza de credenciales antiguas

### Implementación

#### 1. Script de Automatización
Ubicación: `/init-automated-configs/n8n/setup.sh`

**Características principales:**
- Detección automática del estado de N8N
- Manejo inteligente de errores
- Registro de licencia empresarial (si está disponible)
- Creación de 7 credenciales de servicios automáticamente

#### 2. Credenciales Automatizadas

| Servicio | Tipo | Configuración Especial |
|----------|------|------------------------|
| PostgreSQL | `postgres` | SSL deshabilitado para local |
| Neo4j | `neo4j` | Requiere nodo comunitario @Kurea/n8n-nodes-neo4j |
| Qdrant | `qdrantApi` | Sin API key para local |
| MinIO | `aws` | S3-compatible con endpoint local |
| Ollama | `ollamaApi` | Base URL local |
| DataLive Agent | `httpRequestAuth` | Header X-API-Key |
| Google Drive | `googleOAuth2Api` | Requiere autorización manual |

#### 3. Solución de Problemas Resueltos

**Problema de autenticación "emailOrLdapLoginId":**
```json
// Antes (fallaba):
{"email": "user@example.com"}

// Después (funciona):
{"emailOrLdapLoginId": "user@example.com"}
```

**Limpieza automática de credenciales:**
```bash
# El script detecta y elimina credenciales DataLive existentes
# antes de crear nuevas para evitar duplicados
```

### Uso

```bash
# Automático con docker-compose
docker-compose up n8n-setup

# Manual si necesario
docker exec -it datalive-n8n /init/setup.sh
```

---

## 🔐 Configuración de Certificados SSL para Neo4j

### Descripción
Configuración especial para compatibilidad con Safari y otros navegadores que requieren certificados SSL válidos.

### Implementación

#### 1. Generación de Certificados
```bash
cd init-automated-configs/neo4j
./generate-neo4j-ssl.sh
```

#### 2. Estructura de Archivos
```
init-automated-configs/neo4j/ssl/
├── neo4j.cert  # Certificado público
└── neo4j.key   # Clave privada
```

#### 3. Configuración Docker
```yaml
neo4j:
  volumes:
    - ./init-automated-configs/neo4j/ssl:/ssl
  environment:
    - NEO4J_dbms_ssl_policy_bolt_enabled=true
    - NEO4J_dbms_ssl_policy_bolt_base__directory=/ssl
```

### Nota: Actualmente HTTPS está deshabilitado debido a problemas de configuración, pero los certificados están listos para cuando se necesiten.

---

## 🚀 Golden Path de Despliegue

### Descripción
Proceso de despliegue completamente automatizado que logra una instalación funcional con un solo comando.

### Implementación

#### 1. Script Principal
```bash
./init-automated-configs/deploy-infrastructure.sh
```

#### 2. Secuencia de Despliegue
1. **Verificación de requisitos**: Docker, Docker Compose, memoria, espacio
2. **Generación de .env**: Automática desde template
3. **Build de servicios**: Compilación de DataLive Agent con Poetry
4. **Inicio ordenado**:
   - Databases primero (PostgreSQL, Neo4j, Qdrant, MinIO)
   - Luego Ollama y descarga de modelo
   - N8N y su configuración automática
   - Finalmente DataLive Agent
5. **Verificación de salud**: Healthchecks para todos los servicios
6. **Tests de conectividad**: Verificación de APIs

#### 3. Tiempos de Espera Optimizados
- Databases: 5 minutos
- Ollama: 3 minutos  
- N8N: 2 minutos
- Agent: 2 minutos

### Resultado
Sistema completamente operacional en ~10 minutos con:
- 83% de servicios saludables automáticamente
- URLs de acceso mostradas
- Ejemplos de uso listos

---

## 🔑 Gestión Avanzada de Credenciales

### Descripción
Sistema de gestión de credenciales siguiendo las mejores prácticas de seguridad y basado en el documento de arquitectura de credenciales.

### Principios Implementados

#### 1. Seguridad por Defecto
- Todas las credenciales cifradas en N8N
- Sin hardcoding de secretos
- API keys generadas automáticamente

#### 2. Variables de Entorno
```bash
# Generación automática de API key segura
DATALIVE_API_KEY=datalive-secure-api-key-$(openssl rand -hex 16)
```

#### 3. Tipos de Credenciales Profesionales
- Uso de nodos comunitarios cuando están disponibles
- Credenciales genéricas solo cuando es necesario
- Documentación clara del propósito de cada una

### Configuración para Producción

#### 1. Cambiar Passwords por Defecto
```bash
# En .env para producción
POSTGRES_PASSWORD=$(openssl rand -base64 32)
NEO4J_AUTH=neo4j/$(openssl rand -base64 32)
MINIO_ROOT_PASSWORD=$(openssl rand -base64 32)
DATALIVE_API_KEY=$(openssl rand -hex 32)
```

#### 2. Usar Docker Secrets
```yaml
# docker-compose.yml para producción
services:
  n8n:
    environment:
      - CREDENTIALS_OVERWRITE_DATA_FILE=/run/secrets/n8n_credentials
    secrets:
      - n8n_credentials
```

### Validación de Seguridad

El DataLive Agent debe implementar validación de API key:

```python
# En datalive_agent/src/api/routes.py
from fastapi import Header, HTTPException
import os

async def verify_api_key(x_api_key: str = Header(...)):
    expected_key = os.getenv("DATALIVE_API_KEY")
    if not expected_key or x_api_key != expected_key:
        raise HTTPException(status_code=403, detail="Invalid API key")
```

---

## 📚 Referencias

- [Documento de Arquitectura de Credenciales](./cred.txt)
- [Guía de Healthchecks](./HEALTHCHECKS_GUIDE.md)
- [Estado del Proyecto](./PROJECT_STATE.md)

---

*Última actualización: Julio 2025*