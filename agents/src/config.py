"""
Configuration for DataLive Unified Agent
"""

from typing import Optional
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application settings"""
    
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False
    )
    
    # Application settings
    HOST: str = "0.0.0.0"
    PORT: int = 8058
    RELOAD: bool = False
    LOG_LEVEL: str = "INFO"
    PRELOAD_MODELS: bool = True
    
    # Database connections
    POSTGRES_URL: str
    NEO4J_URI: str = "bolt://neo4j:7687"
    NEO4J_USER: str = "neo4j"
    NEO4J_PASSWORD: str = "adminpassword"
    REDIS_URL: str = "redis://redis:6379"
    QDRANT_URL: str = "http://qdrant:6333"
    
    # LLM Configuration
    LLM_PROVIDER: str = "ollama"
    LLM_BASE_URL: str = "http://ollama:11434/v1"
    LLM_API_KEY: str = "ollama"
    LLM_CHOICE: str = "phi-4:latest"
    LLM_TEMPERATURE: float = 0.7
    LLM_MAX_TOKENS: int = 2048
    
    # Embedding Configuration
    EMBEDDING_PROVIDER: str = "ollama"
    EMBEDDING_BASE_URL: str = "http://ollama:11434/v1"
    EMBEDDING_API_KEY: str = "ollama"
    EMBEDDING_MODEL: str = "nomic-embed-text:v1.5"
    EMBEDDING_DIMENSIONS: int = 768
    
    # Agent Configuration
    ENABLE_RAG: bool = True
    ENABLE_KAG: bool = True
    ENABLE_CAG: bool = True
    
    # Cache Configuration
    CACHE_TTL_FACTUAL: int = 86400  # 24 hours
    CACHE_TTL_ANALYTICAL: int = 14400  # 4 hours
    CACHE_TTL_TEMPORAL: int = 3600  # 1 hour
    CACHE_TTL_PERSONAL: int = 1800  # 30 minutes
    
    # Vector Search Configuration
    VECTOR_SEARCH_LIMIT: int = 10
    VECTOR_SEARCH_THRESHOLD: float = 0.7
    
    # Knowledge Graph Configuration
    KG_MAX_DEPTH: int = 3
    KG_RELATIONSHIP_LIMIT: int = 20
    
    # Monitoring
    ENABLE_METRICS: bool = True
    PROMETHEUS_PORT: int = 9091
    
    # Security
    API_KEY: Optional[str] = None
    ENABLE_CORS: bool = True
    CORS_ORIGINS: list = ["*"]


# Create global settings instance
settings = Settings()