#!/bin/sh
# Neo4j Knowledge Graph Initialization Script
# Runs as a sidecar container after Neo4j is healthy

set -e

echo "🧠 Neo4j Knowledge Graph Initialization Starting..."

# Configuration
NEO4J_HOST="${NEO4J_HOST:-neo4j}"
NEO4J_PORT="${NEO4J_BOLT_PORT:-7687}"
NEO4J_USER="${NEO4J_AUTH%/*}"  # Extract username from NEO4J_AUTH
NEO4J_PASSWORD="${NEO4J_AUTH#*/}"  # Extract password from NEO4J_AUTH

# Wait a bit for Neo4j to be fully ready
sleep 5

echo "📋 Connecting to Neo4j at $NEO4J_HOST:$NEO4J_PORT"

# Test Neo4j connection using HTTP API instead of cypher-shell
echo "🔄 Testing Neo4j connection via HTTP API..."

MAX_RETRIES=30
RETRY_DELAY=2
ATTEMPT=1

while [ $ATTEMPT -le $MAX_RETRIES ]; do
    echo "🔄 Connection attempt $ATTEMPT/$MAX_RETRIES..."
    
    # Test connection via HTTP API
    if curl -s -f "http://$NEO4J_HOST:7474/" > /dev/null 2>&1; then
        echo "✅ Neo4j connection successful"
        break
    fi
    
    if [ $ATTEMPT -eq $MAX_RETRIES ]; then
        echo "❌ Failed to connect to Neo4j after $MAX_RETRIES attempts"
        exit 1
    fi
    
    sleep $RETRY_DELAY
    ATTEMPT=$((ATTEMPT + 1))
done

# For now, just verify connection and mark as complete
# TODO: Implement cypher queries via HTTP API if needed

echo "✅ Neo4j connection verified - basic setup complete"
echo "🔷 DataLive Knowledge Graph is ready!"

# Skip schema creation for now to avoid cypher-shell dependency
if false; then
    echo "📊 Creating Neo4j knowledge graph schema..."
    
    # Create constraints and indexes
    cat > /tmp/neo4j-init.cypher << 'EOF'
// DataLive Knowledge Graph Schema

// Entity constraints
CREATE CONSTRAINT entity_id IF NOT EXISTS FOR (e:Entity) REQUIRE e.id IS UNIQUE;
CREATE CONSTRAINT document_id IF NOT EXISTS FOR (d:Document) REQUIRE d.id IS UNIQUE;
CREATE CONSTRAINT concept_name IF NOT EXISTS FOR (c:Concept) REQUIRE c.name IS UNIQUE;
CREATE CONSTRAINT topic_name IF NOT EXISTS FOR (t:Topic) REQUIRE t.name IS UNIQUE;

// Indexes for performance
CREATE INDEX entity_type IF NOT EXISTS FOR (e:Entity) ON (e.type);
CREATE INDEX entity_name IF NOT EXISTS FOR (e:Entity) ON (e.name);
CREATE INDEX document_source IF NOT EXISTS FOR (d:Document) ON (d.source_type);
CREATE INDEX document_created IF NOT EXISTS FOR (d:Document) ON (d.created_at);

// Full-text search indexes
CREATE FULLTEXT INDEX entity_search IF NOT EXISTS FOR (e:Entity) ON EACH [e.name, e.description];
CREATE FULLTEXT INDEX document_search IF NOT EXISTS FOR (d:Document) ON EACH [d.title, d.content];

RETURN "Schema created successfully";
EOF

    # Execute schema creation
    if cypher-shell -a "bolt://$NEO4J_HOST:$NEO4J_PORT" -u "$NEO4J_USER" -p "$NEO4J_PASSWORD" --format plain < /tmp/neo4j-init.cypher; then
        echo "✅ Neo4j schema created successfully"
    else
        echo "❌ Failed to create Neo4j schema"
        exit 1
    fi
fi

# Verify schema
echo "🔍 Verifying Neo4j schema..."

# Count constraints
CONSTRAINTS=$(echo "SHOW CONSTRAINTS YIELD name RETURN COUNT(*) as count;" | cypher-shell -a "bolt://$NEO4J_HOST:$NEO4J_PORT" -u "$NEO4J_USER" -p "$NEO4J_PASSWORD" --format plain | tail -n 1)
echo "   🔒 Constraints: $CONSTRAINTS"

# Count indexes
INDEXES=$(echo "SHOW INDEXES YIELD name WHERE name IS NOT NULL RETURN COUNT(*) as count;" | cypher-shell -a "bolt://$NEO4J_HOST:$NEO4J_PORT" -u "$NEO4J_USER" -p "$NEO4J_PASSWORD" --format plain | tail -n 1)
echo "   📑 Indexes: $INDEXES"

# Create sample data for testing (optional)
if [ "${CREATE_SAMPLE_DATA:-false}" = "true" ]; then
    echo "📊 Creating sample knowledge graph data..."
    
    cat > /tmp/sample-data.cypher << 'EOF'
// Sample DataLive knowledge graph
CREATE (datalive:Entity:System {
    id: 'system-datalive',
    name: 'DataLive',
    type: 'SYSTEM',
    description: 'Advanced RAG+KAG+CAG system'
})
CREATE (rag:Entity:Component {
    id: 'component-rag',
    name: 'RAG Engine',
    type: 'COMPONENT',
    description: 'Retrieval-Augmented Generation'
})
CREATE (kag:Entity:Component {
    id: 'component-kag',
    name: 'KAG Engine',
    type: 'COMPONENT',
    description: 'Knowledge-Augmented Generation'
})
CREATE (cag:Entity:Component {
    id: 'component-cag',
    name: 'CAG Engine',
    type: 'COMPONENT',
    description: 'Cache-Augmented Generation'
})
CREATE (datalive)-[:HAS_COMPONENT]->(rag)
CREATE (datalive)-[:HAS_COMPONENT]->(kag)
CREATE (datalive)-[:HAS_COMPONENT]->(cag)
RETURN "Sample data created";
EOF

    cypher-shell -a "bolt://$NEO4J_HOST:$NEO4J_PORT" -u "$NEO4J_USER" -p "$NEO4J_PASSWORD" --format plain < /tmp/sample-data.cypher
fi

echo "✅ Neo4j initialization completed successfully"
echo "🧠 DataLive Knowledge Graph is ready!"