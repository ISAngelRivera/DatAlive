"""
Vector store implementation for DataLive Unified Agent
"""

import logging
from typing import List, Dict, Any, Optional
import asyncio

try:
    from qdrant_client import AsyncQdrantClient
    from qdrant_client.models import (
        Distance, VectorParams, PointStruct, 
        Filter, FieldCondition, MatchValue
    )
    from qdrant_client.http.exceptions import QdrantException
except ImportError:
    AsyncQdrantClient = None
    QdrantException = Exception

try:
    from sentence_transformers import SentenceTransformer
except ImportError:
    SentenceTransformer = None

from ..config import settings

logger = logging.getLogger(__name__)


class VectorStore:
    """Vector store using Qdrant for similarity search"""
    
    def __init__(self):
        self.client: Optional[AsyncQdrantClient] = None
        self.encoder = None
        self.collection_name = settings.vector_collection_name
        self.vector_dimension = settings.vector_dimension
        
    async def initialize(self) -> bool:
        """Initialize vector store connection and encoder"""
        try:
            # Initialize Qdrant client
            if AsyncQdrantClient:
                self.client = AsyncQdrantClient(
                    url=settings.qdrant_url,
                    timeout=60
                )
                
                # Test connection
                await self.client.get_collections()
                logger.info("✅ Qdrant client connected")
            else:
                logger.warning("Qdrant client not available")
                return False
            
            # Initialize sentence transformer
            if SentenceTransformer:
                self.encoder = SentenceTransformer(settings.embedding_model)
                logger.info(f"✅ Sentence transformer loaded: {settings.embedding_model}")
            else:
                logger.warning("SentenceTransformer not available")
                return False
            
            # Ensure collection exists
            await self._ensure_collection_exists()
            
            return True
            
        except Exception as e:
            logger.error(f"Failed to initialize vector store: {e}")
            return False
    
    async def _ensure_collection_exists(self):
        """Ensure the collection exists in Qdrant"""
        try:
            collections = await self.client.get_collections()
            collection_names = [col.name for col in collections.collections]
            
            if self.collection_name not in collection_names:
                logger.info(f"Creating collection: {self.collection_name}")
                await self.client.create_collection(
                    collection_name=self.collection_name,
                    vectors_config=VectorParams(
                        size=self.vector_dimension,
                        distance=Distance.COSINE
                    )
                )
                logger.info(f"✅ Collection {self.collection_name} created")
            else:
                logger.info(f"✅ Collection {self.collection_name} already exists")
                
        except Exception as e:
            logger.error(f"Error ensuring collection exists: {e}")
            raise
    
    async def add_document(
        self,
        content: str,
        metadata: Dict[str, Any],
        document_id: Optional[str] = None
    ) -> bool:
        """Add document to vector store"""
        try:
            if not self.client or not self.encoder:
                logger.error("Vector store not initialized")
                return False
            
            # Generate embedding
            embedding = self.encoder.encode(content).tolist()
            
            # Create point
            point_id = document_id or f"doc_{len(content)}_{hash(content) % 1000000}"
            
            point = PointStruct(
                id=point_id,
                vector=embedding,
                payload={
                    "content": content,
                    **metadata
                }
            )
            
            # Upload to Qdrant
            await self.client.upsert(
                collection_name=self.collection_name,
                points=[point]
            )
            
            logger.debug(f"Document added to vector store: {point_id}")
            return True
            
        except Exception as e:
            logger.error(f"Error adding document to vector store: {e}")
            return False
    
    async def search(
        self,
        query: str,
        limit: int = 10,
        threshold: float = 0.7,
        filters: Optional[Dict[str, Any]] = None
    ) -> List[Dict[str, Any]]:
        """Search for similar documents"""
        try:
            if not self.client or not self.encoder:
                logger.error("Vector store not initialized")
                return []
            
            # Generate query embedding
            query_embedding = self.encoder.encode(query).tolist()
            
            # Build filter if provided
            search_filter = None
            if filters:
                conditions = []
                for key, value in filters.items():
                    conditions.append(
                        FieldCondition(key=key, match=MatchValue(value=value))
                    )
                if conditions:
                    search_filter = Filter(must=conditions)
            
            # Search in Qdrant
            search_results = await self.client.search(
                collection_name=self.collection_name,
                query_vector=query_embedding,
                query_filter=search_filter,
                limit=limit,
                score_threshold=threshold
            )
            
            # Format results
            results = []
            for result in search_results:
                results.append({
                    "id": result.id,
                    "score": result.score,
                    "content": result.payload.get("content", ""),
                    "metadata": {k: v for k, v in result.payload.items() if k != "content"}
                })
            
            logger.debug(f"Vector search returned {len(results)} results")
            return results
            
        except Exception as e:
            logger.error(f"Error in vector search: {e}")
            return []
    
    async def delete_document(self, document_id: str) -> bool:
        """Delete document from vector store"""
        try:
            if not self.client:
                logger.error("Vector store not initialized")
                return False
            
            await self.client.delete(
                collection_name=self.collection_name,
                points_selector=[document_id]
            )
            
            logger.debug(f"Document deleted from vector store: {document_id}")
            return True
            
        except Exception as e:
            logger.error(f"Error deleting document: {e}")
            return False
    
    async def get_collection_info(self) -> Dict[str, Any]:
        """Get information about the collection"""
        try:
            if not self.client:
                return {"error": "Vector store not initialized"}
            
            collection_info = await self.client.get_collection(self.collection_name)
            
            return {
                "name": self.collection_name,
                "vectors_count": collection_info.vectors_count,
                "indexed_vectors_count": collection_info.indexed_vectors_count,
                "points_count": collection_info.points_count,
                "segments_count": collection_info.segments_count,
                "status": collection_info.status.value if collection_info.status else "unknown"
            }
            
        except Exception as e:
            logger.error(f"Error getting collection info: {e}")
            return {"error": str(e)}
    
    async def health_check(self) -> bool:
        """Perform health check on vector store"""
        try:
            if not self.client:
                return False
            
            # Test connection by getting collections
            await self.client.get_collections()
            
            # Test collection access
            await self.client.get_collection(self.collection_name)
            
            return True
            
        except Exception as e:
            logger.error(f"Vector store health check failed: {e}")
            return False
    
    async def close(self):
        """Close vector store connections"""
        if self.client:
            try:
                await self.client.close()
                logger.info("Vector store connection closed")
            except Exception as e:
                logger.error(f"Error closing vector store: {e}")


