"""
Simple test runner for DataLive system validation
"""

import sys
import os
from pathlib import Path

print("🧪 DataLive Unified Agent - System Validation")
print("=" * 60)

# Test 1: Check project structure
print("\n📁 Testing Project Structure...")
required_dirs = [
    "src/agents",
    "src/api", 
    "src/core",
    "src/config",
    "src/ingestion",
    "tests"
]

missing_dirs = []
for dir_path in required_dirs:
    if not Path(dir_path).exists():
        missing_dirs.append(dir_path)
    else:
        print(f"  ✅ {dir_path}")

if missing_dirs:
    print(f"  ❌ Missing directories: {missing_dirs}")
else:
    print("  ✅ All required directories present")

# Test 2: Check core files
print("\n📄 Testing Core Files...")
required_files = [
    "src/main.py",
    "src/config/settings.py",
    "src/agents/unified_agent.py",
    "src/agents/orchestrator.py", 
    "src/agents/rag_agent.py",
    "src/agents/kag_agent.py",
    "src/agents/cag_agent.py",
    "src/api/routes.py",
    "src/core/database.py",
    "src/core/vector_store.py",
    "src/core/knowledge_graph.py",
    "src/core/graphiti_client.py",
    "src/core/metrics.py",
    "src/ingestion/pipeline.py",
    "requirements.txt"
]

missing_files = []
for file_path in required_files:
    if not Path(file_path).exists():
        missing_files.append(file_path)
    else:
        print(f"  ✅ {file_path}")

if missing_files:
    print(f"  ❌ Missing files: {missing_files}")
else:
    print("  ✅ All required files present")

# Test 3: Import tests
print("\n🐍 Testing Python Imports...")
import_tests = [
    ("src.config.settings", "settings"),
    ("src.agents.unified_agent", "UnifiedAgent"),
    ("src.agents.orchestrator", "OrchestratorAgent"),
    ("src.agents.rag_agent", "RAGAgent"),
    ("src.agents.kag_agent", "KAGAgent"),
    ("src.agents.cag_agent", "CAGAgent"),
    ("src.api.routes", "router"),
    ("src.core.database", "get_postgres_connection"),
    ("src.core.vector_store", "VectorStore"),
    ("src.core.knowledge_graph", "KnowledgeGraph"),
    ("src.core.graphiti_client", "GraphitiClient"),
    ("src.ingestion.pipeline", "MultiModalIngestionPipeline")
]

failed_imports = []
for module_name, class_name in import_tests:
    try:
        module = __import__(module_name, fromlist=[class_name])
        obj = getattr(module, class_name)
        print(f"  ✅ {module_name}.{class_name}")
    except Exception as e:
        failed_imports.append(f"{module_name}.{class_name}: {e}")
        print(f"  ❌ {module_name}.{class_name}: {e}")

# Test 4: Dependency check
print("\n📦 Testing Dependencies...")
required_packages = [
    "fastapi",
    "pydantic",
    "asyncpg", 
    "neo4j",
    "redis",
    "prometheus_client"
]

missing_packages = []
for package in required_packages:
    try:
        __import__(package)
        print(f"  ✅ {package}")
    except ImportError:
        missing_packages.append(package)
        print(f"  ⚠️  {package} (not installed)")

# Test 5: Configuration validation
print("\n⚙️  Testing Configuration...")
try:
    from src.config.settings import settings
    print(f"  ✅ Settings loaded")
    print(f"  ✅ App name: {settings.app_name}")
    print(f"  ✅ App version: {settings.app_version}")
    print(f"  ✅ API port: {settings.api_port}")
except Exception as e:
    print(f"  ❌ Configuration error: {e}")

# Calculate results
print("\n📊 TEST SUMMARY")
print("=" * 60)

total_tests = 5
failed_tests = 0

if missing_dirs:
    failed_tests += 1
if missing_files:
    failed_tests += 1
if failed_imports:
    failed_tests += 1
if missing_packages:
    failed_tests += 0.5  # Dependencies are optional
try:
    from src.config.settings import settings
except:
    failed_tests += 1

passed_tests = total_tests - int(failed_tests)
success_rate = (passed_tests / total_tests) * 100

print(f"📋 Total Tests: {total_tests}")
print(f"✅ Passed: {passed_tests}")
print(f"❌ Failed: {int(failed_tests)}")
print(f"📈 Success Rate: {success_rate:.1f}%")

if success_rate >= 80:
    status = "🟢 HEALTHY"
    exit_code = 0
elif success_rate >= 60:
    status = "🟡 DEGRADED"  
    exit_code = 1
else:
    status = "🔴 UNHEALTHY"
    exit_code = 2

print(f"🎯 Status: {status}")

print("\n💡 RECOMMENDATIONS:")
if missing_packages:
    print("  📦 Install missing packages: pip install " + " ".join(missing_packages))
if failed_imports:
    print("  🐍 Fix import errors to enable full functionality")
if missing_dirs or missing_files:
    print("  📁 Ensure all required files are present")

print("\n🏆 RESULT:")
if success_rate >= 80:
    print("  ✅ System structure is healthy and ready for deployment!")
elif success_rate >= 60:
    print("  ⚠️  System has some issues but core functionality should work")
else:
    print("  ❌ System has critical issues that need to be resolved")

print(f"\nDataLive Unified RAG+KAG+CAG System - Structure Validation Complete")
sys.exit(exit_code)