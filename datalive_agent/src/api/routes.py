"""
API routes for DataLive Unified Agent
"""

import logging
import os
from typing import Dict, Any, Optional, List, Union
from pathlib import Path

from fastapi import APIRouter, HTTPException, BackgroundTasks, UploadFile, File, Header, Depends
from fastapi.responses import StreamingResponse
from pydantic import BaseModel

from ..agents.unified_agent import UnifiedAgent, QueryRequest, QueryResponse
from ..agents.orchestrator import OrchestratorAgent
from ..agents.rag_agent import RAGAgent
from ..agents.kag_agent import KAGAgent
from ..agents.cag_agent import CAGAgent
from ..ingestion.pipeline import MultiModalIngestionPipeline, IngestionConfig
from ..core.vector_store import VectorStore
from ..core.knowledge_graph import KnowledgeGraph
from ..core.metrics import (
    query_counter,
    cache_hit_counter,
    cache_miss_counter
)

logger = logging.getLogger(__name__)

# Create router
router = APIRouter()


async def verify_api_key(x_api_key: str = Header(...)):
    """Verify API key for protected endpoints"""
    expected_key = os.getenv("DATALIVE_API_KEY", "datalive-dev-key-change-in-production")
    if not expected_key or x_api_key != expected_key:
        raise HTTPException(status_code=403, detail="Invalid API key")
    return True

# Initialize agents (will be done properly in dependency injection)
_unified_agent: Optional[UnifiedAgent] = None
_ingestion_pipeline: Optional[MultiModalIngestionPipeline] = None


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


async def get_ingestion_pipeline() -> MultiModalIngestionPipeline:
    """Get or create ingestion pipeline instance"""
    global _ingestion_pipeline
    
    if not _ingestion_pipeline:
        # Initialize core components (mock for now - will be properly injected)
        vector_store = VectorStore()  # TODO: Proper initialization
        knowledge_graph = KnowledgeGraph()  # TODO: Proper initialization
        
        # Create pipeline
        _ingestion_pipeline = MultiModalIngestionPipeline(
            vector_store=vector_store,
            knowledge_graph=knowledge_graph,
            config=IngestionConfig()
        )
        
        logger.info("Ingestion pipeline initialized")
    
    return _ingestion_pipeline


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


class IngestRequest(BaseModel):
    """Document ingestion request"""
    source_type: str  # pdf, txt, markdown, csv, excel
    source: Optional[str] = None  # File path or content
    metadata: Optional[Dict[str, Any]] = None
    config: Optional[Dict[str, Any]] = None


class IngestResponse(BaseModel):
    """Document ingestion response"""
    document_id: str
    status: str
    message: str
    processing_time: float
    entities_extracted: int = 0
    relationships_extracted: int = 0
    chunks_created: int = 0
    errors: List[str] = []


class QueryRequest(BaseModel):
    """Enhanced query request"""
    query: str
    user_id: Optional[str] = None
    session_id: Optional[str] = None
    strategy: Optional[str] = None  # rag, kag, cag, auto
    use_cache: bool = True
    max_results: int = 10
    threshold: float = 0.7


class QueryResponse(BaseModel):
    """Enhanced query response"""
    answer: str
    sources: List[Dict[str, Any]] = []
    entities: List[Dict[str, Any]] = []
    relationships: List[Dict[str, Any]] = []
    confidence: float = 0.0
    strategy_used: str
    processing_time: float = 0.0
    cached: bool = False


# Routes
@router.post("/chat", response_model=ChatResponse)
async def chat(request: ChatRequest, _: bool = Depends(verify_api_key)) -> ChatResponse:
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
        
        # Get unified agent and process query (using optimized version)
        agent = await get_unified_agent()
        result = await agent.process_query_optimized(query_request)
        
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
async def chat_stream(request: ChatRequest, _: bool = Depends(verify_api_key)):
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
    threshold: float = 0.7,
    _: bool = Depends(verify_api_key)
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
    limit: int = 20,
    _: bool = Depends(verify_api_key)
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
    time_range: str = "last_6_months",
    _: bool = Depends(verify_api_key)
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
async def invalidate_cache(pattern: str = "*", _: bool = Depends(verify_api_key)):
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


# New DataLive Core Endpoints

