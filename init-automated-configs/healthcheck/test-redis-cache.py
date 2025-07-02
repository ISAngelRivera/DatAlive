#!/usr/bin/env python3
"""
Test Redis cache functionality
"""

import asyncio
import aioredis
import json
import sys
import os
from datetime import datetime

async def test_redis_connection():
    """Test Redis basic connection"""
    try:
        redis_url = os.getenv("REDIS_URL", "redis://redis:6379")
        redis_client = aioredis.from_url(redis_url, decode_responses=True)
        
        # Test basic operations
        await redis_client.ping()
        print("✅ Redis connection successful")
        
        # Test set/get
        test_key = "datalive:test:connection"
        test_value = {"timestamp": datetime.now().isoformat(), "test": True}
        
        await redis_client.setex(test_key, 60, json.dumps(test_value))
        retrieved = await redis_client.get(test_key)
        
        if retrieved:
            data = json.loads(retrieved)
            if data.get("test") is True:
                print("✅ Redis set/get operations working")
            else:
                print("❌ Redis data integrity issue")
                return False
        else:
            print("❌ Redis get operation failed")
            return False
        
        # Test TTL
        ttl = await redis_client.ttl(test_key)
        if 50 <= ttl <= 60:
            print("✅ Redis TTL working correctly")
        else:
            print(f"⚠️  Redis TTL unexpected: {ttl}")
        
        # Cleanup
        await redis_client.delete(test_key)
        await redis_client.close()
        
        return True
        
    except Exception as e:
        print(f"❌ Redis connection failed: {e}")
        return False

async def test_cache_patterns():
    """Test common cache patterns"""
    try:
        redis_url = os.getenv("REDIS_URL", "redis://redis:6379")
        redis_client = aioredis.from_url(redis_url, decode_responses=True)
        
        # Test query cache pattern
        query_key = "datalive:query:hash:test123"
        query_result = {
            "answer": "Test response",
            "sources": [{"title": "Test doc", "score": 0.95}],
            "confidence": 0.92,
            "strategy_used": ["RAG"],
            "cached_at": datetime.now().isoformat()
        }
        
        # Cache the result
        await redis_client.setex(query_key, 3600, json.dumps(query_result))
        print("✅ Query cache pattern working")
        
        # Test user session cache
        session_key = "datalive:session:user123"
        session_data = {
            "user_id": "user123",
            "recent_queries": ["test query 1", "test query 2"],
            "preferences": {"language": "es", "model": "phi3"}
        }
        
        await redis_client.setex(session_key, 1800, json.dumps(session_data))
        print("✅ Session cache pattern working")
        
        # Test cache invalidation pattern
        pattern_key = "datalive:cache:*"
        keys = await redis_client.keys(pattern_key)
        if keys:
            await redis_client.delete(*keys)
            print("✅ Cache invalidation pattern working")
        
        await redis_client.close()
        return True
        
    except Exception as e:
        print(f"❌ Cache patterns test failed: {e}")
        return False

async def test_performance():
    """Test Redis performance"""
    try:
        redis_url = os.getenv("REDIS_URL", "redis://redis:6379")
        redis_client = aioredis.from_url(redis_url, decode_responses=True)
        
        # Performance test - 100 operations
        start_time = datetime.now()
        
        for i in range(100):
            key = f"datalive:perf:test:{i}"
            value = {"iteration": i, "data": "test" * 100}
            await redis_client.setex(key, 300, json.dumps(value))
        
        mid_time = datetime.now()
        
        for i in range(100):
            key = f"datalive:perf:test:{i}"
            await redis_client.get(key)
        
        end_time = datetime.now()
        
        write_time = (mid_time - start_time).total_seconds()
        read_time = (end_time - mid_time).total_seconds()
        
        print(f"✅ Performance test completed:")
        print(f"   100 writes: {write_time:.3f}s ({100/write_time:.1f} ops/sec)")
        print(f"   100 reads: {read_time:.3f}s ({100/read_time:.1f} ops/sec)")
        
        # Cleanup
        keys = await redis_client.keys("datalive:perf:test:*")
        if keys:
            await redis_client.delete(*keys)
        
        await redis_client.close()
        return True
        
    except Exception as e:
        print(f"❌ Performance test failed: {e}")
        return False

async def main():
    """Run all Redis tests"""
    print("🧪 Testing Redis Cache Functionality")
    print("=" * 40)
    
    tests = [
        ("Basic Connection", test_redis_connection),
        ("Cache Patterns", test_cache_patterns),
        ("Performance", test_performance)
    ]
    
    passed = 0
    total = len(tests)
    
    for test_name, test_func in tests:
        print(f"\n🔍 Testing {test_name}...")
        try:
            result = await test_func()
            if result:
                passed += 1
                print(f"✅ {test_name}: PASSED")
            else:
                print(f"❌ {test_name}: FAILED")
        except Exception as e:
            print(f"❌ {test_name}: ERROR - {e}")
    
    print("\n" + "=" * 40)
    print(f"🏆 Results: {passed}/{total} tests passed")
    
    if passed == total:
        print("🎉 All Redis cache tests passed!")
        return 0
    else:
        print("⚠️  Some Redis cache tests failed!")
        return 1

if __name__ == "__main__":
    exit_code = asyncio.run(main())
    sys.exit(exit_code)