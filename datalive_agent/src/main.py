"""
Main entry point for DataLive Unified Agent
"""

import asyncio
import logging
import os
from contextlib import asynccontextmanager

import uvicorn
from fastapi import FastAPI
from prometheus_client import make_asgi_app

from .api.routes import router as api_router
from .config import settings
from .core.database import init_databases, close_databases
from .core.logging import setup_logging

# Setup logging
logger = setup_logging(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan manager"""
    logger.info("Starting DataLive Unified Agent...")
    
    # Initialize databases
    await init_databases()
    logger.info("Databases initialized")
    
    # Load models if needed
    if settings.debug:  # Use debug flag for preloading in development
        logger.info("Development mode - models loaded on demand")
    
    yield
    
    # Cleanup
    logger.info("Shutting down DataLive Unified Agent...")
    await close_databases()
    logger.info("Cleanup complete")


# Create FastAPI app
app = FastAPI(
    title="DataLive Unified Agent",
    description="Unified RAG+KAG+CAG agent with Knowledge Graph support",
    version="3.0.0",
    lifespan=lifespan
)

# Mount Prometheus metrics
metrics_app = make_asgi_app()
app.mount("/metrics", metrics_app)

# Include API routes
app.include_router(api_router, prefix="/api/v1")

# Health check endpoint
@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "service": "datalive-unified-agent",
        "version": "3.0.0"
    }


def main():
    """Main function to run the server"""
    uvicorn.run(
        "src.main:app",
        host=settings.api_host,
        port=settings.api_port,
        reload=settings.debug,
        log_level=settings.log_level.lower()
    )


if __name__ == "__main__":
    main()