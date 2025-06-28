import pytest
from unittest.mock import Mock, AsyncMock
from src.agents.unified_agent import UnifiedAgent
from src.agents.orchestrator import Orchestrator

class TestUnifiedAgent:
    @pytest.mark.asyncio
    async def test_simple_rag_query(self, test_db, test_redis):
        """Test basic RAG functionality."""
        agent = UnifiedAgent(db=test_db, cache=test_redis)
        
        # Mock LLM response
        agent.llm_client.generate = AsyncMock(return_value="Test response")
        
        result = await agent.process_query(
            message="What is DataLive?",
            user_id="test_user"
        )
        
        assert result.response != ""
        assert result.confidence > 0
        assert "RAG" in result.strategy_used
    
    @pytest.mark.asyncio
    async def test_relationship_query(self, test_neo4j):
        """Test KAG relationship queries."""
        # Insert test data
        await test_neo4j.run("""
            CREATE (p:Project {name: 'DataLive'})
            CREATE (t:Technology {name: 'Neo4j'})
            CREATE (p)-[:USES]->(t)
        """)
        
        agent = UnifiedAgent(neo4j=test_neo4j)
        result = await agent.process_query(
            message="What technologies does DataLive use?",
            user_id="test_user"
        )
        
        assert "Neo4j" in result.response
        assert "KAG" in result.strategy_used
    
    @pytest.mark.asyncio
    async def test_cache_hit(self, test_redis):
        """Test CAG cache functionality."""
        agent = UnifiedAgent(cache=test_redis)
        
        # First query
        result1 = await agent.process_query(
            message="What is the capital of France?",
            user_id="test_user"
        )
        
        # Second identical query should hit cache
        result2 = await agent.process_query(
            message="What is the capital of France?",
            user_id="test_user"
        )
        
        assert result2.cached == True
        assert result2.processing_time < result1.processing_time

    @pytest.mark.asyncio
    async def test_temporal_query(self, test_neo4j):
        """Test temporal analysis capabilities."""
        await test_neo4j.run("""
            CREATE (e1:Event {name: 'Project Start', date: date('2024-01-01')})
            CREATE (e2:Event {name: 'First Release', date: date('2024-06-01')})
            CREATE (e1)-[:PRECEDED]->(e2)
        """)
        
        agent = UnifiedAgent(neo4j=test_neo4j)
        result = await agent.process_query(
            message="How has the project evolved over time?",
            user_id="test_user"
        )
        
        assert "temporal" in result.strategy_used[0].lower()
        assert result.confidence > 0.7