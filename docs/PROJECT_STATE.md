# Documento de Estado del Proyecto: DataLive
**Versión:** 1.0
**Última Actualización:** 2025-06-29 23:55 CEST
**Arquitecto Principal:** N8N - DataLive

## Resumen Ejecutivo
Este documento es la "instantánea cerebral" del proyecto DataLive. Su propósito es actuar como un punto de restauración de contexto para el asistente de IA, garantizando la continuidad, la coherencia y la integridad del código y la arquitectura a lo largo del ciclo de vida del desarrollo.

---

## 1. Directivas Fundamentales para el Asistente (Rol y Comportamiento)

### 1.1. Rol Principal
Asumir el rol de **'DataLive Principal Architect'**, combinando la pericia de un Arquitecto de Sistemas Senior, un Ingeniero de Software Principal y un Revisor de Código implacable, especializado en soluciones autoalojadas y de código abierto.

### 1.2. Principios de Interacción
* **Tono y Estilo:** Las respuestas deben ser breves, concisas y precisas, pero sin sacrificar la justificación técnica. La claridad y la exactitud prevalecen sobre la verbosidad.
* **Principio de "Conservación de Código con Justificación Explícita":** Es imprescindible no perder código. No se eliminará ni modificará ninguna línea de código sin: a) Explicar qué hace, b) Justificar arquitectónicamente el cambio, y c) Obtener confirmación. La integridad es más importante que la velocidad.
* **Principio de "Configuración Completa y Atómica":** Cada vez que se modifique un fichero de configuración (`.env`, `docker-compose.yml`, etc.), se debe proporcionar la versión completa y actualizada del fichero, no fragmentos, para evitar errores de integración.

### 1.3. Directivas Arquitectónicas Clave
* **Directiva de Soberanía y Coste Cero:** El núcleo de la solución (`datalive` como programa) debe ser 100% gratuito, de código abierto y auto-alojado.
* **Principio de "Núcleo Soberano, Conectores Universales":** Se ha clarificado que la directiva de soberanía aplica al **stack de procesamiento y almacenamiento**, no a las fuentes de datos. El sistema está diseñado para conectar con servicios externos y propietarios (Google Drive, SharePoint, Slack, etc.). Las credenciales para estos conectores son una parte **permitida y necesaria** de la configuración.

---

## 2. Arquitectura y Decisiones de Diseño

### 2.1. Stack Tecnológico Aprobado
* **Orquestación:** Docker Compose
* **Agente Principal:** `datalive_agent` (Python 3.11+ con FastAPI)
* **Base de Datos Relacional:** PostgreSQL
* **Base de Datos de Grafo:** Neo4j Community Edition
* **Base de Datos Vectorial:** Qdrant
* **Almacenamiento de Objetos (S3):** MinIO
* **Automatización de Workflows:** n8n
* **Inferencia de LLMs:** Ollama

### 2.2. Patrones Arquitectónicos Implementados
* **Estructura de Ficheros Centralizada:** `docker-compose.yml` y `.env` en la raíz del proyecto como único punto de orquestación y configuración.
* **Configuración en Tres Niveles:**
    1.  `.env`: Secretos y localizadores de infraestructura (no versionado, salvo excepción temporal documentada).
    2.  `pyproject.toml`: Definición del paquete Python y sus dependencias (versionado).
    3.  `agent_config.yaml`: Parámetros de comportamiento de la aplicación (prompts, umbrales) (versionado).
* **Sidecar para Configuración de n8n:** Se utiliza un contenedor efímero (`n8n-setup`) para configurar n8n de forma automática y desatendida, manteniendo la imagen principal de n8n limpia.
* **Layout de Código `src`:** El código fuente del agente reside en `datalive_agent/src/` para evitar problemas de importación y mantener una estructura limpia.

### 2.3. Flujo de Trabajo de Desarrollo
* **Gestión de Dependencias:** Se utiliza **Poetry** como estándar único.
* **Gestión de Versiones de Python:** Se utiliza **pyenv** con un fichero `.python-version` local al proyecto para garantizar la consistencia.
* **Golden Path (Arranque):** `git clone` -> `cp .env.template .env` -> Rellenar `.env` -> `cd datalive_agent` -> `poetry lock` -> `cd ..` -> `docker compose up --build`.

---

## 3. Estado Actual y Plan de Proyecto

### 3.1. Estructura de Ficheros Final (Aprobada)

```
/DatAlive
├── .claude/
├── .env
├── .env.template
├── .git/
├── .gitattributes
├── .github/
│   └── workflows/
├── docker-compose.yml
├── README.md
├── datalive_agent/
│   ├── config/
│   │   └── agent_config.yaml
│   ├── Dockerfile
│   ├── n8n_workflows/
│   │   ├── enhanced/
│   │   │   └── unified-rag-workflow.json
│   │   ├── ingestion/
│   │   │   └── git-repository-ingestion.json
│   │   └── optimization/
│   │       └── query-pattern-optimizer.json
│   ├── pyproject.toml
│   ├── src/
│   │   ├── agents/
│   │   ├── api/
│   │   ├── config/
│   │   ├── core/
│   │   ├── ingestion/
│   │   ├── main.py
│   │   └── __init__.py
│   └── tests/
│       ├── conftest.py
│       ├── test_ingestion.py
│       ├── test_integration.py
│       ├── test_system_health.py
│       ├── test_unified_agent.py
│       └── __init__.py
├── docs/
├── neo4j-init/
│   └── 001-knowledge-graph-schema.cypher
├── postgres-init/
│   └── init.sql
├── scripts/
│   └── setup-n8n.sh
```

### 3.2. Plan de Ejecución
* **Fase 0: Limpieza y Estructuración** - `[✓] COMPLETADA`
* **Fase 1: Infraestructura y Despliegue "One-Touch"** - `[✓] COMPLETADA`
* **Fase 2: Verificación y Desarrollo de la Lógica del Agente** - `[EN PROGRESO]`
    * Verificar la salud de cada servicio post-arranque.
    * Implementar el patrón `outbox` en PostgreSQL.
    * Desarrollar el Orquestador V2 (router semántico).
    * Implementar el pipeline de búsqueda avanzada (re-ranking, etc.).

### 3.3. Checkpoint Actual
* **Último Hito Alcanzado:** Arranque exitoso de toda la infraestructura base mediante `docker compose up --build`. Se han resuelto todos los problemas de configuración del entorno local y de los ficheros de Docker.
* **Estado del Sistema:** Todos los servicios del stack base (PostgreSQL, Neo4j, n8n, Qdrant, MinIO, Ollama, datalive_agent) están en línea. La Fase 1 está validada.
* **Próxima Acción Inmediata:** Realizar una verificación post-arranque para confirmar la correcta inicialización y accesibilidad de cada servicio.

### 3.4 