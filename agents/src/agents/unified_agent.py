"""
Unified Agent that combines RAG, KAG, and CAG capabilities
"""

import logging
from typing import Dict, Any, List, Optional
from datetime import datetime

from pydantic import BaseModel

from .orchestrator import OrchestratorAgent
from .rag_agent import RAGAgent
from .kag_agent import KAGAgent
from .cag_agent import CAGAgent
from ..core.metrics import (
    query_counter,
    query_duration,
    cache_hit_counter,
    agent_usage_counter
)

logger = logging.getLogger(__name__)


class QueryRequest(BaseModel):
    """Query request model"""
    query: str
    user_id: Optional[str] = None
    session_id: Optional[str] = None
    context: Optional[Dict[str, Any]] = None
    filters: Optional[Dict[str, Any]] = None
    use_cache: bool = True
    

class QueryResponse(BaseModel):
    """Query response model"""
    answer: str
    sources: List[Dict[str, Any]]
    confidence: float
    strategy_used: List[str]
    processing_time: float
    cached: bool = False
    metadata: Optional[Dict[str, Any]] = None


class UnifiedAgent:
    """
    Unified agent that orchestrates RAG, KAG, and CAG agents
    to provide comprehensive answers
    """
    
    def __init__(
        self,
        rag_agent: RAGAgent,
        kag_agent: KAGAgent,
        cag_agent: CAGAgent,
        orchestrator: OrchestratorAgent
    ):
        """Initialize unified agent with all sub-agents"""
        self.rag_agent = rag_agent
        self.kag_agent = kag_agent
        self.cag_agent = cag_agent
        self.orchestrator = orchestrator
        
    async def process_query(self, request: QueryRequest) -> QueryResponse:
        """
        Process a query using the optimal combination of agents
        """
        start_time = datetime.now()
        strategies_used = []
        
        try:
            # 1. Check cache first if enabled
            if request.use_cache:
                cache_result = await self._check_cache(request)
                if cache_result:
                    cache_hit_counter.inc()
                    return cache_result
            
            # 2. Analyze query with orchestrator
            strategy = await self.orchestrator.analyze_query(
                request.query,
                request.context
            )
            logger.info(f"Orchestrator strategy: {strategy}")
            
            # 3. Execute strategies in parallel when possible
            results = {}
            
            # RAG Search
            if strategy.use_rag:
                strategies_used.append("RAG")
                agent_usage_counter.labels(agent_type="rag").inc()
                results['rag'] = await self.rag_agent.search(
                    query=request.query,
                    filters=request.filters,
                    limit=strategy.rag_limit
                )
                
            # Knowledge Graph Analysis
            if strategy.use_kag:
                strategies_used.append("KAG")
                agent_usage_counter.labels(agent_type="kag").inc()
                results['kag'] = await self.kag_agent.analyze_relationships(
                    query=request.query,
                    max_depth=strategy.kg_depth
                )
                
            # Temporal Analysis
            if strategy.use_temporal:
                strategies_used.append("KAG-Temporal")
                results['temporal'] = await self.kag_agent.temporal_search(
                    query=request.query,
                    time_range=strategy.time_range
                )
            
            # 4. Combine results
            combined_result = await self._combine_results(
                results=results,
                query=request.query,
                strategy=strategy
            )
            
            # 5. Generate final response
            response = QueryResponse(
                answer=combined_result['answer'],
                sources=combined_result['sources'],
                confidence=combined_result['confidence'],
                strategy_used=strategies_used,
                processing_time=(datetime.now() - start_time).total_seconds(),
                cached=False,
                metadata={
                    'strategy': strategy.dict(),
                    'result_counts': {
                        k: len(v.get('results', [])) if isinstance(v, dict) else 0
                        for k, v in results.items()
                    }
                }
            )
            
            # 6. Update cache
            if request.use_cache:
                await self._update_cache(request, response)
            
            # 7. Record metrics
            query_counter.labels(
                status="success",
                strategy=",".join(strategies_used)
            ).inc()
            
            query_duration.labels(
                strategy=",".join(strategies_used)
            ).observe(response.processing_time)
            
            return response
            
        except Exception as e:
            logger.error(f"Error processing query: {e}")
            query_counter.labels(
                status="error",
                strategy=",".join(strategies_used) or "unknown"
            ).inc()
            raise
            
    async def _check_cache(self, request: QueryRequest) -> Optional[QueryResponse]:
        """Check if query result is in cache"""
        cached_result = await self.cag_agent.check_cache(
            query=request.query,
            user_context={
                'user_id': request.user_id,
                'session_id': request.session_id
            }
        )
        
        if cached_result and cached_result.get('confidence', 0) > 0.9:
            return QueryResponse(
                answer=cached_result['answer'],
                sources=cached_result['sources'],
                confidence=cached_result['confidence'],
                strategy_used=cached_result.get('strategy_used', ['CACHE']),
                processing_time=0.0,
                cached=True,
                metadata=cached_result.get('metadata')
            )
        
        return None
    
    async def _combine_results(
        self,
        results: Dict[str, Any],
        query: str,
        strategy: Any
    ) -> Dict[str, Any]:
        """
        Combine results from different agents into a coherent response
        """
        all_sources = []
        all_content = []
        
        # Extract RAG results
        if 'rag' in results:
            rag_results = results['rag']
            for item in rag_results.get('results', []):
                all_sources.append({
                    'type': 'document',
                    'title': item.get('document_title'),
                    'content': item.get('content'),
                    'score': item.get('score'),
                    'source': 'rag'
                })
                all_content.append(item.get('content', ''))
        
        # Extract KAG results
        if 'kag' in results:
            kag_results = results['kag']
            for rel in kag_results.get('relationships', []):
                all_sources.append({
                    'type': 'relationship',
                    'entities': [rel.get('source'), rel.get('target')],
                    'relationship': rel.get('type'),
                    'properties': rel.get('properties', {}),
                    'source': 'kag'
                })
            
            # Add insights as content
            insights = kag_results.get('insights', [])
            all_content.extend(insights)
        
        # Extract temporal results
        if 'temporal' in results:
            temporal_results = results['temporal']
            for event in temporal_results.get('timeline', []):
                all_sources.append({
                    'type': 'temporal',
                    'date': event.get('date'),
                    'event': event.get('description'),
                    'entities': event.get('entities', []),
                    'source': 'temporal'
                })
        
        # Generate comprehensive answer
        context = "\n\n".join(all_content[:5])  # Limit context
        
        answer = await self.orchestrator.generate_answer(
            query=query,
            context=context,
            sources=all_sources[:10]  # Limit sources
        )
        
        # Calculate confidence based on results
        confidence = self._calculate_confidence(results)
        
        return {
            'answer': answer,
            'sources': all_sources,
            'confidence': confidence
        }
    
    async def _update_cache(self, request: QueryRequest, response: QueryResponse):
        """Update cache with query result"""
        await self.cag_agent.update_cache(
            query=request.query,
            result={
                'answer': response.answer,
                'sources': response.sources,
                'confidence': response.confidence,
                'strategy_used': response.strategy_used,
                'metadata': response.metadata
            },
            user_context={
                'user_id': request.user_id,
                'session_id': request.session_id
            },
            query_type=self._determine_query_type(response.strategy_used)
        )
    
    def _calculate_confidence(self, results: Dict[str, Any]) -> float:
        """Calculate overall confidence score"""
        scores = []
        
        if 'rag' in results:
            rag_scores = [r.get('score', 0) for r in results['rag'].get('results', [])]
            if rag_scores:
                scores.append(sum(rag_scores) / len(rag_scores))
        
        if 'kag' in results:
            # KAG confidence based on number of relationships found
            rel_count = len(results['kag'].get('relationships', []))
            scores.append(min(rel_count / 10, 1.0))  # Normalize to 0-1
        
        if 'temporal' in results:
            # Temporal confidence based on timeline completeness
            timeline_count = len(results['temporal'].get('timeline', []))
            scores.append(min(timeline_count / 5, 1.0))  # Normalize to 0-1
        
        return sum(scores) / len(scores) if scores else 0.5
    
    def _determine_query_type(self, strategies: List[str]) -> str:
        """Determine query type based on strategies used"""
        if "KAG-Temporal" in strategies:
            return "temporal"
        elif "KAG" in strategies and "RAG" in strategies:
            return "analytical"
        elif "RAG" in strategies:
            return "factual"
        else:
            return "general"