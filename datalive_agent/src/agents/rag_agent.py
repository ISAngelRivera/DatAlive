"""
RAG Agent for vector-based semantic search
"""

import logging
from typing import Dict, Any, List, Optional
import asyncpg
import numpy as np

from ..core.database import get_postgres_pool
from ..core.embeddings import get_embedding_client
from ..config import settings

logger = logging.getLogger(__name__)


class RAGResult:
    """Result from RAG search"""
    def __init__(
        self,
        chunk_id: str,
        content: str,
        score: float,
        document_title: str,
        document_source: str,
        metadata: Optional[Dict[str, Any]] = None
    ):
        self.chunk_id = chunk_id
        self.content = content
        self.score = score
        self.document_title = document_title
        self.document_source = document_source
        self.metadata = metadata or {}


class RAGAgent:
    """
    RAG Agent that performs semantic search using vector embeddings
    """
    
    def __init__(self):
        """Initialize RAG agent"""
        self.embedding_client = get_embedding_client()
        
    async def search(
        self,
        query: str,
        filters: Optional[Dict[str, Any]] = None,
        limit: int = 10,
        threshold: Optional[float] = None
    ) -> Dict[str, Any]:
        """
        Perform semantic search using vector embeddings
        """
        try:
            # Generate query embedding
            query_embedding = await self._generate_embedding(query)
            
            # Perform vector search
            results = await self._vector_search(
                embedding=query_embedding,
                filters=filters,
                limit=limit,
                threshold=threshold or settings.VECTOR_SEARCH_THRESHOLD
            )
            
            # Process results
            rag_results = []
            for row in results:
                result = RAGResult(
                    chunk_id=str(row['chunk_id']),
                    content=row['content'],
                    score=float(row['similarity']),
                    document_title=row['document_title'],
                    document_source=row['document_source'],
                    metadata={
                        'chunk_index': row['chunk_index'],
                        'document_id': str(row['document_id']),
                        'created_at': row['created_at'].isoformat() if row['created_at'] else None
                    }
                )
                rag_results.append(result)
            
            logger.info(f"RAG search returned {len(rag_results)} results")
            
            return {
                'query': query,
                'results': [
                    {
                        'chunk_id': r.chunk_id,
                        'content': r.content,
                        'score': r.score,
                        'document_title': r.document_title,
                        'document_source': r.document_source,
                        'metadata': r.metadata
                    }
                    for r in rag_results
                ],
                'total_results': len(rag_results),
                'filters_applied': filters or {}
            }
            
        except Exception as e:
            logger.error(f"Error in RAG search: {e}")
            return {
                'query': query,
                'results': [],
                'total_results': 0,
                'error': str(e)
            }
    
    async def _generate_embedding(self, text: str) -> List[float]:
        """Generate embedding for text"""
        try:
            embedding = await self.embedding_client.embed_text(text)
            return embedding
        except Exception as e:
            logger.error(f"Error generating embedding: {e}")
            # Return zero vector as fallback
            return [0.0] * settings.EMBEDDING_DIMENSIONS
    
    async def _vector_search(
        self,
        embedding: List[float],
        filters: Optional[Dict[str, Any]] = None,
        limit: int = 10,
        threshold: float = 0.7
    ) -> List[Dict[str, Any]]:
        """
        Perform vector similarity search in PostgreSQL
        """
        pool = await get_postgres_pool()
        
        # Build the SQL query
        base_query = """
        SELECT 
            c.chunk_id,
            c.content,
            c.chunk_index,
            c.created_at,
            d.document_id,
            d.title as document_title,
            d.source as document_source,
            1 - (c.embedding <=> $1::vector) as similarity
        FROM documents.chunks c
        JOIN documents.documents d ON c.document_id = d.document_id
        WHERE 1 - (c.embedding <=> $1::vector) >= $2
        """
        
        # Add filters if provided
        params = [embedding, threshold]
        param_count = 2
        
        if filters:
            if 'document_type' in filters:
                param_count += 1
                base_query += f" AND d.document_type = ${param_count}"
                params.append(filters['document_type'])
            
            if 'source' in filters:
                param_count += 1
                base_query += f" AND d.source ILIKE ${param_count}"
                params.append(f"%{filters['source']}%")
            
            if 'date_from' in filters:
                param_count += 1
                base_query += f" AND d.created_at >= ${param_count}"
                params.append(filters['date_from'])
            
            if 'date_to' in filters:
                param_count += 1
                base_query += f" AND d.created_at <= ${param_count}"
                params.append(filters['date_to'])
        
        # Add ordering and limit
        base_query += f"""
        ORDER BY similarity DESC
        LIMIT ${param_count + 1}
        """
        params.append(limit)
        
        try:
            async with pool.acquire() as conn:
                rows = await conn.fetch(base_query, *params)
                return [dict(row) for row in rows]
        except Exception as e:
            logger.error(f"Database error in vector search: {e}")
            return []
    
    async def get_document_context(
        self,
        document_id: str,
        chunk_limit: int = 5
    ) -> Dict[str, Any]:
        """
        Get full context for a document
        """
        pool = await get_postgres_pool()
        
        query = """
        SELECT 
            d.document_id,
            d.title,
            d.source,
            d.document_type,
            d.created_at,
            array_agg(c.content ORDER BY c.chunk_index) as chunks
        FROM documents.documents d
        LEFT JOIN documents.chunks c ON d.document_id = c.document_id
        WHERE d.document_id = $1
        GROUP BY d.document_id, d.title, d.source, d.document_type, d.created_at
        """
        
        try:
            async with pool.acquire() as conn:
                row = await conn.fetchrow(query, document_id)
                if row:
                    chunks = row['chunks'][:chunk_limit] if row['chunks'] else []
                    return {
                        'document_id': str(row['document_id']),
                        'title': row['title'],
                        'source': row['source'],
                        'document_type': row['document_type'],
                        'created_at': row['created_at'].isoformat() if row['created_at'] else None,
                        'content': '\n\n'.join(chunks),
                        'chunk_count': len(chunks)
                    }
                else:
                    return {}
        except Exception as e:
            logger.error(f"Error getting document context: {e}")
            return {}
    
    async def search_similar_documents(
        self,
        query: str,
        limit: int = 5
    ) -> List[Dict[str, Any]]:
        """
        Search for similar documents (not chunks)
        """
        try:
            # Generate query embedding
            query_embedding = await self._generate_embedding(query)
            
            pool = await get_postgres_pool()
            
            # Search at document level using average chunk embeddings
            query = """
            WITH doc_similarities AS (
                SELECT 
                    d.document_id,
                    d.title,
                    d.source,
                    d.document_type,
                    d.created_at,
                    AVG(1 - (c.embedding <=> $1::vector)) as avg_similarity
                FROM documents.documents d
                JOIN documents.chunks c ON d.document_id = c.document_id
                GROUP BY d.document_id, d.title, d.source, d.document_type, d.created_at
            )
            SELECT *
            FROM doc_similarities
            WHERE avg_similarity >= $2
            ORDER BY avg_similarity DESC
            LIMIT $3
            """
            
            async with pool.acquire() as conn:
                rows = await conn.fetch(
                    query,
                    query_embedding,
                    settings.VECTOR_SEARCH_THRESHOLD,
                    limit
                )
                
                return [
                    {
                        'document_id': str(row['document_id']),
                        'title': row['title'],
                        'source': row['source'],
                        'document_type': row['document_type'],
                        'similarity': float(row['avg_similarity']),
                        'created_at': row['created_at'].isoformat() if row['created_at'] else None
                    }
                    for row in rows
                ]
                
        except Exception as e:
            logger.error(f"Error in document similarity search: {e}")
            return []