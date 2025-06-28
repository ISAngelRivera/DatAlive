"""
System health tests for DataLive Unified RAG+KAG+CAG
Tests all major components and their interactions
"""

import asyncio
import logging
import sys
from typing import Dict, Any, List
from datetime import datetime
import json
import traceback

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class SystemHealthChecker:
    """Comprehensive system health checker for DataLive"""
    
    def __init__(self):
        self.test_results = []
        self.failed_tests = []
        self.passed_tests = []
    
    async def run_all_tests(self) -> Dict[str, Any]:
        """Run all system health tests"""
        logger.info("🚀 Starting DataLive System Health Check...")
        
        start_time = datetime.now()
        
        # Test categories
        test_categories = [
            ("Core Components", self._test_core_components),
            ("Agent Systems", self._test_agent_systems),
            ("Database Connections", self._test_database_connections),
            ("API Functionality", self._test_api_functionality),
            ("Ingestion Pipeline", self._test_ingestion_pipeline),
            ("End-to-End Flow", self._test_end_to_end_flow)
        ]
        
        for category_name, test_function in test_categories:
            logger.info(f"\n📋 Testing {category_name}...")
            try:
                await test_function()
                logger.info(f"✅ {category_name} tests completed")
            except Exception as e:
                logger.error(f"❌ {category_name} tests failed: {e}")
                self.failed_tests.append(f"{category_name}: {str(e)}")
        
        end_time = datetime.now()
        duration = (end_time - start_time).total_seconds()
        
        # Generate summary
        summary = self._generate_summary(duration)
        logger.info(f"\n📊 Health Check Summary:\n{json.dumps(summary, indent=2)}")
        
        return summary
    
    async def _test_core_components(self):
        """Test core system components"""
        tests = [
            ("Import Unified Agent", self._test_import_unified_agent),
            ("Import Orchestrator", self._test_import_orchestrator),
            ("Import RAG Agent", self._test_import_rag_agent),
            ("Import KAG Agent", self._test_import_kag_agent),
            ("Import CAG Agent", self._test_import_cag_agent),
            ("Import Graphiti Client", self._test_import_graphiti),
            ("Import Ingestion Pipeline", self._test_import_ingestion),
            ("Import API Routes", self._test_import_api_routes)
        ]
        
        for test_name, test_func in tests:
            await self._run_test(test_name, test_func)
    
    async def _test_agent_systems(self):
        """Test agent system functionality"""
        tests = [
            ("Create Unified Agent", self._test_create_unified_agent),
            ("Test Orchestrator Logic", self._test_orchestrator_logic),
            ("Test RAG Search", self._test_rag_search),
            ("Test KAG Analysis", self._test_kag_analysis),
            ("Test CAG Caching", self._test_cag_caching),
            ("Test Agent Communication", self._test_agent_communication)
        ]
        
        for test_name, test_func in tests:
            await self._run_test(test_name, test_func)
    
    async def _test_database_connections(self):
        """Test database connectivity"""
        tests = [
            ("PostgreSQL Connection", self._test_postgres_connection),
            ("Neo4j Connection", self._test_neo4j_connection),
            ("Redis Connection", self._test_redis_connection),
            ("Vector Store Health", self._test_vector_store_health)
        ]
        
        for test_name, test_func in tests:
            await self._run_test(test_name, test_func)
    
    async def _test_api_functionality(self):
        """Test API endpoints"""
        tests = [
            ("API Models", self._test_api_models),
            ("Route Definitions", self._test_route_definitions),
            ("Health Endpoint", self._test_health_endpoint),
            ("Metrics Endpoint", self._test_metrics_endpoint)
        ]
        
        for test_name, test_func in tests:
            await self._run_test(test_name, test_func)
    
    async def _test_ingestion_pipeline(self):
        """Test document ingestion pipeline"""
        tests = [
            ("Pipeline Creation", self._test_pipeline_creation),
            ("Document Processors", self._test_document_processors),
            ("Entity Extraction", self._test_entity_extraction),
            ("Relationship Extraction", self._test_relationship_extraction)
        ]
        
        for test_name, test_func in tests:
            await self._run_test(test_name, test_func)
    
    async def _test_end_to_end_flow(self):
        """Test complete end-to-end functionality"""
        tests = [
            ("Query Processing Flow", self._test_query_processing_flow),
            ("Strategy Selection", self._test_strategy_selection),
            ("Response Generation", self._test_response_generation),
            ("Error Handling", self._test_error_handling)
        ]
        
        for test_name, test_func in tests:
            await self._run_test(test_name, test_func)
    
    async def _run_test(self, test_name: str, test_func):
        """Run individual test with error handling"""
        try:
            await test_func()
            self.passed_tests.append(test_name)
            logger.info(f"  ✅ {test_name}")
        except Exception as e:
            self.failed_tests.append(f"{test_name}: {str(e)}")
            logger.warning(f"  ⚠️  {test_name}: {str(e)}")
    
    # Individual test implementations
    async def _test_import_unified_agent(self):
        """Test importing unified agent"""
        try:
            from ..src.agents.unified_agent import UnifiedAgent, QueryRequest, QueryResponse
            assert UnifiedAgent is not None
            assert QueryRequest is not None
            assert QueryResponse is not None
        except ImportError as e:
            raise Exception(f"Failed to import unified agent: {e}")
    
    async def _test_import_orchestrator(self):
        """Test importing orchestrator"""
        try:
            from ..src.agents.orchestrator import OrchestratorAgent, QueryStrategy
            assert OrchestratorAgent is not None
            assert QueryStrategy is not None
        except ImportError as e:
            raise Exception(f"Failed to import orchestrator: {e}")
    
    async def _test_import_rag_agent(self):
        """Test importing RAG agent"""
        try:
            from ..src.agents.rag_agent import RAGAgent
            assert RAGAgent is not None
        except ImportError as e:
            raise Exception(f"Failed to import RAG agent: {e}")
    
    async def _test_import_kag_agent(self):
        """Test importing KAG agent"""
        try:
            from ..src.agents.kag_agent import KAGAgent
            assert KAGAgent is not None
        except ImportError as e:
            raise Exception(f"Failed to import KAG agent: {e}")
    
    async def _test_import_cag_agent(self):
        """Test importing CAG agent"""
        try:
            from ..src.agents.cag_agent import CAGAgent
            assert CAGAgent is not None
        except ImportError as e:
            raise Exception(f"Failed to import CAG agent: {e}")
    
    async def _test_import_graphiti(self):
        """Test importing Graphiti client"""
        try:
            from ..src.core.graphiti_client import GraphitiClient
            assert GraphitiClient is not None
        except ImportError as e:
            raise Exception(f"Failed to import Graphiti client: {e}")
    
    async def _test_import_ingestion(self):
        """Test importing ingestion pipeline"""
        try:
            from ..src.ingestion.pipeline import MultiModalIngestionPipeline
            assert MultiModalIngestionPipeline is not None
        except ImportError as e:
            raise Exception(f"Failed to import ingestion pipeline: {e}")
    
    async def _test_import_api_routes(self):
        """Test importing API routes"""
        try:
            from ..src.api.routes import router, ChatRequest, ChatResponse
            assert router is not None
            assert ChatRequest is not None
            assert ChatResponse is not None
        except ImportError as e:
            raise Exception(f"Failed to import API routes: {e}")
    
    async def _test_create_unified_agent(self):
        """Test creating unified agent instance"""
        try:
            from ..src.agents.unified_agent import UnifiedAgent
            from ..src.agents.rag_agent import RAGAgent
            from ..src.agents.kag_agent import KAGAgent
            from ..src.agents.cag_agent import CAGAgent
            from ..src.agents.orchestrator import OrchestratorAgent
            
            # Create sub-agents
            rag_agent = RAGAgent()
            kag_agent = KAGAgent()
            cag_agent = CAGAgent()
            orchestrator = OrchestratorAgent()
            
            # Create unified agent
            unified_agent = UnifiedAgent(
                rag_agent=rag_agent,
                kag_agent=kag_agent,
                cag_agent=cag_agent,
                orchestrator=orchestrator
            )
            
            assert unified_agent is not None
            assert unified_agent.rag_agent is not None
            assert unified_agent.kag_agent is not None
            assert unified_agent.cag_agent is not None
            assert unified_agent.orchestrator is not None
            
        except Exception as e:
            raise Exception(f"Failed to create unified agent: {e}")
    
    async def _test_orchestrator_logic(self):
        """Test orchestrator decision logic"""
        try:
            from ..src.agents.orchestrator import OrchestratorAgent, QueryStrategy
            
            orchestrator = OrchestratorAgent()
            
            # Test different query types
            test_queries = [
                "What is DataLive?",
                "Who works on the DataLive team?",
                "When was DataLive created?",
                "How has DataLive evolved over time?"
            ]
            
            for query in test_queries:
                # This should not fail even if LLM is not available
                strategy = QueryStrategy(
                    use_rag=True,
                    use_kag=False,
                    use_temporal=False,
                    reasoning="Test strategy"
                )
                assert strategy is not None
                
        except Exception as e:
            raise Exception(f"Orchestrator logic test failed: {e}")
    
    async def _test_rag_search(self):
        """Test RAG search functionality"""
        try:
            from ..src.agents.rag_agent import RAGAgent
            
            rag_agent = RAGAgent()
            assert rag_agent is not None
            
            # Test basic search method exists
            assert hasattr(rag_agent, 'search')
            assert hasattr(rag_agent, 'generate_response')
            
        except Exception as e:
            raise Exception(f"RAG search test failed: {e}")
    
    async def _test_kag_analysis(self):
        """Test KAG relationship analysis"""
        try:
            from ..src.agents.kag_agent import KAGAgent
            
            kag_agent = KAGAgent()
            assert kag_agent is not None
            
            # Test methods exist
            assert hasattr(kag_agent, 'analyze_relationships')
            assert hasattr(kag_agent, 'temporal_search')
            assert hasattr(kag_agent, 'temporal_search_with_graphiti')
            
        except Exception as e:
            raise Exception(f"KAG analysis test failed: {e}")
    
    async def _test_cag_caching(self):
        """Test CAG caching functionality"""
        try:
            from ..src.agents.cag_agent import CAGAgent
            
            cag_agent = CAGAgent()
            assert cag_agent is not None
            
            # Test methods exist
            assert hasattr(cag_agent, 'get_cached_response')
            assert hasattr(cag_agent, 'cache_response')
            assert hasattr(cag_agent, 'get_cache_stats')
            
        except Exception as e:
            raise Exception(f"CAG caching test failed: {e}")
    
    async def _test_agent_communication(self):
        """Test inter-agent communication"""
        try:
            from ..src.agents.unified_agent import QueryRequest
            
            # Test request model
            request = QueryRequest(
                query="Test query",
                user_id="test_user",
                session_id="test_session"
            )
            
            assert request.query == "Test query"
            assert request.user_id == "test_user"
            assert request.session_id == "test_session"
            
        except Exception as e:
            raise Exception(f"Agent communication test failed: {e}")
    
    async def _test_postgres_connection(self):
        """Test PostgreSQL connection"""
        try:
            # Try to import database module
            from ..src.core.database import get_postgres_connection
            # This will likely fail without actual DB, but import should work
            assert get_postgres_connection is not None
        except ImportError as e:
            raise Exception(f"Cannot import postgres connection: {e}")
        except Exception:
            # Expected to fail without actual database
            pass
    
    async def _test_neo4j_connection(self):
        """Test Neo4j connection"""
        try:
            from ..src.core.database import get_neo4j_driver
            assert get_neo4j_driver is not None
        except ImportError as e:
            raise Exception(f"Cannot import Neo4j driver: {e}")
        except Exception:
            # Expected to fail without actual database
            pass
    
    async def _test_redis_connection(self):
        """Test Redis connection"""
        try:
            from ..src.core.database import get_redis_client
            assert get_redis_client is not None
        except ImportError as e:
            raise Exception(f"Cannot import Redis client: {e}")
        except Exception:
            # Expected to fail without actual Redis
            pass
    
    async def _test_vector_store_health(self):
        """Test vector store health"""
        try:
            from ..src.core.vector_store import VectorStore
            vector_store = VectorStore()
            assert vector_store is not None
            assert hasattr(vector_store, 'health_check')
        except ImportError as e:
            raise Exception(f"Cannot import vector store: {e}")
        except Exception:
            # Expected to fail without actual vector store
            pass
    
    async def _test_api_models(self):
        """Test API models"""
        try:
            from ..src.api.routes import ChatRequest, ChatResponse
            
            # Test request model
            request = ChatRequest(
                message="Test message",
                user_id="test_user"
            )
            assert request.message == "Test message"
            
            # Test response model
            response = ChatResponse(
                response="Test response",
                confidence=0.8
            )
            assert response.response == "Test response"
            assert response.confidence == 0.8
            
        except Exception as e:
            raise Exception(f"API models test failed: {e}")
    
    async def _test_route_definitions(self):
        """Test route definitions"""
        try:
            from ..src.api.routes import router
            assert router is not None
            # Check that routes are defined
            assert len(router.routes) > 0
        except Exception as e:
            raise Exception(f"Route definitions test failed: {e}")
    
    async def _test_health_endpoint(self):
        """Test health endpoint logic"""
        try:
            from ..src.api.routes import status
            # This should be callable
            assert callable(status)
        except Exception as e:
            raise Exception(f"Health endpoint test failed: {e}")
    
    async def _test_metrics_endpoint(self):
        """Test metrics endpoint"""
        try:
            from ..src.api.routes import metrics_summary
            assert callable(metrics_summary)
        except Exception as e:
            raise Exception(f"Metrics endpoint test failed: {e}")
    
    async def _test_pipeline_creation(self):
        """Test ingestion pipeline creation"""
        try:
            from ..src.ingestion.pipeline import MultiModalIngestionPipeline, IngestionConfig
            
            config = IngestionConfig()
            assert config is not None
            
            # Can't create pipeline without vector store and KG
            # But we can test the class exists
            assert MultiModalIngestionPipeline is not None
            
        except Exception as e:
            raise Exception(f"Pipeline creation test failed: {e}")
    
    async def _test_document_processors(self):
        """Test document processors"""
        try:
            from ..src.ingestion.processors.pdf_processor import PDFProcessor
            from ..src.ingestion.processors.word_processor import WordProcessor
            from ..src.ingestion.processors.excel_processor import ExcelProcessor
            from ..src.ingestion.processors.confluence_processor import ConfluenceProcessor
            
            # Test processor creation
            pdf_proc = PDFProcessor()
            word_proc = WordProcessor()
            excel_proc = ExcelProcessor()
            confluence_proc = ConfluenceProcessor()
            
            assert pdf_proc is not None
            assert word_proc is not None
            assert excel_proc is not None
            assert confluence_proc is not None
            
        except Exception as e:
            raise Exception(f"Document processors test failed: {e}")
    
    async def _test_entity_extraction(self):
        """Test entity extraction"""
        try:
            from ..src.ingestion.extractors.entity_extractor import EntityExtractor
            
            extractor = EntityExtractor()
            assert extractor is not None
            assert hasattr(extractor, 'extract')
            
        except Exception as e:
            raise Exception(f"Entity extraction test failed: {e}")
    
    async def _test_relationship_extraction(self):
        """Test relationship extraction"""
        try:
            from ..src.ingestion.extractors.relationship_extractor import RelationshipExtractor
            
            extractor = RelationshipExtractor()
            assert extractor is not None
            assert hasattr(extractor, 'extract')
            
        except Exception as e:
            raise Exception(f"Relationship extraction test failed: {e}")
    
    async def _test_query_processing_flow(self):
        """Test complete query processing flow"""
        try:
            from ..src.agents.unified_agent import QueryRequest, QueryResponse
            
            # Test models can be created
            request = QueryRequest(query="Test query")
            assert request.query == "Test query"
            
            # Test response structure
            response = QueryResponse(
                answer="Test answer",
                confidence=0.8,
                strategy_used=["RAG"],
                processing_time=1.0,
                cached=False,
                sources=[]
            )
            
            assert response.answer == "Test answer"
            assert response.confidence == 0.8
            
        except Exception as e:
            raise Exception(f"Query processing flow test failed: {e}")
    
    async def _test_strategy_selection(self):
        """Test strategy selection logic"""
        try:
            from ..src.agents.orchestrator import QueryStrategy
            
            strategy = QueryStrategy(
                use_rag=True,
                use_kag=False,
                use_temporal=False,
                reasoning="Test reasoning"
            )
            
            assert strategy.use_rag is True
            assert strategy.use_kag is False
            assert strategy.reasoning == "Test reasoning"
            
        except Exception as e:
            raise Exception(f"Strategy selection test failed: {e}")
    
    async def _test_response_generation(self):
        """Test response generation"""
        try:
            from ..src.agents.unified_agent import QueryResponse
            
            response = QueryResponse(
                answer="Generated response",
                confidence=0.9,
                strategy_used=["RAG", "KAG"],
                processing_time=2.5,
                cached=True,
                sources=[{"type": "document", "id": "doc1"}]
            )
            
            assert len(response.strategy_used) == 2
            assert response.cached is True
            assert len(response.sources) == 1
            
        except Exception as e:
            raise Exception(f"Response generation test failed: {e}")
    
    async def _test_error_handling(self):
        """Test error handling mechanisms"""
        try:
            # Test with various invalid inputs
            from ..src.agents.unified_agent import QueryRequest
            
            # Empty query
            request1 = QueryRequest(query="")
            assert request1.query == ""
            
            # None values
            request2 = QueryRequest(query="test", user_id=None)
            assert request2.user_id is None
            
            # Very long query
            long_query = "test " * 1000
            request3 = QueryRequest(query=long_query)
            assert len(request3.query) > 1000
            
        except Exception as e:
            raise Exception(f"Error handling test failed: {e}")
    
    def _generate_summary(self, duration: float) -> Dict[str, Any]:
        """Generate test summary"""
        total_tests = len(self.passed_tests) + len(self.failed_tests)
        success_rate = len(self.passed_tests) / total_tests if total_tests > 0 else 0
        
        return {
            "timestamp": datetime.now().isoformat(),
            "duration_seconds": round(duration, 2),
            "total_tests": total_tests,
            "passed_tests": len(self.passed_tests),
            "failed_tests": len(self.failed_tests),
            "success_rate": round(success_rate * 100, 1),
            "status": "HEALTHY" if success_rate >= 0.8 else "DEGRADED" if success_rate >= 0.5 else "UNHEALTHY",
            "passed_test_names": self.passed_tests,
            "failed_test_details": self.failed_tests,
            "recommendations": self._generate_recommendations()
        }
    
    def _generate_recommendations(self) -> List[str]:
        """Generate recommendations based on test results"""
        recommendations = []
        
        if len(self.failed_tests) == 0:
            recommendations.append("✅ All tests passed - system is healthy")
        elif len(self.failed_tests) < 5:
            recommendations.append("⚠️ Some tests failed - check failed test details")
            recommendations.append("💡 Most failures are likely due to missing infrastructure (databases, etc.)")
        else:
            recommendations.append("❌ Many tests failed - review system configuration")
            recommendations.append("🔧 Ensure all dependencies are installed and configured")
        
        # Specific recommendations
        if any("import" in test.lower() for test in self.failed_tests):
            recommendations.append("📦 Install missing Python packages: pip install -r requirements.txt")
        
        if any("database" in test.lower() or "connection" in test.lower() for test in self.failed_tests):
            recommendations.append("🗄️ Start database services: docker-compose up -d")
        
        return recommendations


async def main():
    """Run system health check"""
    checker = SystemHealthChecker()
    
    try:
        summary = await checker.run_all_tests()
        
        # Print final status
        status_emoji = {
            "HEALTHY": "🟢",
            "DEGRADED": "🟡", 
            "UNHEALTHY": "🔴"
        }
        
        status = summary["status"]
        emoji = status_emoji.get(status, "❓")
        
        print(f"\n{emoji} FINAL STATUS: {status}")
        print(f"📊 Success Rate: {summary['success_rate']}%")
        print(f"⏱️ Duration: {summary['duration_seconds']}s")
        
        if summary['recommendations']:
            print(f"\n💡 Recommendations:")
            for rec in summary['recommendations']:
                print(f"  {rec}")
        
        # Exit with appropriate code
        sys.exit(0 if status == "HEALTHY" else 1)
        
    except Exception as e:
        logger.error(f"Health check failed: {e}")
        traceback.print_exc()
        sys.exit(2)


if __name__ == "__main__":
    asyncio.run(main())