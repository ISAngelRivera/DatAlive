"""Graphiti integration for temporal knowledge graph management."""
import os
from typing import List, Dict, Any, Optional
from datetime import datetime
import asyncio
from graphiti_core import Graphiti
from graphiti_core.nodes import EpisodeType
from neo4j import AsyncGraphDatabase
import logging

logger = logging.getLogger(__name__)

class GraphitiManager:
    """Manages Graphiti temporal knowledge graph integration."""
    
    def __init__(self, neo4j_url: str, neo4j_auth: tuple):
        self.neo4j_url = neo4j_url
        self.neo4j_auth = neo4j_auth
        self.graphiti = None
        self._initialized = False
    
    async def initialize(self):
        """Initialize Graphiti with Neo4j backend."""
        if self._initialized:
            return
            
        try:
            # Initialize Graphiti with Neo4j
            self.graphiti = Graphiti(
                neo4j_uri=self.neo4j_url,
                neo4j_user=self.neo4j_auth[0],
                neo4j_password=self.neo4j_auth[1],
                llm_provider="openai",  # o "ollama" según tu config
                embedder_provider="openai",  # o "ollama"
            )
            
            # Initialize schema
            await self.graphiti.build_indices()
            
            self._initialized = True
            logger.info("Graphiti initialized successfully")
            
        except Exception as e:
            logger.error(f"Failed to initialize Graphiti: {e}")
            raise
    
    async def add_episode(
        self,
        content: str,
        source: str,
        timestamp: Optional[datetime] = None,
        metadata: Optional[Dict[str, Any]] = None
    ):
        """Add new episode (event/document) to temporal graph."""
        if not self._initialized:
            await self.initialize()
        
        episode_data = {
            "content": content,
            "source": source,
            "timestamp": timestamp or datetime.now(),
            "metadata": metadata or {}
        }
        
        try:
            # Process episode through Graphiti
            result = await self.graphiti.add_episode(
                name=f"episode_{timestamp.isoformat()}",
                episode_type=EpisodeType.message,
                content=content,
                source=source,
                reference_time=timestamp
            )
            
            logger.info(f"Added episode: {result.name}")
            return result
            
        except Exception as e:
            logger.error(f"Failed to add episode: {e}")
            raise
    
    async def search(
        self,
        query: str,
        num_results: int = 10,
        time_range: Optional[tuple] = None
    ) -> List[Dict[str, Any]]:
        """Search temporal knowledge graph."""
        if not self._initialized:
            await self.initialize()
        
        try:
            # Build search parameters
            search_params = {
                "query": query,
                "num_results": num_results
            }
            
            if time_range:
                search_params["start_time"] = time_range[0]
                search_params["end_time"] = time_range[1]
            
            # Execute search
            results = await self.graphiti.search(**search_params)
            
            return [
                {
                    "content": r.content,
                    "source": r.source,
                    "timestamp": r.reference_time,
                    "relevance_score": r.relevance_score,
                    "metadata": r.metadata
                }
                for r in results
            ]
            
        except Exception as e:
            logger.error(f"Search failed: {e}")
            return []
    
    async def get_timeline(
        self,
        entity: str,
        start_date: Optional[datetime] = None,
        end_date: Optional[datetime] = None
    ) -> List[Dict[str, Any]]:
        """Get timeline of events for an entity."""
        query = f"""
        MATCH (e:Entity {{name: $entity}})-[:PARTICIPATED_IN]->(event:Event)
        WHERE event.timestamp >= $start_date AND event.timestamp <= $end_date
        RETURN event
        ORDER BY event.timestamp
        """
        
        async with AsyncGraphDatabase.driver(self.neo4j_url, auth=self.neo4j_auth) as driver:
            async with driver.session() as session:
                result = await session.run(
                    query,
                    entity=entity,
                    start_date=start_date or datetime(2020, 1, 1),
                    end_date=end_date or datetime.now()
                )
                
                return [dict(record["event"]) async for record in result]
    
    async def update_relationships(self):
        """Update entity relationships based on temporal patterns."""
        # Detectar patrones temporales y actualizar relaciones
        query = """
        MATCH (e1:Entity)-[:MENTIONED_WITH]->(e2:Entity)
        WHERE e1.last_seen > datetime() - duration('P7D')
        AND e2.last_seen > datetime() - duration('P7D')
        MERGE (e1)-[r:CURRENTLY_RELATED_TO]->(e2)
        SET r.strength = r.strength + 1
        """
        
        async with AsyncGraphDatabase.driver(self.neo4j_url, auth=self.neo4j_auth) as driver:
            async with driver.session() as session:
                await session.run(query)