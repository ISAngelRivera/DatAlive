"""
Multi-modal document ingestion pipeline for DataLive Enterprise RAG+KAG+CAG
Processes documents from various sources and formats into vector DB and knowledge graph
"""

import asyncio
import logging
from typing import Dict, List, Any, Optional, Union
from datetime import datetime
from pathlib import Path

from pydantic import BaseModel, Field
import hashlib

from .processors.pdf_processor import PDFProcessor
from .processors.confluence_processor import ConfluenceProcessor
from .processors.excel_processor import ExcelProcessor
from .processors.word_processor import WordProcessor
from .extractors.entity_extractor import EntityExtractor
from .extractors.relationship_extractor import RelationshipExtractor
from ..core.vector_store import VectorStore
from ..core.knowledge_graph import KnowledgeGraph
from ..core.metrics import (
    query_counter,
    agent_usage_counter,
    kg_nodes_count,
    kg_relationships_count
)

logger = logging.getLogger(__name__)


class DocumentMetadata(BaseModel):
    """Document metadata model"""
    source_type: str
    source_url: Optional[str] = None
    file_path: Optional[str] = None
    title: str
    author: Optional[str] = None
    created_at: Optional[datetime] = None
    modified_at: Optional[datetime] = None
    content_type: str
    file_size: Optional[int] = None
    content_hash: str
    tags: List[str] = Field(default_factory=list)
    language: str = "en"


class ProcessedDocument(BaseModel):
    """Processed document model"""
    id: str
    metadata: DocumentMetadata
    content: str
    chunks: List[Dict[str, Any]] = Field(default_factory=list)
    entities: List[Dict[str, Any]] = Field(default_factory=list)
    relationships: List[Dict[str, Any]] = Field(default_factory=list)
    processing_time: float = 0.0
    errors: List[str] = Field(default_factory=list)


class IngestionConfig(BaseModel):
    """Ingestion pipeline configuration"""
    chunk_size: int = 1000
    chunk_overlap: int = 200
    extract_entities: bool = True
    extract_relationships: bool = True
    store_in_vector_db: bool = True
    store_in_knowledge_graph: bool = True
    enable_temporal_analysis: bool = True
    batch_size: int = 10
    max_concurrent_docs: int = 5


