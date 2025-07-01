"""
Embedding generation client
"""

import logging
from typing import List
import httpx

from ..config import settings

logger = logging.getLogger(__name__)


class EmbeddingClient:
    """Client for generating embeddings"""
    
    def __init__(self):
        self.base_url = settings.llm_base_url
        self.api_key = settings.llm_api_key
        self.model = settings.embedding_model
        self.client = httpx.AsyncClient(timeout=30.0)
    
    async def embed_text(self, text: str) -> List[float]:
        """Generate embedding for text"""
        try:
            if settings.embedding_provider == "ollama":
                return await self._embed_ollama(text)
            elif settings.embedding_provider == "openai":
                return await self._embed_openai(text)
            else:
                raise ValueError(f"Unsupported embedding provider: {settings.embedding_provider}")
                
        except Exception as e:
            logger.error(f"Error generating embedding: {e}")
            # Return zero vector as fallback
            return [0.0] * settings.vector_dimension
    
    async def _embed_ollama(self, text: str) -> List[float]:
        """Generate embedding using Ollama"""
        response = await self.client.post(
            f"{self.base_url}/api/embeddings",
            json={
                "model": self.model,
                "prompt": text
            }
        )
        response.raise_for_status()
        
        data = response.json()
        return data["embedding"]
    
    async def _embed_openai(self, text: str) -> List[float]:
        """Generate embedding using OpenAI"""
        response = await self.client.post(
            f"{self.base_url}/embeddings",
            headers={
                "Authorization": f"Bearer {self.api_key}",
                "Content-Type": "application/json"
            },
            json={
                "model": self.model,
                "input": text
            }
        )
        response.raise_for_status()
        
        data = response.json()
        return data["data"][0]["embedding"]
    
    async def close(self):
        """Close the HTTP client"""
        await self.client.aclose()


# Global embedding client
_embedding_client = None


def get_embedding_client() -> EmbeddingClient:
    """Get global embedding client"""
    global _embedding_client
    if not _embedding_client:
        _embedding_client = EmbeddingClient()
    return _embedding_client