@router.post("/ingest", response_model=IngestResponse)
async def ingest_document(request: IngestRequest, _: bool = Depends(verify_api_key)) -> IngestResponse:
    """
    Ingest a document into the DataLive system
    
    Supports: PDF, XLSX, TXT, Markdown, CSV
    """
    try:
        pipeline = await get_ingestion_pipeline()
        
        # Process the document
        processed_doc = await pipeline.process_document(
            source=request.source,
            source_type=request.source_type,
            **(request.config or {})
        )
        
        # Build response
        if processed_doc.errors:
            status = "partial_success" if processed_doc.content else "failed"
            message = f"Document processed with {len(processed_doc.errors)} errors"
        else:
            status = "success"
            message = "Document successfully ingested"
        
        return IngestResponse(
            document_id=processed_doc.id,
            status=status,
            message=message,
            processing_time=processed_doc.processing_time,
            entities_extracted=len(processed_doc.entities),
            relationships_extracted=len(processed_doc.relationships),
            chunks_created=len(processed_doc.chunks),
            errors=processed_doc.errors
        )
        
    except Exception as e:
        logger.error(f"Error in ingest endpoint: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/ingest/file")
async def ingest_file(
    file: UploadFile = File(...),
    source_type: Optional[str] = None,
    _: bool = Depends(verify_api_key)
) -> IngestResponse:
    """
    Ingest a file upload into the DataLive system
    """
    try:
        # Auto-detect source type if not provided
        if not source_type:
            suffix = Path(file.filename or "").suffix.lower()
            type_mapping = {
                '.pdf': 'pdf',
                '.txt': 'txt', 
                '.md': 'markdown',
                '.csv': 'csv',
                '.xlsx': 'excel',
                '.xls': 'excel'
            }
            source_type = type_mapping.get(suffix)
            
            if not source_type:
                raise HTTPException(
                    status_code=400, 
                    detail=f"Unsupported file type: {suffix}"
                )
        
        # Save uploaded file temporarily
        import tempfile
        with tempfile.NamedTemporaryFile(delete=False, suffix=Path(file.filename or "").suffix) as tmp_file:
            content = await file.read()
            tmp_file.write(content)
            tmp_file_path = tmp_file.name
        
        try:
            # Create ingest request
            request = IngestRequest(
                source_type=source_type,
                source=tmp_file_path,
                metadata={"original_filename": file.filename}
            )
            
            # Process using existing ingest endpoint
            response = await ingest_document(request)
            return response
            
        finally:
            # Cleanup temp file
            try:
                Path(tmp_file_path).unlink()
            except Exception:
                pass
                
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error in file ingest endpoint: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/ingest/directory")
async def ingest_directory(
    directory_path: str,
    file_patterns: Optional[List[str]] = None,
    recursive: bool = True,
    background_tasks: BackgroundTasks = None,
    _: bool = Depends(verify_api_key)
) -> Dict[str, Any]:
    """
    Ingest all supported files from a directory
    """
    try:
        pipeline = await get_ingestion_pipeline()
        
        if not Path(directory_path).exists():
            raise HTTPException(status_code=404, detail="Directory not found")
        
        if not Path(directory_path).is_dir():
            raise HTTPException(status_code=400, detail="Path is not a directory")
        
        # Process directory
        results = await pipeline.ingest_directory(
            directory_path=Path(directory_path),
            file_patterns=file_patterns,
            recursive=recursive
        )
        
        # Summarize results
        successful = len([r for r in results if not r.errors])
        failed = len([r for r in results if r.errors])
        total_entities = sum(len(r.entities) for r in results)
        total_relationships = sum(len(r.relationships) for r in results)
        total_chunks = sum(len(r.chunks) for r in results)
        
        return {
            "status": "completed",
            "summary": {
                "total_files": len(results),
                "successful": successful,
                "failed": failed,
                "entities_extracted": total_entities,
                "relationships_extracted": total_relationships,
                "chunks_created": total_chunks
            },
            "results": [
                {
                    "document_id": r.id,
                    "status": "success" if not r.errors else "failed",
                    "processing_time": r.processing_time,
                    "errors": r.errors
                }
                for r in results
            ]
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error in directory ingest endpoint: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/query", response_model=QueryResponse)
async def query_documents(request: QueryRequest, _: bool = Depends(verify_api_key)) -> QueryResponse:
    """
    Query the DataLive knowledge base using RAG+KAG+CAG
    """
    try:
        # Convert to unified agent request format
        unified_request = QueryRequest(
            query=request.query,
            user_id=request.user_id,
            session_id=request.session_id,
            context={
                "strategy": request.strategy,
                "max_results": request.max_results,
                "threshold": request.threshold
            },
            use_cache=request.use_cache
        )
        
        # Get unified agent and process query (using optimized version)
        agent = await get_unified_agent()
        result = await agent.process_query_optimized(unified_request)
        
        # Enhanced response with more details
        return QueryResponse(
            answer=result.answer,
            sources=result.sources,
            entities=getattr(result, 'entities', []),
            relationships=getattr(result, 'relationships', []),
            confidence=result.confidence,
            strategy_used=result.strategy_used[0] if result.strategy_used else "auto",
            processing_time=result.processing_time,
            cached=result.cached
        )
        
    except Exception as e:
        logger.error(f"Error in query endpoint: {e}")
        raise HTTPException(status_code=500, detail=str(e))