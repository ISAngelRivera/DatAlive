#!/bin/bash
echo "=== VERIFICACIÓN GOLDEN PATH DESPUÉS DE PGVECTOR ==="
echo ""

echo "🚀 Simulando despliegue desde cero..."
echo ""

echo "1. Deteniendo todos los servicios..."
cd ..
docker-compose down
echo ""

echo "2. Iniciando con Golden Path (docker-compose up -d)..."
docker-compose up -d
echo ""

echo "3. Esperando que todos los servicios estén listos (60 segundos)..."
sleep 60
echo ""

echo "4. Verificando sidecars automáticos..."
echo ""

echo "   PostgreSQL sidecar logs:"
docker logs datalive-postgres-init 2>/dev/null | tail -10 || echo "   Sin logs de postgres-init"
echo ""

echo "   Qdrant sidecar logs:"
docker logs datalive-qdrant-init 2>/dev/null | tail -5 || echo "   Sin logs de qdrant-init"
echo ""

echo "   Neo4j sidecar logs:"
docker logs datalive-neo4j-init 2>/dev/null | tail -5 || echo "   Sin logs de neo4j-init"
echo ""

echo "5. Verificando extensiones PostgreSQL automáticas:"
docker exec datalive-postgres psql -U datalive_user -d datalive_db -c "\dx" | grep -E "(vector|uuid|crypto)"
echo ""

echo "6. Verificando esquemas automáticos:"
docker exec datalive-postgres psql -U datalive_user -d datalive_db -c "\dn" | grep -E "(rag|cag|monitoring)"
echo ""

echo "7. Verificando tablas automáticas:"
echo "   RAG tables:"
docker exec datalive-postgres psql -U datalive_user -d datalive_db -c "\dt rag.*" | wc -l
echo "   CAG tables:"
docker exec datalive-postgres psql -U datalive_user -d datalive_db -c "\dt cag.*" | wc -l
echo "   Monitoring tables:"
docker exec datalive-postgres psql -U datalive_user -d datalive_db -c "\dt monitoring.*" | wc -l
echo ""

echo "8. Verificando servicios finales:"
echo -n "   Agent: "; curl -s http://localhost:8058/health >/dev/null 2>&1 && echo "✓ OK" || echo "✗ ERROR"
echo -n "   N8N: "; curl -s http://localhost:5678/healthz >/dev/null 2>&1 && echo "✓ OK" || echo "✗ ERROR"
echo -n "   Neo4j: "; curl -s http://localhost:7474 >/dev/null 2>&1 && echo "✓ OK" || echo "✗ ERROR"
echo ""

echo "9. Prueba de funcionalidad pgvector:"
docker exec datalive-postgres psql -U datalive_user -d datalive_db -c "SELECT '[1,2,3]'::vector <-> '[3,2,1]'::vector as test_distance;" | grep -E "[0-9]+\."
echo ""

echo "✅ GOLDEN PATH VERIFICATION COMPLETED"
echo ""
echo "💡 El Golden Path mantiene su automatismo completo con pgvector incluido"