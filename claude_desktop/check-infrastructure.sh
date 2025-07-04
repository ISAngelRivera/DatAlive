#!/bin/bash
# Script simple de verificación de infraestructura DataLive

echo "=== VERIFICACIÓN INFRAESTRUCTURA DATALIVE ==="
echo "Fecha: $(date)"
echo ""

# 1. Contenedores Docker
echo "### CONTENEDORES DOCKER ###"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Image}}" | grep -E "datalive|NAME"
echo ""

# 2. Verificar servicios críticos
echo "### ESTADO DE SERVICIOS ###"
echo -n "PostgreSQL: "; docker exec datalive-postgres pg_isready -U postgres >/dev/null 2>&1 && echo "✓ OK" || echo "✗ ERROR"
echo -n "Redis: "; docker exec datalive-redis redis-cli ping >/dev/null 2>&1 && echo "✓ OK" || echo "✗ ERROR"
echo -n "Neo4j: "; curl -s http://localhost:7474 >/dev/null 2>&1 && echo "✓ OK" || echo "✗ ERROR"
echo -n "Unified Agent: "; curl -s http://localhost:8058/health >/dev/null 2>&1 && echo "✓ OK" || echo "✗ ERROR"
echo -n "N8N: "; curl -s http://localhost:5678/healthz >/dev/null 2>&1 && echo "✓ OK" || echo "✗ ERROR"
echo ""

# 3. Verificaciones específicas
echo "### VERIFICACIONES ESPECÍFICAS ###"
echo "PostgreSQL - pgvector:"
docker exec datalive-postgres psql -U postgres -d datalive -c "SELECT extname, extversion FROM pg_extension WHERE extname = 'vector';" 2>/dev/null || echo "No instalado"
echo ""

echo "Neo4j - Plugins:"
docker exec datalive-neo4j cypher-shell -u neo4j -p adminpassword "CALL dbms.procedures() YIELD name WHERE name STARTS WITH 'apoc' RETURN count(*) as apoc_procedures" 2>/dev/null || echo "Error conectando"
echo ""

echo "Ollama - Modelos:"
docker exec datalive-ollama ollama list 2>/dev/null || echo "Ollama no disponible"
echo ""

# 4. Logs recientes con errores
echo "### ERRORES RECIENTES (últimas 10 líneas) ###"
for service in postgres redis neo4j unified-agent n8n; do
    echo "=== $service ==="
    docker logs datalive-$service 2>&1 | grep -i error | tail -5 || echo "Sin errores"
done

echo ""
echo "=== FIN DE VERIFICACIÓN ==="