# Fallback implementation for when Qdrant is not available
class MockVectorStore:
    """Mock vector store for testing/development"""
    
    def __init__(self):
        self.documents = {}
        self.next_id = 1
    
    async def initialize(self) -> bool:
        logger.warning("Using mock vector store - install qdrant-client for full functionality")
        return True
    
    async def add_document(
        self,
        content: str,
        metadata: Dict[str, Any],
        document_id: Optional[str] = None
    ) -> bool:
        doc_id = document_id or f"mock_doc_{self.next_id}"
        self.next_id += 1
        
        self.documents[doc_id] = {
            "content": content,
            "metadata": metadata
        }
        return True
    
    async def search(
        self,
        query: str,
        limit: int = 10,
        threshold: float = 0.7,
        filters: Optional[Dict[str, Any]] = None
    ) -> List[Dict[str, Any]]:
        # Simple keyword matching for mock
        results = []
        query_words = set(query.lower().split())
        
        for doc_id, doc_data in list(self.documents.items())[:limit]:
            content_words = set(doc_data["content"].lower().split())
            overlap = len(query_words.intersection(content_words))
            
            if overlap > 0:
                score = overlap / len(query_words.union(content_words))
                if score >= threshold:
                    results.append({
                        "id": doc_id,
                        "score": score,
                        "content": doc_data["content"],
                        "metadata": doc_data["metadata"]
                    })
        
        # Sort by score
        results.sort(key=lambda x: x["score"], reverse=True)
        return results[:limit]
    
    async def delete_document(self, document_id: str) -> bool:
        if document_id in self.documents:
            del self.documents[document_id]
            return True
        return False
    
    async def get_collection_info(self) -> Dict[str, Any]:
        return {
            "name": "mock_collection",
            "vectors_count": len(self.documents),
            "status": "mock"
        }
    
    async def health_check(self) -> bool:
        return True
    
    async def close(self):
        pass