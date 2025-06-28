#!/bin/bash
# backup-neo4j.sh - Automated Neo4j backup script

set -e

# Configuration
BACKUP_DIR="/Users/angelrivera/Desktop/GIT/DatAlive/docker/backups/neo4j"
NEO4J_CONTAINER="datalive-neo4j"
RETENTION_DAYS=7
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Create backup directory
mkdir -p "$BACKUP_DIR"

echo "Starting Neo4j backup at $TIMESTAMP"

# Stop database for consistent backup
docker exec $NEO4J_CONTAINER neo4j-admin database stop neo4j

# Create backup
docker exec $NEO4J_CONTAINER neo4j-admin database dump \
    --to-path=/backups/neo4j_backup_$TIMESTAMP.dump \
    neo4j

# Start database
docker exec $NEO4J_CONTAINER neo4j-admin database start neo4j

# Copy backup to host
docker cp $NEO4J_CONTAINER:/backups/neo4j_backup_$TIMESTAMP.dump \
    $BACKUP_DIR/

# Clean old backups
find $BACKUP_DIR -name "neo4j_backup_*.dump" -mtime +$RETENTION_DAYS -delete

echo "Neo4j backup completed: neo4j_backup_$TIMESTAMP.dump"

# Verify backup
if [ -f "$BACKUP_DIR/neo4j_backup_$TIMESTAMP.dump" ]; then
    echo "Backup verified successfully"
    exit 0
else
    echo "ERROR: Backup file not found"
    exit 1
fi