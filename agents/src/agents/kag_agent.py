"""
KAG Agent for Knowledge Graph operations
"""

import logging
from typing import Dict, Any, List, Optional
from datetime import datetime, timedelta
import json

from neo4j import AsyncGraphDatabase
from ..core.database import get_neo4j_driver
from ..config import settings

logger = logging.getLogger(__name__)


class EntityResult:
    """Result for an entity from knowledge graph"""
    def __init__(
        self,
        entity_id: str,
        name: str,
        type: str,
        properties: Dict[str, Any]
    ):
        self.entity_id = entity_id
        self.name = name
        self.type = type
        self.properties = properties


class RelationshipResult:
    """Result for a relationship from knowledge graph"""
    def __init__(
        self,
        source: str,
        target: str,
        relationship_type: str,
        properties: Dict[str, Any],
        confidence: float = 1.0
    ):
        self.source = source
        self.target = target
        self.relationship_type = relationship_type
        self.properties = properties
        self.confidence = confidence


class KAGAgent:
    """
    Knowledge-Augmented Generation agent using Neo4j + Graphiti
    """
    
    def __init__(self):
        """Initialize KAG agent"""
        self.driver = None
        
    async def _get_driver(self):
        """Get Neo4j driver instance"""
        if not self.driver:
            self.driver = await get_neo4j_driver()
        return self.driver
    
    async def analyze_relationships(
        self,
        query: str,
        max_depth: int = 3,
        limit: int = 20
    ) -> Dict[str, Any]:
        """
        Analyze relationships in the knowledge graph based on query
        """
        try:
            # Extract entities from query
            entities = await self._extract_entities_from_query(query)
            
            if not entities:
                logger.warning("No entities found in query")
                return {
                    'query': query,
                    'entities': [],
                    'relationships': [],
                    'insights': []
                }
            
            # Find relationships
            relationships = await self._find_relationships(
                entities=entities,
                max_depth=max_depth,
                limit=limit
            )
            
            # Generate insights
            insights = await self._generate_insights(entities, relationships)
            
            logger.info(f"KAG analysis found {len(relationships)} relationships")
            
            return {
                'query': query,
                'entities': [
                    {
                        'entity_id': e.entity_id,
                        'name': e.name,
                        'type': e.type,
                        'properties': e.properties
                    }
                    for e in entities
                ],
                'relationships': [
                    {
                        'source': r.source,
                        'target': r.target,
                        'type': r.relationship_type,
                        'properties': r.properties,
                        'confidence': r.confidence
                    }
                    for r in relationships
                ],
                'insights': insights
            }
            
        except Exception as e:
            logger.error(f"Error in KAG analysis: {e}")
            return {
                'query': query,
                'entities': [],
                'relationships': [],
                'insights': [],
                'error': str(e)
            }
    
    async def temporal_search(
        self,
        query: str,
        time_range: Optional[str] = "last_6_months"
    ) -> Dict[str, Any]:
        """
        Search for temporal patterns in the knowledge graph
        """
        try:
            # Parse time range
            end_date = datetime.now()
            if time_range == "last_6_months":
                start_date = end_date - timedelta(days=180)
            elif time_range == "last_year":
                start_date = end_date - timedelta(days=365)
            elif time_range == "last_month":
                start_date = end_date - timedelta(days=30)
            else:
                start_date = end_date - timedelta(days=180)  # Default
            
            # Extract entities
            entities = await self._extract_entities_from_query(query)
            
            # Find temporal events
            timeline = await self._find_temporal_events(
                entities=entities,
                start_date=start_date,
                end_date=end_date
            )
            
            # Analyze trends
            trends = await self._analyze_temporal_trends(timeline)
            
            return {
                'query': query,
                'time_range': {
                    'start': start_date.isoformat(),
                    'end': end_date.isoformat(),
                    'description': time_range
                },
                'timeline': timeline,
                'trends': trends,
                'entities': [e.name for e in entities]
            }
            
        except Exception as e:
            logger.error(f"Error in temporal search: {e}")
            return {
                'query': query,
                'timeline': [],
                'trends': [],
                'error': str(e)
            }
    
    async def _extract_entities_from_query(self, query: str) -> List[EntityResult]:
        """
        Extract named entities from query text
        """
        try:
            driver = await self._get_driver()
            
            # First, try to find entities by name matching
            cypher_query = """
            MATCH (e:Entity)
            WHERE toLower(e.name) CONTAINS toLower($query_text)
               OR any(alias IN e.aliases WHERE toLower(alias) CONTAINS toLower($query_text))
            RETURN e.id as entity_id, e.name as name, labels(e)[0] as type, properties(e) as properties
            LIMIT 10
            """
            
            async with driver.session() as session:
                result = await session.run(cypher_query, query_text=query)
                records = await result.data()
                
                entities = []
                for record in records:
                    entity = EntityResult(
                        entity_id=record['entity_id'],
                        name=record['name'],
                        type=record['type'],
                        properties=record['properties']
                    )
                    entities.append(entity)
                
                return entities
                
        except Exception as e:
            logger.error(f"Error extracting entities: {e}")
            return []
    
    async def _find_relationships(
        self,
        entities: List[EntityResult],
        max_depth: int = 3,
        limit: int = 20
    ) -> List[RelationshipResult]:
        """
        Find relationships between entities
        """
        try:
            if not entities:
                return []
            
            driver = await self._get_driver()
            
            entity_ids = [e.entity_id for e in entities]
            
            # Find relationships with variable depth
            cypher_query = f"""
            MATCH (source:Entity)-[r*1..{max_depth}]-(target:Entity)
            WHERE source.id IN $entity_ids
               OR target.id IN $entity_ids
            WITH source, target, r
            UNWIND r as relationship
            RETURN DISTINCT
                source.name as source_name,
                target.name as target_name,
                type(relationship) as rel_type,
                properties(relationship) as rel_properties,
                relationship.confidence as confidence,
                relationship.created_at as created_at
            ORDER BY coalesce(relationship.confidence, 1.0) DESC
            LIMIT $limit
            """
            
            async with driver.session() as session:
                result = await session.run(
                    cypher_query,
                    entity_ids=entity_ids,
                    limit=limit
                )
                records = await result.data()
                
                relationships = []
                for record in records:
                    rel = RelationshipResult(
                        source=record['source_name'],
                        target=record['target_name'],
                        relationship_type=record['rel_type'],
                        properties=record['rel_properties'] or {},
                        confidence=record['confidence'] or 1.0
                    )
                    relationships.append(rel)
                
                return relationships
                
        except Exception as e:
            logger.error(f"Error finding relationships: {e}")
            return []
    
    async def _find_temporal_events(
        self,
        entities: List[EntityResult],
        start_date: datetime,
        end_date: datetime
    ) -> List[Dict[str, Any]]:
        """
        Find temporal events related to entities
        """
        try:
            if not entities:
                return []
            
            driver = await self._get_driver()
            entity_names = [e.name for e in entities]
            
            # Find events with temporal data
            cypher_query = """
            MATCH (e:Entity)-[r:OCCURRED_AT|CREATED_AT|MODIFIED_AT]-(event:Event)
            WHERE e.name IN $entity_names
              AND event.date >= $start_date
              AND event.date <= $end_date
            RETURN 
                event.date as date,
                event.description as description,
                event.type as event_type,
                collect(e.name) as entities,
                properties(event) as properties
            ORDER BY event.date DESC
            """
            
            async with driver.session() as session:
                result = await session.run(
                    cypher_query,
                    entity_names=entity_names,
                    start_date=start_date,
                    end_date=end_date
                )
                records = await result.data()
                
                timeline = []
                for record in records:
                    event = {
                        'date': record['date'].isoformat() if record['date'] else None,
                        'description': record['description'],
                        'type': record['event_type'],
                        'entities': record['entities'],
                        'properties': record['properties'] or {}
                    }
                    timeline.append(event)
                
                return timeline
                
        except Exception as e:
            logger.error(f"Error finding temporal events: {e}")
            return []
    
    async def _generate_insights(
        self,
        entities: List[EntityResult],
        relationships: List[RelationshipResult]
    ) -> List[str]:
        """
        Generate insights from entities and relationships
        """
        insights = []
        
        try:
            if not entities or not relationships:
                return insights
            
            # Insight 1: Most connected entities
            entity_connections = {}
            for rel in relationships:
                entity_connections[rel.source] = entity_connections.get(rel.source, 0) + 1
                entity_connections[rel.target] = entity_connections.get(rel.target, 0) + 1
            
            if entity_connections:
                most_connected = max(entity_connections, key=entity_connections.get)
                insights.append(
                    f"'{most_connected}' is the most connected entity with "
                    f"{entity_connections[most_connected]} relationships"
                )
            
            # Insight 2: Relationship types
            rel_types = {}
            for rel in relationships:
                rel_types[rel.relationship_type] = rel_types.get(rel.relationship_type, 0) + 1
            
            if rel_types:
                common_rel = max(rel_types, key=rel_types.get)
                insights.append(
                    f"Most common relationship type is '{common_rel}' "
                    f"({rel_types[common_rel]} occurrences)"
                )
            
            # Insight 3: High confidence relationships
            high_conf_rels = [r for r in relationships if r.confidence > 0.8]
            if high_conf_rels:
                insights.append(
                    f"Found {len(high_conf_rels)} high-confidence relationships "
                    f"(confidence > 0.8)"
                )
            
            return insights
            
        except Exception as e:
            logger.error(f"Error generating insights: {e}")
            return ["Unable to generate insights due to processing error"]
    
    async def _analyze_temporal_trends(
        self,
        timeline: List[Dict[str, Any]]
    ) -> List[Dict[str, Any]]:
        """
        Analyze trends in temporal data
        """
        trends = []
        
        try:
            if len(timeline) < 2:
                return trends
            
            # Group events by month
            monthly_counts = {}
            for event in timeline:
                if event.get('date'):
                    date_obj = datetime.fromisoformat(event['date'].replace('Z', '+00:00'))
                    month_key = date_obj.strftime('%Y-%m')
                    monthly_counts[month_key] = monthly_counts.get(month_key, 0) + 1
            
            # Analyze activity trends
            if len(monthly_counts) > 1:
                sorted_months = sorted(monthly_counts.items())
                recent_activity = sorted_months[-1][1]
                previous_activity = sorted_months[-2][1] if len(sorted_months) > 1 else 0
                
                if recent_activity > previous_activity:
                    trends.append({
                        'type': 'increasing_activity',
                        'description': f"Activity increased from {previous_activity} to {recent_activity} events",
                        'trend': 'upward'
                    })
                elif recent_activity < previous_activity:
                    trends.append({
                        'type': 'decreasing_activity',
                        'description': f"Activity decreased from {previous_activity} to {recent_activity} events",
                        'trend': 'downward'
                    })
            
            # Event type distribution
            event_types = {}
            for event in timeline:
                event_type = event.get('type', 'unknown')
                event_types[event_type] = event_types.get(event_type, 0) + 1
            
            if event_types:
                dominant_type = max(event_types, key=event_types.get)
                trends.append({
                    'type': 'dominant_event_type',
                    'description': f"Most frequent event type: {dominant_type} ({event_types[dominant_type]} events)",
                    'data': event_types
                })
            
            return trends
            
        except Exception as e:
            logger.error(f"Error analyzing trends: {e}")
            return []