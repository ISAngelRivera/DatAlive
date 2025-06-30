# Documento Maestro de Arquitectura y Estado: DataLive
**Versión:** 3.0 (Plano Arquitectónico Canónico)
**Última Actualización:** 2025-06-30 11:15 CEST
**Arquitecto Principal:** N8N - DataLive

## 1. Principios y Directivas Fundamentales

### 1.1. Misión del Proyecto
**DataLive** es un sistema de inteligencia empresarial soberano, diseñado para actuar como el **cerebro de conocimiento centralizado** de una organización. Su misión es democratizar el acceso al conocimiento corporativo, permitiendo a los empleados obtener respuestas precisas y auditables a preguntas complejas a través de sus herramientas de colaboración habituales (e.g., **Microsoft Teams, Slack**), conectándose de forma segura a las fuentes de datos de la empresa (e.g., **Google Drive, SharePoint, Confluence, GitHub**).

### 1.2. Directivas del Arquitecto (Rol y Comportamiento)
* **Rol Principal:** Actuar como 'DataLive Principal Architect', un experto técnico riguroso especializado en soluciones de código abierto y auto-alojadas.
* **Principios de Interacción:**
    * **Precisión sobre Velocidad:** Las respuestas deben ser técnicamente precisas y justificadas, tomando el tiempo necesario para el análisis.
    * **Integridad del Código:** Es imprescindible no perder código. No se eliminará ni modificará ninguna línea sin un dictamen arquitectónico explícito y una justificación clara.
    * **Configuración Completa y Atómica:** Cada vez que se modifique un fichero de configuración, se proporcionará la versión completa y actualizada del mismo.

### 1.3. Principios Arquitectónicos
* **Núcleo Soberano, Conectores Universales:** El stack de procesamiento y almacenamiento es 100% gratuito y auto-alojado. El sistema está diseñado para conectar con fuentes de datos y APIs externas propietarias.
* **La Herramienta Correcta para Cada Trabajo:** Cada componente del stack se elige por ser el especialista en su dominio (Neo4j para grafos, Qdrant para vectores, etc.).

---

## 2. Mapa de Arquitectura del Sistema

El siguiente diagrama ilustra el flujo de datos y control entre los componentes del sistema.


```text
                                      +-------------------------------------------------------------------------+
                                      |                      NÚCLEO SOBERANO DATALIVE (Docker Stack)            |
                                      |                                                                         |
+--------------------------+          |   +---------------------------+        +-----------------------------+  |          +----------------------------+
| FUENTES DE DATOS         |          |   | CAPA DE ORQUESTACIÓN Y    |        | API Y LÓGICA DE APLICACIÓN  |  |          | DESTINOS DE NOTIFICACIÓN   |
| (Google Drive,           |--Ingesta-->| CONECTORES (n8n)            |------> | (datalive_agent)            |--Respuesta-->| (Slack, Teams, etc.)       |
| SharePoint, Confluence)  |<--Consulta--|                           |<------ |                             |  |          |                            |
+--------------------------+          |   +---------------------------+        +-------------+---------------+  |          +----------------------------+
                                      |                                        (Orquestador) |                 |
                                      |                                                      |                 |
                                      |                +-------------------------------------+-----------------+------------------+
                                      |                |                                     |                 |                  |
                                      |                V                                     V                 V                  V
                                      | +--------------------------+        +--------------------------+       +------------------+       +---------------+
                                      | |      GRAFO (Neo4j)       |        |    VECTORES (Qdrant)     |       | METADATOS (PostgreSQL)|       | FICHEROS (MinIO)|
                                      | +--------------------------+        +--------------------------+       +------------------+       +---------------+
                                      | (Relaciones, Entidades)             | (Embeddings, Búsqueda Semántica)|  (Chunks, Logs, Caché) |   (PDFs, DOCX)    |
                                      |                                                                         |                  |                  |
                                      |                ^                                     ^                 ^                  ^                  |
                                      |                |                                     |                 |                  |                  |
                                      |                +-------------------------------------+-----------------+------------------+                  |
                                      |                                        (LLMs Locales - Ollama)         (Inferencia)                         |
                                      |                                                                                                               |
                                      +---------------------------------------------------------------------------------------------------------------+
```


## 3. Stack Tecnológico y Justificación

