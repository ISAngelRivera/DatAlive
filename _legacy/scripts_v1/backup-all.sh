#!/bin/bash
# backup-all.sh - Complete system backup

set -e

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_ROOT="/Users/angelrivera/Desktop/GIT/DatAlive/docker/backups"

echo "=== Starting DataLive Full Backup - $TIMESTAMP ==="

# 1. PostgreSQL (ya configurado con backup-service)
echo "PostgreSQL backup handled by backup-service container"

# 2. Neo4j
echo "Backing up Neo4j..."
./scripts/backup-neo4j.sh

# 3. Redis
echo "Backing up Redis..."
docker exec datalive-redis redis-cli BGSAVE
sleep 5
mkdir -p $BACKUP_ROOT/redis
docker cp datalive-redis:/data/dump.rdb $BACKUP_ROOT/redis/redis_backup_$TIMESTAMP.rdb

# 4. MinIO
echo "Backing up MinIO..."
mkdir -p $BACKUP_ROOT/minio
docker run --rm \
    --network=docker_backend \
    -v $BACKUP_ROOT/minio:/backup \
    -e MC_HOST_minio=http://datalive_admin:change_this_minio_password@minio:9000 \
    minio/mc \
    mirror --overwrite minio /backup/minio_backup_$TIMESTAMP

# 5. Configuration files
echo "Backing up configurations..."
mkdir -p $BACKUP_ROOT/config
tar -czf $BACKUP_ROOT/config/config_backup_$TIMESTAMP.tar.gz \
    docker/docker-compose*.yml \
    docker/config/ \
    docker/workflows/

echo "=== Backup completed successfully ==="
echo "Backup location: $BACKUP_ROOT"