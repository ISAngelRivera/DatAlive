import pytest
from pathlib import Path
from src.ingestion.pipeline import IngestionPipeline
from src.ingestion.processors.pdf_processor import PDFProcessor

class TestIngestion:
    @pytest.mark.asyncio
    async def test_pdf_processing(self, tmp_path):
        """Test PDF document processing."""
        # Create test PDF
        test_pdf = tmp_path / "test.pdf"
        # ... crear PDF de prueba ...
        
        processor = PDFProcessor()
        result = await processor.process(test_pdf)
        
        assert result.text != ""
        assert len(result.chunks) > 0
        assert result.metadata["format"] == "pdf"
    
    @pytest.mark.asyncio
    async def test_entity_extraction(self):
        """Test entity extraction from text."""
        from src.ingestion.extractors.entity_extractor import EntityExtractor
        
        extractor = EntityExtractor()
        text = "DataLive is a project developed by Acme Corp using Neo4j and Python."
        
        entities = await extractor.extract(text)
        
        assert any(e.name == "DataLive" and e.type == "Project" for e in entities)
        assert any(e.name == "Acme Corp" and e.type == "Organization" for e in entities)
        assert any(e.name == "Neo4j" and e.type == "Technology" for e in entities)