| Componente | Tecnología | Rol en la Arquitectura |
| :--- | :--- | :--- |
| **Orquestación** | Docker Compose | Define, configura y ejecuta todo el ecosistema de servicios de forma coherente. |
| **Agente Principal** | Python (FastAPI) | `datalive_agent`: El cerebro del sistema. Expone la API y contiene la lógica de agentes. |
| **Base de Datos Relacional** | PostgreSQL | Almacena datos estructurados: metadatos de documentos, chunks de texto, caché de consultas y logs de monitorización. |
| **Base de Datos de Grafo** | Neo4j | El corazón del KAG. Modela el conocimiento de la empresa como un grafo de entidades y relaciones. |
| **Base de Datos Vectorial** | Qdrant | Motor de búsqueda semántica. Almacena los embeddings para encontrar información por su significado. |
| **Almacenamiento de Objetos** | MinIO | Repositorio para ficheros binarios (PDFs, DOCX, imágenes) compatible con el estándar S3. |
| **Automatización** | n8n | Capa de conectores. Gestiona los flujos de trabajo para la ingesta de datos y la entrega de respuestas. |
| **Inferencia de IA** | Ollama | Servidor para la ejecución local y privada de los Modelos de Lenguaje Grandes (LLMs). |
| **Herramientas de Desarrollo** | Pyenv & Poetry | Garantizan entornos de desarrollo y dependencias 100% reproducibles y profesionales. |

---

## 4. Flujos de Datos y Procesos de Agente

### 4.1. Proceso Detallado de Ingesta y Construcción de Conocimiento
1.  **Disparo y Detección (n8n):** Un workflow de n8n se activa (periódicamente o por webhook), se conecta a la fuente (ej. SharePoint) y compara los metadatos de los ficheros con la tabla `rag.documents` para identificar deltas (ficheros nuevos/modificados).
2.  **Staging y Persistencia Atómica (MinIO + PostgreSQL):** Los ficheros nuevos se descargan a **MinIO**. Inmediatamente, se crea un registro en `rag.documents` en **PostgreSQL** con estado `pending`. Esto asegura que la operación es atómica y auditable.
3.  **Procesamiento y Chunking Semántico (`datalive_agent`):** El agente recupera el fichero, extrae su texto con parsers especializados y lo divide en "chunks" que respetan la estructura semántica (párrafos, tablas). Cada chunk se guarda en `rag.chunks`.
4.  **Enriquecimiento Vectorial (RAG):** Por cada chunk, se genera un embedding vectorial vía **Ollama** y se almacena en **Qdrant**, creando el índice para la búsqueda semántica.
5.  **Enriquecimiento de Grafo (KAG):** Cada chunk se analiza con un LLM para extraer entidades y relaciones. El agente ejecuta consultas **Cypher** para poblar **Neo4j**, creando un mapa de conocimiento interconectado y con referencias a los chunks de origen.
6.  **Finalización:** El estado del documento en `rag.documents` se actualiza a `completed`.

### 4.2. Proceso Detallado de Consulta (Ciclo del Agente Inteligente)
1.  **Gateway (Slack → n8n → Agente):** La pregunta de un usuario en Slack llega a n8n, que la reenvía de forma segura al endpoint `/query` del `datalive_agent`.
2.  **Agente de Análisis de Consulta:** Recibe la pregunta y usa un LLM para crear un "plan de ataque" en JSON, que incluye la intención, las entidades extraídas y sub-preguntas refinadas.
3.  **Agente de Ejecución e Investigación Híbrida:** Ejecuta el plan utilizando un conjunto de herramientas:
    * **Herramienta de Grafo:** Consulta **Neo4j** para obtener contexto estructural y relaciones directas.
    * **Herramienta Vectorial:** Realiza una búsqueda semántica en **Qdrant**, a menudo filtrada con los resultados del grafo para máxima precisión.
4.  **Agente de Calidad (Re-ranking):** Consolida los fragmentos de texto recuperados y utiliza un modelo `Cross-Encoder` para reordenarlos, garantizando que solo la evidencia más relevante pase al siguiente paso.
5.  **Agente de Síntesis:** Construye un prompt final con el contexto de máxima calidad (del grafo y de los textos) y se lo entrega a un LLM potente para generar la respuesta final, con citas y fuentes.
6.  **Cierre del Ciclo (Caché y Entrega):** La respuesta se guarda en la caché de **PostgreSQL** y se devuelve a **n8n**, que la formatea y la envía de vuelta a Slack.

