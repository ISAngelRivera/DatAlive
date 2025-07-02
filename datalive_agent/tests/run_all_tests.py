#!/usr/bin/env python3
"""
Comprehensive Test Runner for DataLive Agent
Runs all tests and generates coverage reports
"""

import subprocess
import sys
import os
import asyncio
from pathlib import Path
import time


class TestRunner:
    """Test runner with reporting and metrics"""
    
    def __init__(self):
        self.test_dir = Path(__file__).parent
        self.project_root = self.test_dir.parent
        self.results = {}
    
    def run_command(self, command: str, description: str):
        """Run a command and capture results"""
        print(f"\n{'='*60}")
        print(f"🧪 {description}")
        print(f"{'='*60}")
        print(f"Command: {command}")
        print()
        
        start_time = time.time()
        
        try:
            result = subprocess.run(
                command,
                shell=True,
                cwd=self.project_root,
                capture_output=True,
                text=True,
                timeout=300  # 5 minute timeout
            )
            
            end_time = time.time()
            duration = end_time - start_time
            
            print(result.stdout)
            if result.stderr:
                print("STDERR:")
                print(result.stderr)
            
            success = result.returncode == 0
            self.results[description] = {
                'success': success,
                'duration': duration,
                'return_code': result.returncode,
                'stdout': result.stdout,
                'stderr': result.stderr
            }
            
            status = "✅ PASSED" if success else "❌ FAILED"
            print(f"\n{status} - Duration: {duration:.2f}s")
            
            return success
            
        except subprocess.TimeoutExpired:
            print("❌ TIMEOUT - Test took longer than 5 minutes")
            self.results[description] = {
                'success': False,
                'duration': 300,
                'return_code': -1,
                'error': 'timeout'
            }
            return False
        except Exception as e:
            print(f"❌ ERROR - {str(e)}")
            self.results[description] = {
                'success': False,
                'duration': 0,
                'return_code': -1,
                'error': str(e)
            }
            return False
    
    def check_dependencies(self):
        """Check if testing dependencies are available"""
        print("🔍 Checking test dependencies...")
        
        # Check Python packages
        required_packages = [
            'pytest',
            'pytest-asyncio',
            'pytest-cov',
            'coverage'
        ]
        
        missing_packages = []
        for package in required_packages:
            try:
                __import__(package.replace('-', '_'))
            except ImportError:
                missing_packages.append(package)
        
        if missing_packages:
            print(f"❌ Missing packages: {', '.join(missing_packages)}")
            print("Install with: pip install pytest pytest-asyncio pytest-cov coverage")
            return False
        
        print("✅ All required packages available")
        return True
    
    def run_unit_tests(self):
        """Run unit tests"""
        return self.run_command(
            "python -m pytest tests/ -v --tb=short",
            "Unit Tests"
        )
    
    def run_integration_tests(self):
        """Run integration tests"""
        return self.run_command(
            "python -m pytest tests/test_integration.py tests/test_database_integration.py -v --tb=short",
            "Integration Tests"
        )
    
    def run_performance_tests(self):
        """Run performance tests"""
        return self.run_command(
            "python -m pytest tests/test_agents_performance.py tests/test_cache_performance.py -v --tb=short",
            "Performance Tests"
        )
    
    def run_security_tests(self):
        """Run security tests"""
        return self.run_command(
            "python -m pytest tests/test_api_security.py -v --tb=short",
            "Security Tests"
        )
    
    def run_with_coverage(self):
        """Run all tests with coverage"""
        return self.run_command(
            "python -m pytest tests/ --cov=src --cov-report=html --cov-report=term-missing --cov-report=xml",
            "Coverage Analysis"
        )
    
    def run_specific_test_files(self):
        """Run specific test files individually"""
        test_files = [
            ("test_api_security.py", "API Security Tests"),
            ("test_cache_performance.py", "Cache Performance Tests"),
            ("test_agents_performance.py", "Agent Performance Tests"),
            ("test_database_integration.py", "Database Integration Tests"),
            ("test_integration.py", "System Integration Tests"),
            ("test_ingestion.py", "Ingestion Tests"),
            ("test_system_health.py", "System Health Tests"),
            ("test_unified_agent.py", "Unified Agent Tests")
        ]
        
        results = {}
        for test_file, description in test_files:
            test_path = self.test_dir / test_file
            if test_path.exists():
                success = self.run_command(
                    f"python -m pytest tests/{test_file} -v",
                    description
                )
                results[test_file] = success
            else:
                print(f"⚠️  Test file not found: {test_file}")
                results[test_file] = False
        
        return results
    
    def run_lint_checks(self):
        """Run code quality checks"""
        # Check if tools are available
        try:
            self.run_command("python -m flake8 src/ --max-line-length=120 --ignore=E203,W503", "Flake8 Linting")
        except:
            print("⚠️  Flake8 not available, skipping lint checks")
        
        try:
            self.run_command("python -m mypy src/ --ignore-missing-imports", "Type Checking")
        except:
            print("⚠️  MyPy not available, skipping type checks")
    
    def generate_summary_report(self):
        """Generate summary report"""
        print(f"\n{'='*80}")
        print("📊 TEST SUMMARY REPORT")
        print(f"{'='*80}")
        
        total_tests = len(self.results)
        passed_tests = sum(1 for r in self.results.values() if r['success'])
        failed_tests = total_tests - passed_tests
        
        print(f"Total Test Suites: {total_tests}")
        print(f"Passed: {passed_tests} ✅")
        print(f"Failed: {failed_tests} ❌")
        print(f"Success Rate: {(passed_tests/total_tests)*100:.1f}%")
        
        total_duration = sum(r['duration'] for r in self.results.values())
        print(f"Total Duration: {total_duration:.2f}s")
        
        print(f"\n{'Test Suite':<40} {'Status':<10} {'Duration':<10}")
        print("-" * 70)
        
        for test_name, result in self.results.items():
            status = "✅ PASS" if result['success'] else "❌ FAIL"
            duration = f"{result['duration']:.2f}s"
            print(f"{test_name:<40} {status:<10} {duration:<10}")
        
        # Show failed tests details
        failed_details = [(name, result) for name, result in self.results.items() if not result['success']]
        if failed_details:
            print(f"\n❌ FAILED TESTS DETAILS:")
            print("-" * 50)
            for test_name, result in failed_details:
                print(f"\n{test_name}:")
                if 'error' in result:
                    print(f"  Error: {result['error']}")
                if result.get('stderr'):
                    print(f"  stderr: {result['stderr'][:200]}...")
        
        # Coverage info
        coverage_dir = self.project_root / "htmlcov"
        if coverage_dir.exists():
            print(f"\n📈 Coverage report generated: {coverage_dir}/index.html")
        
        return passed_tests == total_tests
    
    def run_all_tests(self, quick_mode=False):
        """Run all tests"""
        print("🚀 Starting DataLive Test Suite")
        print(f"Test directory: {self.test_dir}")
        print(f"Project root: {self.project_root}")
        
        # Check dependencies
        if not self.check_dependencies():
            return False
        
        all_passed = True
        
        if not quick_mode:
            # Run comprehensive test suite
            all_passed &= self.run_unit_tests()
            all_passed &= self.run_integration_tests()
            all_passed &= self.run_performance_tests()
            all_passed &= self.run_security_tests()
            all_passed &= self.run_with_coverage()
            
            # Run lint checks
            self.run_lint_checks()
        else:
            # Quick mode - just basic tests
            all_passed &= self.run_unit_tests()
        
        # Generate report
        all_passed &= self.generate_summary_report()
        
        return all_passed


def main():
    """Main entry point"""
    runner = TestRunner()
    
    # Parse command line arguments
    quick_mode = '--quick' in sys.argv
    specific_test = None
    
    for arg in sys.argv[1:]:
        if arg.startswith('--test='):
            specific_test = arg.split('=')[1]
    
    if specific_test:
        # Run specific test
        success = runner.run_command(
            f"python -m pytest tests/{specific_test} -v",
            f"Specific Test: {specific_test}"
        )
        runner.generate_summary_report()
        sys.exit(0 if success else 1)
    else:
        # Run all tests
        success = runner.run_all_tests(quick_mode=quick_mode)
        sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()