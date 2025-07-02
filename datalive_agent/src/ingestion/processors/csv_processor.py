"""
CSV processor for DataLive ingestion pipeline
Handles .csv files with intelligent structure detection and content extraction
"""

import logging
import csv
import io
from typing import Dict, Any, Tuple, List, Optional, Union
from pathlib import Path
from datetime import datetime
import chardet

from .base_processor import BaseProcessor

logger = logging.getLogger(__name__)


class CSVProcessor(BaseProcessor):
    """
    CSV processor with intelligent structure detection
    Extracts tabular data and converts to searchable text format
    """
    
    def __init__(self):
        super().__init__()
        self.supported_extensions = ['.csv', '.tsv']
        self.supported_mimetypes = [
            'text/csv',
            'application/csv',
            'text/tab-separated-values'
        ]
    
    async def extract_content(
        self,
        source: str,
        **kwargs
    ) -> Tuple[str, Dict[str, Any]]:
        """
        Extract content from CSV file
        
        Args:
            source: File path or CSV content
            **kwargs: Additional parameters
                - max_rows: Maximum number of rows to process (default: 10000)
                - sample_rows: Number of rows to analyze for structure (default: 100)
                - delimiter: CSV delimiter (auto-detected if not provided)
                
        Returns:
            Tuple of (content, metadata)
        """
        try:
            if Path(source).exists():
                return await self._process_file(source, **kwargs)
            else:
                return await self._process_csv_content(source, **kwargs)
                
        except Exception as e:
            logger.error(f"Error processing CSV source: {e}")
            raise
    
    async def _process_file(
        self,
        file_path: str,
        **kwargs
    ) -> Tuple[str, Dict[str, Any]]:
        """Process CSV file"""
        
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
        
        # Process CSV content
        processed_content, csv_metadata = await self._process_csv_content(content, **kwargs)
        
        # Get file stats
        stat = file_path.stat()
        
        # Combine metadata
        metadata = {
            'source_type': 'csv',
            'file_path': str(file_path),
            'title': file_path.stem,
            'content_type': 'text/csv',
            'file_size': stat.st_size,
            'created_at': datetime.fromtimestamp(stat.st_ctime),
            'modified_at': datetime.fromtimestamp(stat.st_mtime),
            'encoding': encoding,
            'processor': 'CSVProcessor',
            'extraction_method': 'file_read'
        }
        
        # Add CSV-specific metadata
        metadata.update(csv_metadata)
        
        logger.info(f"Processed CSV file: {file_path.name} ({csv_metadata['row_count']} rows, {csv_metadata['column_count']} columns)")
        return processed_content, metadata
    
    async def _process_csv_content(
        self,
        content: str,
        **kwargs
    ) -> Tuple[str, Dict[str, Any]]:
        """Process CSV content and extract structured data"""
        
        max_rows = kwargs.get('max_rows', 10000)
        sample_rows = kwargs.get('sample_rows', 100)
        delimiter = kwargs.get('delimiter')
        
        # Detect delimiter if not provided
        if not delimiter:
            delimiter = self._detect_delimiter(content)
        
        # Parse CSV
        reader = csv.reader(io.StringIO(content), delimiter=delimiter)
        rows = []
        headers = None
        
        try:
            # Read and analyze data
            for i, row in enumerate(reader):
                if i == 0:
                    # Assume first row is headers
                    headers = [col.strip() for col in row]
                elif i <= max_rows:
                    rows.append([cell.strip() for cell in row])
                else:
                    break
        except csv.Error as e:
            logger.warning(f"CSV parsing error: {e}")
            # Fallback to simple line processing
            lines = content.split('\n')
            if lines:
                headers = [col.strip() for col in lines[0].split(delimiter)]
                for line in lines[1:max_rows+1]:
                    if line.strip():
                        rows.append([cell.strip() for cell in line.split(delimiter)])
        
        # Analyze structure
        analysis = self._analyze_csv_structure(headers, rows[:sample_rows])
        
        # Convert to searchable text
        searchable_text = self._csv_to_text(headers, rows, analysis)
        
        # Generate metadata
        metadata = {
            'content_type': 'text/csv',
            'character_count': len(content),
            'row_count': len(rows),
            'column_count': len(headers) if headers else 0,
            'delimiter': delimiter,
            'processor': 'CSVProcessor',
            'extraction_method': 'csv_parse',
            'created_at': datetime.now(),
            
            # CSV-specific metadata
            'headers': headers,
            'column_analysis': analysis,
            'has_headers': headers is not None,
            'estimated_data_types': {col: analysis.get(col, {}).get('type', 'text') for col in headers} if headers else {},
            'sample_data': rows[:5] if rows else [],  # First 5 rows as sample
            'total_cells': len(rows) * len(headers) if headers else 0,
            'empty_cells': analysis.get('empty_cells', 0),
            'data_quality_score': analysis.get('quality_score', 0.0)
        }
        
        # Add title from kwargs or filename pattern
        metadata['title'] = kwargs.get('title', 'CSV Dataset')
        
        logger.info(f"Processed CSV content ({len(rows)} rows, {len(headers) if headers else 0} columns)")
        return searchable_text, metadata
    
    def _detect_delimiter(self, content: str) -> str:
        """Detect CSV delimiter"""
        # Try common delimiters
        delimiters = [',', ';', '\t', '|']
        
        # Get first few lines
        lines = content.split('\n')[:5]
        sample = '\n'.join(lines)
        
        # Count occurrences of each delimiter
        delimiter_counts = {}
        for delimiter in delimiters:
            count = 0
            for line in lines:
                if line.strip():
                    count += line.count(delimiter)
            delimiter_counts[delimiter] = count
        
        # Return most common delimiter
        if delimiter_counts:
            return max(delimiter_counts, key=delimiter_counts.get)
        else:
            return ','  # Default fallback
    
    def _analyze_csv_structure(self, headers: List[str], sample_rows: List[List[str]]) -> Dict[str, Any]:
        """Analyze CSV structure and data types"""
        
        if not headers or not sample_rows:
            return {'quality_score': 0.0, 'empty_cells': 0}
        
        analysis = {}
        total_cells = 0
        empty_cells = 0
        
        for col_idx, header in enumerate(headers):
            col_data = []
            col_empty = 0
            
            # Extract column data
            for row in sample_rows:
                if col_idx < len(row):
                    cell = row[col_idx]
                    if cell.strip():
                        col_data.append(cell)
                    else:
                        col_empty += 1
                        empty_cells += 1
                else:
                    col_empty += 1
                    empty_cells += 1
                total_cells += 1
            
            # Analyze data type
            data_type = self._detect_column_type(col_data)
            
            # Calculate column quality
            quality = (len(col_data) / (len(col_data) + col_empty)) if (len(col_data) + col_empty) > 0 else 0
            
            analysis[header] = {
                'type': data_type,
                'sample_values': col_data[:3],
                'unique_values': len(set(col_data)),
                'empty_count': col_empty,
                'quality': quality
            }
        
        # Overall quality score
        analysis['quality_score'] = (total_cells - empty_cells) / total_cells if total_cells > 0 else 0
        analysis['empty_cells'] = empty_cells
        
        return analysis
    
    def _detect_column_type(self, values: List[str]) -> str:
        """Detect column data type"""
        if not values:
            return 'empty'
        
        # Count type patterns
        numeric_count = 0
        date_count = 0
        boolean_count = 0
        
        for value in values[:10]:  # Sample first 10 values
            value = value.strip()
            
            # Check numeric
            try:
                float(value.replace(',', ''))
                numeric_count += 1
                continue
            except ValueError:
                pass
            
            # Check boolean
            if value.lower() in ['true', 'false', 'yes', 'no', '1', '0', 'y', 'n']:
                boolean_count += 1
                continue
            
            # Check date patterns (simple)
            if any(char in value for char in ['/', '-']) and any(char.isdigit() for char in value):
                if len(value.split('/')) == 3 or len(value.split('-')) == 3:
                    date_count += 1
                    continue
        
        # Determine type based on majority
        total = len(values[:10])
        if numeric_count / total > 0.7:
            return 'numeric'
        elif date_count / total > 0.7:
            return 'date'
        elif boolean_count / total > 0.7:
            return 'boolean'
        else:
            return 'text'
    
    def _csv_to_text(self, headers: List[str], rows: List[List[str]], analysis: Dict[str, Any]) -> str:
        """Convert CSV data to searchable text format"""
        
        if not headers or not rows:
            return ""
        
        text_parts = []
        
        # Add headers as description
        text_parts.append(f"Dataset with {len(rows)} records and {len(headers)} fields:")
        text_parts.append("Fields: " + ", ".join(headers))
        text_parts.append("")
        
        # Add column descriptions
        for header in headers:
            col_info = analysis.get(header, {})
            data_type = col_info.get('type', 'text')
            unique_count = col_info.get('unique_values', 0)
            
            description = f"{header} ({data_type})"
            if unique_count > 0:
                description += f" - {unique_count} unique values"
            
            sample_values = col_info.get('sample_values', [])
            if sample_values:
                description += f" - Examples: {', '.join(sample_values)}"
            
            text_parts.append(description)
        
        text_parts.append("")
        text_parts.append("Sample data:")
        
        # Add sample rows in readable format
        for i, row in enumerate(rows[:10]):  # First 10 rows
            row_text = []
            for j, cell in enumerate(row):
                if j < len(headers):
                    row_text.append(f"{headers[j]}: {cell}")
            
            text_parts.append(f"Record {i+1}: " + "; ".join(row_text))
        
        if len(rows) > 10:
            text_parts.append(f"... and {len(rows) - 10} more records")
        
        return "\n".join(text_parts)
    
    async def validate_source(self, source: str) -> bool:
        """Validate if source can be processed"""
        try:
            if Path(source).exists():
                file_path = Path(source)
                return file_path.suffix.lower() in self.supported_extensions
            else:
                # Check if it looks like CSV content
                lines = source.split('\n')[:3]
                for line in lines:
                    if ',' in line or ';' in line or '\t' in line:
                        return True
                return False
        except Exception:
            return False
    
    async def get_metadata_preview(self, source: str) -> Dict[str, Any]:
        """Get metadata without full content extraction"""
        try:
            if Path(source).exists():
                file_path = Path(source)
                stat = file_path.stat()
                
                # Quick line count
                with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                    line_count = sum(1 for line in f)
                
                return {
                    'file_name': file_path.name,
                    'file_size': stat.st_size,
                    'file_extension': file_path.suffix.lower(),
                    'modified_at': datetime.fromtimestamp(stat.st_mtime),
                    'estimated_rows': max(0, line_count - 1),  # Subtract header
                    'processor': 'CSVProcessor'
                }
            else:
                lines = source.split('\n')
                return {
                    'content_length': len(source),
                    'estimated_rows': len([l for l in lines if l.strip()]),
                    'processor': 'CSVProcessor'
                }
        except Exception as e:
            logger.error(f"Error getting metadata preview: {e}")
            return {'error': str(e)}
    
    async def health_check(self) -> Dict[str, Any]:
        """Perform health check"""
        return {
            'status': 'healthy',
            'processor': 'CSVProcessor',
            'supported_extensions': self.supported_extensions,
            'supported_mimetypes': self.supported_mimetypes,
            'features': [
                'delimiter_detection',
                'data_type_analysis',
                'structure_extraction',
                'quality_assessment',
                'text_conversion',
                'metadata_enrichment'
            ]
        }