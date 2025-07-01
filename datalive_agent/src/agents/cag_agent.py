"""
CAG Agent for intelligent caching strategies
"""

import logging
import hashlib
import json
from typing import Dict, Any, List, Optional
from datetime import datetime, timedelta

import redis.asyncio as redis
from ..core.database import get_redis_client
from ..core.embeddings import get_embedding_client
from ..config import settings

logger = logging.getLogger(__name__)


class CAGAgent:
    """
    Cache-Augmented Generation agent with intelligent caching strategies
    """
    
    def __init__(self):
        """Initialize CAG agent"""
        self.redis_client = None
        self.embedding_client = get_embedding_client()
        
        # Cache TTL settings
        self.cache_ttl = {
            'factual': settings.cache_ttl_factual,
            'analytical': settings.cache_ttl_analytical,
            'temporal': settings.cache_ttl_temporal,
            'personal': settings.cache_ttl_personal,
            'general': settings.cache_ttl_factual  # Default
        }
    
    async def _get_redis_client(self):
        """Get Redis client instance"""
        if not self.redis_client:
            self.redis_client = await get_redis_client()
        return self.redis_client
    
    async def check_cache(
        self,
        query: str,
        user_context: Optional[Dict[str, Any]] = None
    ) -> Optional[Dict[str, Any]]:
        """
        Check if query result exists in cache with intelligent lookup
        """
        try:
            redis_client = await self._get_redis_client()
            
            # Generate multiple cache keys for different lookup strategies
            cache_keys = await self._generate_cache_keys(query, user_context)
            
            # Check exact match first
            for key in cache_keys:
                cached_data = await redis_client.get(key)
                if cached_data:
                    result = json.loads(cached_data)
                    
                    # Verify freshness
                    if self._is_fresh(result):
                        logger.info(f"Cache hit for key: {key}")
                        result['cache_key'] = key
                        return result
                    else:
                        # Remove stale cache
                        await redis_client.delete(key)
            
            # If no exact match, try semantic similarity search
            similar_result = await self._find_similar_cached_query(query)
            if similar_result:
                logger.info("Found similar cached query")
                return similar_result
            
            return None
            
        except Exception as e:
            logger.error(f"Error checking cache: {e}")
            return None
    
    async def update_cache(
        self,
        query: str,
        result: Dict[str, Any],
        user_context: Optional[Dict[str, Any]] = None,
        query_type: str = "general"
    ):
        """
        Update cache with query result using intelligent strategy
        """
        try:
            redis_client = await self._get_redis_client()
            
            # Prepare cache data
            cache_data = {
                'query': query,
                'result': result,
                'user_context': user_context or {},
                'query_type': query_type,
                'cached_at': datetime.now().isoformat(),
                'confidence': result.get('confidence', 0.5),
                'ttl': self.cache_ttl.get(query_type, self.cache_ttl['general'])
            }
            
            # Generate cache keys
            cache_keys = await self._generate_cache_keys(query, user_context)
            
            # Get TTL for query type
            ttl = self.cache_ttl.get(query_type, self.cache_ttl['general'])
            
            # Store in cache with different keys
            for key in cache_keys:
                await redis_client.setex(
                    key,
                    ttl,
                    json.dumps(cache_data, default=str)
                )
            
            # Store semantic embedding for similarity search
            await self._store_semantic_cache(query, cache_data)
            
            logger.info(f"Cached query with {len(cache_keys)} keys, TTL: {ttl}s")
            
        except Exception as e:
            logger.error(f"Error updating cache: {e}")
    
    async def _generate_cache_keys(
        self,
        query: str,
        user_context: Optional[Dict[str, Any]] = None
    ) -> List[str]:
        """
        Generate multiple cache keys for different lookup strategies
        """
        keys = []
        
        # 1. Exact query key
        exact_key = f"exact:{self._hash_text(query)}"
        keys.append(exact_key)
        
        # 2. Normalized query key (lowercase, trimmed)
        normalized_query = query.lower().strip()
        normalized_key = f"normalized:{self._hash_text(normalized_query)}"
        keys.append(normalized_key)
        
        # 3. User-specific key
        if user_context and user_context.get('user_id'):
            user_key = f"user:{user_context['user_id']}:{self._hash_text(query)}"
            keys.append(user_key)
        
        # 4. Session-specific key
        if user_context and user_context.get('session_id'):
            session_key = f"session:{user_context['session_id']}:{self._hash_text(query)}"
            keys.append(session_key)
        
        # 5. Semantic hash key
        semantic_hash = await self._get_semantic_hash(query)
        if semantic_hash:
            semantic_key = f"semantic:{semantic_hash}"
            keys.append(semantic_key)
        
        return keys
    
    async def _store_semantic_cache(
        self,
        query: str,
        cache_data: Dict[str, Any]
    ):
        """
        Store query embedding for semantic similarity search
        """
        try:
            # Generate embedding
            embedding = await self.embedding_client.embed_text(query)
            
            # Store in a separate Redis key for semantic search
            semantic_data = {
                'query': query,
                'embedding': embedding,
                'cache_data': cache_data,
                'created_at': datetime.now().isoformat()
            }
            
            redis_client = await self._get_redis_client()
            semantic_key = f"semantic_embeddings:{self._hash_text(query)}"
            
            # Store with longer TTL for semantic search
            await redis_client.setex(
                semantic_key,
                self.cache_ttl['analytical'],
                json.dumps(semantic_data, default=str)
            )
            
        except Exception as e:
            logger.error(f"Error storing semantic cache: {e}")
    
    async def _find_similar_cached_query(
        self,
        query: str,
        similarity_threshold: float = 0.85
    ) -> Optional[Dict[str, Any]]:
        """
        Find semantically similar cached queries
        """
        try:
            redis_client = await self._get_redis_client()
            
            # Get query embedding
            query_embedding = await self.embedding_client.embed_text(query)
            
            # Find all semantic embeddings
            pattern = "semantic_embeddings:*"
            keys = await redis_client.keys(pattern)
            
            best_match = None
            best_similarity = 0.0
            
            for key in keys[:50]:  # Limit search for performance
                cached_data = await redis_client.get(key)
                if cached_data:
                    try:
                        data = json.loads(cached_data)
                        cached_embedding = data['embedding']
                        
                        # Calculate cosine similarity
                        similarity = self._cosine_similarity(
                            query_embedding,
                            cached_embedding
                        )
                        
                        if similarity > similarity_threshold and similarity > best_similarity:
                            best_similarity = similarity
                            best_match = data['cache_data']
                            best_match['similarity_score'] = similarity
                            best_match['original_query'] = data['query']
                    except Exception:
                        continue
            
            if best_match:
                logger.info(f"Found similar query with similarity: {best_similarity:.3f}")
            
            return best_match
            
        except Exception as e:
            logger.error(f"Error finding similar cached query: {e}")
            return None
    
    async def _get_semantic_hash(self, text: str) -> Optional[str]:
        """
        Generate semantic hash for text
        """
        try:
            # Simple approach: use important keywords
            import re
            
            # Extract meaningful words (remove stop words, short words)
            stop_words = {
                'a', 'an', 'and', 'are', 'as', 'at', 'be', 'by', 'for', 'from',
                'has', 'he', 'in', 'is', 'it', 'its', 'of', 'on', 'that', 'the',
                'to', 'was', 'will', 'with', 'what', 'how', 'when', 'where', 'who'
            }
            
            words = re.findall(r'\b\w+\b', text.lower())
            meaningful_words = [
                word for word in words 
                if len(word) > 3 and word not in stop_words
            ]
            
            if meaningful_words:
                # Sort and join to create consistent hash
                meaningful_words.sort()
                semantic_content = ' '.join(meaningful_words[:10])  # Limit words
                return self._hash_text(semantic_content)
            
            return None
            
        except Exception as e:
            logger.error(f"Error generating semantic hash: {e}")
            return None
    
    def _hash_text(self, text: str) -> str:
        """Generate hash for text"""
        return hashlib.md5(text.encode()).hexdigest()
    
    def _is_fresh(self, cached_result: Dict[str, Any]) -> bool:
        """Check if cached result is still fresh"""
        try:
            cached_at = datetime.fromisoformat(cached_result['cached_at'])
            ttl = cached_result.get('ttl', self.cache_ttl['general'])
            
            age = (datetime.now() - cached_at).total_seconds()
            return age < ttl
            
        except Exception:
            return False
    
    def _cosine_similarity(self, vec1: List[float], vec2: List[float]) -> float:
        """Calculate cosine similarity between two vectors"""
        try:
            import numpy as np
            
            vec1 = np.array(vec1)
            vec2 = np.array(vec2)
            
            dot_product = np.dot(vec1, vec2)
            norm1 = np.linalg.norm(vec1)
            norm2 = np.linalg.norm(vec2)
            
            if norm1 == 0 or norm2 == 0:
                return 0.0
            
            return dot_product / (norm1 * norm2)
            
        except Exception:
            return 0.0
    
    async def invalidate_cache_pattern(self, pattern: str):
        """Invalidate cache entries matching pattern"""
        try:
            redis_client = await self._get_redis_client()
            keys = await redis_client.keys(pattern)
            
            if keys:
                await redis_client.delete(*keys)
                logger.info(f"Invalidated {len(keys)} cache entries matching: {pattern}")
            
        except Exception as e:
            logger.error(f"Error invalidating cache: {e}")
    
    async def get_cache_stats(self) -> Dict[str, Any]:
        """Get cache statistics"""
        try:
            redis_client = await self._get_redis_client()
            
            # Get info about different cache types
            stats = {}
            
            for cache_type in ['exact', 'normalized', 'user', 'session', 'semantic']:
                pattern = f"{cache_type}:*"
                keys = await redis_client.keys(pattern)
                stats[cache_type] = len(keys)
            
            # Get memory usage
            info = await redis_client.info('memory')
            stats['memory_used'] = info.get('used_memory_human', 'Unknown')
            stats['memory_peak'] = info.get('used_memory_peak_human', 'Unknown')
            
            return stats
            
        except Exception as e:
            logger.error(f"Error getting cache stats: {e}")
            return {}