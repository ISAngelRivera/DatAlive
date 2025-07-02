"""
Markdown processor for DataLive ingestion pipeline
Handles .md files with structure preservation and metadata extraction
"""

import logging
import re
from typing import Dict, Any, Tuple, List, Optional
from pathlib import Path
from datetime import datetime
import chardet

from .base_processor import BaseProcessor

logger = logging.getLogger(__name__)


class MarkdownProcessor(BaseProcessor):
    """
    Markdown processor with structure awareness
    Extracts content while preserving document structure and extracting metadata
    """
    
    def __init__(self):
        super().__init__()
        self.supported_extensions = ['.md', '.markdown', '.mdown', '.mkd']
        self.supported_mimetypes = [
            'text/markdown',
            'text/x-markdown',
            'application/markdown'
        ]
    
    async def extract_content(
        self,
        source: str,
        **kwargs
    ) -> Tuple[str, Dict[str, Any]]:
        """
        Extract content from markdown file
        
        Args:
            source: File path or markdown content
            **kwargs: Additional parameters
            
        Returns:
            Tuple of (content, metadata)
        """
        try:
            if Path(source).exists():
                return await self._process_file(source, **kwargs)
            else:
                return await self._process_markdown_content(source, **kwargs)
                
        except Exception as e:
            logger.error(f"Error processing markdown source: {e}")
            raise
    
    async def _process_file(
        self,
        file_path: str,
        **kwargs
    ) -> Tuple[str, Dict[str, Any]]:
        """Process markdown file"""
        
        file_path = Path(file_path)
        
        # Detect encoding
        with open(file_path, 'rb') as f:
            raw_data = f.read()
            encoding_result = chardet.detect(raw_data)
            encoding = encoding_result.get('encoding', 'utf-8')
        
        # Read file
        try:
            with open(file_path, 'r', encoding=encoding) as f:
                content = f.read()
        except UnicodeDecodeError:
            logger.warning(f"Failed to decode with {encoding}, falling back to utf-8")
            with open(file_path, 'r', encoding='utf-8', errors='replace') as f:
                content = f.read()
            encoding = 'utf-8 (fallback)'
        
        # Process content and extract metadata
        processed_content, md_metadata = await self._process_markdown_content(content)
        
        # Get file stats
        stat = file_path.stat()
        
        # Combine metadata
        metadata = {
            'source_type': 'markdown',
            'file_path': str(file_path),
            'title': md_metadata.get('title') or file_path.stem,
            'content_type': 'text/markdown',
            'file_size': stat.st_size,
            'created_at': datetime.fromtimestamp(stat.st_ctime),
            'modified_at': datetime.fromtimestamp(stat.st_mtime),
            'encoding': encoding,
            'processor': 'MarkdownProcessor',
            'extraction_method': 'file_read'
        }
        
        # Add markdown-specific metadata
        metadata.update(md_metadata)
        
        logger.info(f"Processed markdown file: {file_path.name} ({len(content)} chars)")
        return processed_content, metadata
    
    async def _process_markdown_content(
        self,
        content: str,
        **kwargs
    ) -> Tuple[str, Dict[str, Any]]:
        """Process markdown content and extract structure"""
        
        # Extract frontmatter if present
        frontmatter = self._extract_frontmatter(content)
        if frontmatter['has_frontmatter']:
            content = frontmatter['content']
        
        # Extract document structure
        structure = self._extract_structure(content)
        
        # Extract links and references
        links = self._extract_links(content)
        
        # Extract code blocks
        code_blocks = self._extract_code_blocks(content)
        
        # Convert to plain text for processing while preserving structure
        plain_text = self._markdown_to_text(content)
        
        # Generate metadata
        metadata = {
            'content_type': 'text/markdown',
            'character_count': len(content),
            'word_count': len(plain_text.split()),
            'line_count': len(content.splitlines()),
            'language': self._detect_language(plain_text),
            'processor': 'MarkdownProcessor',
            'extraction_method': 'markdown_parse',
            'created_at': datetime.now(),
            
            # Markdown-specific metadata
            'frontmatter': frontmatter['data'],
            'has_frontmatter': frontmatter['has_frontmatter'],
            'structure': structure,
            'heading_count': len(structure['headings']),
            'max_heading_level': max([h['level'] for h in structure['headings']] + [0]),
            'link_count': len(links['internal']) + len(links['external']),
            'internal_links': links['internal'],
            'external_links': links['external'],
            'code_block_count': len(code_blocks),
            'code_languages': list(set(cb['language'] for cb in code_blocks if cb['language'])),
            'table_count': structure['table_count'],
            'list_count': structure['list_count']
        }
        
        # Use frontmatter title if available
        if frontmatter['data'].get('title'):
            metadata['title'] = frontmatter['data']['title']
        elif structure['headings']:
            metadata['title'] = structure['headings'][0]['text']
        else:
            metadata['title'] = kwargs.get('title', 'Markdown Document')
        
        # Add author from frontmatter
        if frontmatter['data'].get('author'):
            metadata['author'] = frontmatter['data']['author']
        
        # Add tags from frontmatter
        if frontmatter['data'].get('tags'):
            metadata['tags'] = frontmatter['data']['tags']
        
        logger.info(f"Processed markdown content ({len(content)} chars, {len(structure['headings'])} headings)")
        return plain_text, metadata
    
    def _extract_frontmatter(self, content: str) -> Dict[str, Any]:
        """Extract YAML frontmatter from markdown"""
        frontmatter_pattern = r'^---\s*\n(.*?)\n---\s*\n'
        match = re.match(frontmatter_pattern, content, re.DOTALL)
        
        if not match:
            return {
                'has_frontmatter': False,
                'data': {},
                'content': content
            }
        
        frontmatter_text = match.group(1)
        content_without_frontmatter = content[match.end():]
        
        # Simple YAML parsing (basic key: value pairs)
        data = {}
        for line in frontmatter_text.split('\n'):
            line = line.strip()
            if ':' in line and not line.startswith('#'):
                key, value = line.split(':', 1)
                key = key.strip()
                value = value.strip().strip('"\'')
                
                # Handle arrays (simple comma-separated)
                if value.startswith('[') and value.endswith(']'):
                    value = [item.strip().strip('"\'') for item in value[1:-1].split(',')]
                
                data[key] = value
        
        return {
            'has_frontmatter': True,
            'data': data,
            'content': content_without_frontmatter
        }
    
    def _extract_structure(self, content: str) -> Dict[str, Any]:
        """Extract document structure (headings, lists, tables)"""
        
        # Extract headings
        headings = []
        heading_pattern = r'^(#{1,6})\s+(.+)$'
        for match in re.finditer(heading_pattern, content, re.MULTILINE):
            level = len(match.group(1))
            text = match.group(2).strip()
            headings.append({
                'level': level,
                'text': text,
                'anchor': self._text_to_anchor(text)
            })
        
        # Count tables
        table_count = len(re.findall(r'\|.*\|', content))
        
        # Count lists
        list_pattern = r'^[\s]*[-*+]\s+|^[\s]*\d+\.\s+'
        list_count = len(re.findall(list_pattern, content, re.MULTILINE))
        
        return {
            'headings': headings,
            'table_count': table_count,
            'list_count': list_count
        }
    
    def _extract_links(self, content: str) -> Dict[str, List[Dict[str, str]]]:
        """Extract internal and external links"""
        
        # Pattern for markdown links [text](url)
        link_pattern = r'\[([^\]]+)\]\(([^)]+)\)'
        
        internal_links = []
        external_links = []
        
        for match in re.finditer(link_pattern, content):
            text = match.group(1)
            url = match.group(2)
            
            link_data = {'text': text, 'url': url}
            
            if url.startswith(('http://', 'https://', 'ftp://', 'mailto:')):
                external_links.append(link_data)
            else:
                internal_links.append(link_data)
        
        return {
            'internal': internal_links,
            'external': external_links
        }
    
    def _extract_code_blocks(self, content: str) -> List[Dict[str, str]]:
        """Extract code blocks with language information"""
        
        code_blocks = []
        
        # Fenced code blocks
        fenced_pattern = r'```(\w+)?\n(.*?)\n```'
        for match in re.finditer(fenced_pattern, content, re.DOTALL):
            language = match.group(1) or ''
            code = match.group(2)
            code_blocks.append({
                'language': language,
                'code': code,
                'type': 'fenced'
            })
        
        # Inline code
        inline_pattern = r'`([^`]+)`'
        for match in re.finditer(inline_pattern, content):
            code_blocks.append({
                'language': '',
                'code': match.group(1),
                'type': 'inline'
            })
        
        return code_blocks
    
    def _markdown_to_text(self, content: str) -> str:
        """Convert markdown to plain text"""
        
        # Remove code blocks first
        content = re.sub(r'```.*?```', '', content, flags=re.DOTALL)
        
        # Remove inline code
        content = re.sub(r'`[^`]+`', '', content)
        
        # Remove markdown formatting
        content = re.sub(r'#{1,6}\s+', '', content)  # Headings
        content = re.sub(r'\*\*([^*]+)\*\*', r'\1', content)  # Bold
        content = re.sub(r'\*([^*]+)\*', r'\1', content)  # Italic
        content = re.sub(r'_([^_]+)_', r'\1', content)  # Italic
        content = re.sub(r'\[([^\]]+)\]\([^)]+\)', r'\1', content)  # Links
        content = re.sub(r'!\[([^\]]*)\]\([^)]+\)', r'\1', content)  # Images
        content = re.sub(r'^[-*+]\s+', '', content, flags=re.MULTILINE)  # Lists
        content = re.sub(r'^\d+\.\s+', '', content, flags=re.MULTILINE)  # Numbered lists
        content = re.sub(r'^\s*\|\s*', '', content, flags=re.MULTILINE)  # Tables
        content = re.sub(r'\s*\|\s*$', '', content, flags=re.MULTILINE)  # Tables
        
        # Clean up extra whitespace
        content = re.sub(r'\n\s*\n', '\n\n', content)
        content = content.strip()
        
        return content
    
    def _text_to_anchor(self, text: str) -> str:
        """Convert heading text to anchor"""
        # Simple anchor generation
        anchor = text.lower()
        anchor = re.sub(r'[^\w\s-]', '', anchor)
        anchor = re.sub(r'[\s_]+', '-', anchor)
        return anchor.strip('-')
    
    def _detect_language(self, text: str) -> str:
        """Simple language detection"""
        # Reuse logic from TXT processor
        text_lower = text.lower()
        
        spanish_words = ['el', 'la', 'de', 'que', 'y', 'en', 'un', 'es', 'se', 'no']
        spanish_count = sum(1 for word in spanish_words if f' {word} ' in text_lower)
        
        english_words = ['the', 'and', 'of', 'to', 'a', 'in', 'is', 'it', 'you', 'that']
        english_count = sum(1 for word in english_words if f' {word} ' in text_lower)
        
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
                file_path = Path(source)
                return file_path.suffix.lower() in self.supported_extensions
            else:
                # Check if it looks like markdown content
                return isinstance(source, str) and ('# ' in source or '## ' in source or '```' in source)
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
                    'estimated_pages': max(1, stat.st_size // 3000),
                    'processor': 'MarkdownProcessor'
                }
            else:
                return {
                    'content_length': len(source),
                    'estimated_words': len(source.split()),
                    'processor': 'MarkdownProcessor'
                }
        except Exception as e:
            logger.error(f"Error getting metadata preview: {e}")
            return {'error': str(e)}
    
    async def health_check(self) -> Dict[str, Any]:
        """Perform health check"""
        return {
            'status': 'healthy',
            'processor': 'MarkdownProcessor',
            'supported_extensions': self.supported_extensions,
            'supported_mimetypes': self.supported_mimetypes,
            'features': [
                'frontmatter_extraction',
                'structure_analysis',
                'link_extraction',
                'code_block_detection',
                'plain_text_conversion',
                'metadata_enrichment'
            ]
        }