"""
Configuration settings for DataLive Unified Agent
"""

import os
from typing import Optional, List
from pydantic import Field
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """Application settings"""
    
    # Application
    app_name: str = "DataLive Unified Agent"
    app_version: str = "3.0.0"
    debug: bool = False
    log_level: str = Field(default="INFO", env="LOG_LEVEL")
    
    # API
    api_host: str = Field(default="0.0.0.0", env="API_HOST")
    api_port: int = Field(default=8058, env="API_PORT")
    api_prefix: str = "/api/v1"
    
    # Database URLs (using Docker service names)
    postgres_url: str = Field(
        default="postgresql://datalive_user:adminpassword@postgres:5432/datalive_db",
        env="POSTGRES_URL"
    )
    neo4j_url: str = Field(
        default="neo4j://neo4j:7687",
        env="NEO4J_URL"
    )
    redis_url: str = Field(
        default="redis://redis:6379",
        env="REDIS_URL"
    )
    
    # Vector database
    qdrant_url: str = Field(
        default="http://qdrant:6333",
        env="QDRANT_URL"
    )
    vector_collection_name: str = "datalive_vectors"
    vector_dimension: int = 768
    
    # LLM Configuration
    llm_provider: str = Field(default="ollama", env="LLM_PROVIDER")
    llm_model: str = Field(default="phi-4:latest", env="LLM_MODEL")
    llm_base_url: str = Field(default="http://ollama:11434", env="LLM_BASE_URL")
    llm_api_key: Optional[str] = Field(default=None, env="LLM_API_KEY")
    
    # Embedding Configuration
    embedding_provider: str = Field(default="sentence-transformers", env="EMBEDDING_PROVIDER")
    embedding_model: str = Field(default="all-MiniLM-L6-v2", env="EMBEDDING_MODEL")
    
    # Cache Configuration
    cache_ttl_default: int = 3600  # 1 hour
    cache_ttl_factual: int = 86400  # 24 hours
    cache_ttl_analytical: int = 14400  # 4 hours
    cache_ttl_temporal: int = 3600  # 1 hour
    cache_ttl_personal: int = 1800  # 30 minutes
    
    # Agent Configuration
    max_query_length: int = 10000
    default_rag_limit: int = 10
    default_kag_depth: int = 3
    default_confidence_threshold: float = 0.5
    
    # Ingestion Configuration
    ingestion_chunk_size: int = 1000
    ingestion_chunk_overlap: int = 200
    ingestion_batch_size: int = 10
    ingestion_max_concurrent: int = 5
    
    # Monitoring
    enable_metrics: bool = True
    metrics_port: int = 9090
    
    # Security
    secret_key: str = Field(
        default="your-secret-key-change-in-production",
        env="SECRET_KEY"
    )
    allowed_origins: List[str] = ["*"]
    
    # Cache Configuration
    cache_ttl_factual: int = Field(default=3600, env="CACHE_TTL_FACTUAL")      # 1 hour
    cache_ttl_analytical: int = Field(default=1800, env="CACHE_TTL_ANALYTICAL") # 30 minutes  
    cache_ttl_temporal: int = Field(default=900, env="CACHE_TTL_TEMPORAL")      # 15 minutes
    cache_ttl_personal: int = Field(default=300, env="CACHE_TTL_PERSONAL")      # 5 minutes
    cache_max_size: int = Field(default=1000, env="CACHE_MAX_SIZE")
    cache_high_confidence_threshold: float = Field(default=0.9, env="CACHE_HIGH_CONFIDENCE_THRESHOLD")
    
    # Feature flags
    enable_graphiti: bool = Field(default=True, env="ENABLE_GRAPHITI")
    enable_temporal_analysis: bool = Field(default=True, env="ENABLE_TEMPORAL_ANALYSIS")
    enable_relationship_extraction: bool = Field(default=True, env="ENABLE_RELATIONSHIP_EXTRACTION")
    enable_caching: bool = Field(default=True, env="ENABLE_CACHING")
    
    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"
        case_sensitive = False


# Global settings instance
settings = Settings()