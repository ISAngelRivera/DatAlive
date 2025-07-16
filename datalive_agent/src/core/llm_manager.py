"""
Advanced LLM Manager with Intelligent Fallback System
Supports multiple models with automatic resource monitoring and fallback
"""

import asyncio
import logging
import psutil
import time
from enum import Enum
from typing import Any, Dict, List, Optional, Union
from dataclasses import dataclass
from contextlib import asynccontextmanager

import httpx
from ..config import settings

logger = logging.getLogger(__name__)


class ModelTier(Enum):
    """Model performance tiers"""
    PRIMARY = "primary"      # phi4 - Best reasoning, highest memory
    FALLBACK = "fallback"    # phi3:medium - Good balance
    LIGHT = "light"          # phi4-mini - Fast, low memory


class ModelStatus(Enum):
    """Model availability status"""
    AVAILABLE = "available"
    UNAVAILABLE = "unavailable" 
    LOADING = "loading"
    ERROR = "error"


@dataclass
class ModelConfig:
    """Configuration for a specific model"""
    name: str
    tier: ModelTier
    memory_requirement_gb: float
    max_context_length: int
    supports_reasoning: bool
    speed_rating: int  # 1-10, higher is faster


class LLMManager:
    """Intelligent LLM Manager with automatic fallback"""
    
    def __init__(self):
        self.base_url = settings.llm_base_url.replace('/v1', '')
        self.client = None
        self._model_status: Dict[str, ModelStatus] = {}
        self._model_configs = self._init_model_configs()
        self._current_model = None
        self._last_health_check = 0
        self._health_check_interval = 30  # seconds
        
    def _init_model_configs(self) -> Dict[str, ModelConfig]:
        """Initialize model configurations"""
        return {
            getattr(settings, 'llm_model_primary', 'phi4'): ModelConfig(
                name=getattr(settings, 'llm_model_primary', 'phi4'),
                tier=ModelTier.PRIMARY,
                memory_requirement_gb=8.0,
                max_context_length=128000,
                supports_reasoning=True,
                speed_rating=7
            ),
            getattr(settings, 'llm_model_fallback', 'phi3:medium'): ModelConfig(
                name=getattr(settings, 'llm_model_fallback', 'phi3:medium'),
                tier=ModelTier.FALLBACK,
                memory_requirement_gb=6.0,
                max_context_length=128000,
                supports_reasoning=True,
                speed_rating=8
            ),
            getattr(settings, 'llm_model_light', 'phi4-mini'): ModelConfig(
                name=getattr(settings, 'llm_model_light', 'phi4-mini'),
                tier=ModelTier.LIGHT,
                memory_requirement_gb=2.5,
                max_context_length=128000,
                supports_reasoning=False,
                speed_rating=10
            )
        }
    
    async def initialize(self):
        """Initialize the LLM manager"""
        try:
            self.client = httpx.AsyncClient(
                base_url=self.base_url,
                timeout=httpx.Timeout(60.0)
            )
            await self._check_all_models_health()
            self._current_model = await self._select_best_model()
            logger.info(f"LLM Manager initialized with model: {self._current_model}")
        except Exception as e:
            logger.error(f"Failed to initialize LLM Manager: {e}")
            raise
    
    async def _check_model_availability(self, model_name: str) -> ModelStatus:
        """Check if a specific model is available"""
        try:
            if not self.client:
                return ModelStatus.UNAVAILABLE
                
            response = await self.client.get("/api/tags")
            if response.status_code != 200:
                return ModelStatus.UNAVAILABLE
                
            models_data = response.json()
            available_models = [model['name'] for model in models_data.get('models', [])]
            
            # Check exact match or partial match for phi4 -> phi4:latest
            model_available = any(
                model_name in available_model or available_model.startswith(model_name + ":")
                for available_model in available_models
            )
            
            return ModelStatus.AVAILABLE if model_available else ModelStatus.UNAVAILABLE
            
        except Exception as e:
            logger.warning(f"Error checking model {model_name}: {e}")
            return ModelStatus.ERROR
    
    async def _check_all_models_health(self):
        """Check health of all configured models"""
        current_time = time.time()
        if current_time - self._last_health_check < self._health_check_interval:
            return
            
        for model_name in self._model_configs.keys():
            status = await self._check_model_availability(model_name)
            self._model_status[model_name] = status
            logger.debug(f"Model {model_name}: {status.value}")
            
        self._last_health_check = current_time
    
    def _get_available_memory_gb(self) -> float:
        """Get available system memory in GB"""
        try:
            memory = psutil.virtual_memory()
            return memory.available / (1024**3)
        except Exception as e:
            logger.warning(f"Error getting memory info: {e}")
            return 4.0  # Conservative fallback
    
    async def _select_best_model(self, task_type: str = "general") -> Optional[str]:
        """Select the best available model based on resources and task type"""
        await self._check_all_models_health()
        available_memory = self._get_available_memory_gb()
        
        # Define model priority based on task type
        if task_type == "reasoning":
            priority_order = [ModelTier.PRIMARY, ModelTier.FALLBACK, ModelTier.LIGHT]
        elif task_type == "speed":
            priority_order = [ModelTier.LIGHT, ModelTier.FALLBACK, ModelTier.PRIMARY]
        else:  # general
            priority_order = [ModelTier.PRIMARY, ModelTier.FALLBACK, ModelTier.LIGHT]
        
        # Check memory threshold setting
        memory_threshold = getattr(settings, 'llm_memory_threshold_gb', 7.0)
        auto_fallback = getattr(settings, 'llm_auto_fallback', True)
        
        for tier in priority_order:
            for model_name, config in self._model_configs.items():
                if (config.tier == tier and 
                    self._model_status.get(model_name) == ModelStatus.AVAILABLE):
                    
                    # Check memory requirements
                    if auto_fallback and available_memory < memory_threshold:
                        if config.memory_requirement_gb <= available_memory:
                            logger.info(f"Selected model {model_name} (memory constraint: {available_memory:.1f}GB available)")
                            return model_name
                    else:
                        logger.info(f"Selected model {model_name} (preferred)")
                        return model_name
        
        logger.error("No suitable model available!")
        return None
    
    async def get_model_for_task(self, task_type: str = "general") -> Optional[str]:
        """Get the best model for a specific task type"""
        if not self._current_model or task_type != "general":
            self._current_model = await self._select_best_model(task_type)
        return self._current_model
    
    async def generate_completion(self, 
                                prompt: str, 
                                model: Optional[str] = None,
                                max_tokens: int = 2048,
                                temperature: float = 0.7,
                                **kwargs) -> Optional[str]:
        """Generate completion with automatic fallback"""
        target_model = model or await self.get_model_for_task()
        if not target_model:
            raise ValueError("No suitable model available")
        
        retry_attempts = getattr(settings, 'llm_retry_attempts', 2)
        fallback_on_error = getattr(settings, 'llm_fallback_on_error', True)
        
        for attempt in range(retry_attempts + 1):
            try:
                response = await self.client.post("/api/generate", json={
                    "model": target_model,
                    "prompt": prompt,
                    "stream": False,
                    "options": {
                        "num_predict": max_tokens,
                        "temperature": temperature,
                        **kwargs
                    }
                })
                
                if response.status_code == 200:
                    result = response.json()
                    return result.get("response", "")
                else:
                    logger.warning(f"Model {target_model} returned status {response.status_code}")
                    
            except Exception as e:
                logger.warning(f"Error with model {target_model} (attempt {attempt + 1}): {e}")
                
                # Mark model as problematic
                self._model_status[target_model] = ModelStatus.ERROR
                
                # Try fallback if enabled
                if fallback_on_error and attempt < retry_attempts:
                    fallback_model = await self._select_best_model()
                    if fallback_model and fallback_model != target_model:
                        logger.info(f"Falling back to model: {fallback_model}")
                        target_model = fallback_model
                    else:
                        break
                        
        raise Exception(f"All models failed after {retry_attempts + 1} attempts")
    
    async def stream_completion(self, 
                               prompt: str, 
                               model: Optional[str] = None,
                               **kwargs):
        """Stream completion with fallback (async generator)"""
        target_model = model or await self.get_model_for_task()
        if not target_model:
            raise ValueError("No suitable model available")
            
        try:
            async with self.client.stream("POST", "/api/generate", json={
                "model": target_model,
                "prompt": prompt,
                "stream": True,
                **kwargs
            }) as response:
                async for line in response.aiter_lines():
                    if line:
                        try:
                            data = line.json() if hasattr(line, 'json') else {}
                            if "response" in data:
                                yield data["response"]
                        except:
                            continue
                            
        except Exception as e:
            logger.error(f"Streaming error with {target_model}: {e}")
            raise
    
    def get_model_info(self) -> Dict[str, Any]:
        """Get information about available models"""
        return {
            "current_model": self._current_model,
            "available_memory_gb": self._get_available_memory_gb(),
            "model_status": {name: status.value for name, status in self._model_status.items()},
            "model_configs": {name: {
                "tier": config.tier.value,
                "memory_requirement_gb": config.memory_requirement_gb,
                "supports_reasoning": config.supports_reasoning,
                "speed_rating": config.speed_rating
            } for name, config in self._model_configs.items()}
        }
    
    async def health_check(self) -> Dict[str, Any]:
        """Comprehensive health check"""
        await self._check_all_models_health()
        return {
            "status": "healthy" if self._current_model else "degraded",
            "current_model": self._current_model,
            "models_available": len([s for s in self._model_status.values() if s == ModelStatus.AVAILABLE]),
            "total_models": len(self._model_configs),
            **self.get_model_info()
        }
    
    async def close(self):
        """Clean up resources"""
        if self.client:
            await self.client.aclose()


# Global instance
llm_manager = LLMManager()


# Compatibility functions for existing code
async def get_llm_model() -> Any:
    """Get configured LLM model for Pydantic AI with fallback support"""
    try:
        if not llm_manager.client:
            await llm_manager.initialize()
            
        current_model = await llm_manager.get_model_for_task()
        
        if settings.llm_provider == "ollama":
            from pydantic_ai.models.ollama import OllamaModel
            return OllamaModel(
                model_name=current_model or settings.llm_model,
                base_url=settings.llm_base_url.replace('/v1', ''),
            )
        # ... other providers as before
        
    except Exception as e:
        logger.error(f"Error configuring LLM model: {e}")
        from pydantic_ai.models.test import TestModel
        return TestModel()


async def get_llm_client():
    """Get LLM manager instance"""
    if not llm_manager.client:
        await llm_manager.initialize()
    return llm_manager