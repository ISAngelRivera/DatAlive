"""
Plain text processor for DataLive ingestion pipeline
Handles .txt files and raw text content
"""

import logging
from typing import Dict, Any, Tuple, Optional
from pathlib import Path
import chardet
from datetime import datetime

from .base_processor import BaseProcessor

logger = logging.getLogger(__name__)


class TXTProcessor(BaseProcessor):
    """
    Plain text processor
    Handles .txt files and raw text content with encoding detection
    """
    
    def __init__(self):
        super().__init__()
        self.supported_extensions = ['.txt']
        self.supported_mimetypes = [
            'text/plain',
            'text/txt',
            'application/txt'
        ]
    
    async def extract_content(
        self,
        source: str,
        **kwargs
    ) -> Tuple[str, Dict[str, Any]]:
        """
        Extract content from text file
        
        Args:
            source: File path or text content
            **kwargs: Additional parameters
            
        Returns:
            Tuple of (content, metadata)
        """
        try:
            if Path(source).exists():
                # Process file
                return await self._process_file(source, **kwargs)
            else:
                # Process raw text content
                return await self._process_text(source, **kwargs)
                
        except Exception as e:
            logger.error(f"Error processing text source: {e}")
            raise
    
    async def _process_file(
        self,
        file_path: str,
        **kwargs
    ) -> Tuple[str, Dict[str, Any]]:
        """Process text file"""
        
        file_path = Path(file_path)
        
        # Detect encoding
        with open(file_path, 'rb') as f:
            raw_data = f.read()
            encoding_result = chardet.detect(raw_data)
            encoding = encoding_result.get('encoding', 'utf-8')
            confidence = encoding_result.get('confidence', 0.0)
        
        # Read file with detected encoding
        try:
            with open(file_path, 'r', encoding=encoding) as f:
                content = f.read()
        except UnicodeDecodeError:
            # Fallback to utf-8 with error handling
            logger.warning(f"Failed to decode with {encoding}, falling back to utf-8")
            with open(file_path, 'r', encoding='utf-8', errors='replace') as f:
                content = f.read()
            encoding = 'utf-8 (fallback)'
        
        # Get file stats
        stat = file_path.stat()
        
        # Generate metadata
        metadata = {
            'source_type': 'txt',
            'file_path': str(file_path),
            'title': file_path.stem,
            'content_type': 'text/plain',
            'file_size': stat.st_size,
            'created_at': datetime.fromtimestamp(stat.st_ctime),
            'modified_at': datetime.fromtimestamp(stat.st_mtime),
            'encoding': encoding,
            'encoding_confidence': confidence,
            'line_count': len(content.splitlines()),
            'character_count': len(content),
            'word_count': len(content.split()),
            'language': self._detect_language(content),
            'extraction_method': 'file_read',
            'processor': 'TXTProcessor'
        }
        
        logger.info(f"Processed text file: {file_path.name} ({len(content)} chars)")
        return content, metadata
    
    async def _process_text(
        self,
        text_content: str,
        **kwargs
    ) -> Tuple[str, Dict[str, Any]]:
        """Process raw text content"""
        
        # Generate metadata for raw text
        metadata = {
            'source_type': 'txt',
            'content_type': 'text/plain',
            'title': kwargs.get('title', 'Raw Text Content'),
            'character_count': len(text_content),
            'word_count': len(text_content.split()),
            'line_count': len(text_content.splitlines()),
            'language': self._detect_language(text_content),
            'extraction_method': 'raw_text',
            'processor': 'TXTProcessor',
            'created_at': datetime.now()
        }
        
        # Add any additional metadata from kwargs
        metadata.update(kwargs.get('metadata', {}))
        
        logger.info(f"Processed raw text content ({len(text_content)} chars)")
        return text_content, metadata
    
    def _detect_language(self, text: str) -> str:
        """
        Simple language detection
        Can be enhanced with libraries like langdetect
        """
        # Simple heuristics for common languages
        text_lower = text.lower()
        
        # Spanish indicators
        spanish_words = ['el', 'la', 'de', 'que', 'y', 'en', 'un', 'es', 'se', 'no', 'te', 'lo', 'le', 'da', 'su', 'por', 'son', 'con', 'para', 'al']
        spanish_count = sum(1 for word in spanish_words if f' {word} ' in text_lower)
        
        # English indicators  
        english_words = ['the', 'and', 'of', 'to', 'a', 'in', 'is', 'it', 'you', 'that', 'he', 'was', 'for', 'on', 'are', 'as', 'with', 'his', 'they', 'i']
        english_count = sum(1 for word in english_words if f' {word} ' in text_lower)
        
        # Simple decision
        if spanish_count > english_count:
            return 'es'
        elif english_count > 0:
            return 'en'
        else:
            return 'unknown'
    
    async def validate_source(self, source: str) -> bool:
        """Validate if source can be processed"""
        try:
            if Path(source).exists():
                # Check file extension
                file_path = Path(source)
                return file_path.suffix.lower() in self.supported_extensions
            else:
                # Assume raw text is always valid
                return isinstance(source, str) and len(source.strip()) > 0
        except Exception:
            return False
    
    async def get_metadata_preview(self, source: str) -> Dict[str, Any]:
        """Get metadata without full content extraction"""
        try:
            if Path(source).exists():
                file_path = Path(source)
                stat = file_path.stat()
                
                return {
                    'file_name': file_path.name,
                    'file_size': stat.st_size,
                    'file_extension': file_path.suffix.lower(),
                    'modified_at': datetime.fromtimestamp(stat.st_mtime),
                    'estimated_pages': max(1, stat.st_size // 2000),  # Rough estimate
                    'processor': 'TXTProcessor'
                }
            else:
                return {
                    'content_length': len(source),
                    'estimated_words': len(source.split()),
                    'processor': 'TXTProcessor'
                }
        except Exception as e:
            logger.error(f"Error getting metadata preview: {e}")
            return {'error': str(e)}
    
    async def health_check(self) -> Dict[str, Any]:
        """Perform health check"""
        return {
            'status': 'healthy',
            'processor': 'TXTProcessor',
            'supported_extensions': self.supported_extensions,
            'supported_mimetypes': self.supported_mimetypes,
            'features': [
                'encoding_detection',
                'language_detection',
                'metadata_extraction',
                'raw_text_processing'
            ]
        }