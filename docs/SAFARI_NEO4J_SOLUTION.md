# Solución para Neo4j en Safari

## Problema
Safari no permite conexiones no encriptadas a Neo4j Browser, mostrando el error:
```
Unencrypted connections are not supported in Safari. Try another browser.
```

## Soluciones Disponibles

### Opción 1: Usar otro navegador (Recomendado)
**✅ SOLUCIÓN INMEDIATA:** Usar Chrome, Firefox o Edge para acceder a Neo4j Browser.

- **Chrome**: http://localhost:7474
- **Firefox**: http://localhost:7474  
- **Edge**: http://localhost:7474

### Opción 2: Configurar HTTPS para Neo4j (En desarrollo)
Se está configurando SSL/TLS para Neo4j para compatibilidad completa con Safari.

**Estado actual:**
- ✅ Certificados SSL generados
- ⚠️ Configuración de Neo4j en proceso
- 🔄 Puerto HTTPS: 7473 (cuando esté disponible)

### Opción 3: Acceso vía API REST
Neo4j también se puede usar programáticamente sin navegador:

```bash
# Test de conectividad
curl -u neo4j:adminpassword -H "Content-Type: application/json" \
     -d '{"statements":[{"statement":"MATCH (n) RETURN COUNT(n) as nodes"}]}' \
     http://localhost:7474/db/neo4j/tx/commit
```

## URLs de Acceso

| Servicio | HTTP | HTTPS | Estado |
|----------|------|-------|--------|
| **Neo4j Browser** | http://localhost:7474 | https://localhost:7473 | ⚠️ HTTP funciona |
| **Neo4j API** | http://localhost:7474/db/neo4j/tx/commit | - | ✅ Funcionando |
| **Bolt Protocol** | neo4j://localhost:7687 | - | ✅ Funcionando |

## Credenciales
- **Usuario**: neo4j
- **Contraseña**: adminpassword

## Verificación del Estado

```bash
# Verificar estado de contenedores
docker ps | grep neo4j

# Verificar logs
docker logs datalive-neo4j --tail 20

# Test de conectividad HTTP
curl -I http://localhost:7474

# Test de conectividad HTTPS (cuando esté listo)
curl -k -I https://localhost:7473
```

## Workaround Temporal para Safari
Mientras se configura HTTPS completamente, usar:

1. **Chrome/Firefox** para Neo4j Browser
2. **DataLive Agent API** (puerto 8058) funciona perfectamente en Safari
3. **N8N Interface** (puerto 5678) funciona perfectamente en Safari

Todos los demás servicios del sistema DataLive son completamente compatibles con Safari.