import pytest
import asyncio
from typing import AsyncGenerator
import os
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker
from neo4j import AsyncGraphDatabase
import redis.asyncio as redis
from fastapi.testclient import TestClient

# Test database URLs
TEST_POSTGRES_URL = os.getenv("TEST_POSTGRES_URL", "postgresql+asyncpg://postgres:adminpassword@localhost:5432/test_datalive")
TEST_NEO4J_URL = os.getenv("TEST_NEO4J_URL", "neo4j://neo4j:adminpassword@localhost:7687")
TEST_REDIS_URL = os.getenv("TEST_REDIS_URL", "redis://localhost:6379/1")

@pytest.fixture(scope="session")
def event_loop():
    """Create an instance of the default event loop for the test session."""
    loop = asyncio.get_event_loop_policy().new_event_loop()
    yield loop
    loop.close()

@pytest.fixture(scope="session")
async def test_db():
    """Create test database session."""
    engine = create_async_engine(TEST_POSTGRES_URL, echo=False)
    async_session = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)
    
    async with engine.begin() as conn:
        # Create test schema
        await conn.run_sync(Base.metadata.create_all)
    
    async with async_session() as session:
        yield session
    
    async with engine.begin() as conn:
        # Drop test schema
        await conn.run_sync(Base.metadata.drop_all)
    
    await engine.dispose()

@pytest.fixture(scope="session")
async def test_neo4j():
    """Create test Neo4j session."""
    driver = AsyncGraphDatabase.driver(TEST_NEO4J_URL)
    async with driver.session() as session:
        # Clear test data
        await session.run("MATCH (n) DETACH DELETE n")
        yield session
    await driver.close()

@pytest.fixture(scope="session")
async def test_redis():
    """Create test Redis connection."""
    client = await redis.from_url(TEST_REDIS_URL, decode_responses=True)
    await client.flushdb()
    yield client
    await client.close()

@pytest.fixture
def test_client():
    """Create test client for API."""
    from src.main import app
    return TestClient(app)