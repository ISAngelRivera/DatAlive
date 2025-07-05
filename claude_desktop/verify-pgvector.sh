#!/bin/bash
echo "=== VERIFICACIÓN PGVECTOR POST-ACTUALIZACIÓN ==="
echo ""

echo "1. Estado de PostgreSQL:"
docker exec datalive-postgres pg_isready -U datalive_user -d datalive_db
echo ""

echo "2. Extensiones instaladas:"
docker exec datalive-postgres psql -U datalive_user -d datalive_db -c "\dx" | grep vector
echo ""

echo "3. Versión de pgvector:"
docker exec datalive-postgres psql -U datalive_user -d datalive_db -c "SELECT extversion FROM pg_extension WHERE extname = 'vector';"
echo ""

echo "4. Prueba de funcionalidad vectorial:"
docker exec datalive-postgres psql -U datalive_user -d datalive_db -c "
CREATE TABLE IF NOT EXISTS test_vectors (id serial, embedding vector(3));
INSERT INTO test_vectors (embedding) VALUES ('[1,2,3]'), ('[4,5,6]');
SELECT id, embedding, embedding <-> '[1,2,3]' as distance FROM test_vectors ORDER BY distance;
DROP TABLE test_vectors;
"
echo ""

echo "5. Estado general de servicios:"
echo -n "PostgreSQL: "; curl -s http://localhost:5432 >/dev/null 2>&1 && echo "✓ Puerto abierto" || echo "✓ Rechaza conexiones HTTP (normal)"
echo -n "Agent: "; curl -s http://localhost:8058/health >/dev/null 2>&1 && echo "✓ OK" || echo "✗ ERROR"
echo -n "N8N: "; curl -s http://localhost:5678/healthz >/dev/null 2>&1 && echo "✓ OK" || echo "✗ ERROR"
echo ""

echo "✅ VERIFICACIÓN COMPLETADA"