class MultiModalIngestionPipeline:
    """
    Multi-modal document ingestion pipeline
    Processes various document types and stores in vector DB and knowledge graph
    """

    def __init__(
        self,
        vector_store: VectorStore,
        knowledge_graph: KnowledgeGraph,
        config: Optional[IngestionConfig] = None
    ):
        self.vector_store = vector_store
        self.knowledge_graph = knowledge_graph
        self.config = config or IngestionConfig()
        
        # Initialize processors
        self.processors = {
            'pdf': PDFProcessor(),
            'confluence': ConfluenceProcessor(),
            'excel': ExcelProcessor(),
            'word': WordProcessor()
        }
        
        # Initialize extractors
        self.entity_extractor = EntityExtractor()
        self.relationship_extractor = RelationshipExtractor()
        
        # Processing metrics
        self.processed_documents = 0
        self.failed_documents = 0
        
        logger.info("Multi-modal ingestion pipeline initialized")

    async def process_document(
        self,
        source: Union[str, Path, Dict[str, Any]],
        source_type: str,
        **kwargs
    ) -> ProcessedDocument:
        """
        Process a single document through the pipeline
        
        Args:
            source: Document source (file path, URL, or data dict)
            source_type: Type of source (pdf, confluence, excel, word)
            **kwargs: Additional processing parameters
        
        Returns:
            ProcessedDocument with all extracted information
        """
        start_time = datetime.now()
        
        try:
            # Get appropriate processor
            if source_type not in self.processors:
                raise ValueError(f"Unsupported source type: {source_type}")
            
            processor = self.processors[source_type]
            
            # Extract content and metadata
            logger.info(f"Processing {source_type} document: {source}")
            raw_content, metadata = await processor.extract_content(source, **kwargs)
            
            # Generate document ID
            content_hash = hashlib.sha256(raw_content.encode()).hexdigest()
            doc_id = f"{source_type}_{content_hash[:16]}"
            
            # Create document metadata
            doc_metadata = DocumentMetadata(
                source_type=source_type,
                source_url=str(source) if source_type == 'confluence' else None,
                file_path=str(source) if isinstance(source, (str, Path)) else None,
                content_hash=content_hash,
                **metadata
            )
            
            # Initialize processed document
            processed_doc = ProcessedDocument(
                id=doc_id,
                metadata=doc_metadata,
                content=raw_content
            )
            
            # Create text chunks for vector storage
            if self.config.store_in_vector_db:
                processed_doc.chunks = await self._create_chunks(
                    raw_content,
                    doc_metadata
                )
            
            # Extract entities and relationships for knowledge graph
            if self.config.extract_entities:
                processed_doc.entities = await self.entity_extractor.extract(
                    raw_content,
                    doc_metadata
                )
            
            if self.config.extract_relationships:
                processed_doc.relationships = await self.relationship_extractor.extract(
                    raw_content,
                    processed_doc.entities,
                    doc_metadata
                )
            
            # Store in vector database
            if self.config.store_in_vector_db and processed_doc.chunks:
                await self._store_in_vector_db(processed_doc)
            
            # Store in knowledge graph
            if self.config.store_in_knowledge_graph:
                await self._store_in_knowledge_graph(processed_doc)
            
            # Calculate processing time
            processing_time = (datetime.now() - start_time).total_seconds()
            processed_doc.processing_time = processing_time
            
            # Update metrics
            self.processed_documents += 1
            agent_usage_counter.labels(agent_type='ingestion').inc()
            
            logger.info(f"Successfully processed document {doc_id} in {processing_time:.2f}s")
            return processed_doc
            
        except Exception as e:
            error_msg = f"Error processing document {source}: {str(e)}"
            logger.error(error_msg)
            
            self.failed_documents += 1
            
            # Return error document
            return ProcessedDocument(
                id=f"error_{datetime.now().timestamp()}",
                metadata=DocumentMetadata(
                    source_type=source_type,
                    title="Processing Error",
                    content_type="error",
                    content_hash="error"
                ),
                content="",
                errors=[error_msg],
                processing_time=(datetime.now() - start_time).total_seconds()
            )

    async def process_batch(
        self,
        documents: List[Dict[str, Any]]
    ) -> List[ProcessedDocument]:
        """
        Process a batch of documents concurrently
        
        Args:
            documents: List of document specs with 'source', 'source_type', and optional kwargs
        
        Returns:
            List of ProcessedDocument results
        """
        logger.info(f"Processing batch of {len(documents)} documents")
        
        # Create semaphore to limit concurrent processing
        semaphore = asyncio.Semaphore(self.config.max_concurrent_docs)
        
        async def process_with_semaphore(doc_spec):
            async with semaphore:
                return await self.process_document(
                    source=doc_spec['source'],
                    source_type=doc_spec['source_type'],
                    **doc_spec.get('kwargs', {})
                )
        
        # Process documents concurrently
        tasks = [process_with_semaphore(doc) for doc in documents]
        results = await asyncio.gather(*tasks, return_exceptions=True)
        
        # Handle exceptions
        processed_results = []
        for i, result in enumerate(results):
            if isinstance(result, Exception):
                logger.error(f"Failed to process document {documents[i]}: {result}")
                processed_results.append(ProcessedDocument(
                    id=f"batch_error_{i}",
                    metadata=DocumentMetadata(
                        source_type=documents[i].get('source_type', 'unknown'),
                        title="Batch Processing Error",
                        content_type="error",
                        content_hash="batch_error"
                    ),
                    content="",
                    errors=[str(result)]
                ))
            else:
                processed_results.append(result)
        
        logger.info(f"Batch processing completed: {len(processed_results)} documents")
        return processed_results

    async def ingest_confluence_space(
        self,
        space_key: str,
        base_url: str,
        credentials: Dict[str, str],
        **kwargs
    ) -> List[ProcessedDocument]:
        """
        Ingest all pages from a Confluence space
        
        Args:
            space_key: Confluence space key
            base_url: Confluence base URL
            credentials: Authentication credentials
            **kwargs: Additional processing parameters
        
        Returns:
            List of processed documents
        """
        logger.info(f"Starting Confluence space ingestion: {space_key}")
        
        try:
            confluence_processor = self.processors['confluence']
            
            # Get all pages in space
            pages = await confluence_processor.get_space_pages(
                space_key,
                base_url,
                credentials
            )
            
            # Create document specs
            document_specs = [
                {
                    'source': page['url'],
                    'source_type': 'confluence',
                    'kwargs': {
                        'credentials': credentials,
                        'page_id': page['id'],
                        'space_key': space_key
                    }
                }
                for page in pages
            ]
            
            # Process in batches
            all_results = []
            for i in range(0, len(document_specs), self.config.batch_size):
                batch = document_specs[i:i + self.config.batch_size]
                batch_results = await self.process_batch(batch)
                all_results.extend(batch_results)
                
                logger.info(f"Processed batch {i // self.config.batch_size + 1}/{(len(document_specs) + self.config.batch_size - 1) // self.config.batch_size}")
            
            logger.info(f"Confluence space ingestion completed: {len(all_results)} pages processed")
            return all_results
            
        except Exception as e:
            logger.error(f"Error in Confluence space ingestion: {e}")
            raise

    async def ingest_directory(
        self,
        directory_path: Path,
        file_patterns: List[str] = None,
        recursive: bool = True
    ) -> List[ProcessedDocument]:
        """
        Ingest all supported files from a directory
        
        Args:
            directory_path: Path to directory
            file_patterns: File patterns to match (e.g., ['*.pdf', '*.docx'])
            recursive: Whether to search recursively
        
        Returns:
            List of processed documents
        """
        if file_patterns is None:
            file_patterns = ['*.pdf', '*.docx', '*.xlsx', '*.txt']
        
        logger.info(f"Starting directory ingestion: {directory_path}")
        
        # Find all matching files
        files = []
        for pattern in file_patterns:
            if recursive:
                files.extend(directory_path.rglob(pattern))
            else:
                files.extend(directory_path.glob(pattern))
        
        # Determine source types
        document_specs = []
        for file_path in files:
            suffix = file_path.suffix.lower()
            if suffix == '.pdf':
                source_type = 'pdf'
            elif suffix in ['.docx', '.doc']:
                source_type = 'word'
            elif suffix in ['.xlsx', '.xls']:
                source_type = 'excel'
            else:
                continue  # Skip unsupported files
            
            document_specs.append({
                'source': file_path,
                'source_type': source_type
            })
        
        logger.info(f"Found {len(document_specs)} files to process")
        
        # Process in batches
        all_results = []
        for i in range(0, len(document_specs), self.config.batch_size):
            batch = document_specs[i:i + self.config.batch_size]
            batch_results = await self.process_batch(batch)
            all_results.extend(batch_results)
            
            logger.info(f"Processed batch {i // self.config.batch_size + 1}/{(len(document_specs) + self.config.batch_size - 1) // self.config.batch_size}")
        
        logger.info(f"Directory ingestion completed: {len(all_results)} files processed")
        return all_results

    async def _create_chunks(
        self,
        content: str,
        metadata: DocumentMetadata
    ) -> List[Dict[str, Any]]:
        """Create text chunks for vector storage"""
        chunks = []
        
        # Simple text chunking (can be enhanced with semantic chunking)
        words = content.split()
        
        for i in range(0, len(words), self.config.chunk_size - self.config.chunk_overlap):
            chunk_words = words[i:i + self.config.chunk_size]
            chunk_text = ' '.join(chunk_words)
            
            chunk = {
                'text': chunk_text,
                'metadata': {
                    'document_id': metadata.content_hash,
                    'source_type': metadata.source_type,
                    'title': metadata.title,
                    'chunk_index': len(chunks),
                    'created_at': datetime.now().isoformat()
                }
            }
            chunks.append(chunk)
        
        return chunks

    async def _store_in_vector_db(self, document: ProcessedDocument):
        """Store document chunks in vector database"""
        try:
            for chunk in document.chunks:
                await self.vector_store.add_document(
                    content=chunk['text'],
                    metadata=chunk['metadata']
                )
            
            logger.debug(f"Stored {len(document.chunks)} chunks in vector DB for document {document.id}")
            
        except Exception as e:
            logger.error(f"Error storing document {document.id} in vector DB: {e}")
            document.errors.append(f"Vector DB storage error: {str(e)}")

    async def _store_in_knowledge_graph(self, document: ProcessedDocument):
        """Store entities and relationships in knowledge graph"""
        try:
            # Create document node
            await self.knowledge_graph.create_document_node(
                document_id=document.id,
                metadata=document.metadata.dict()
            )
            
            # Store entities
            for entity in document.entities:
                await self.knowledge_graph.create_entity(
                    entity_id=entity['id'],
                    entity_type=entity['type'],
                    properties=entity['properties'],
                    document_id=document.id
                )
            
            # Store relationships
            for relationship in document.relationships:
                await self.knowledge_graph.create_relationship(
                    source_id=relationship['source_id'],
                    target_id=relationship['target_id'],
                    relationship_type=relationship['type'],
                    properties=relationship['properties'],
                    document_id=document.id
                )
            
            # Update metrics
            kg_nodes_count.inc(len(document.entities))
            kg_relationships_count.inc(len(document.relationships))
            
            logger.debug(f"Stored {len(document.entities)} entities and {len(document.relationships)} relationships in KG for document {document.id}")
            
        except Exception as e:
            logger.error(f"Error storing document {document.id} in knowledge graph: {e}")
            document.errors.append(f"Knowledge graph storage error: {str(e)}")

    async def get_processing_stats(self) -> Dict[str, Any]:
        """Get processing statistics"""
        return {
            'processed_documents': self.processed_documents,
            'failed_documents': self.failed_documents,
            'success_rate': (
                self.processed_documents / (self.processed_documents + self.failed_documents)
                if (self.processed_documents + self.failed_documents) > 0
                else 0
            ),
            'supported_formats': list(self.processors.keys()),
            'configuration': self.config.dict()
        }

    async def health_check(self) -> Dict[str, Any]:
        """Perform health check"""
        try:
            # Check vector store connection
            vector_health = await self.vector_store.health_check()
            
            # Check knowledge graph connection
            kg_health = await self.knowledge_graph.health_check()
            
            return {
                'status': 'healthy' if vector_health and kg_health else 'unhealthy',
                'vector_store': 'connected' if vector_health else 'disconnected',
                'knowledge_graph': 'connected' if kg_health else 'disconnected',
                'processors': list(self.processors.keys()),
                'timestamp': datetime.now().isoformat()
            }
            
        except Exception as e:
            return {
                'status': 'unhealthy',
                'error': str(e),
                'timestamp': datetime.now().isoformat()
            }