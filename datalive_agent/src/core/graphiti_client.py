"""
Graphiti client for temporal knowledge graph analysis
Integrates with the KAG agent for time-aware reasoning
"""

import logging
from typing import Dict, Any, List, Optional, Union
from datetime import datetime, timedelta
import asyncio

try:
    import graphiti
    from graphiti import Graphiti
    from graphiti.nodes import Node, Relationship
except ImportError:
    graphiti = None
    Graphiti = None

from pydantic import BaseModel

logger = logging.getLogger(__name__)


class TemporalQuery(BaseModel):
    """Temporal query model for Graphiti"""
    query: str
    time_range: Optional[str] = None
    start_time: Optional[datetime] = None
    end_time: Optional[datetime] = None
    entities: List[str] = []
    relationships: List[str] = []


class TemporalResult(BaseModel):
    """Result from temporal analysis"""
    timeline: List[Dict[str, Any]] = []
    changes: List[Dict[str, Any]] = []
    patterns: List[Dict[str, Any]] = []
    confidence: float = 0.0
    temporal_insights: str = ""


class GraphitiClient:
    """
    Client for Graphiti temporal knowledge graph analysis
    Provides time-aware reasoning capabilities for the KAG agent
    """
    
    def __init__(
        self,
        neo4j_url: str = "neo4j://localhost:7687",
        neo4j_user: str = "neo4j",
        neo4j_password: str = "adminpassword",
        llm_model: str = "gpt-4",
        embedding_model: str = "text-embedding-ada-002"
    ):
        self.neo4j_url = neo4j_url
        self.neo4j_user = neo4j_user
        self.neo4j_password = neo4j_password
        self.llm_model = llm_model
        self.embedding_model = embedding_model
        
        self.client = None
        self.is_available = graphiti is not None
        
        if not self.is_available:
            logger.warning("Graphiti not available. Install with: pip install graphiti-ai")
        
        logger.info(f"GraphitiClient initialized (available: {self.is_available})")
    
    async def initialize(self) -> bool:
        """Initialize Graphiti client"""
        if not self.is_available:
            logger.warning("Graphiti not available for initialization")
            return False
        
        try:
            # Initialize Graphiti with Neo4j backend
            self.client = Graphiti(
                neo4j_uri=self.neo4j_url,
                neo4j_user=self.neo4j_user,
                neo4j_password=self.neo4j_password,
                llm_model=self.llm_model,
                embedding_model=self.embedding_model
            )
            
            # Test connection
            await self.client.connect()
            logger.info("✅ Graphiti client initialized successfully")
            return True
            
        except Exception as e:
            logger.error(f"Failed to initialize Graphiti client: {e}")
            self.client = None
            return False
    
    async def add_temporal_data(
        self,
        content: str,
        timestamp: datetime,
        document_id: str,
        metadata: Optional[Dict[str, Any]] = None
    ) -> bool:
        """Add content with temporal information to Graphiti"""
        if not self.client:
            return False
        
        try:
            # Add temporal context to metadata
            temporal_metadata = {
                "timestamp": timestamp.isoformat(),
                "document_id": document_id,
                **(metadata or {})
            }
            
            # Add to Graphiti with temporal context
            await self.client.add(
                content=content,
                metadata=temporal_metadata
            )
            
            logger.debug(f"Added temporal data for document {document_id}")
            return True
            
        except Exception as e:
            logger.error(f"Error adding temporal data: {e}")
            return False
    
    async def temporal_search(
        self,
        query: str,
        time_range: str = "last_6_months",
        limit: int = 10
    ) -> TemporalResult:
        """Perform temporal search using Graphiti"""
        if not self.client:
            return self._fallback_temporal_search(query, time_range, limit)
        
        try:
            # Parse time range
            start_time, end_time = self._parse_time_range(time_range)
            
            # Create temporal query
            temporal_query = TemporalQuery(
                query=query,
                time_range=time_range,
                start_time=start_time,
                end_time=end_time
            )
            
            # Execute search with temporal constraints
            results = await self.client.search(
                query=query,
                filters={
                    "timestamp": {
                        "gte": start_time.isoformat(),
                        "lte": end_time.isoformat()
                    }
                },
                limit=limit
            )
            
            # Process results for temporal analysis
            timeline = await self._build_timeline(results, start_time, end_time)
            changes = await self._detect_changes(results)
            patterns = await self._identify_patterns(results)
            
            # Generate temporal insights
            insights = await self._generate_temporal_insights(
                query, timeline, changes, patterns
            )
            
            return TemporalResult(
                timeline=timeline,
                changes=changes,
                patterns=patterns,
                confidence=0.8,
                temporal_insights=insights
            )
            
        except Exception as e:
            logger.error(f"Error in temporal search: {e}")
            return self._fallback_temporal_search(query, time_range, limit)
    
    async def analyze_evolution(
        self,
        entity: str,
        time_range: str = "last_year"
    ) -> Dict[str, Any]:
        """Analyze how an entity has evolved over time"""
        if not self.client:
            return {"error": "Graphiti not available"}
        
        try:
            start_time, end_time = self._parse_time_range(time_range)
            
            # Search for entity mentions over time
            results = await self.client.search(
                query=entity,
                filters={
                    "timestamp": {
                        "gte": start_time.isoformat(),
                        "lte": end_time.isoformat()
                    }
                },
                limit=50
            )
            
            # Group by time periods
            evolution = await self._group_by_time_periods(results, entity)
            
            return {
                "entity": entity,
                "time_range": time_range,
                "evolution": evolution,
                "trend_analysis": await self._analyze_trends(evolution),
                "key_changes": await self._identify_key_changes(evolution)
            }
            
        except Exception as e:
            logger.error(f"Error analyzing evolution for {entity}: {e}")
            return {"error": str(e)}
    
    async def get_temporal_relationships(
        self,
        entity: str,
        time_point: datetime
    ) -> List[Dict[str, Any]]:
        """Get relationships for an entity at a specific time point"""
        if not self.client:
            return []
        
        try:
            # Search around the time point (±1 month)
            start_time = time_point - timedelta(days=30)
            end_time = time_point + timedelta(days=30)
            
            results = await self.client.search(
                query=entity,
                filters={
                    "timestamp": {
                        "gte": start_time.isoformat(),
                        "lte": end_time.isoformat()
                    }
                },
                limit=20
            )
            
            # Extract relationships from results
            relationships = []
            for result in results:
                if hasattr(result, 'relationships'):
                    for rel in result.relationships:
                        relationships.append({
                            "source": rel.source,
                            "target": rel.target,
                            "type": rel.type,
                            "timestamp": result.metadata.get("timestamp"),
                            "confidence": getattr(rel, 'confidence', 0.7)
                        })
            
            return relationships
            
        except Exception as e:
            logger.error(f"Error getting temporal relationships: {e}")
            return []
    
    def _parse_time_range(self, time_range: str) -> tuple[datetime, datetime]:
        """Parse time range string to datetime objects"""
        now = datetime.now()
        
        if time_range == "last_hour":
            start_time = now - timedelta(hours=1)
        elif time_range == "last_day":
            start_time = now - timedelta(days=1)
        elif time_range == "last_week":
            start_time = now - timedelta(weeks=1)
        elif time_range == "last_month":
            start_time = now - timedelta(days=30)
        elif time_range == "last_3_months":
            start_time = now - timedelta(days=90)
        elif time_range == "last_6_months":
            start_time = now - timedelta(days=180)
        elif time_range == "last_year":
            start_time = now - timedelta(days=365)
        else:
            # Default to last 6 months
            start_time = now - timedelta(days=180)
        
        return start_time, now
    
    async def _build_timeline(
        self,
        results: List[Any],
        start_time: datetime,
        end_time: datetime
    ) -> List[Dict[str, Any]]:
        """Build timeline from search results"""
        timeline = []
        
        for result in results:
            timestamp_str = result.metadata.get("timestamp")
            if timestamp_str:
                try:
                    timestamp = datetime.fromisoformat(timestamp_str.replace('Z', '+00:00'))
                    timeline.append({
                        "timestamp": timestamp.isoformat(),
                        "content": result.content[:200] + "...",
                        "document_id": result.metadata.get("document_id"),
                        "relevance": getattr(result, 'score', 0.5)
                    })
                except Exception as e:
                    logger.warning(f"Error parsing timestamp {timestamp_str}: {e}")
        
        # Sort by timestamp
        timeline.sort(key=lambda x: x["timestamp"])
        return timeline
    
    async def _detect_changes(self, results: List[Any]) -> List[Dict[str, Any]]:
        """Detect significant changes over time"""
        changes = []
        
        # Group results by time periods and detect changes
        # This is a simplified implementation
        for i, result in enumerate(results[1:], 1):
            prev_result = results[i-1]
            
            # Simple change detection based on content similarity
            if self._content_similarity(result.content, prev_result.content) < 0.7:
                changes.append({
                    "timestamp": result.metadata.get("timestamp"),
                    "type": "content_change",
                    "description": f"Significant content change detected",
                    "confidence": 0.6
                })
        
        return changes
    
    async def _identify_patterns(self, results: List[Any]) -> List[Dict[str, Any]]:
        """Identify temporal patterns in the data"""
        patterns = []
        
        # Simple pattern detection
        if len(results) > 5:
            patterns.append({
                "type": "activity_increase",
                "description": f"Increased activity detected ({len(results)} mentions)",
                "confidence": 0.7
            })
        
        return patterns
    
    async def _generate_temporal_insights(
        self,
        query: str,
        timeline: List[Dict[str, Any]],
        changes: List[Dict[str, Any]],
        patterns: List[Dict[str, Any]]
    ) -> str:
        """Generate human-readable temporal insights"""
        insights = []
        
        if timeline:
            insights.append(f"Found {len(timeline)} temporal references for '{query}'")
            
            # Time span analysis
            if len(timeline) > 1:
                first_mention = timeline[0]["timestamp"]
                last_mention = timeline[-1]["timestamp"]
                insights.append(f"Activity spans from {first_mention[:10]} to {last_mention[:10]}")
        
        if changes:
            insights.append(f"Detected {len(changes)} significant changes over time")
        
        if patterns:
            for pattern in patterns:
                insights.append(f"Pattern: {pattern['description']}")
        
        return ". ".join(insights) if insights else "No significant temporal patterns detected."
    
    async def _group_by_time_periods(
        self,
        results: List[Any],
        entity: str
    ) -> List[Dict[str, Any]]:
        """Group results by time periods for evolution analysis"""
        periods = {}
        
        for result in results:
            timestamp_str = result.metadata.get("timestamp")
            if timestamp_str:
                try:
                    timestamp = datetime.fromisoformat(timestamp_str.replace('Z', '+00:00'))
                    period = f"{timestamp.year}-{timestamp.month:02d}"
                    
                    if period not in periods:
                        periods[period] = []
                    
                    periods[period].append({
                        "content": result.content,
                        "timestamp": timestamp.isoformat(),
                        "relevance": getattr(result, 'score', 0.5)
                    })
                except Exception as e:
                    logger.warning(f"Error processing timestamp: {e}")
        
        return [{"period": period, "mentions": mentions} for period, mentions in sorted(periods.items())]
    
    async def _analyze_trends(self, evolution: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Analyze trends in evolution data"""
        if len(evolution) < 2:
            return {"trend": "insufficient_data"}
        
        mention_counts = [len(period["mentions"]) for period in evolution]
        
        # Simple trend analysis
        if mention_counts[-1] > mention_counts[0]:
            trend = "increasing"
        elif mention_counts[-1] < mention_counts[0]:
            trend = "decreasing"
        else:
            trend = "stable"
        
        return {
            "trend": trend,
            "total_periods": len(evolution),
            "avg_mentions_per_period": sum(mention_counts) / len(mention_counts)
        }
    
    async def _identify_key_changes(self, evolution: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Identify key changes in evolution"""
        changes = []
        
        for i, period in enumerate(evolution[1:], 1):
            prev_period = evolution[i-1]
            
            current_count = len(period["mentions"])
            prev_count = len(prev_period["mentions"])
            
            if current_count > prev_count * 1.5:
                changes.append({
                    "period": period["period"],
                    "type": "activity_spike",
                    "description": f"Activity increased from {prev_count} to {current_count} mentions"
                })
            elif current_count < prev_count * 0.5:
                changes.append({
                    "period": period["period"],
                    "type": "activity_drop",
                    "description": f"Activity decreased from {prev_count} to {current_count} mentions"
                })
        
        return changes
    
    def _content_similarity(self, content1: str, content2: str) -> float:
        """Simple content similarity calculation"""
        words1 = set(content1.lower().split())
        words2 = set(content2.lower().split())
        
        if not words1 and not words2:
            return 1.0
        if not words1 or not words2:
            return 0.0
        
        intersection = words1.intersection(words2)
        union = words1.union(words2)
        
        return len(intersection) / len(union)
    
    async def _fallback_temporal_search(
        self,
        query: str,
        time_range: str,
        limit: int
    ) -> TemporalResult:
        """Fallback temporal search when Graphiti is not available"""
        logger.warning("Using fallback temporal search (Graphiti not available)")
        
        return TemporalResult(
            timeline=[{
                "timestamp": datetime.now().isoformat(),
                "content": f"Fallback search for: {query}",
                "note": "Graphiti not available - limited temporal analysis"
            }],
            temporal_insights=f"Basic temporal search for '{query}' over {time_range}. Install Graphiti for advanced temporal analysis."
        )
    
    async def health_check(self) -> Dict[str, Any]:
        """Perform health check"""
        status = "healthy" if self.client else "unavailable"
        
        health = {
            "status": status,
            "graphiti_available": self.is_available,
            "client_connected": self.client is not None,
            "neo4j_url": self.neo4j_url,
            "capabilities": [
                "temporal_search",
                "evolution_analysis", 
                "temporal_relationships",
                "pattern_detection"
            ] if self.is_available else ["fallback_search"]
        }
        
        if self.client:
            try:
                # Test connection
                await self.client.ping()
                health["connection_test"] = "passed"
            except Exception as e:
                health["connection_test"] = f"failed: {str(e)}"
                health["status"] = "degraded"
        
        return health