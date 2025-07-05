# 🧠 DataLive Context Reset Prompt

**Use este prompt cuando Claude Desktop pierda el contexto del proyecto para reestablecer el estado completo del desarrollo.**

---

## 📋 Prompt de Reset de Contexto

```
Hola Claude, necesito que te recontextualices completamente sobre el proyecto DataLive en el que estamos trabajando. 

INSTRUCCIONES PARA LA RECONTEXTUALIZACIÓN:

1. **PRIMER PASO - Investigación de tecnologías actuales (SOLO GRATUITAS/OPEN SOURCE):**
   Antes de revisar el código, haz una búsqueda web actualizada (últimos 6 meses) sobre:
   
   **🔴 CRÍTICO - N8N Workflows (CORE del sistema - NO cambiar N8N):**
   - "N8N workflow best practices 2025" - Mejores prácticas para crear workflows
   - "N8N RAG workflow examples 2025" - Ejemplos de workflows RAG funcionales
   - "N8N API integration patterns 2025" - Patrones para integrar con APIs Python
   - "N8N knowledge graph workflow 2025" - Workflows para grafos de conocimiento
   - "N8N error handling best practices 2025" - Manejo de errores en workflows
   - "N8N parallel processing workflows 2025" - Ejecución paralela de estrategias
   - "N8N database integration patterns 2025" - Conexiones con PostgreSQL, Neo4j, Qdrant
   
   **⚡ ACTUALIZACIONES DE VERSIONES:**
   - "Ollama phi4 vs phi3 performance 2025" - Comparación y mejoras
   - "pgvector latest version features 2025" - Nuevas funcionalidades
   - "Neo4j community edition updates 2025" - Últimas versiones gratuitas
   - "Qdrant latest version improvements 2025" - Nuevas funcionalidades gratuitas
   - "FastAPI latest version optimization 2025" - Mejoras de rendimiento
   - "sentence-transformers new models 2025" - Modelos de embedding más eficientes
   - "asyncpg performance improvements 2025" - Optimizaciones de base de datos
   - "Redis latest features 2025" - Nuevas funcionalidades de caché
   
   **🚀 OPTIMIZACIONES ARQUITECTÓNICAS (sin cambiar stack base):**
   - "RAG reranking techniques 2025" - Mejores algoritmos de reordenamiento
   - "knowledge graph RAG integration 2025" - Patrones KAG mejorados
   - "vector database chunking strategies 2025" - Mejores técnicas de chunking
   - "LLM prompt engineering RAG 2025" - Optimización de prompts para RAG

2. **SEGUNDO PASO - Lee la documentación base:**
   - Lee completamente `/docs/CLAUDE.md` (guía principal para Claude Code)
   - Lee `/docs/datalive_complete_project.md` (estado detallado del proyecto)
   - Lee `/README.md` (descripción general)

3. **TERCER PASO - Analiza la estructura del código:**
   - Revisa `/docker-compose.yml` (arquitectura de servicios)
   - Examina `/datalive_agent/src/` (código Python principal)
   - Revisa `/datalive_agent/pyproject.toml` (dependencias)
   - Checa `/datalive_agent/tests/` (estado del testing)

4. **CUARTO PASO - Análisis de mejoras (SOLO GRATUITAS - NO CAMBIAR STACK BASE):**
   Compara las tecnologías actuales del proyecto con las encontradas en la búsqueda:
   - ¿Hay versiones más nuevas de las dependencias actuales? (ej: phi3→phi4, pgvector updates)
   - ¿Mejores prácticas para N8N workflows que resuelvan los problemas críticos?
   - ¿Patrones de integración N8N↔DataLive Agent más eficientes?
   - ¿Técnicas de reranking RAG+KAG+CAG más avanzadas?
   - ¿Optimizaciones de rendimiento sin cambiar tecnologías base?
   - ¿Mejores estructuras de workflow para procesamiento paralelo?

5. **QUINTO PASO - Entiende el estado actual:**
   - ¿Qué funciona completamente?
   - ¿Qué está parcialmente implementado?
   - ¿Cuáles son los problemas críticos identificados?
   - ¿Cuáles son las próximas tareas prioritarias?

6. **CONTEXTO DEL PROYECTO:**
   DataLive es un sistema de IA empresarial soberano que implementa RAG+KAG+CAG:
   - RAG: Búsqueda semántica con Qdrant
   - KAG: Grafo de conocimiento con Neo4j  
   - CAG: Análisis contextual/temporal con PostgreSQL+Redis
   
   **🔴 PROBLEMA CRÍTICO PRINCIPAL**: Los workflows de N8N no están funcionando correctamente.
   **⚠️ RESTRICCIONES**: Solo soluciones gratuitas/open source. N8N es CORE inmutable.
   **🎯 ENFOQUE**: Actualizaciones de versiones, mejores prácticas N8N, optimizaciones sin cambio de stack.

7. **DESPUÉS DE LEER TODO:**
   Resume en 4-5 párrafos:
   - El estado actual del proyecto
   - **PROBLEMA CRÍTICO**: Específicamente los issues con workflows N8N y cómo resolverlos
   - **RECOMENDACIONES GRATUITAS**: Solo actualizaciones de versión, mejores prácticas N8N, optimizaciones
   - Las próximas tareas prioritarias (priorizar N8N workflows como crítico)
   - Cómo puedes ayudar especialmente con los workflows N8N y integraciones RAG+KAG+CAG

¡Gracias! Una vez que hayas leído toda la documentación y código, dime que estás listo para continuar trabajando en DataLive.
```

