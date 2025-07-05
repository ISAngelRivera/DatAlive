# 🤖 Prompt para Claude Desktop - DataLive Project

Hola Claude Desktop (Opus),

Soy Claude Code y necesito que tomes el liderazgo del proyecto **DataLive** - un sistema de IA empresarial soberano con arquitectura **RAG+KAG+CAG**.

## 📋 TU MISIÓN

**Revisar, optimizar y completar** el sistema DataLive que está **90% operacional** pero necesita tu expertise para llevarlo al 100% y optimizarlo.

## 🚀 ESTADO ACTUAL

✅ **Infraestructura**: 100% automatizada (Golden Path funcional)  
✅ **PostgreSQL**: Actualizado con pgvector 0.8.0 automático  
✅ **Stack completo**: 10 servicios Docker orquestados  
✅ **APIs**: Agent FastAPI funcionando  
⚠️ **Workflows N8N**: Solo 30% completados (TU PRIORIDAD)  
⚠️ **Agents Python**: 70% implementados (necesita optimización)  

## 📚 DOCUMENTACIÓN QUE DEBES REVISAR

**EMPIEZA AQUÍ** - Lee en este orden:

1. **`/claude_desktop/HANDOFF_TO_CLAUDE_DESKTOP.md`** - **LEE ESTO PRIMERO** (estado completo, herramientas disponibles, tareas específicas)

2. **`/docs/datalive_complete_project.md`** - Documento técnico completo del proyecto (1,300+ líneas con toda la arquitectura)

3. **`/docs/ULTIMATE_WORKFLOW_DOCUMENTATION.md`** - Documentación de workflows RAG+KAG+CAG y estrategias de reranking

4. **`/datalive_agent/src/`** - Código Python de los agentes (necesita tu optimización)

## 🎯 LO QUE NECESITO QUE HAGAS

### 🥇 **PRIORIDAD 1: Workflows N8N (CRÍTICO)**
- Los workflows actuales no son funcionales
- Necesitas implementar RAG+KAG+CAG completo en N8N
- Usar scripts en `/claude_desktop/utilities/` para desarrollo

### 🥈 **PRIORIDAD 2: Optimizar Agentes Python**
- Revisar `/datalive_agent/src/agents/unified_agent.py`
- Mejorar algoritmos de reranking
- Optimizar router intelligence

### 🥉 **PRIORIDAD 3: Arquitectura General**
- Evaluar si RAG+KAG+CAG está bien diseñado
- Proponer mejoras arquitectónicas
- Documentar optimizaciones

## 🛠️ HERRAMIENTAS A TU DISPOSICIÓN

```bash
# Verificar estado actual
./claude_desktop/verify-pgvector.sh

# Scripts de desarrollo N8N
./claude_desktop/utilities/configure-mcp.sh
./claude_desktop/utilities/validate-ultimate-workflow.sh
./claude_desktop/utilities/deploy-ultimate-workflow.sh

# APIs para testing
curl http://localhost:8058/health
```

## ⚡ QUICK START

```bash
# 1. Verificar que todo funciona
./claude_desktop/verify-pgvector.sh

# 2. Probar API
curl http://localhost:8058/health

# 3. Revisar workflows existentes
ls -la datalive_agent/n8n_workflows/

# 4. Configurar desarrollo N8N
./claude_desktop/utilities/configure-mcp.sh
```

## 🎯 RESULTADO ESPERADO

Al final de tu trabajo, DataLive debe ser:
- ✅ 100% funcional para RAG+KAG+CAG
- ✅ Workflows N8N completos y operacionales
- ✅ Agentes Python optimizados
- ✅ Arquitectura validada y documentada
- ✅ APIs completamente funcionales

## 💡 CONTEXTO IMPORTANTE

- **Golden Path**: Sistema despliega con `docker-compose up -d`
- **PostgreSQL**: Ahora incluye pgvector 0.8.0 automático
- **Stack**: 10 servicios todos funcionando
- **Documentación**: Completa y actualizada
- **Scripts**: Herramientas de desarrollo listas

**El proyecto está en excelente estado técnico, solo necesita tu expertise para completar la funcionalidad de workflows y optimizar la arquitectura.**

¿Estás listo para tomar el liderazgo? **Empieza leyendo `/claude_desktop/HANDOFF_TO_CLAUDE_DESKTOP.md`**

---

*Handoff from Claude Code - El sistema está listo para tu expertise*