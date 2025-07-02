#!/usr/bin/env python3
"""
DataLive Python Test Suite
Complementary to the bash script for more complex testing
"""

import requests
import json
import time
import os
import sys
from typing import Dict, List, Any, Optional
import asyncio
import concurrent.futures


class DataLiveTestSuite:
    """Python-based test suite for DataLive system"""
    
    def __init__(self):
        self.base_url = "http://datalive_agent:8058"
        self.api_key = os.getenv("DATALIVE_API_KEY")
        self.session = requests.Session()
        self.test_results = []
        
        # Set default headers
        if self.api_key:
            self.session.headers.update({"X-API-Key": self.api_key})
    
    def log_test_result(self, test_name: str, success: bool, duration: float, details: str = ""):
        """Log test result"""
        result = {
            'test_name': test_name,
            'success': success,
            'duration': duration,
            'details': details,
            'timestamp': time.time()
        }
        self.test_results.append(result)
        
        status = "✅ PASS" if success else "❌ FAIL"
        print(f"{status} {test_name} ({duration:.2f}s)")
        if details and not success:
            print(f"    Details: {details}")
    
    def test_api_endpoints(self) -> bool:
        """Test all API endpoints"""
        print("\n🔌 Testing API Endpoints...")
        
        endpoints = [
            ("/health", "GET", None, "Health Check"),
            ("/status", "GET", None, "Status Check"),
            ("/docs", "GET", None, "Documentation"),
            ("/metrics", "GET", None, "Metrics")
        ]
        
        all_passed = True
        
        for endpoint, method, payload, description in endpoints:
            start_time = time.time()
            
            try:
                if method == "GET":
                    response = self.session.get(f"{self.base_url}{endpoint}", timeout=10)
                else:
                    response = self.session.post(f"{self.base_url}{endpoint}", json=payload, timeout=10)
                
                success = response.status_code == 200
                duration = time.time() - start_time
                details = f"Status: {response.status_code}" if not success else ""
                
                self.log_test_result(f"API {description}", success, duration, details)
                all_passed &= success
                
            except Exception as e:
                duration = time.time() - start_time
                self.log_test_result(f"API {description}", False, duration, str(e))
                all_passed = False
        
        return all_passed
    
    def test_query_functionality(self) -> bool:
        """Test query processing functionality"""
        print("\n🧠 Testing Query Functionality...")
        
        if not self.api_key:
            print("⚠️  No API key available, skipping query tests")
            return True
        
        test_queries = [
            ("What is DataLive?", "Basic Query"),
            ("Who developed DataLive?", "Entity Query"),
            ("How does the system work?", "Complex Query"),
            ("", "Empty Query"),  # Should handle gracefully
        ]
        
        all_passed = True
        
        for query, description in test_queries:
            start_time = time.time()
            
            try:
                payload = {
                    "query": query,
                    "max_results": 5,
                    "use_cache": True
                }
                
                response = self.session.post(
                    f"{self.base_url}/api/v1/query",
                    json=payload,
                    timeout=30
                )
                
                duration = time.time() - start_time
                
                if response.status_code == 200:
                    data = response.json()
                    # Check response structure
                    required_fields = ['answer', 'confidence', 'strategy_used']
                    success = all(field in data for field in required_fields)
                    details = f"Response fields: {list(data.keys())}" if not success else ""
                else:
                    success = query == ""  # Empty query should fail
                    details = f"Status: {response.status_code}"
                
                self.log_test_result(f"Query {description}", success, duration, details)
                all_passed &= success
                
            except Exception as e:
                duration = time.time() - start_time
                self.log_test_result(f"Query {description}", False, duration, str(e))
                all_passed = False
        
        return all_passed
    
    def test_ingestion_functionality(self) -> bool:
        """Test document ingestion"""
        print("\n📄 Testing Ingestion Functionality...")
        
        if not self.api_key:
            print("⚠️  No API key available, skipping ingestion tests")
            return True
        
        test_documents = [
            ("txt", "This is a test document for automated testing.", "Text Ingestion"),
            ("md", "# Test Document\n\nThis is a **markdown** test document.", "Markdown Ingestion"),
        ]
        
        all_passed = True
        
        for source_type, content, description in test_documents:
            start_time = time.time()
            
            try:
                payload = {
                    "source_type": source_type,
                    "source": content,
                    "metadata": {
                        "test_document": True,
                        "created_by": "automated_test"
                    }
                }
                
                response = self.session.post(
                    f"{self.base_url}/api/v1/ingest",
                    json=payload,
                    timeout=30
                )
                
                duration = time.time() - start_time
                success = response.status_code == 200
                details = f"Status: {response.status_code}" if not success else ""
                
                if success and response.status_code == 200:
                    data = response.json()
                    success = 'document_id' in data or 'success' in data
                
                self.log_test_result(f"Ingestion {description}", success, duration, details)
                all_passed &= success
                
            except Exception as e:
                duration = time.time() - start_time
                self.log_test_result(f"Ingestion {description}", False, duration, str(e))
                all_passed = False
        
        return all_passed
    
    def test_cache_performance(self) -> bool:
        """Test cache performance"""
        print("\n⚡ Testing Cache Performance...")
        
        if not self.api_key:
            print("⚠️  No API key available, skipping cache tests")
            return True
        
        test_query = "Cache performance test query"
        payload = {
            "query": test_query,
            "use_cache": True
        }
        
        # First request (cache miss)
        start_time = time.time()
        try:
            response1 = self.session.post(f"{self.base_url}/api/v1/query", json=payload, timeout=30)
            first_duration = time.time() - start_time
            
            # Second request (cache hit)
            start_time = time.time()
            response2 = self.session.post(f"{self.base_url}/api/v1/query", json=payload, timeout=30)
            second_duration = time.time() - start_time
            
            if response1.status_code == 200 and response2.status_code == 200:
                # Cache should make second request faster
                performance_improvement = first_duration > second_duration
                self.log_test_result("Cache Performance", performance_improvement, second_duration,
                                   f"First: {first_duration:.2f}s, Second: {second_duration:.2f}s")
                return performance_improvement
            else:
                self.log_test_result("Cache Performance", False, second_duration, "API requests failed")
                return False
                
        except Exception as e:
            self.log_test_result("Cache Performance", False, 0, str(e))
            return False
    
    def test_concurrent_requests(self) -> bool:
        """Test concurrent request handling"""
        print("\n🔄 Testing Concurrent Requests...")
        
        if not self.api_key:
            print("⚠️  No API key available, skipping concurrent tests")
            return True
        
        def make_request(query_id: int) -> Dict:
            """Make a single request"""
            try:
                payload = {"query": f"Concurrent test query {query_id}"}
                start_time = time.time()
                response = self.session.post(f"{self.base_url}/api/v1/query", json=payload, timeout=30)
                duration = time.time() - start_time
                return {
                    'id': query_id,
                    'success': response.status_code == 200,
                    'duration': duration
                }
            except Exception as e:
                return {
                    'id': query_id,
                    'success': False,
                    'duration': 0,
                    'error': str(e)
                }
        
        # Run 5 concurrent requests
        start_time = time.time()
        with concurrent.futures.ThreadPoolExecutor(max_workers=5) as executor:
            futures = [executor.submit(make_request, i) for i in range(5)]
            results = [future.result() for future in concurrent.futures.as_completed(futures)]
        
        total_duration = time.time() - start_time
        
        successful_requests = sum(1 for r in results if r['success'])
        success = successful_requests >= 4  # At least 80% success rate
        
        self.log_test_result("Concurrent Requests", success, total_duration,
                           f"{successful_requests}/5 requests successful")
        
        return success
    
    def test_error_handling(self) -> bool:
        """Test error handling"""
        print("\n🛡️  Testing Error Handling...")
        
        test_cases = [
            ("/api/v1/query", {"query": "x" * 10000}, "Very Long Query"),  # Should be rejected
            ("/api/v1/query", {}, "Missing Query Field"),  # Should be rejected
            ("/api/v1/ingest", {"source_type": "invalid"}, "Invalid Source Type"),  # Should be rejected
            ("/nonexistent", {}, "Nonexistent Endpoint"),  # Should return 404
        ]
        
        all_passed = True
        
        for endpoint, payload, description in test_cases:
            start_time = time.time()
            
            try:
                response = self.session.post(f"{self.base_url}{endpoint}", json=payload, timeout=10)
                duration = time.time() - start_time
                
                # These should all fail gracefully (not 5xx errors)
                success = response.status_code in [400, 404, 422]  # Client errors, not server errors
                details = f"Status: {response.status_code}"
                
                self.log_test_result(f"Error Handling {description}", success, duration, details)
                all_passed &= success
                
            except Exception as e:
                duration = time.time() - start_time
                self.log_test_result(f"Error Handling {description}", False, duration, str(e))
                all_passed = False
        
        return all_passed
    
    def generate_report(self) -> Dict:
        """Generate comprehensive test report"""
        total_tests = len(self.test_results)
        passed_tests = sum(1 for r in self.test_results if r['success'])
        failed_tests = total_tests - passed_tests
        
        if total_tests > 0:
            success_rate = (passed_tests / total_tests) * 100
            avg_duration = sum(r['duration'] for r in self.test_results) / total_tests
        else:
            success_rate = 0
            avg_duration = 0
        
        report = {
            'total_tests': total_tests,
            'passed_tests': passed_tests,
            'failed_tests': failed_tests,
            'success_rate': success_rate,
            'average_duration': avg_duration,
            'timestamp': time.time(),
            'results': self.test_results
        }
        
        print(f"\n{'='*50}")
        print("🏆 PYTHON TEST SUITE SUMMARY")
        print(f"{'='*50}")
        print(f"Total Tests: {total_tests}")
        print(f"Passed: {passed_tests} ✅")
        print(f"Failed: {failed_tests} ❌")
        print(f"Success Rate: {success_rate:.1f}%")
        print(f"Average Duration: {avg_duration:.2f}s")
        
        return report
    
    def run_all_tests(self) -> bool:
        """Run all tests"""
        print("🐍 DataLive Python Test Suite Starting...")
        
        all_passed = True
        
        # Run all test categories
        all_passed &= self.test_api_endpoints()
        all_passed &= self.test_query_functionality()
        all_passed &= self.test_ingestion_functionality()
        all_passed &= self.test_cache_performance()
        all_passed &= self.test_concurrent_requests()
        all_passed &= self.test_error_handling()
        
        # Generate final report
        report = self.generate_report()
        
        # Save report to file
        report_file = "/tmp/datalive-test-results/python-tests.json"
        os.makedirs(os.path.dirname(report_file), exist_ok=True)
        with open(report_file, 'w') as f:
            json.dump(report, f, indent=2)
        
        return all_passed


def main():
    """Main entry point"""
    test_suite = DataLiveTestSuite()
    success = test_suite.run_all_tests()
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()