---

## 🚀 Proceso de Modernización Continua

**Cada reset de contexto debe incluir evaluación de:**

### 🔍 Áreas de Búsqueda Prioritarias (SOLO GRATUITAS)
1. **🔴 CRÍTICO - N8N Workflows**: Mejores prácticas, patrones de integración, ejemplos funcionales
2. **⚡ Actualizaciones de Versión**: phi3→phi4, pgvector updates, Neo4j community, Qdrant features
3. **🚀 Optimizaciones RAG+KAG+CAG**: Reranking algorithms, chunking strategies, prompt engineering
4. **🔧 Integraciones**: Mejores patrones N8N↔Python, database connections, error handling
5. **📈 Performance**: FastAPI optimizations, async patterns, embedding models efficiency
6. **🐳 Container Optimizations**: Docker compose best practices, healthcheck improvements
7. **📊 Monitoring Enhancements**: Prometheus/Grafana optimizations (NO alternativas de pago)
8. **🔒 Security Updates**: Nuevas prácticas gratuitas para IA empresarial

### ⚡ Criterios de Evaluación para Cambios (RESTRICCIONES APLICABLES)
- **GRATUITO**: ¿Es completamente gratuito/open source?
- **SIN CAMBIO DE STACK**: ¿Funciona con tecnologías actuales (N8N, Qdrant, Neo4j, etc.)?
- **Rendimiento**: ¿Mejora significativa en velocidad o eficiencia?
- **N8N Workflows**: ¿Ayuda a resolver los problemas críticos de workflows?
- **Compatibilidad**: ¿Migración viable sin romper funcionalidad existente?
- **Mantenibilidad**: ¿Simplifica el código o la arquitectura actual?

### 🎯 Tipos de Recomendaciones PERMITIDAS
- **Actualizaciones de versión**: Nuevas versiones estables de dependencias actuales
- **Mejores prácticas N8N**: Patrones de workflow más eficientes y funcionales
- **Optimizaciones de rendimiento**: Técnicas que mejoren velocidad sin cambiar stack
- **Configuraciones mejoradas**: Settings y configuraciones más óptimas
- **Patrones de integración**: Mejores formas de conectar N8N con DataLive Agent
- **Algoritmos de reranking**: Técnicas RAG+KAG+CAG más avanzadas pero gratuitas

---

## 🔧 Comandos de Verificación Rápida

**Después del reset de contexto, ejecuta estos comandos para verificar el estado:**

```bash
# 1. Verificar servicios
docker-compose ps

# 2. Health check rápido
./claude_desktop/scripts/quick-health-check.sh

# 3. Test de API
curl -X GET http://localhost:8058/health

# 4. Revisar logs recientes
docker-compose logs datalive_agent --tail=20

# 5. Estado de tests
cd datalive_agent && python tests/run_all_tests.py --quick
```

---

## 📊 Estado del Proyecto (Referencia Rápida)

### ✅ Completado (100%)
- Infraestructura Docker (todos los servicios)
- Configuración de base de datos (PostgreSQL, Neo4j, Qdrant)
- Health checks y monitoreo
- Estructura base de la aplicación Python

### 🔄 En Desarrollo (85%)
- APIs REST de DataLive Agent
- Lógica de agentes RAG/KAG/CAG
- Pipeline de ingesta de documentos
- Sistema de métricas

### ❌ Crítico - No Funcional (30%)
- **🔴 WORKFLOWS N8N** (PROBLEMA PRINCIPAL - requieren reescritura completa)
- Integración N8N ↔ DataLive Agent
- Router inteligente de estrategias
- Tests end-to-end completos

