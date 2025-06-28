"""
PDF document processor using PyPDF2 and pdfplumber
"""

import logging
from typing import Dict, Any, Tuple, Union
from pathlib import Path
from datetime import datetime

try:
    import PyPDF2
    import pdfplumber
except ImportError:
    PyPDF2 = None
    pdfplumber = None

from .base_processor import BaseProcessor

logger = logging.getLogger(__name__)


class PDFProcessor(BaseProcessor):
    """PDF document processor"""
    
    def __init__(self):
        super().__init__()
        self.supported_extensions = ['.pdf']
        
        if not PyPDF2 or not pdfplumber:
            logger.warning("PyPDF2 or pdfplumber not installed. PDF processing will use fallback method.")
    
    async def extract_content(
        self,
        source: Union[str, Path, Dict[str, Any]],
        **kwargs
    ) -> Tuple[str, Dict[str, Any]]:
        """
        Extract content and metadata from PDF file
        
        Args:
            source: Path to PDF file
            **kwargs: Additional processing parameters
                - extract_tables: bool = False - Extract tables separately
                - extract_images: bool = False - Extract image descriptions
        
        Returns:
            Tuple of (content, metadata)
        """
        file_path = Path(source)
        
        if not await self.validate_source(file_path):
            raise FileNotFoundError(f"PDF file not found: {file_path}")
        
        extract_tables = kwargs.get('extract_tables', False)
        extract_images = kwargs.get('extract_images', False)
        
        try:
            if pdfplumber:
                content, metadata = await self._extract_with_pdfplumber(
                    file_path, extract_tables, extract_images
                )
            elif PyPDF2:
                content, metadata = await self._extract_with_pypdf2(file_path)
            else:
                # Fallback to simple text extraction
                content, metadata = await self._extract_fallback(file_path)
            
            # Add basic file metadata
            basic_metadata = self.extract_basic_metadata(file_path)
            metadata.update(basic_metadata)
            
            return self.clean_text(content), metadata
            
        except Exception as e:
            logger.error(f"Error processing PDF {file_path}: {e}")
            raise
    
    async def _extract_with_pdfplumber(
        self,
        file_path: Path,
        extract_tables: bool = False,
        extract_images: bool = False
    ) -> Tuple[str, Dict[str, Any]]:
        """Extract content using pdfplumber (more accurate)"""
        content_parts = []
        metadata = {
            'page_count': 0,
            'has_tables': False,
            'has_images': False,
            'extraction_method': 'pdfplumber'
        }
        
        with pdfplumber.open(file_path) as pdf:
            metadata['page_count'] = len(pdf.pages)
            
            # Extract PDF metadata
            if pdf.metadata:
                pdf_meta = pdf.metadata
                metadata.update({
                    'title': pdf_meta.get('Title', file_path.stem),
                    'author': pdf_meta.get('Author'),
                    'subject': pdf_meta.get('Subject'),
                    'creator': pdf_meta.get('Creator'),
                    'producer': pdf_meta.get('Producer'),
                    'creation_date': pdf_meta.get('CreationDate'),
                    'modification_date': pdf_meta.get('ModDate')
                })
            
            for i, page in enumerate(pdf.pages):
                # Extract text
                page_text = page.extract_text()
                if page_text:
                    content_parts.append(f"[Page {i+1}]\n{page_text}\n")
                
                # Extract tables if requested
                if extract_tables:
                    tables = page.extract_tables()
                    if tables:
                        metadata['has_tables'] = True
                        for j, table in enumerate(tables):
                            table_text = self._format_table(table, i+1, j+1)
                            content_parts.append(table_text)
                
                # Check for images
                if extract_images and hasattr(page, 'images') and page.images:
                    metadata['has_images'] = True
                    content_parts.append(f"[Page {i+1} contains {len(page.images)} images]")
        
        return '\n'.join(content_parts), metadata
    
    async def _extract_with_pypdf2(self, file_path: Path) -> Tuple[str, Dict[str, Any]]:
        """Extract content using PyPDF2 (fallback)"""
        content_parts = []
        metadata = {
            'extraction_method': 'pypdf2'
        }
        
        with open(file_path, 'rb') as file:
            pdf_reader = PyPDF2.PdfReader(file)
            metadata['page_count'] = len(pdf_reader.pages)
            
            # Extract PDF metadata
            if pdf_reader.metadata:
                pdf_meta = pdf_reader.metadata
                metadata.update({
                    'title': pdf_meta.get('/Title', file_path.stem),
                    'author': pdf_meta.get('/Author'),
                    'subject': pdf_meta.get('/Subject'),
                    'creator': pdf_meta.get('/Creator'),
                    'producer': pdf_meta.get('/Producer'),
                    'creation_date': pdf_meta.get('/CreationDate'),
                    'modification_date': pdf_meta.get('/ModDate')
                })
            
            # Extract text from each page
            for i, page in enumerate(pdf_reader.pages):
                try:
                    page_text = page.extract_text()
                    if page_text:
                        content_parts.append(f"[Page {i+1}]\n{page_text}\n")
                except Exception as e:
                    logger.warning(f"Error extracting text from page {i+1}: {e}")
                    content_parts.append(f"[Page {i+1} - text extraction failed]")
        
        return '\n'.join(content_parts), metadata
    
    async def _extract_fallback(self, file_path: Path) -> Tuple[str, Dict[str, Any]]:
        """Fallback extraction method"""
        logger.warning("Using fallback PDF extraction method")
        
        metadata = {
            'extraction_method': 'fallback',
            'title': file_path.stem
        }
        
        # Simple approach - just indicate PDF content
        content = f"PDF Document: {file_path.name}\n"
        content += "Content extraction requires PyPDF2 or pdfplumber libraries.\n"
        content += f"File size: {file_path.stat().st_size} bytes"
        
        return content, metadata
    
    def _format_table(self, table: list, page_num: int, table_num: int) -> str:
        """Format extracted table as text"""
        if not table:
            return ""
        
        table_text = f"\n[Table {table_num} on Page {page_num}]\n"
        
        for row in table:
            if row:
                # Filter out None values and join with tabs
                clean_row = [str(cell) if cell is not None else "" for cell in row]
                table_text += "\t".join(clean_row) + "\n"
        
        return table_text + "\n"
    
    def get_pdf_info(self, file_path: Path) -> Dict[str, Any]:
        """Get basic PDF information without full extraction"""
        try:
            if pdfplumber:
                with pdfplumber.open(file_path) as pdf:
                    return {
                        'page_count': len(pdf.pages),
                        'metadata': pdf.metadata or {},
                        'file_size': file_path.stat().st_size
                    }
            elif PyPDF2:
                with open(file_path, 'rb') as file:
                    pdf_reader = PyPDF2.PdfReader(file)
                    return {
                        'page_count': len(pdf_reader.pages),
                        'metadata': pdf_reader.metadata or {},
                        'file_size': file_path.stat().st_size
                    }
            else:
                return {'error': 'No PDF library available'}
                
        except Exception as e:
            logger.error(f"Error getting PDF info for {file_path}: {e}")
            return {'error': str(e)}