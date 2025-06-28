"""
Confluence document processor using Atlassian Python API
"""

import logging
from typing import Dict, Any, Tuple, Union, List
from datetime import datetime
import re

try:
    from atlassian import Confluence
    import requests
except ImportError:
    Confluence = None
    requests = None

from .base_processor import BaseProcessor

logger = logging.getLogger(__name__)


class ConfluenceProcessor(BaseProcessor):
    """Confluence document processor"""
    
    def __init__(self):
        super().__init__()
        self.supported_extensions = []  # URL-based, no file extensions
        
        if not Confluence or not requests:
            logger.warning("atlassian-python-api or requests not installed. Confluence processing disabled.")
    
    async def extract_content(
        self,
        source: Union[str, Dict[str, Any]],
        **kwargs
    ) -> Tuple[str, Dict[str, Any]]:
        """
        Extract content and metadata from Confluence page
        
        Args:
            source: Confluence page URL or page data dict
            **kwargs: Additional processing parameters
                - credentials: Dict with username/password or token
                - page_id: str - Specific page ID
                - space_key: str - Space key
                - include_attachments: bool = False
                - include_comments: bool = False
        
        Returns:
            Tuple of (content, metadata)
        """
        if not Confluence:
            raise ImportError("atlassian-python-api required for Confluence processing")
        
        credentials = kwargs.get('credentials', {})
        page_id = kwargs.get('page_id')
        space_key = kwargs.get('space_key')
        include_attachments = kwargs.get('include_attachments', False)
        include_comments = kwargs.get('include_comments', False)
        
        if not credentials:
            raise ValueError("Confluence credentials required")
        
        try:
            # Initialize Confluence client
            confluence = self._create_confluence_client(credentials)
            
            # Get page content
            if page_id:
                page_data = await self._get_page_by_id(confluence, page_id)
            elif isinstance(source, str) and source.startswith('http'):
                page_data = await self._get_page_by_url(confluence, source)
            else:
                raise ValueError("Invalid source: provide page_id or valid Confluence URL")
            
            # Extract content
            content = self._extract_page_content(page_data)
            
            # Extract metadata
            metadata = self._extract_page_metadata(page_data, space_key)
            
            # Add attachments if requested
            if include_attachments:
                attachments_content = await self._get_page_attachments(
                    confluence, page_data['id']
                )
                if attachments_content:
                    content += f"\n\n[Attachments]\n{attachments_content}"
                    metadata['has_attachments'] = True
            
            # Add comments if requested
            if include_comments:
                comments_content = await self._get_page_comments(
                    confluence, page_data['id']
                )
                if comments_content:
                    content += f"\n\n[Comments]\n{comments_content}"
                    metadata['has_comments'] = True
            
            return self.clean_text(content), metadata
            
        except Exception as e:
            logger.error(f"Error processing Confluence page {source}: {e}")
            raise
    
    def _create_confluence_client(self, credentials: Dict[str, str]) -> Confluence:
        """Create Confluence client with credentials"""
        base_url = credentials.get('base_url')
        if not base_url:
            raise ValueError("base_url required in credentials")
        
        # Support different authentication methods
        if 'token' in credentials:
            # API token authentication
            return Confluence(
                url=base_url,
                token=credentials['token']
            )
        elif 'username' in credentials and 'password' in credentials:
            # Username/password authentication
            return Confluence(
                url=base_url,
                username=credentials['username'],
                password=credentials['password']
            )
        else:
            raise ValueError("Either 'token' or 'username'+'password' required in credentials")
    
    async def _get_page_by_id(self, confluence: Confluence, page_id: str) -> Dict[str, Any]:
        """Get page data by ID"""
        try:
            page = confluence.get_page_by_id(
                page_id,
                expand='body.storage,metadata,version,space,ancestors'
            )
            return page
        except Exception as e:
            logger.error(f"Error getting Confluence page {page_id}: {e}")
            raise
    
    async def _get_page_by_url(self, confluence: Confluence, url: str) -> Dict[str, Any]:
        """Get page data by URL"""
        try:
            # Extract page ID from URL
            page_id_match = re.search(r'/pages/(\d+)', url)
            if page_id_match:
                page_id = page_id_match.group(1)
                return await self._get_page_by_id(confluence, page_id)
            
            # Try to extract space and title from URL
            url_parts = url.split('/')
            if 'display' in url_parts:
                idx = url_parts.index('display')
                if len(url_parts) > idx + 2:
                    space_key = url_parts[idx + 1]
                    page_title = url_parts[idx + 2].replace('+', ' ')
                    
                    page = confluence.get_page_by_title(space_key, page_title)
                    if page:
                        return await self._get_page_by_id(confluence, page['id'])
            
            raise ValueError(f"Could not extract page information from URL: {url}")
            
        except Exception as e:
            logger.error(f"Error getting Confluence page from URL {url}: {e}")
            raise
    
    def _extract_page_content(self, page_data: Dict[str, Any]) -> str:
        """Extract readable content from Confluence page"""
        content_parts = []
        
        # Add title
        title = page_data.get('title', 'Untitled')
        content_parts.append(f"# {title}\n")
        
        # Extract body content
        body = page_data.get('body', {})
        storage_body = body.get('storage', {})
        
        if storage_body and 'value' in storage_body:
            # Parse Confluence storage format (simplified)
            html_content = storage_body['value']
            text_content = self._html_to_text(html_content)
            content_parts.append(text_content)
        
        # Add ancestors (breadcrumb)
        ancestors = page_data.get('ancestors', [])
        if ancestors:
            breadcrumb = ' > '.join([ancestor.get('title', '') for ancestor in ancestors])
            content_parts.insert(1, f"Location: {breadcrumb} > {title}\n")
        
        return '\n'.join(content_parts)
    
    def _extract_page_metadata(
        self,
        page_data: Dict[str, Any],
        space_key: str = None
    ) -> Dict[str, Any]:
        """Extract metadata from Confluence page"""
        metadata = {
            'title': page_data.get('title', 'Untitled'),
            'content_type': 'confluence/page',
            'extraction_method': 'confluence_api'
        }
        
        # Page ID and space
        metadata['confluence_page_id'] = page_data.get('id')
        
        space = page_data.get('space', {})
        if space:
            metadata['confluence_space_key'] = space.get('key', space_key)
            metadata['confluence_space_name'] = space.get('name')
        
        # Version information
        version = page_data.get('version', {})
        if version:
            metadata['version_number'] = version.get('number')
            metadata['modified_at'] = version.get('when')
            
            author = version.get('by', {})
            if author:
                metadata['author'] = author.get('displayName')
                metadata['author_email'] = author.get('email')
        
        # Creation date from metadata
        page_metadata = page_data.get('metadata', {})
        if page_metadata:
            metadata['created_at'] = page_metadata.get('createdDate')
        
        # Labels/tags
        labels = page_data.get('metadata', {}).get('labels', {}).get('results', [])
        if labels:
            metadata['tags'] = [label.get('name') for label in labels]
        
        # URL
        base_url = getattr(page_data, '_base_url', '')
        if base_url and metadata.get('confluence_page_id'):
            metadata['source_url'] = f"{base_url}/pages/{metadata['confluence_page_id']}"
        
        return metadata
    
    def _html_to_text(self, html_content: str) -> str:
        """Convert Confluence HTML to readable text"""
        if not html_content:
            return ""
        
        # Simple HTML to text conversion
        # Remove XML namespace declarations
        text = re.sub(r'<\?xml[^>]+\?>', '', html_content)
        
        # Convert common HTML tags
        text = re.sub(r'<h[1-6][^>]*>', '\n## ', text)
        text = re.sub(r'</h[1-6]>', '\n', text)
        text = re.sub(r'<p[^>]*>', '\n', text)
        text = re.sub(r'</p>', '\n', text)
        text = re.sub(r'<br[^>]*/?>', '\n', text)
        text = re.sub(r'<li[^>]*>', '\n- ', text)
        text = re.sub(r'</li>', '', text)
        text = re.sub(r'<strong[^>]*>', '**', text)
        text = re.sub(r'</strong>', '**', text)
        text = re.sub(r'<em[^>]*>', '_', text)
        text = re.sub(r'</em>', '_', text)
        
        # Remove remaining HTML tags
        text = re.sub(r'<[^>]+>', '', text)
        
        # Clean up whitespace
        text = re.sub(r'\n\s*\n', '\n\n', text)
        text = re.sub(r'[ \t]+', ' ', text)
        
        return text.strip()
    
    async def _get_page_attachments(
        self,
        confluence: Confluence,
        page_id: str
    ) -> str:
        """Get attachments information for a page"""
        try:
            attachments = confluence.get_attachments_from_content(page_id)
            if not attachments or not attachments.get('results'):
                return ""
            
            attachment_info = []
            for attachment in attachments['results']:
                name = attachment.get('title', 'Unknown')
                size = attachment.get('extensions', {}).get('fileSize', 0)
                media_type = attachment.get('extensions', {}).get('mediaType', 'unknown')
                
                attachment_info.append(f"- {name} ({media_type}, {size} bytes)")
            
            return '\n'.join(attachment_info)
            
        except Exception as e:
            logger.warning(f"Error getting attachments for page {page_id}: {e}")
            return ""
    
    async def _get_page_comments(
        self,
        confluence: Confluence,
        page_id: str
    ) -> str:
        """Get comments for a page"""
        try:
            comments = confluence.get_page_comments(page_id)
            if not comments or not comments.get('results'):
                return ""
            
            comment_texts = []
            for comment in comments['results']:
                author = comment.get('version', {}).get('by', {}).get('displayName', 'Unknown')
                date = comment.get('version', {}).get('when', '')
                body = comment.get('body', {}).get('storage', {}).get('value', '')
                
                if body:
                    text = self._html_to_text(body)
                    comment_texts.append(f"**{author}** ({date}):\n{text}")
            
            return '\n\n'.join(comment_texts)
            
        except Exception as e:
            logger.warning(f"Error getting comments for page {page_id}: {e}")
            return ""
    
    async def get_space_pages(
        self,
        space_key: str,
        base_url: str,
        credentials: Dict[str, str],
        limit: int = 100
    ) -> List[Dict[str, Any]]:
        """Get all pages in a Confluence space"""
        if not Confluence:
            raise ImportError("atlassian-python-api required for Confluence processing")
        
        try:
            confluence = self._create_confluence_client({
                'base_url': base_url,
                **credentials
            })
            
            pages = []
            start = 0
            
            while True:
                result = confluence.get_all_pages_from_space(
                    space_key,
                    start=start,
                    limit=limit,
                    expand='version'
                )
                
                if not result or not result.get('results'):
                    break
                
                for page in result['results']:
                    pages.append({
                        'id': page['id'],
                        'title': page['title'],
                        'url': f"{base_url}/pages/{page['id']}",
                        'modified': page.get('version', {}).get('when')
                    })
                
                # Check if there are more pages
                if len(result['results']) < limit:
                    break
                
                start += limit
            
            logger.info(f"Found {len(pages)} pages in space {space_key}")
            return pages
            
        except Exception as e:
            logger.error(f"Error getting pages from space {space_key}: {e}")
            raise