---

## 5. Estado del Proyecto y Plan de Acción

### 5.1. Estructura de Ficheros (Estado Final Aprobado)

```
DatAlive/
├── docker-compose.yml
├── README.md
├── docs/
│   ├── PROJECT_STATE.md
│   └── SECURITY_DEBT.md
├── datalive_agent/
│   ├── Dockerfile
│   ├── poetry.lock
│   ├── pyproject.toml
│   ├── config/
│   │   └── agent_config.yaml
│   ├── n8n_workflows/
│   │   ├── enhanced/
│   │   ├── ingestion/
│   │   └── optimization/
│   ├── src/
│   │   ├── __init__.py
│   │   ├── main.py
│   │   ├── agents/
│   │   ├── api/
│   │   ├── config/
│   │   ├── core/
│   │   ├── ingestion/
│   │   └── tests/
│   │       ├── __init__.py
│   │       ├── conftest.py
│   │       ├── test_ingestion.py
│   │       ├── test_integration.py
│   │       ├── test_system_health.py
│   │       └── test_unified_agent.py
├── init-n8n/
│   ├── Dockerfile
│   └── setup-n8n.sh
├── init-neo4j/
│   └── 001-knowledge-graph-schema.cypher
├── init-postgres/
│   └── init.sql
```

### 5.2. Plan de Ejecución y Estado Actual
#### Fase 0: Cimentación y Arquitectura [✓ COMPLETADA]
El objetivo de esta fase fue establecer una base de código profesional y definir los principios del proyecto.
- **Tareas Completadas:**
    - `[✓]` Análisis del Repositorio Legado e identificación de riesgos.
    - `[✓]` Definición de Principios Arquitectónicos ("Núcleo Soberano", "Coste Cero", etc.).
    - `[✓]` Diseño del Stack Tecnológico especialista (Postgres, Neo4j, Qdrant, n8n, Ollama).
    - `[✓]` Refactorización y Limpieza de la Estructura de Ficheros del repositorio.
    - `[✓]` Estandarización del Flujo de Desarrollo (pyenv, Poetry).
    - `[✓]` Creación del Documento de Estado del Proyecto (`PROJECT_STATE.md`).

---

#### Fase 1: Infraestructura "One-Touch" [EN PROGRESO]
El objetivo de esta fase es tener un stack de infraestructura 100% automatizado, que se despliegue con un solo comando tras la configuración inicial del `.env`.

- **1.0. Diseño de la Infraestructura como Código:**
    - `[✓]` Diseño y refactorización del fichero `docker-compose.yml`.
    - `[✓]` Diseño de los scripts de inicialización de bases de datos (`init-postgres`, `init-neo4j`).
- **2.0. Tarea Crítica: Lograr el Primer Arranque Limpio y Verificable:**
    - `[ ]` **2.1. Resolver el fallo de arranque del contenedor `n8n`** (diagnóstico en curso sobre la carga de variables de entorno).
    - `[ ]` **2.2. Obtener una ejecución de `docker compose up --build` sin errores** ni advertencias críticas.
    - `[ ]` **2.3. Realizar la Verificación Post-Arranque** para confirmar que todos los servicios son accesibles y están correctamente inicializados.
- **3.0. Automatización Completa del Setup de n8n:**
    - `[ ]` **3.1. Implementación final del script `init-n8n/setup-n8n.sh`** para auto-registrar el usuario propietario y activar la licencia vía API.
    - `[ ]` **3.2. Implementar la creación automática de credenciales** para PostgreSQL, Neo4j, etc., a través de la API de n8n.
    - `[ ]` **3.3. Implementar la importación y activación automática** de los workflows desde la carpeta `datalive_agent/n8n_workflows/`.
- **4.0. Inicialización de Servicios Adicionales:**
    - `[ ]` **4.1. Crear un script `init-ollama.sh`** que descargue los modelos base (`phi3`, `nomic-embed-text`) al primer arranque.
    - `[ ]` **4.2. Crear un script `init-minio.sh`** que cree los `buckets` necesarios para la ingesta.

---

