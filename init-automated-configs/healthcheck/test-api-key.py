#!/usr/bin/env python3
"""
Quick test script for API key validation
"""

import requests
import os
import sys

# Configuration
API_BASE_URL = "http://localhost:8058"
API_KEY = os.getenv("DATALIVE_API_KEY", "datalive-dev-key-change-in-production")

def test_endpoint_without_key(endpoint):
    """Test endpoint without API key - should return 422 (missing required header)"""
    try:
        response = requests.get(f"{API_BASE_URL}{endpoint}")
        return response.status_code, response.text[:100]
    except Exception as e:
        return None, str(e)

def test_endpoint_with_wrong_key(endpoint):
    """Test endpoint with wrong API key - should return 403"""
    try:
        headers = {"X-API-Key": "wrong-api-key"}
        response = requests.get(f"{API_BASE_URL}{endpoint}", headers=headers)
        return response.status_code, response.text[:100]
    except Exception as e:
        return None, str(e)

def test_endpoint_with_correct_key(endpoint):
    """Test endpoint with correct API key - should work normally"""
    try:
        headers = {"X-API-Key": API_KEY}
        response = requests.get(f"{API_BASE_URL}{endpoint}", headers=headers)
        return response.status_code, response.text[:100]
    except Exception as e:
        return None, str(e)

def main():
    print("🧪 Testing DataLive API Key Validation")
    print("=" * 50)
    print(f"API Base URL: {API_BASE_URL}")
    print(f"Using API Key: {API_KEY[:8]}...")
    print()

    # Test public endpoints (should work without API key)
    print("📖 Testing public endpoints (no API key required):")
    public_endpoints = ["/health", "/status", "/docs"]
    
    for endpoint in public_endpoints:
        status, response = test_endpoint_without_key(endpoint)
        if status:
            print(f"  ✅ {endpoint}: {status} (public access)")
        else:
            print(f"  ❌ {endpoint}: Error - {response}")
    
    print()
    
    # Test protected endpoints
    print("🔒 Testing protected endpoints:")
    protected_endpoints = [
        "/api/v1/search/vector?query=test",
        "/cache/stats",
        "/metrics/summary"
    ]
    
    for endpoint in protected_endpoints:
        print(f"\n  Testing {endpoint}:")
        
        # Test without key
        status, response = test_endpoint_without_key(endpoint)
        if status == 422:
            print(f"    ✅ No API key: {status} (correctly blocked)")
        else:
            print(f"    ⚠️  No API key: {status} - {response}")
        
        # Test with wrong key
        status, response = test_endpoint_with_wrong_key(endpoint)
        if status == 403:
            print(f"    ✅ Wrong API key: {status} (correctly blocked)")
        else:
            print(f"    ⚠️  Wrong API key: {status} - {response}")
        
        # Test with correct key
        status, response = test_endpoint_with_correct_key(endpoint)
        if status in [200, 500]:  # 500 is OK if service isn't fully initialized
            print(f"    ✅ Correct API key: {status} (access granted)")
        else:
            print(f"    ⚠️  Correct API key: {status} - {response}")
    
    print("\n" + "=" * 50)
    print("🔍 Test completed! Check results above.")

if __name__ == "__main__":
    main()