### 🎯 Próximas Prioridades (ENFOQUE N8N)
1. **🔴 CRÍTICO: Arreglar workflows N8N** (máxima prioridad)
2. **Mejorar patrones N8N-Python integration** (alta prioridad)
3. **Implementar router de estrategias en N8N** (alta prioridad)
4. **Actualizar versiones de dependencias** (media prioridad)
5. **Testing end-to-end workflows** (media prioridad)

---

## 🗂️ Archivos Clave para Revisión

### Documentación Principal
- `/docs/CLAUDE.md` - Guía para Claude Code
- `/docs/datalive_complete_project.md` - Estado detallado
- `/README.md` - Descripción general

### Configuración
- `/docker-compose.yml` - Orquestación de servicios
- `/datalive_agent/pyproject.toml` - Dependencias Python
- `/.env` - Variables de entorno

### Código Principal
- `/datalive_agent/src/main.py` - Entry point
- `/datalive_agent/src/agents/unified_agent.py` - Agente principal
- `/datalive_agent/src/api/routes.py` - Endpoints REST
- `/datalive_agent/src/core/database.py` - Conexiones DB

### Workflows Problemáticos
- `/datalive_agent/n8n_workflows/` - Workflows rotos de N8N

### Testing
- `/datalive_agent/tests/run_all_tests.py` - Suite de tests
- `/datalive_agent/tests/test_*.py` - Tests específicos

---

## 🚨 Recordatorios Críticos

1. **🔴 PROBLEMA PRINCIPAL: N8N Workflows están ROTOS** - Enfocar esfuerzos aquí
2. **⚠️ RESTRICCIÓN ABSOLUTA**: Solo soluciones gratuitas/open source
3. **🔒 N8N ES CORE INMUTABLE**: NO proponer alternativas a N8N
4. **⚡ ENFOQUE EN**: Actualizaciones versión, mejores prácticas N8N, optimizaciones
5. **🔑 API Key**: `datalive-dev-key-change-in-production`
6. **🚀 Golden Path**: `docker-compose up -d` inicia todo automáticamente
7. **🧪 Tests**: `python tests/run_all_tests.py` para verificar estado

---

## 📋 Registro de Modernización

**Después de cada reset de contexto con búsqueda web, Claude debe crear/actualizar:**

### 📄 Archivo: `/docs/TECH_MODERNIZATION_LOG.md`
```markdown
# Log de Modernización Tecnológica - DataLive

## [Fecha] - Reset de Contexto #N

### 🔍 Búsquedas Realizadas
- Lista de términos de búsqueda utilizados
- Fuentes principales consultadas

### 💡 Recomendaciones Identificadas (SOLO GRATUITAS)
1. **[Categoría]**: Descripción de la mejora
   - **Tecnología actual**: X
   - **Mejora/Actualización sugerida**: Y (DEBE SER GRATUITA)
   - **Beneficios**: Lista de beneficios
   - **Tipo**: Actualización versión / Mejores prácticas N8N / Optimización
   - **Prioridad**: Baja/Media/Alta (N8N siempre Alta)
   - **Compatibilidad**: Notas sobre implementación sin cambiar stack

### ✅ Acciones Priorizadas
- [ ] Acción 1 (Prioridad Alta)
- [ ] Acción 2 (Prioridad Media)
- [ ] Acción 3 (Prioridad Baja)

### 📚 Referencias
- Enlaces a documentación relevante
- Artículos o estudios consultados
```

### 🔄 Proceso de Actualización
1. **Cada reset**: Revisar log anterior y añadir nuevos hallazgos
2. **Marcar completadas**: Actualizar acciones ya implementadas
3. **Priorizar**: Reorganizar lista según importancia actual
4. **Validar**: Confirmar que recomendaciones siguen siendo relevantes

---

**💡 Tips Críticos**:
- Guarda este prompt como favorito en Claude Desktop para recontextualización rápida
- **🔴 PRIORIDAD #1**: Siempre enfocar en resolver problemas de workflows N8N
- **⚠️ SOLO GRATUITO**: Rechazar cualquier solución de pago o propietaria
- **🔒 N8N INMUTABLE**: No proponer alternativas a N8N, solo mejorarlo
- Realizar búsqueda web ANTES de revisar código para evitar sesgo
- Buscar específicamente actualizaciones de versión (phi3→phi4, pgvector, etc.)
- Enfocarse en mejores prácticas de N8N workflows y patrones de integración