#### Fase 2: Lógica de Ingesta y Construcción del Conocimiento
El objetivo de esta fase es implementar el pipeline completo que lee de las fuentes de datos y puebla nuestras bases de conocimiento.

- **1.0. Conectividad de Datos en el `datalive_agent`:**
    - `[ ]` 1.1. Implementar la capa de acceso a datos para PostgreSQL.
    - `[ ]` 1.2. Implementar la capa de acceso a datos para Neo4j.
    - `[ ]` 1.3. Implementar la capa de acceso a datos para Qdrant y MinIO.
- **2.0. API de Ingesta (`/ingest`):**
    - `[ ]` 2.1. Desarrollar el endpoint que recibe ficheros desde n8n.
- **3.0. Pipeline de Procesamiento de Documentos:**
    - `[ ]` 3.1. Implementar los parsers para extraer texto de PDF, DOCX, etc.
    - `[ ]` 3.2. Implementar la lógica de "chunking" semántico.
- **4.0. Pipeline de Enriquecimiento Híbrido (RAG/KAG):**
    - `[ ]` 4.1. Integrar con Ollama para la generación de embeddings.
    - `[ ]` 4.2. Implementar la carga de vectores en Qdrant.
    - `[ ]` 4.3. Implementar la extracción de entidades y relaciones usando un LLM.
    - `[ ]` 4.4. Implementar la carga del grafo en Neo4j.
- **5.0. Garantía de Consistencia (Patrón Outbox):**
    - `[ ]` 5.1. Diseñar y crear la tabla `outbox` en PostgreSQL.
    - `[ ]` 5.2. Desarrollar el `worker` que procesa la cola y garantiza la sincronización segura con Neo4j.

---

#### Fase 3: Lógica de Consulta y Sistema de Agentes
El objetivo de esta fase es implementar la capacidad del sistema para entender y responder preguntas.

- **1.0. API de Consulta (`/query`):**
    - `[ ]` 1.1. Desarrollar el endpoint que recibe las preguntas desde n8n.
- **2.0. Implementación del `Agente de Análisis de Consulta`:**
    - `[ ]` 2.1. Integrar con un LLM para descomponer y refinar las preguntas de los usuarios.
- **3.0. Implementación del `Agente de Ejecución` y sus Herramientas:**
    - `[ ]` 3.1. Desarrollar la herramienta de consulta al grafo (KAG).
    - `[ ]` 3.2. Desarrollar la herramienta de búsqueda vectorial (RAG).
- **4.0. Implementación del `Agente de Calidad (Re-ranking)`:**
    - `[ ]` 4.1. Integrar un modelo Cross-Encoder local para la reordenación de resultados.
- **5.0. Implementación del `Agente de Síntesis`:**
    - `[ ]` 5.1. Construir la lógica de prompts para la generación de la respuesta final.
- **6.0. Implementación de la Caché de Consultas (CAG):**
    - `[ ]` 6.1. Desarrollar la lógica para guardar y recuperar respuestas de la tabla `cag.query_cache`.

---

#### Fase 4: Conectores, Pruebas y Despliegue (Resultado Final Idílico)
El objetivo de esta fase es finalizar el producto, asegurar su calidad y prepararlo para un entorno real.

- **1.0. Desarrollo de Workflows de n8n:**
    - `[ ]` 1.1. Workflow final para la ingesta desde Google Drive.
    - `[ ]` 1.2. Workflow final para la interacción bidireccional con Slack y/o Microsoft Teams.
    - `[ ]` 1.3. (Opcional) Workflows para otras fuentes de datos como Confluence o GitHub.
- **2.0. Pruebas de Calidad Exhaustivas:**
    - `[ ]` 2.1. Alcanzar una cobertura de pruebas unitarias superior al 85%.
    - `[ ]` 2.2. Crear una suite de pruebas de integración que valide los flujos de ingesta y consulta.
    - `[ ]` 2.3. Realizar pruebas de carga y rendimiento.
- **3.0. Preparación para Producción:**
    - `[ ]` 3.1. Remediación de toda la deuda técnica registrada en `SECURITY_DEBT.md`.
    - `[ ]` 3.2. Creación de un script de backup y restauración de los volúmenes de datos.
    - `[ ]` 3.3. Finalización de la documentación para el usuario/administrador.