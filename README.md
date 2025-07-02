# 🧠 DataLive - Sistema de Inteligencia Empresarial Soberano

[![Status](https://img.shields.io/badge/Status-Operacional-success)]()
[![Automation](https://img.shields.io/badge/Automation-100%25-brightgreen)]()
[![Deploy](https://img.shields.io/badge/Deploy-Golden_Path-gold)]()
[![License](https://img.shields.io/badge/License-Open_Source-blue)]()

**DataLive** es un sistema de inteligencia empresarial **soberano y completamente automatizado** que democratiza el acceso al conocimiento organizacional. Combina las técnicas más avanzadas de IA (RAG+KAG+CAG) en una solución 100% auto-alojada y lista para producción.

## 🎯 ¿Qué es DataLive?

DataLive actúa como el **cerebro de conocimiento centralizado** de tu organización, permitiendo a los empleados obtener respuestas precisas y auditables a preguntas complejas a través de sus herramientas habituales (Slack, Teams, etc.), conectándose de forma segura a todas las fuentes de datos empresariales.

### 🔑 Características Únicas

- **🚀 Golden Path Deployment**: Despliegue completo con un solo comando
- **🤖 100% Automatizado**: N8N, credenciales, workflows - todo configurado automáticamente
- **🧠 Triple IA**: RAG + KAG + CAG para máxima precisión
- **🔒 Soberanía Completa**: Todos los datos y procesamiento en tu infraestructura
- **⚡ Listo para Producción**: 83% de servicios saludables desde el primer despliegue

## 🏗️ Arquitectura Híbrida (RAG+KAG+CAG)

```mermaid
graph TB
    subgraph \"🔍 Capa de Consulta\"
        UI[Slack/Teams/API] --> N8N[N8N Orchestrator]
    end
    
    subgraph \"🧠 Capa de Inteligencia\"
        N8N --> Agent[DataLive Agent]
        Agent --> RAG[RAG Engine]
        Agent --> KAG[KAG Engine] 
        Agent --> CAG[CAG Engine]
    end
    
    subgraph \"💾 Capa de Datos\"
        RAG --> Qdrant[(Qdrant\\nVectores)]
        KAG --> Neo4j[(Neo4j\\nGrafo)]
        CAG --> Postgres[(PostgreSQL\\nTemporal)]
    end
    
    subgraph \"🛠️ Capa de Procesamiento\"
        Ollama[Ollama\\nLLMs Locales] --> Agent
        MinIO[(MinIO\\nArchivos)] --> Agent
    end
```

### Estrategias de IA

- **🔍 RAG (Retrieval Augmented Generation)**: Búsqueda semántica para preguntas factuales
- **🕸️ KAG (Knowledge Augmented Generation)**: Grafo de conocimiento para preguntas relacionales  
- **⏰ CAG (Contextual Augmented Generation)**: Contexto temporal para análisis histórico

## ⚡ Quick Start - Golden Path

### Requisitos Mínimos
- Docker + Docker Compose
- 4GB RAM disponible
- 10GB espacio en disco
- Linux/macOS/Windows (WSL2)

### Despliegue Automático
```bash
# 1. Clonar repositorio
git clone https://github.com/tu-org/datalive.git
cd datalive

# 2. Despliegue con un comando (Golden Path)
./init-automated-configs/deploy-infrastructure.sh

# ✨ ¡Listo! El sistema está funcionando
```

### Acceso Inmediato
- **🤖 DataLive Agent**: http://localhost:8058/docs
- **🔄 N8N Workflows**: http://localhost:5678  
- **🕸️ Neo4j Browser**: http://localhost:7474
- **📊 Qdrant Dashboard**: http://localhost:6333/dashboard

## 🧪 Prueba Inmediata

```bash
# Ingestar tu primer documento
curl -X POST http://localhost:8058/api/v1/ingest \\
  -H 'Content-Type: application/json' \\
  -d '{\"source_type\": \"txt\", \"source\": \"DataLive es un sistema de IA empresarial\"}'

# Hacer tu primera consulta inteligente
curl -X POST http://localhost:8058/api/v1/query \\
  -H 'Content-Type: application/json' \\
  -d '{\"query\": \"¿Qué es DataLive?\"}'
```

## 🛠️ Stack Tecnológico

| Componente | Tecnología | Propósito |
|------------|------------|-----------|
| **🤖 IA Engine** | Ollama (Phi-4, Llama3) | LLMs locales sin dependencias externas |
| **🔍 Búsqueda Semántica** | Qdrant | Base de datos vectorial de alta performance |
| **🕸️ Grafo de Conocimiento** | Neo4j | Relaciones entre entidades y conceptos |
| **📊 Metadatos** | PostgreSQL | Datos estructurados y logs |
| **📁 Almacenamiento** | MinIO | Archivos (S3-compatible) |
| **🔄 Orquestación** | N8N | Workflows y automatización |
| **🐳 Infraestructura** | Docker + Poetry | Contenerización y dependencias |

## 📚 Documentación

### 📖 Para Usuarios
- **[README.md](README.md)** - Descripción del proyecto y quick start *(este archivo)*

### 🔧 Para Desarrolladores  
- **[docs/DOCUMENTACION_TECNICA.md](docs/DOCUMENTACION_TECNICA.md)** - Arquitectura, APIs, configuración técnica
- **[docs/PROCEDIMIENTOS_ESPECIALES.md](docs/PROCEDIMIENTOS_ESPECIALES.md)** - Automatización N8N, SSL, configuraciones avanzadas

### 📊 Para Gestión
- **[docs/PROJECT_STATE.md](docs/PROJECT_STATE.md)** - Estado del proyecto, hitos, tareas pendientes

## 🚀 Casos de Uso

### 🏢 Inteligencia Empresarial
```bash
# \"¿Qué proyectos están relacionados con IA en la empresa?\"
# → Combina RAG (documentos) + KAG (relaciones) + CAG (timeline)
```

### 📋 Gestión de Conocimiento
```bash
# \"¿Quién trabajó en el proyecto X el año pasado?\"
# → KAG encuentra relaciones persona-proyecto + CAG contexto temporal
```

### 🔍 Búsqueda Avanzada
```bash
# \"Documentos similares a este contrato\"
# → RAG búsqueda semántica + KAG entidades relacionadas
```

## 🔐 Características de Seguridad

- **🔒 Zero Trust**: Sin credenciales hardcodeadas
- **🔑 API Keys Automáticas**: Generación criptográfica segura
- **🛡️ Credenciales Cifradas**: Todas las credenciales cifradas en N8N
- **🌐 Red Privada**: Comunicación interna entre contenedores
- **📋 Audit Trail**: Logs completos de todas las operaciones

## 🏆 Estado del Proyecto

**✅ OPERACIONAL - 100% Automatizado**

- ✅ **Automatización Completa**: Golden Path despliega todo automáticamente
- ✅ **N8N 100% Funcional**: Owner, credenciales, workflows configurados
- ✅ **APIs Operacionales**: Ingesta, query, chat endpoints funcionando  
- ✅ **Documentación Completa**: Guías técnicas y de usuario actualizadas

Ver detalles completos en [📊 Estado del Proyecto](docs/PROJECT_STATE.md)

## 🤝 Contribuir

### Reportar Issues
```bash
# Para bugs o sugerencias
https://github.com/tu-org/datalive/issues
```

### Desarrollo Local
```bash
# Setup para desarrollo
git clone https://github.com/tu-org/datalive.git
cd datalive
./init-automated-configs/deploy-infrastructure.sh
```

## 📄 Licencia

Open Source - Ver [LICENSE](LICENSE) para detalles.

## 🆘 Soporte

- **📖 Documentación**: [docs/DOCUMENTACION_TECNICA.md](docs/DOCUMENTACION_TECNICA.md)
- **🔧 Troubleshooting**: Incluido en documentación técnica
- **💬 Comunidad**: GitHub Issues
- **📧 Contacto**: [tu-contacto@empresa.com]

---

## 🎉 ¿Por qué DataLive?

> *\"El conocimiento es poder, pero el conocimiento **accesible** es transformación\"*

DataLive no es solo otra solución de IA. Es el resultado de implementar las mejores prácticas de la industria en un sistema que:

- **⚡ Funciona desde el primer momento** (Golden Path)
- **🔒 Mantiene tus datos seguros** (100% auto-alojado)  
- **🧠 Combina múltiples tipos de IA** (RAG+KAG+CAG)
- **🛠️ Se integra con tus herramientas** (Slack, Teams, etc.)
- **📈 Escala con tu organización** (Arquitectura de microservicios)

### 🚀 Próximo Paso: Pruébalo Ahora

```bash
./init-automated-configs/deploy-infrastructure.sh
```

**En 10 minutos tendrás tu propio sistema de IA empresarial funcionando.**

---

*Construido con ❤️ para democratizar el acceso al conocimiento organizacional*