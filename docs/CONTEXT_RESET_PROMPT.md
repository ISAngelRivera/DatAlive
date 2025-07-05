# 🧠 DataLive Context Reset Prompt

**Use este prompt cuando Claude Desktop pierda el contexto del proyecto para reestablecer el estado completo del desarrollo.**

---

## 📋 Prompt de Reset de Contexto

```
Hola Claude, necesito que te recontextualices completamente sobre el proyecto DataLive en el que estamos trabajando. 

INSTRUCCIONES PARA LA RECONTEXTUALIZACIÓN:

1. **PRIMER PASO - Investigación de tecnologías actuales:**
   Antes de revisar el código, haz una búsqueda web actualizada (últimos 6 meses) sobre:
   - "RAG system best practices 2025" - Nuevas técnicas y optimizaciones
   - "vector database comparison 2025" - Alternativas a Qdrant o mejoras
   - "knowledge graph databases 2025" - Avances en Neo4j o nuevas opciones
   - "LLM orchestration frameworks 2025" - Alternativas a Ollama o mejoras
   - "FastAPI performance optimization 2025" - Nuevas técnicas de optimización
   - "Docker compose best practices 2025" - Mejoras en orquestación
   - "N8N workflow automation alternatives 2025" - Nuevas herramientas de workflow
   - "enterprise AI deployment patterns 2025" - Mejores prácticas de despliegue
   - "embedding models performance 2025" - Modelos más eficientes que sentence-transformers
   - "async Python database patterns 2025" - Mejoras en asyncpg, redis.asyncio

2. **SEGUNDO PASO - Lee la documentación base:**
   - Lee completamente `/docs/CLAUDE.md` (guía principal para Claude Code)
   - Lee `/docs/datalive_complete_project.md` (estado detallado del proyecto)
   - Lee `/README.md` (descripción general)

3. **TERCER PASO - Analiza la estructura del código:**
   - Revisa `/docker-compose.yml` (arquitectura de servicios)
   - Examina `/datalive_agent/src/` (código Python principal)
   - Revisa `/datalive_agent/pyproject.toml` (dependencias)
   - Checa `/datalive_agent/tests/` (estado del testing)

4. **CUARTO PASO - Comparación tecnológica:**
   Compara las tecnologías actuales del proyecto con las encontradas en la búsqueda:
   - ¿Hay versiones más nuevas de las dependencias actuales?
   - ¿Existen alternativas más eficientes o modernas?
   - ¿Hay patrones arquitectónicos mejores que podríamos adoptar?
   - ¿Qué mejoras de rendimiento o seguridad están disponibles?

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
   
   ESTADO CRÍTICO: Los workflows de N8N están rotos y necesitan reescritura completa.

7. **DESPUÉS DE LEER TODO:**
   Resume en 4-5 párrafos:
   - El estado actual del proyecto
   - Los problemas críticos pendientes
   - **RECOMENDACIONES DE MODERNIZACIÓN**: Tecnologías o prácticas nuevas que deberíamos considerar
   - Las próximas tareas prioritarias (incluyendo actualizaciones tecnológicas)
   - Cómo puedes ayudar a continuar el desarrollo manteniendo el proyecto actualizado

¡Gracias! Una vez que hayas leído toda la documentación y código, dime que estás listo para continuar trabajando en DataLive.
```

---

## 🚀 Proceso de Modernización Continua

**Cada reset de contexto debe incluir evaluación de:**

### 🔍 Áreas de Búsqueda Prioritarias
1. **Stack RAG/KAG/CAG**: Nuevos enfoques, frameworks emergentes
2. **Vector Databases**: Rendimiento, nuevas funcionalidades, alternativas
3. **LLM Orchestration**: Herramientas más eficientes que Ollama
4. **Workflow Automation**: Alternativas modernas a N8N o mejoras
5. **Python AI Stack**: Nuevas librerías para FastAPI, async, embeddings
6. **Containerization**: Mejoras en Docker, Kubernetes patterns
7. **Monitoring & Observability**: Herramientas más avanzadas que Prometheus/Grafana
8. **Security Patterns**: Nuevas prácticas de seguridad para IA empresarial

### ⚡ Criterios de Evaluación para Cambios
- **Rendimiento**: ¿Mejora significativa en velocidad o eficiencia?
- **Mantenibilidad**: ¿Simplifica el código o la arquitectura?
- **Escalabilidad**: ¿Mejor soporte para crecimiento empresarial?
- **Seguridad**: ¿Mejores prácticas de seguridad o compliance?
- **Ecosistema**: ¿Mayor adopción, mejor documentación, comunidad activa?
- **Compatibilidad**: ¿Migración viable sin romper funcionalidad existente?

### 🎯 Tipos de Recomendaciones Esperadas
- **Actualizaciones de versión**: Dependencias con nuevas versiones estables
- **Reemplazos tecnológicos**: Tecnologías obsoletas que deberían cambiarse
- **Mejoras arquitectónicas**: Patrones más modernos o eficientes
- **Optimizaciones de rendimiento**: Técnicas nuevas para mejorar velocidad
- **Funcionalidades emergentes**: Capacidades nuevas que agregar valor

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
- **Workflows N8N** (requieren reescritura completa)
- Integración N8N ↔ DataLive Agent
- Router inteligente de estrategias
- Tests end-to-end completos

### 🎯 Próximas Prioridades
1. **Arreglar workflows N8N** (crítico)
2. **Completar lógica de agentes** (alta)
3. **Implementar router de estrategias** (alta)
4. **Testing end-to-end** (media)

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

## 🚨 Recordatorios Importantes

1. **N8N Workflows están ROTOS** - No intentar usar los actuales
2. **API Key por defecto**: `datalive-dev-key-change-in-production`
3. **Puertos principales**: DataLive:8058, N8N:5678, Neo4j:7474
4. **Golden Path**: `docker-compose up -d` inicia todo automáticamente
5. **Tests**: Usar `python tests/run_all_tests.py` para verificar estado

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

### 💡 Recomendaciones Identificadas
1. **[Categoría]**: Descripción de la mejora
   - **Tecnología actual**: X
   - **Alternativa sugerida**: Y
   - **Beneficios**: Lista de beneficios
   - **Esfuerzo estimado**: Bajo/Medio/Alto
   - **Prioridad**: Baja/Media/Alta
   - **Compatibilidad**: Notas sobre migración

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

**💡 Tips Importantes**:
- Guarda este prompt como favorito en Claude Desktop para recontextualización rápida
- Siempre realizar la búsqueda web ANTES de revisar el código para evitar sesgo
- Buscar específicamente en últimos 6 meses para información más reciente
- Considerar tanto mejoras incrementales como cambios arquitectónicos mayores