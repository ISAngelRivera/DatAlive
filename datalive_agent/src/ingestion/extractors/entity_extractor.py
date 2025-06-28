"""
Entity extraction for knowledge graph population
Uses NLP techniques to identify and classify entities from text
"""

import logging
import re
from typing import Dict, Any, List, Optional, Set
from datetime import datetime
import hashlib

try:
    import spacy
    from spacy import displacy
except ImportError:
    spacy = None

from pydantic import BaseModel

logger = logging.getLogger(__name__)


class Entity(BaseModel):
    """Entity model"""
    id: str
    name: str
    type: str
    aliases: List[str] = []
    properties: Dict[str, Any] = {}
    confidence: float = 0.0
    source_span: Optional[str] = None
    document_context: Optional[str] = None


class EntityExtractor:
    """
    Entity extractor for knowledge graph
    Extracts entities like organizations, people, technologies, etc.
    """
    
    def __init__(self, model_name: str = "en_core_web_sm"):
        self.model_name = model_name
        self.nlp = None
        
        # Entity type mappings from spaCy to our schema
        self.entity_type_mapping = {
            'PERSON': 'Person',
            'ORG': 'Organization',
            'GPE': 'Location',  # Geopolitical entity
            'LOC': 'Location',
            'PRODUCT': 'Technology',
            'EVENT': 'Event',
            'WORK_OF_ART': 'Document',
            'LAW': 'Document',
            'LANGUAGE': 'Technology',
            'DATE': 'TemporalEntity',
            'TIME': 'TemporalEntity',
            'PERCENT': 'Metric',
            'MONEY': 'Metric',
            'QUANTITY': 'Metric',
            'ORDINAL': 'Metric',
            'CARDINAL': 'Metric'
        }
        
        # Technology-related patterns
        self.tech_patterns = [
            r'\b(?:API|SDK|CLI|GUI|UI|UX)\b',
            r'\b(?:Python|Java|JavaScript|TypeScript|Go|Rust|C\+\+|C#)\b',
            r'\b(?:Docker|Kubernetes|AWS|Azure|GCP|Google Cloud)\b',
            r'\b(?:React|Vue|Angular|Django|Flask|Spring|Node\.js)\b',
            r'\b(?:PostgreSQL|MySQL|MongoDB|Redis|Neo4j|Elasticsearch)\b',
            r'\b(?:Git|GitHub|GitLab|Jenkins|CI/CD|DevOps)\b',
            r'\b(?:REST|GraphQL|gRPC|WebSocket|HTTP|HTTPS|SSL/TLS)\b',
            r'\b(?:JSON|XML|YAML|CSV|PDF|HTML|CSS)\b'
        ]
        
        # Business entity patterns
        self.business_patterns = [
            r'\b(?:Inc\.|Corp\.|LLC|Ltd\.|Limited|Company|Co\.)\b',
            r'\b(?:Department|Division|Team|Group|Unit)\b',
            r'\b(?:Project|Initiative|Program|Campaign)\b',
            r'\b(?:Process|Workflow|Procedure|Protocol)\b'
        ]
        
        self._load_model()
    
    def _load_model(self):
        """Load spaCy model"""
        if not spacy:
            logger.warning("spaCy not installed. Using pattern-based entity extraction.")
            return
        
        try:
            self.nlp = spacy.load(self.model_name)
            logger.info(f"Loaded spaCy model: {self.model_name}")
        except OSError:
            logger.warning(f"spaCy model {self.model_name} not found. Using pattern-based extraction.")
            self.nlp = None
    
    async def extract(
        self,
        text: str,
        metadata: Optional[Dict[str, Any]] = None
    ) -> List[Dict[str, Any]]:
        """
        Extract entities from text
        
        Args:
            text: Text content to analyze
            metadata: Document metadata for context
        
        Returns:
            List of extracted entities
        """
        if not text or not text.strip():
            return []
        
        entities = []
        
        # Use spaCy if available
        if self.nlp:
            entities.extend(await self._extract_with_spacy(text, metadata))
        
        # Always use pattern-based extraction for domain-specific entities
        entities.extend(await self._extract_with_patterns(text, metadata))
        
        # Deduplicate and enhance entities
        entities = await self._deduplicate_entities(entities)
        entities = await self._enhance_entities(entities, text, metadata)
        
        logger.debug(f"Extracted {len(entities)} entities from text")
        return [entity.dict() for entity in entities]
    
    async def _extract_with_spacy(
        self,
        text: str,
        metadata: Optional[Dict[str, Any]] = None
    ) -> List[Entity]:
        """Extract entities using spaCy NER"""
        entities = []
        
        try:
            # Process text with spaCy
            doc = self.nlp(text[:1000000])  # Limit text size for performance
            
            for ent in doc.ents:
                # Map spaCy entity type to our schema
                entity_type = self.entity_type_mapping.get(ent.label_, 'Unknown')
                
                # Skip very short entities
                if len(ent.text.strip()) < 2:
                    continue
                
                # Create entity
                entity = Entity(
                    id=self._generate_entity_id(ent.text, entity_type),
                    name=ent.text.strip(),
                    type=entity_type,
                    confidence=0.8,  # Base confidence for spaCy
                    source_span=ent.text,
                    properties={
                        'spacy_label': ent.label_,
                        'start_char': ent.start_char,
                        'end_char': ent.end_char,
                        'extraction_method': 'spacy'
                    }
                )
                
                entities.append(entity)
        
        except Exception as e:
            logger.error(f"Error in spaCy entity extraction: {e}")
        
        return entities
    
    async def _extract_with_patterns(
        self,
        text: str,
        metadata: Optional[Dict[str, Any]] = None
    ) -> List[Entity]:
        """Extract entities using regex patterns"""
        entities = []
        
        # Extract technology entities
        for pattern in self.tech_patterns:
            matches = re.finditer(pattern, text, re.IGNORECASE)
            for match in matches:
                entity_name = match.group().strip()
                if len(entity_name) > 1:
                    entity = Entity(
                        id=self._generate_entity_id(entity_name, 'Technology'),
                        name=entity_name,
                        type='Technology',
                        confidence=0.7,
                        source_span=entity_name,
                        properties={
                            'pattern_type': 'technology',
                            'extraction_method': 'pattern'
                        }
                    )
                    entities.append(entity)
        
        # Extract business entities
        for pattern in self.business_patterns:
            matches = re.finditer(pattern, text, re.IGNORECASE)
            for match in matches:
                entity_name = match.group().strip()
                if len(entity_name) > 1:
                    entity_type = self._classify_business_entity(entity_name)
                    entity = Entity(
                        id=self._generate_entity_id(entity_name, entity_type),
                        name=entity_name,
                        type=entity_type,
                        confidence=0.6,
                        source_span=entity_name,
                        properties={
                            'pattern_type': 'business',
                            'extraction_method': 'pattern'
                        }
                    )
                    entities.append(entity)
        
        # Extract email addresses
        email_pattern = r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b'
        email_matches = re.finditer(email_pattern, text)
        for match in email_matches:
            email = match.group()
            entity = Entity(
                id=self._generate_entity_id(email, 'Contact'),
                name=email,
                type='Contact',
                confidence=0.9,
                source_span=email,
                properties={
                    'contact_type': 'email',
                    'extraction_method': 'pattern'
                }
            )
            entities.append(entity)
        
        # Extract URLs
        url_pattern = r'https?://[^\s<>"{}|\\^`\[\]]+'
        url_matches = re.finditer(url_pattern, text)
        for match in url_matches:
            url = match.group()
            entity = Entity(
                id=self._generate_entity_id(url, 'Resource'),
                name=url,
                type='Resource',
                confidence=0.9,
                source_span=url,
                properties={
                    'resource_type': 'url',
                    'extraction_method': 'pattern'
                }
            )
            entities.append(entity)
        
        # Extract version numbers
        version_pattern = r'\bv?\d+\.\d+(?:\.\d+)?(?:-[\w\d]+)?\b'
        version_matches = re.finditer(version_pattern, text, re.IGNORECASE)
        for match in version_matches:
            version = match.group()
            entity = Entity(
                id=self._generate_entity_id(version, 'Version'),
                name=version,
                type='Version',
                confidence=0.8,
                source_span=version,
                properties={
                    'extraction_method': 'pattern'
                }
            )
            entities.append(entity)
        
        return entities
    
    def _classify_business_entity(self, text: str) -> str:
        """Classify business entity type"""
        text_lower = text.lower()
        
        if any(word in text_lower for word in ['inc', 'corp', 'llc', 'ltd', 'company']):
            return 'Organization'
        elif any(word in text_lower for word in ['department', 'division', 'team', 'group']):
            return 'OrganizationalUnit'
        elif any(word in text_lower for word in ['project', 'initiative', 'program']):
            return 'Project'
        elif any(word in text_lower for word in ['process', 'workflow', 'procedure']):
            return 'Process'
        else:
            return 'BusinessEntity'
    
    async def _deduplicate_entities(self, entities: List[Entity]) -> List[Entity]:
        """Remove duplicate entities"""
        seen = set()
        deduplicated = []
        
        for entity in entities:
            # Create a key for deduplication
            key = (entity.name.lower(), entity.type)
            
            if key not in seen:
                seen.add(key)
                deduplicated.append(entity)
            else:
                # Find existing entity and merge if confidence is higher
                for existing in deduplicated:
                    if (existing.name.lower() == entity.name.lower() and 
                        existing.type == entity.type):
                        if entity.confidence > existing.confidence:
                            existing.confidence = entity.confidence
                            existing.properties.update(entity.properties)
                        break
        
        return deduplicated
    
    async def _enhance_entities(
        self,
        entities: List[Entity],
        text: str,
        metadata: Optional[Dict[str, Any]] = None
    ) -> List[Entity]:
        """Enhance entities with additional information"""
        for entity in entities:
            # Add document context
            entity.document_context = self._get_entity_context(entity, text)
            
            # Add metadata from document
            if metadata:
                entity.properties['document_source'] = metadata.get('source_type')
                entity.properties['document_title'] = metadata.get('title')
                
                # Boost confidence for entities in title
                if metadata.get('title') and entity.name.lower() in metadata['title'].lower():
                    entity.confidence = min(1.0, entity.confidence + 0.2)
            
            # Generate aliases
            entity.aliases = self._generate_aliases(entity.name, entity.type)
            
            # Add temporal information
            entity.properties['extracted_at'] = datetime.now().isoformat()
        
        return entities
    
    def _get_entity_context(self, entity: Entity, text: str, window: int = 50) -> str:
        """Get surrounding context for entity"""
        try:
            # Find entity in text
            start = text.lower().find(entity.name.lower())
            if start == -1:
                return ""
            
            # Get context window
            context_start = max(0, start - window)
            context_end = min(len(text), start + len(entity.name) + window)
            
            context = text[context_start:context_end].strip()
            return context
        except Exception:
            return ""
    
    def _generate_aliases(self, name: str, entity_type: str) -> List[str]:
        """Generate aliases for entity"""
        aliases = []
        
        # Common abbreviations
        if entity_type == 'Technology':
            # Add common tech abbreviations
            tech_abbrevs = {
                'JavaScript': ['JS'],
                'TypeScript': ['TS'],
                'Python': ['Py'],
                'PostgreSQL': ['Postgres'],
                'Kubernetes': ['K8s'],
                'Application Programming Interface': ['API'],
                'Software Development Kit': ['SDK'],
                'Command Line Interface': ['CLI']
            }
            aliases.extend(tech_abbrevs.get(name, []))
        
        # Add variations
        if ' ' in name:
            # Remove spaces
            aliases.append(name.replace(' ', ''))
            # Add acronym
            words = name.split()
            if len(words) > 1:
                acronym = ''.join(word[0].upper() for word in words if word)
                if len(acronym) > 1:
                    aliases.append(acronym)
        
        return list(set(aliases))  # Remove duplicates
    
    def _generate_entity_id(self, name: str, entity_type: str) -> str:
        """Generate unique entity ID"""
        # Create hash of name and type
        content = f"{name.lower().strip()}:{entity_type}"
        hash_digest = hashlib.md5(content.encode()).hexdigest()[:12]
        return f"{entity_type.lower()}_{hash_digest}"
    
    def get_supported_entity_types(self) -> List[str]:
        """Get list of supported entity types"""
        return [
            'Person',
            'Organization',
            'OrganizationalUnit',
            'Technology',
            'Project',
            'Process',
            'Location',
            'Document',
            'Contact',
            'Resource',
            'Version',
            'Event',
            'TemporalEntity',
            'Metric',
            'BusinessEntity'
        ]
    
    async def health_check(self) -> Dict[str, Any]:
        """Perform health check"""
        return {
            'status': 'healthy',
            'spacy_available': self.nlp is not None,
            'model_name': self.model_name if self.nlp else None,
            'supported_types': len(self.get_supported_entity_types()),
            'extraction_methods': ['spacy', 'pattern'] if self.nlp else ['pattern']
        }