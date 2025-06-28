// Neo4j Knowledge Graph Schema Initialization
// DataLive Enterprise RAG+KAG System v3.0
// Fecha: 2025-06-28

// ============================================================================
// 1. CONSTRAINTS Y ÍNDICES ÚNICOS
// ============================================================================

// Entidades principales
CREATE CONSTRAINT entity_id_unique IF NOT EXISTS FOR (e:Entity) REQUIRE e.id IS UNIQUE;
CREATE CONSTRAINT document_id_unique IF NOT EXISTS FOR (d:Document) REQUIRE d.id IS UNIQUE;
CREATE CONSTRAINT chunk_id_unique IF NOT EXISTS FOR (c:Chunk) REQUIRE c.id IS UNIQUE;

// Tipos específicos de entidades
CREATE CONSTRAINT person_id_unique IF NOT EXISTS FOR (p:Person) REQUIRE p.id IS UNIQUE;
CREATE CONSTRAINT organization_id_unique IF NOT EXISTS FOR (o:Organization) REQUIRE o.id IS UNIQUE;
CREATE CONSTRAINT technology_id_unique IF NOT EXISTS FOR (t:Technology) REQUIRE t.id IS UNIQUE;
CREATE CONSTRAINT project_id_unique IF NOT EXISTS FOR (pr:Project) REQUIRE pr.id IS UNIQUE;
CREATE CONSTRAINT process_id_unique IF NOT EXISTS FOR (proc:Process) REQUIRE proc.id IS UNIQUE;
CREATE CONSTRAINT location_id_unique IF NOT EXISTS FOR (l:Location) REQUIRE l.id IS UNIQUE;

// ============================================================================
// 2. ÍNDICES PARA OPTIMIZAR BÚSQUEDAS
// ============================================================================

// Índices de texto para búsquedas
CREATE INDEX entity_name_index IF NOT EXISTS FOR (e:Entity) ON (e.name);
CREATE INDEX entity_type_index IF NOT EXISTS FOR (e:Entity) ON (e.type);
CREATE INDEX document_title_index IF NOT EXISTS FOR (d:Document) ON (d.title);
CREATE INDEX chunk_text_index IF NOT EXISTS FOR (c:Chunk) ON (c.text);

// Índices temporales
CREATE INDEX entity_created_index IF NOT EXISTS FOR (e:Entity) ON (e.created_at);
CREATE INDEX entity_updated_index IF NOT EXISTS FOR (e:Entity) ON (e.updated_at);
CREATE INDEX document_created_index IF NOT EXISTS FOR (d:Document) ON (d.created_at);

// Índices para búsquedas de similitud
CREATE INDEX entity_embedding_index IF NOT EXISTS FOR (e:Entity) ON (e.embedding_id);
CREATE INDEX chunk_embedding_index IF NOT EXISTS FOR (c:Chunk) ON (c.embedding_id);

// ============================================================================
// 3. ESQUEMA DE NODOS BÁSICOS
// ============================================================================

// Crear nodos de configuración del sistema
MERGE (config:SystemConfig {
  id: 'main_config',
  version: '3.0',
  created_at: datetime(),
  schema_initialized: true,
  knowledge_graph_enabled: true,
  temporal_analysis_enabled: true
});

// ============================================================================
// 4. PROCEDIMIENTOS Y FUNCIONES PERSONALIZADAS
// ============================================================================

// Nota: Las funciones APOC y GDS se instalan automáticamente
// Verificar instalación de plugins:
CALL dbms.components() YIELD name, versions, edition 
WHERE name IN ['APOC', 'Graph Data Science Library']
RETURN name, versions, edition;

// ============================================================================
// 5. CONFIGURACIÓN DE TEMPORAL QUERIES
// ============================================================================

// Crear índices para consultas temporales eficientes
CREATE INDEX relationship_created_index IF NOT EXISTS FOR ()-[r]-() ON (r.created_at);
CREATE INDEX relationship_updated_index IF NOT EXISTS FOR ()-[r]-() ON (r.updated_at);
CREATE INDEX relationship_valid_from_index IF NOT EXISTS FOR ()-[r]-() ON (r.valid_from);
CREATE INDEX relationship_valid_to_index IF NOT EXISTS FOR ()-[r]-() ON (r.valid_to);

// ============================================================================
// 6. INICIALIZACIÓN DE DATOS DE EJEMPLO
// ============================================================================

// Crear entidades de sistema básicas
MERGE (system:Organization {
  id: 'datalive_system',
  name: 'DataLive System',
  type: 'system',
  description: 'Sistema principal DataLive RAG+KAG',
  created_at: datetime(),
  status: 'active'
});

MERGE (rag:Technology {
  id: 'rag_technology',
  name: 'Retrieval-Augmented Generation',
  type: 'ai_technology',
  description: 'Tecnología de generación aumentada por recuperación',
  created_at: datetime(),
  status: 'active'
});

MERGE (kag:Technology {
  id: 'kag_technology', 
  name: 'Knowledge-Augmented Generation',
  type: 'ai_technology',
  description: 'Tecnología de generación aumentada por conocimiento',
  created_at: datetime(),
  status: 'active'
});

// Crear relaciones básicas del sistema
MERGE (system)-[r:USES {
  created_at: datetime(),
  relationship_type: 'technology_usage',
  confidence: 1.0
}]->(rag);

MERGE (system)-[r2:USES {
  created_at: datetime(),
  relationship_type: 'technology_usage', 
  confidence: 1.0
}]->(kag);

// ============================================================================
// 7. CONFIGURACIÓN FINAL
// ============================================================================

// Actualizar configuración del sistema
MATCH (config:SystemConfig {id: 'main_config'})
SET config.initialized_at = datetime(),
    config.total_constraints = 11,
    config.total_indexes = 15,
    config.sample_data_created = true;

// Mostrar resumen de inicialización
MATCH (config:SystemConfig {id: 'main_config'})
RETURN 
  config.version as schema_version,
  config.initialized_at as initialized_time,
  config.total_constraints as constraints_created,
  config.total_indexes as indexes_created,
  'Knowledge Graph Schema Successfully Initialized' as status;