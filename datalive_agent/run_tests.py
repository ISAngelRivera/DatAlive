#!/usr/bin/env python3
"""
Test runner for DataLive Unified Agent System
Executes comprehensive system validation
"""

import os
import sys
import asyncio
import logging
from pathlib import Path

# Add src to path for imports
sys.path.insert(0, str(Path(__file__).parent / "src"))

from tests.test_system_health import SystemHealthChecker

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)

async def main():
    """Run comprehensive system tests"""
    print("🧪 DataLive Unified Agent - System Validation")
    print("=" * 60)
    
    try:
        # Create health checker
        checker = SystemHealthChecker()
        
        # Run all tests
        summary = await checker.run_all_tests()
        
        # Print results
        print(f"\n📊 TEST SUMMARY")
        print(f"{'='*60}")
        print(f"🕐 Duration: {summary['duration_seconds']}s")
        print(f"📋 Total Tests: {summary['total_tests']}")
        print(f"✅ Passed: {summary['passed_tests']}")
        print(f"❌ Failed: {summary['failed_tests']}")
        print(f"📈 Success Rate: {summary['success_rate']}%")
        print(f"🎯 Status: {summary['status']}")
        
        if summary.get('failed_test_details'):
            print(f"\n❌ FAILED TESTS:")
            print(f"{'-'*60}")
            for failure in summary['failed_test_details']:
                print(f"  • {failure}")
        
        if summary.get('recommendations'):
            print(f"\n💡 RECOMMENDATIONS:")
            print(f"{'-'*60}")
            for rec in summary['recommendations']:
                print(f"  {rec}")
        
        # Determine exit code
        if summary['status'] == 'HEALTHY':
            print(f"\n🟢 SYSTEM STATUS: HEALTHY - All critical tests passed")
            return 0
        elif summary['status'] == 'DEGRADED':
            print(f"\n🟡 SYSTEM STATUS: DEGRADED - Some tests failed")
            return 1
        else:
            print(f"\n🔴 SYSTEM STATUS: UNHEALTHY - Critical failures detected")
            return 2
            
    except Exception as e:
        print(f"\n💥 CRITICAL ERROR: {e}")
        import traceback
        traceback.print_exc()
        return 3

if __name__ == "__main__":
    exit_code = asyncio.run(main())
    sys.exit(exit_code)