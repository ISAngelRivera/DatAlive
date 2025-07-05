#!/bin/bash
echo "=== ACTUALIZANDO POSTGRESQL CON PGVECTOR ==="
echo ""

echo "1. Deteniendo contenedor postgres actual..."
docker stop datalive-postgres
echo ""

echo "2. Eliminando contenedor (manteniendo datos)..."
docker rm datalive-postgres
echo ""

echo "3. Iniciando nuevo contenedor con pgvector..."
cd ..
docker-compose up -d postgres
echo ""

echo "4. Esperando que PostgreSQL esté listo (30 segundos)..."
sleep 30
echo ""

echo "5. Verificando que pgvector está disponible..."
docker exec datalive-postgres psql -U datalive_user -d datalive_db -c "CREATE EXTENSION IF NOT EXISTS vector;"
echo ""

echo "6. Verificando extensiones instaladas:"
docker exec datalive-postgres psql -U datalive_user -d datalive_db -c "\dx"
echo ""

echo "7. Probando funcionalidad de vectores..."
docker exec datalive-postgres psql -U datalive_user -d datalive_db -c "SELECT vector '[1,2,3]' <-> vector '[3,2,1]' as distance;"
echo ""

echo "8. Iniciando resto de servicios..."
docker-compose up -d
echo ""

echo "✅ ACTUALIZACIÓN COMPLETADA"
echo "PostgreSQL ahora incluye pgvector y está listo para operaciones vectoriales"