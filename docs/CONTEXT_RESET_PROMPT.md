# 🧠 DataLive Context Reset Prompt

**Use este prompt cuando Claude Desktop pierda el contexto del proyecto para reestablecer el estado completo del desarrollo.**

---

## 📋 Prompt de Reset de Contexto

```
Hola Claude, necesito que te recontextualices completamente sobre el proyecto DataLive en el que estamos trabajando. 

INSTRUCCIONES PARA LA RECONTEXTUALIZACIÓN:

1. **PRIMER PASO - Lee la documentación base:**
   - Lee completamente `/docs/CLAUDE.md` (guía principal para Claude Code)
   - Lee `/docs/datalive_complete_project.md` (estado detallado del proyecto)
   - Lee `/README.md` (descripción general)

2. **SEGUNDO PASO - Analiza la estructura del código:**
   - Revisa `/docker-compose.yml` (arquitectura de servicios)
   - Examina `/datalive_agent/src/` (código Python principal)
   - Revisa `/datalive_agent/pyproject.toml` (dependencias)
   - Checa `/datalive_agent/tests/` (estado del testing)

3. **TERCER PASO - Entiende el estado actual:**
   - ¿Qué funciona completamente?
   - ¿Qué está parcialmente implementado?
   - ¿Cuáles son los problemas críticos identificados?
   - ¿Cuáles son las próximas tareas prioritarias?

4. **CONTEXTO DEL PROYECTO:**
   DataLive es un sistema de IA empresarial soberano que implementa RAG+KAG+CAG:
   - RAG: Búsqueda semántica con Qdrant
   - KAG: Grafo de conocimiento con Neo4j  
   - CAG: Análisis contextual/temporal con PostgreSQL+Redis
   
   ESTADO CRÍTICO: Los workflows de N8N están rotos y necesitan reescritura completa.

5. **DESPUÉS DE LEER TODO:**
   Resume en 3-4 párrafos:
   - El estado actual del proyecto
   - Los problemas críticos pendientes
   - Las próximas tareas prioritarias
   - Cómo puedes ayudar a continuar el desarrollo

¡Gracias! Una vez que hayas leído toda la documentación y código, dime que estás listo para continuar trabajando en DataLive.
```

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

**💡 Tip**: Guarda este prompt como favorito en Claude Desktop para recontextualización rápida cuando sea necesario.