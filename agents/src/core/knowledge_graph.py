"""
Knowledge Graph implementation for DataLive Unified Agent
"""

import logging
from typing import Dict, Any, List, Optional
from datetime import datetime

from .database import get_neo4j_driver
from ..config import settings

logger = logging.getLogger(__name__)


class KnowledgeGraph:
    """Knowledge Graph using Neo4j for relationship storage and querying"""
    
    def __init__(self):
        self.driver = None
    
    async def initialize(self) -> bool:
        """Initialize knowledge graph connection"""
        try:
            self.driver = await get_neo4j_driver()
            await self._ensure_schema()
            logger.info("✅ Knowledge graph initialized")
            return True
        except Exception as e:
            logger.error(f"Failed to initialize knowledge graph: {e}")
            return False
    
    async def _ensure_schema(self):
        """Ensure required schema exists"""
        try:
            schema_queries = [
                # Create constraints
                "CREATE CONSTRAINT entity_id_unique IF NOT EXISTS FOR (e:Entity) REQUIRE e.id IS UNIQUE",
                "CREATE CONSTRAINT document_id_unique IF NOT EXISTS FOR (d:Document) REQUIRE d.id IS UNIQUE",
                
                # Create indexes
                "CREATE INDEX entity_name_index IF NOT EXISTS FOR (e:Entity) ON (e.name)",
                "CREATE INDEX entity_type_index IF NOT EXISTS FOR (e:Entity) ON (e.type)",
                "CREATE INDEX document_title_index IF NOT EXISTS FOR (d:Document) ON (d.title)"
            ]
            
            async with self.driver.session() as session:
                for query in schema_queries:
                    try:
                        await session.run(query)
                    except Exception as e:
                        logger.debug(f"Schema query result (may already exist): {e}")
            
            logger.info("Knowledge graph schema verified")
            
        except Exception as e:
            logger.error(f"Error ensuring schema: {e}")
            raise
    
    async def create_document_node(
        self,
        document_id: str,
        metadata: Dict[str, Any]
    ) -> bool:
        """Create document node in knowledge graph"""
        try:
            query = """
            MERGE (d:Document {id: $document_id})
            SET d.title = $title,
                d.source_type = $source_type,
                d.created_at = $created_at,
                d.updated_at = datetime()
            RETURN d
            """
            
            params = {
                "document_id": document_id,
                "title": metadata.get("title", "Untitled"),
                "source_type": metadata.get("source_type", "unknown"),
                "created_at": metadata.get("created_at", datetime.now().isoformat())
            }
            
            async with self.driver.session() as session:
                result = await session.run(query, params)
                await result.consume()
            
            logger.debug(f"Document node created: {document_id}")
            return True
            
        except Exception as e:
            logger.error(f"Error creating document node: {e}")
            return False
    
    async def create_entity(
        self,
        entity_id: str,
        entity_type: str,
        properties: Dict[str, Any],
        document_id: str
    ) -> bool:
        """Create entity node and link to document"""
        try:
            query = """
            MERGE (e:Entity {id: $entity_id})
            SET e.name = $name,
                e.type = $entity_type,
                e.confidence = $confidence,
                e.created_at = coalesce(e.created_at, datetime()),
                e.updated_at = datetime()
            
            MERGE (d:Document {id: $document_id})
            MERGE (e)-[:MENTIONED_IN]->(d)
            
            RETURN e
            """
            
            params = {
                "entity_id": entity_id,
                "entity_type": entity_type,
                "name": properties.get("name", entity_id),
                "confidence": properties.get("confidence", 0.8),
                "document_id": document_id
            }
            
            async with self.driver.session() as session:
                result = await session.run(query, params)
                await result.consume()
            
            logger.debug(f"Entity created: {entity_id}")
            return True
            
        except Exception as e:
            logger.error(f"Error creating entity: {e}")
            return False
    
    async def create_relationship(
        self,
        source_id: str,
        target_id: str,
        relationship_type: str,
        properties: Dict[str, Any],
        document_id: str
    ) -> bool:
        """Create relationship between entities"""
        try:
            # Sanitize relationship type for Cypher
            rel_type = relationship_type.upper().replace(" ", "_").replace("-", "_")
            
            query = f"""
            MATCH (source:Entity {{id: $source_id}})
            MATCH (target:Entity {{id: $target_id}})
            MATCH (d:Document {{id: $document_id}})
            
            MERGE (source)-[r:{rel_type}]->(target)
            SET r.confidence = $confidence,
                r.created_at = coalesce(r.created_at, datetime()),
                r.updated_at = datetime(),
                r.source_document = $document_id
            
            MERGE (r)-[:EVIDENCED_BY]->(d)
            
            RETURN r
            """
            
            params = {
                "source_id": source_id,
                "target_id": target_id,
                "confidence": properties.get("confidence", 0.7),
                "document_id": document_id
            }
            
            async with self.driver.session() as session:
                result = await session.run(query, params)
                await result.consume()
            
            logger.debug(f"Relationship created: {source_id} -{rel_type}-> {target_id}")
            return True
            
        except Exception as e:
            logger.error(f"Error creating relationship: {e}")
            return False
    
    async def find_entities(
        self,
        entity_name: str = None,
        entity_type: str = None,
        limit: int = 20
    ) -> List[Dict[str, Any]]:
        """Find entities by name or type"""
        try:
            conditions = []
            params = {"limit": limit}
            
            if entity_name:
                conditions.append("toLower(e.name) CONTAINS toLower($entity_name)")
                params["entity_name"] = entity_name
            
            if entity_type:
                conditions.append("e.type = $entity_type")
                params["entity_type"] = entity_type
            
            where_clause = "WHERE " + " AND ".join(conditions) if conditions else ""
            
            query = f"""
            MATCH (e:Entity)
            {where_clause}
            RETURN e.id as id, e.name as name, e.type as type, 
                   e.confidence as confidence, e.created_at as created_at
            LIMIT $limit
            """
            
            async with self.driver.session() as session:
                result = await session.run(query, params)
                records = await result.data()
            
            entities = []
            for record in records:
                entities.append({
                    "id": record["id"],
                    "name": record["name"],
                    "type": record["type"],
                    "confidence": record["confidence"],
                    "created_at": record["created_at"]
                })
            
            return entities
            
        except Exception as e:
            logger.error(f"Error finding entities: {e}")
            return []
    
    async def find_relationships(
        self,
        source_entity: str = None,
        target_entity: str = None,
        relationship_type: str = None,
        limit: int = 20
    ) -> List[Dict[str, Any]]:
        """Find relationships between entities"""
        try:
            conditions = []
            params = {"limit": limit}
            
            if source_entity:
                conditions.append("toLower(source.name) CONTAINS toLower($source_entity)")
                params["source_entity"] = source_entity
            
            if target_entity:
                conditions.append("toLower(target.name) CONTAINS toLower($target_entity)")
                params["target_entity"] = target_entity
            
            where_clause = "WHERE " + " AND ".join(conditions) if conditions else ""
            
            # Build relationship pattern
            rel_pattern = "[r]"
            if relationship_type:
                rel_type = relationship_type.upper().replace(" ", "_").replace("-", "_")
                rel_pattern = f"[r:{rel_type}]"
            
            query = f"""
            MATCH (source:Entity)-{rel_pattern}->(target:Entity)
            {where_clause}
            RETURN source.name as source_name, target.name as target_name,
                   type(r) as relationship_type, r.confidence as confidence,
                   r.created_at as created_at, r.source_document as source_document
            LIMIT $limit
            """
            
            async with self.driver.session() as session:
                result = await session.run(query, params)
                records = await result.data()
            
            relationships = []
            for record in records:
                relationships.append({
                    "source": record["source_name"],
                    "target": record["target_name"],
                    "type": record["relationship_type"],
                    "confidence": record["confidence"],
                    "created_at": record["created_at"],
                    "source_document": record["source_document"]
                })
            
            return relationships
            
        except Exception as e:
            logger.error(f"Error finding relationships: {e}")
            return []
    
    async def get_entity_neighbors(
        self,
        entity_name: str,
        max_depth: int = 2,
        limit: int = 50
    ) -> Dict[str, Any]:
        """Get entity and its neighbors up to max_depth"""
        try:
            query = """
            MATCH path = (center:Entity)-[*1..$max_depth]-(neighbor:Entity)
            WHERE toLower(center.name) CONTAINS toLower($entity_name)
            WITH center, neighbor, relationships(path) as rels
            RETURN center.name as center_name, center.type as center_type,
                   neighbor.name as neighbor_name, neighbor.type as neighbor_type,
                   [rel in rels | {type: type(rel), confidence: rel.confidence}] as relationship_path
            LIMIT $limit
            """
            
            params = {
                "entity_name": entity_name,
                "max_depth": max_depth,
                "limit": limit
            }
            
            async with self.driver.session() as session:
                result = await session.run(query, params)
                records = await result.data()
            
            # Organize results
            center_entities = set()
            neighbors = []
            
            for record in records:
                center_entities.add((record["center_name"], record["center_type"]))
                neighbors.append({
                    "name": record["neighbor_name"],
                    "type": record["neighbor_type"],
                    "relationship_path": record["relationship_path"]
                })
            
            return {
                "query_entity": entity_name,
                "found_entities": list(center_entities),
                "neighbors": neighbors,
                "total_neighbors": len(neighbors)
            }
            
        except Exception as e:
            logger.error(f"Error getting entity neighbors: {e}")
            return {"query_entity": entity_name, "error": str(e)}
    
    async def get_graph_stats(self) -> Dict[str, Any]:
        """Get knowledge graph statistics"""
        try:
            stats_query = """
            MATCH (e:Entity) 
            WITH count(e) as entity_count
            MATCH (d:Document)
            WITH entity_count, count(d) as document_count
            MATCH ()-[r]->()
            RETURN entity_count, document_count, count(r) as relationship_count
            """
            
            async with self.driver.session() as session:
                result = await session.run(stats_query)
                record = await result.single()
            
            if record:
                return {
                    "entities": record["entity_count"],
                    "documents": record["document_count"],
                    "relationships": record["relationship_count"]
                }
            else:
                return {"entities": 0, "documents": 0, "relationships": 0}
                
        except Exception as e:
            logger.error(f"Error getting graph stats: {e}")
            return {"error": str(e)}
    
    async def health_check(self) -> bool:
        """Perform health check on knowledge graph"""
        try:
            if not self.driver:
                return False
            
            # Test connection with simple query
            query = "MATCH (n) RETURN count(n) as node_count LIMIT 1"
            
            async with self.driver.session() as session:
                result = await session.run(query)
                await result.single()
            
            return True
            
        except Exception as e:
            logger.error(f"Knowledge graph health check failed: {e}")
            return False
    
    async def close(self):
        """Close knowledge graph connections"""
        if self.driver:
            try:
                await self.driver.close()
                logger.info("Knowledge graph connection closed")
            except Exception as e:
                logger.error(f"Error closing knowledge graph: {e}")


