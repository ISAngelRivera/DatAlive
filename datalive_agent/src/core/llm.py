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
        if settings.llm_provider == "ollama":
            from pydantic_ai.models.ollama import OllamaModel
            return OllamaModel(
                model_name=settings.llm_model,
                base_url=settings.llm_base_url.replace('/v1', ''),  # Remove /v1 suffix for Ollama
            )
        elif settings.llm_provider == "openai":
            from pydantic_ai.models.openai import OpenAIModel
            return OpenAIModel(
                model_name=settings.llm_model,
                api_key=settings.llm_api_key,
                base_url=settings.llm_base_url
            )
        elif settings.llm_provider == "gemini":
            from pydantic_ai.models.gemini import GeminiModel
            return GeminiModel(
                model_name=settings.llm_model,
                api_key=settings.llm_api_key
            )
        else:
            raise ValueError(f"Unsupported LLM provider: {settings.llm_provider}")
            
    except Exception as e:
        logger.error(f"Error configuring LLM model: {e}")
        # Fallback to a simple model
        from pydantic_ai.models.test import TestModel
        return TestModel()


def get_llm_client():
    """Get direct LLM client for non-Pydantic AI usage"""
    try:
        if settings.llm_provider == "ollama":
            import httpx
            return httpx.AsyncClient(base_url=settings.llm_base_url)
        elif settings.llm_provider == "openai":
            from openai import AsyncOpenAI
            return AsyncOpenAI(
                api_key=settings.llm_api_key,
                base_url=settings.llm_base_url
            )
        else:
            raise ValueError(f"Unsupported LLM provider: {settings.llm_provider}")
            
    except Exception as e:
        logger.error(f"Error creating LLM client: {e}")
        return None