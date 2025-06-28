"""
Base processor class for document processing
"""

import logging
from abc import ABC, abstractmethod
from typing import Dict, Any, Tuple, Union
from pathlib import Path

logger = logging.getLogger(__name__)


class BaseProcessor(ABC):
    """Base class for document processors"""
    
    def __init__(self):
        self.name = self.__class__.__name__
        self.supported_extensions = []
    
    @abstractmethod
    async def extract_content(
        self,
        source: Union[str, Path, Dict[str, Any]],
        **kwargs
    ) -> Tuple[str, Dict[str, Any]]:
        """
        Extract content and metadata from source
        
        Args:
            source: Document source (file path, URL, or data dict)
            **kwargs: Additional processing parameters
        
        Returns:
            Tuple of (content, metadata)
        """
        pass
    
    def is_supported(self, file_path: Path) -> bool:
        """Check if file is supported by this processor"""
        return file_path.suffix.lower() in self.supported_extensions
    
    async def validate_source(self, source: Union[str, Path]) -> bool:
        """Validate that source exists and is accessible"""
        if isinstance(source, (str, Path)):
            path = Path(source)
            return path.exists() and path.is_file()
        return True  # For URLs or other sources
    
    def clean_text(self, text: str) -> str:
        """Clean and normalize extracted text"""
        if not text:
            return ""
        
        # Remove extra whitespace
        text = ' '.join(text.split())
        
        # Remove common artifacts
        text = text.replace('\x00', '')  # Null bytes
        text = text.replace('\ufeff', '')  # BOM
        
        return text.strip()
    
    def extract_basic_metadata(self, file_path: Path) -> Dict[str, Any]:
        """Extract basic file metadata"""
        if not file_path.exists():
            return {}
        
        stat = file_path.stat()
        
        return {
            'title': file_path.stem,
            'file_size': stat.st_size,
            'created_at': stat.st_ctime,
            'modified_at': stat.st_mtime,
            'content_type': f"application/{file_path.suffix[1:]}" if file_path.suffix else "text/plain"
        }