# Mock implementation for testing
class MockKnowledgeGraph:
    """Mock knowledge graph for testing/development"""
    
    def __init__(self):
        self.entities = {}
        self.relationships = []
        self.documents = {}
    
    async def initialize(self) -> bool:
        logger.warning("Using mock knowledge graph - configure Neo4j for full functionality")
        return True
    
    async def create_document_node(self, document_id: str, metadata: Dict[str, Any]) -> bool:
        self.documents[document_id] = metadata
        return True
    
    async def create_entity(self, entity_id: str, entity_type: str, properties: Dict[str, Any], document_id: str) -> bool:
        self.entities[entity_id] = {
            "type": entity_type,
            "properties": properties,
            "document_id": document_id
        }
        return True
    
    async def create_relationship(self, source_id: str, target_id: str, relationship_type: str, properties: Dict[str, Any], document_id: str) -> bool:
        self.relationships.append({
            "source": source_id,
            "target": target_id,
            "type": relationship_type,
            "properties": properties,
            "document_id": document_id
        })
        return True
    
    async def find_entities(self, entity_name: str = None, entity_type: str = None, limit: int = 20) -> List[Dict[str, Any]]:
        results = []
        for entity_id, entity_data in self.entities.items():
            if entity_name and entity_name.lower() not in entity_data["properties"].get("name", "").lower():
                continue
            if entity_type and entity_type != entity_data["type"]:
                continue
            
            results.append({
                "id": entity_id,
                "name": entity_data["properties"].get("name", entity_id),
                "type": entity_data["type"],
                "confidence": entity_data["properties"].get("confidence", 0.8)
            })
            
            if len(results) >= limit:
                break
        
        return results
    
    async def find_relationships(self, source_entity: str = None, target_entity: str = None, relationship_type: str = None, limit: int = 20) -> List[Dict[str, Any]]:
        results = []
        for rel in self.relationships:
            if relationship_type and relationship_type != rel["type"]:
                continue
            
            results.append({
                "source": rel["source"],
                "target": rel["target"],
                "type": rel["type"],
                "confidence": rel["properties"].get("confidence", 0.7)
            })
            
            if len(results) >= limit:
                break
        
        return results
    
    async def get_entity_neighbors(self, entity_name: str, max_depth: int = 2, limit: int = 50) -> Dict[str, Any]:
        neighbors = []
        for rel in self.relationships:
            if entity_name.lower() in rel["source"].lower():
                neighbors.append({
                    "name": rel["target"],
                    "type": rel["type"],
                    "relationship_path": [{"type": rel["type"]}]
                })
        
        return {
            "query_entity": entity_name,
            "neighbors": neighbors[:limit],
            "total_neighbors": len(neighbors)
        }
    
    async def get_graph_stats(self) -> Dict[str, Any]:
        return {
            "entities": len(self.entities),
            "documents": len(self.documents),
            "relationships": len(self.relationships)
        }
    
    async def health_check(self) -> bool:
        return True
    
    async def close(self):
        pass