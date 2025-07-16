"""
Database connections and initialization
"""

import logging
import asyncio
from typing import Optional

import asyncpg
from neo4j import AsyncGraphDatabase
import redis.asyncio as redis

from ..config import settings

logger = logging.getLogger(__name__)

# Global connection pools
_postgres_pool: Optional[asyncpg.Pool] = None
_neo4j_driver: Optional[AsyncGraphDatabase] = None
_redis_client: Optional[redis.Redis] = None


async def init_databases():
    """Initialize all database connections"""
    await init_postgres()
    await init_neo4j()
    await init_redis()
    logger.info("Databases initialized")


async def close_databases():
    """Close all database connections"""
    await close_postgres()
    await close_neo4j()
    await close_redis()
    logger.info("Database connections closed")


# PostgreSQL
async def init_postgres():
    """Initialize PostgreSQL connection pool"""
    global _postgres_pool
    
    try:
        _postgres_pool = await asyncpg.create_pool(
            settings.postgres_url,
            min_size=2,
            max_size=10,
            command_timeout=60
        )
        
        # Test connection
        async with _postgres_pool.acquire() as conn:
            await conn.fetchval("SELECT 1")
        
        logger.info("PostgreSQL connection pool created")
        
    except Exception as e:
        logger.error(f"Failed to initialize PostgreSQL: {e}")
        raise


async def close_postgres():
    """Close PostgreSQL connection pool"""
    global _postgres_pool
    
    if _postgres_pool:
        await _postgres_pool.close()
        _postgres_pool = None
        logger.info("PostgreSQL connection pool closed")


async def get_postgres_pool() -> asyncpg.Pool:
    """Get PostgreSQL connection pool"""
    if not _postgres_pool:
        await init_postgres()
    return _postgres_pool


# Neo4j
async def init_neo4j():
    """Initialize Neo4j driver"""
    global _neo4j_driver
    
    try:
        # Use bolt+s:// scheme to avoid routing issues with Neo4j 2025.01
        neo4j_url = settings.neo4j_url.replace("neo4j://", "bolt://")
        
        _neo4j_driver = AsyncGraphDatabase.driver(
            neo4j_url,
            auth=("neo4j", "adminpassword"),
            max_connection_lifetime=3600,
            max_connection_pool_size=50
        )
        
        # Test connection with timeout
        try:
            await asyncio.wait_for(_neo4j_driver.verify_connectivity(), timeout=10.0)
        except asyncio.TimeoutError:
            logger.warning("Neo4j connection verification timed out, but will continue")
        
        logger.info("Neo4j driver initialized")
        
    except Exception as e:
        logger.error(f"Failed to initialize Neo4j: {e}")
        # For now, make Neo4j optional to avoid blocking startup
        logger.warning("Continuing without Neo4j connection - KAG features will be disabled")
        _neo4j_driver = None


async def close_neo4j():
    """Close Neo4j driver"""
    global _neo4j_driver
    
    if _neo4j_driver:
        await _neo4j_driver.close()
        _neo4j_driver = None
        logger.info("Neo4j driver closed")


async def get_neo4j_driver() -> Optional[AsyncGraphDatabase]:
    """Get Neo4j driver"""
    if not _neo4j_driver:
        await init_neo4j()
    return _neo4j_driver


# Redis
async def init_redis():
    """Initialize Redis client"""
    global _redis_client
    
    try:
        _redis_client = redis.from_url(
            settings.redis_url,
            decode_responses=True,
            max_connections=20
        )
        
        # Test connection
        await _redis_client.ping()
        
        logger.info("Redis client initialized")
        
    except Exception as e:
        logger.error(f"Failed to initialize Redis: {e}")
        raise


async def close_redis():
    """Close Redis client"""
    global _redis_client
    
    if _redis_client:
        await _redis_client.close()
        _redis_client = None
        logger.info("Redis client closed")


async def get_redis_client() -> redis.Redis:
    """Get Redis client"""
    if not _redis_client:
        await init_redis()
    return _redis_client