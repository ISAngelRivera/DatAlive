#!/bin/bash
echo "=== FIXING DATALIVE INFRASTRUCTURE ==="
echo ""

# 1. Instalar pgvector
echo "1. Instalando pgvector..."
docker exec datalive-postgres psql -U datalive_user -d datalive_db -c "CREATE EXTENSION IF NOT EXISTS vector;"
echo ""

# 2. Verificar extensiones instaladas
echo "2. Extensiones PostgreSQL instaladas:"
docker exec datalive-postgres psql -U datalive_user -d datalive_db -c "\dx"
echo ""

# 3. Buscar archivos SQL de schema
echo "3. Archivos SQL encontrados:"
find .. -name "*.sql" -type f | grep -E "(schema|init|vector)" | head -10
echo ""

# 4. Verificar health del agent
echo "4. Verificando Agent:"
curl -s http://localhost:8058/health || echo "Agent no responde en :8058"
echo ""

# 5. Verificar estructura de base de datos actual
echo "5. Tablas actuales en PostgreSQL:"
docker exec datalive-postgres psql -U datalive_user -d datalive_db -c "\dt"
echo ""

# 6. Verificar esquemas
echo "6. Esquemas disponibles:"
docker exec datalive-postgres psql -U datalive_user -d datalive_db -c "\dn"
echo ""

# 7. Ejecutar init.sql si existe
echo "7. Ejecutando schema principal..."
if [ -f "../init-automated-configs/postgres/init.sql" ]; then
    echo "Ejecutando init.sql..."
    docker exec -i datalive-postgres psql -U datalive_user -d datalive_db < ../init-automated-configs/postgres/init.sql
else
    echo "init.sql no encontrado"
fi
echo ""

# 8. Verificar tablas después de init
echo "8. Tablas después de init:"
docker exec datalive-postgres psql -U datalive_user -d datalive_db -c "\dt rag.*"
echo ""
docker exec datalive-postgres psql -U datalive_user -d datalive_db -c "\dt cag.*"
echo ""
docker exec datalive-postgres psql -U datalive_user -d datalive_db -c "\dt monitoring.*"