// Knowledge Graph Schema for DataLive Enterprise RAG
// This file initializes the Neo4j database with the required schema

// Create constraints and indexes
CREATE CONSTRAINT entity_id_unique IF NOT EXISTS FOR (e:Entity) REQUIRE e.id IS UNIQUE;
CREATE CONSTRAINT document_id_unique IF NOT EXISTS FOR (d:Document) REQUIRE d.id IS UNIQUE;
CREATE CONSTRAINT event_id_unique IF NOT EXISTS FOR (e:Event) REQUIRE e.id IS UNIQUE;

// Create indexes for performance
CREATE INDEX entity_name_index IF NOT EXISTS FOR (e:Entity) ON (e.name);
CREATE INDEX entity_type_index IF NOT EXISTS FOR (e:Entity) ON (e.type);
CREATE INDEX document_title_index IF NOT EXISTS FOR (d:Document) ON (d.title);
CREATE INDEX event_date_index IF NOT EXISTS FOR (e:Event) ON (e.date);

// Entity types
CREATE (orgType:EntityType {name: 'Organization', description: 'Companies, departments, teams'});
CREATE (personType:EntityType {name: 'Person', description: 'People, employees, contacts'});
CREATE (techType:EntityType {name: 'Technology', description: 'Software, hardware, tools'});
CREATE (projectType:EntityType {name: 'Project', description: 'Projects, initiatives, programs'});
CREATE (processType:EntityType {name: 'Process', description: 'Business processes, workflows'});
CREATE (locationTitle:EntityType {name: 'Location', description: 'Offices, cities, countries'});

// Relationship types with descriptions
CREATE (partnershipRel:RelationshipType {
    name: 'PARTNERSHIP', 
    description: 'Business partnership or collaboration',
    confidence_threshold: 0.7
});

CREATE (ownershipRel:RelationshipType {
    name: 'OWNS', 
    description: 'Ownership relationship',
    confidence_threshold: 0.8
});

CREATE (worksForRel:RelationshipType {
    name: 'WORKS_FOR', 
    description: 'Employment relationship',
    confidence_threshold: 0.9
});

CREATE (usesRel:RelationshipType {
    name: 'USES', 
    description: 'Technology or tool usage',
    confidence_threshold: 0.6
});

CREATE (locatedAtRel:RelationshipType {
    name: 'LOCATED_AT', 
    description: 'Physical location',
    confidence_threshold: 0.8
});

CREATE (relatedToRel:RelationshipType {
    name: 'RELATED_TO', 
    description: 'General relationship',
    confidence_threshold: 0.5
});

// Sample entities (can be extended)
CREATE (datalive:Entity:Organization {
    id: 'datalive-org',
    name: 'DataLive',
    type: 'Organization',
    description: 'Enterprise RAG system',
    created_at: datetime(),
    aliases: ['DatAlive', 'DataLive System']
});

CREATE (rag:Entity:Technology {
    id: 'rag-tech',
    name: 'RAG',
    type: 'Technology',
    description: 'Retrieval-Augmented Generation',
    created_at: datetime(),
    aliases: ['Retrieval-Augmented Generation', 'RAG System']
});

CREATE (kag:Entity:Technology {
    id: 'kag-tech',
    name: 'Knowledge Graph',
    type: 'Technology',
    description: 'Knowledge Graph technology',
    created_at: datetime(),
    aliases: ['KG', 'Neo4j', 'Graph Database']
});

// Sample relationships
CREATE (datalive)-[:USES {
    confidence: 0.95,
    created_at: datetime(),
    source: 'system_initialization'
}]->(rag);

CREATE (datalive)-[:USES {
    confidence: 0.90,
    created_at: datetime(),
    source: 'system_initialization'
}]->(kag);

// Temporal event example
CREATE (launchEvent:Event {
    id: 'datalive-launch',
    date: datetime(),
    description: 'DataLive system launch',
    type: 'system_event',
    created_at: datetime()
});

CREATE (datalive)-[:OCCURRED_AT {
    confidence: 1.0,
    created_at: datetime()
}]->(launchEvent);

// Create schema info node
CREATE (schemaInfo:SchemaInfo {
    version: '1.0.0',
    created_at: datetime(),
    description: 'DataLive Enterprise RAG Knowledge Graph Schema',
    entity_types: ['Organization', 'Person', 'Technology', 'Project', 'Process', 'Location'],
    relationship_types: ['PARTNERSHIP', 'OWNS', 'WORKS_FOR', 'USES', 'LOCATED_AT', 'RELATED_TO']
});