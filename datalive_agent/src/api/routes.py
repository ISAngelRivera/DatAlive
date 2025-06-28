"""
API routes for DataLive Unified Agent
"""

import logging
from typing import Dict, Any, Optional

from fastapi import APIRouter, HTTPException, BackgroundTasks
from fastapi.responses import StreamingResponse
from pydantic import BaseModel

from ..agents.unified_agent import UnifiedAgent, QueryRequest, QueryResponse
from ..agents.orchestrator import OrchestratorAgent
from ..agents.rag_agent import RAGAgent
from ..agents.kag_agent import KAGAgent
from ..agents.cag_agent import CAGAgent
from ..core.metrics import (
    query_counter,
    cache_hit_counter,
    cache_miss_counter
)

logger = logging.getLogger(__name__)

# Create router
router = APIRouter()

# Initialize agents (will be done properly in dependency injection)
_unified_agent: Optional[UnifiedAgent] = None


async def get_unified_agent() -> UnifiedAgent:
    """Get or create unified agent instance"""
    global _unified_agent
    
    if not _unified_agent:
        # Initialize sub-agents
        rag_agent = RAGAgent()
        kag_agent = KAGAgent()
        cag_agent = CAGAgent()
        orchestrator = OrchestratorAgent()
        
        # Create unified agent
        _unified_agent = UnifiedAgent(
            rag_agent=rag_agent,
            kag_agent=kag_agent,
            cag_agent=cag_agent,
            orchestrator=orchestrator
        )
        
        logger.info("Unified agent initialized")
    
    return _unified_agent


# Request/Response models
class ChatRequest(BaseModel):
    """Chat request model"""
    message: str
    user_id: Optional[str] = None
    session_id: Optional[str] = None
    context: Optional[Dict[str, Any]] = None
    use_cache: bool = True


class ChatResponse(BaseModel):
    """Chat response model"""
    response: str
    sources: list = []
    confidence: float = 0.0
    strategy_used: list = []
    processing_time: float = 0.0
    cached: bool = False


# Routes
@router.post("/chat", response_model=ChatResponse)
async def chat(request: ChatRequest) -> ChatResponse:
    """
    Process a chat query and return response
    """
    try:
        # Convert to internal request format
        query_request = QueryRequest(
            query=request.message,
            user_id=request.user_id,
            session_id=request.session_id,
            context=request.context,
            use_cache=request.use_cache
        )
        
        # Get unified agent and process query
        agent = await get_unified_agent()
        result = await agent.process_query(query_request)
        
        # Convert to response format
        return ChatResponse(
            response=result.answer,
            sources=result.sources,
            confidence=result.confidence,
            strategy_used=result.strategy_used,
            processing_time=result.processing_time,
            cached=result.cached
        )
        
    except Exception as e:
        logger.error(f"Error in chat endpoint: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/chat/stream")
async def chat_stream(request: ChatRequest):
    """
    Process a chat query with streaming response
    """
    async def generate_stream():
        try:
            # For now, return the full response
            # TODO: Implement proper streaming
            response = await chat(request)
            
            # Yield response as server-sent events
            yield f"data: {response.json()}\n\n"
            
        except Exception as e:
            error_response = {"error": str(e)}
            yield f"data: {error_response}\n\n"
    
    return StreamingResponse(
        generate_stream(),
        media_type="text/plain",
        headers={"Cache-Control": "no-cache"}
    )


@router.get("/search/vector")
async def vector_search(
    query: str,
    limit: int = 10,
    threshold: float = 0.7
):
    """
    Perform vector search only
    """
    try:
        agent = await get_unified_agent()
        result = await agent.rag_agent.search(
            query=query,
            limit=limit,
            threshold=threshold
        )
        return result
        
    except Exception as e:
        logger.error(f"Error in vector search: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/search/knowledge-graph")
async def knowledge_graph_search(
    query: str,
    max_depth: int = 3,
    limit: int = 20
):
    """
    Perform knowledge graph search only
    """
    try:
        agent = await get_unified_agent()
        result = await agent.kag_agent.analyze_relationships(
            query=query,
            max_depth=max_depth,
            limit=limit
        )
        return result
        
    except Exception as e:
        logger.error(f"Error in knowledge graph search: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/search/temporal")
async def temporal_search(
    query: str,
    time_range: str = "last_6_months"
):
    """
    Perform temporal search
    """
    try:
        agent = await get_unified_agent()
        result = await agent.kag_agent.temporal_search(
            query=query,
            time_range=time_range
        )
        return result
        
    except Exception as e:
        logger.error(f"Error in temporal search: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/cache/stats")
async def cache_stats():
    """
    Get cache statistics
    """
    try:
        agent = await get_unified_agent()
        stats = await agent.cag_agent.get_cache_stats()
        return stats
        
    except Exception as e:
        logger.error(f"Error getting cache stats: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.delete("/cache/invalidate")
async def invalidate_cache(pattern: str = "*"):
    """
    Invalidate cache entries
    """
    try:
        agent = await get_unified_agent()
        await agent.cag_agent.invalidate_cache_pattern(pattern)
        return {"message": f"Cache invalidated for pattern: {pattern}"}
        
    except Exception as e:
        logger.error(f"Error invalidating cache: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/status")
async def status():
    """
    Get service status
    """
    try:
        # Check if agent is initialized
        agent = await get_unified_agent()
        
        return {
            "status": "healthy",
            "service": "datalive-unified-agent",
            "version": "3.0.0",
            "components": {
                "rag_agent": "ready",
                "kag_agent": "ready",
                "cag_agent": "ready",
                "orchestrator": "ready"
            }
        }
        
    except Exception as e:
        logger.error(f"Error in status check: {e}")
        return {
            "status": "unhealthy",
            "error": str(e)
        }


@router.get("/metrics/summary")
async def metrics_summary():
    """
    Get metrics summary
    """
    return {
        "queries_processed": query_counter._value.sum(),
        "cache_hits": cache_hit_counter._value.sum(),
        "cache_misses": cache_miss_counter._value.sum(),
        "cache_hit_rate": (
            cache_hit_counter._value.sum() / 
            (cache_hit_counter._value.sum() + cache_miss_counter._value.sum())
            if (cache_hit_counter._value.sum() + cache_miss_counter._value.sum()) > 0
            else 0
        )
    }