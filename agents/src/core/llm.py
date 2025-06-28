"""
LLM model configuration and client
"""

import logging
from typing import Any

from ..config import settings

logger = logging.getLogger(__name__)


def get_llm_model() -> Any:
    """Get configured LLM model for Pydantic AI"""
    try:
        if settings.LLM_PROVIDER == "ollama":
            from pydantic_ai.models.ollama import OllamaModel
            return OllamaModel(
                model_name=settings.LLM_CHOICE,
                base_url=settings.LLM_BASE_URL.replace('/v1', ''),  # Remove /v1 suffix for Ollama
            )
        elif settings.LLM_PROVIDER == "openai":
            from pydantic_ai.models.openai import OpenAIModel
            return OpenAIModel(
                model_name=settings.LLM_CHOICE,
                api_key=settings.LLM_API_KEY,
                base_url=settings.LLM_BASE_URL
            )
        elif settings.LLM_PROVIDER == "gemini":
            from pydantic_ai.models.gemini import GeminiModel
            return GeminiModel(
                model_name=settings.LLM_CHOICE,
                api_key=settings.LLM_API_KEY
            )
        else:
            raise ValueError(f"Unsupported LLM provider: {settings.LLM_PROVIDER}")
            
    except Exception as e:
        logger.error(f"Error configuring LLM model: {e}")
        # Fallback to a simple model
        from pydantic_ai.models.test import TestModel
        return TestModel()


def get_llm_client():
    """Get direct LLM client for non-Pydantic AI usage"""
    try:
        if settings.LLM_PROVIDER == "ollama":
            import httpx
            return httpx.AsyncClient(base_url=settings.LLM_BASE_URL)
        elif settings.LLM_PROVIDER == "openai":
            from openai import AsyncOpenAI
            return AsyncOpenAI(
                api_key=settings.LLM_API_KEY,
                base_url=settings.LLM_BASE_URL
            )
        else:
            raise ValueError(f"Unsupported LLM provider: {settings.LLM_PROVIDER}")
            
    except Exception as e:
        logger.error(f"Error creating LLM client: {e}")
        return None