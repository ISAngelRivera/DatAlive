"""
Relationship extraction for knowledge graph population
Identifies relationships between entities in text
"""

import logging
import re
from typing import Dict, Any, List, Optional, Tuple
from datetime import datetime
import hashlib

try:
    import spacy
    from spacy.matcher import Matcher, DependencyMatcher
except ImportError:
    spacy = None
    Matcher = None
    DependencyMatcher = None

from pydantic import BaseModel

# Import LLM client for advanced relationship extraction
from ...core.llm import get_llm_model

logger = logging.getLogger(__name__)


class Relationship(BaseModel):
    """Relationship model"""
    id: str
    source_id: str
    target_id: str
    type: str
    properties: Dict[str, Any] = {}
    confidence: float = 0.0
    source_span: Optional[str] = None
    context: Optional[str] = None


class RelationshipExtractor:
    """
    Relationship extractor for knowledge graph
    Identifies relationships between entities using linguistic patterns
    """
    
    def __init__(self, model_name: str = "en_core_web_sm"):
        self.model_name = model_name
        self.nlp = None
        self.matcher = None
        self.dep_matcher = None
        self.llm_model = None
        
        # Relationship patterns
        self.relationship_patterns = {
            'WORKS_FOR': [
                r'\b(?:works?\s+(?:for|at)|employed\s+(?:by|at)|employee\s+of)\b',
                r'\b(?:CEO|CTO|CFO|VP|Director|Manager)\s+(?:of|at)\b',
                r'\b(?:team\s+member|staff\s+member|part\s+of)\b'
            ],
            'OWNS': [
                r'\b(?:owns?|owned\s+by|belongs\s+to|property\s+of)\b',
                r'\b(?:subsidiary|division|branch)\s+of\b',
                r'\b(?:acquired\s+by|purchased\s+by|bought\s+by)\b'
            ],
            'PARTNERSHIP': [
                r'\b(?:partners?\s+with|partnership\s+with|collaborates?\s+with)\b',
                r'\b(?:joint\s+venture|alliance\s+with|cooperation\s+with)\b',
                r'\b(?:integration\s+with|compatible\s+with)\b'
            ],
            'USES': [
                r'\b(?:uses?|utilizing|implements?|deploys?)\b',
                r'\b(?:built\s+with|powered\s+by|based\s+on)\b',
                r'\b(?:runs?\s+on|hosted\s+on|supported\s+by)\b'
            ],
            'LOCATED_AT': [
                r'\b(?:located\s+(?:in|at)|based\s+(?:in|at)|situated\s+in)\b',
                r'\b(?:headquarters\s+in|office\s+in|facility\s+in)\b',
                r'\b(?:operates\s+in|present\s+in|available\s+in)\b'
            ],
            'RELATED_TO': [
                r'\b(?:related\s+to|associated\s+with|connected\s+to)\b',
                r'\b(?:similar\s+to|comparable\s+to|like)\b',
                r'\b(?:part\s+of|component\s+of|element\s+of)\b'
            ],
            'PREDECESSOR': [
                r'\b(?:replaced\s+by|succeeded\s+by|followed\s+by)\b',
                r'\b(?:upgrade\s+from|migration\s+from|evolution\s+of)\b'
            ],
            'DEPENDS_ON': [
                r'\b(?:depends\s+on|requires?|needs?)\b',
                r'\b(?:prerequisite|dependency|requirement)\b'
            ],
            'MANAGES': [
                r'\b(?:manages?|oversees?|supervises?|leads?)\b',
                r'\b(?:responsible\s+for|in\s+charge\s+of)\b'
            ],
            'CREATES': [
                r'\b(?:creates?|develops?|builds?|designs?|produces?)\b',
                r'\b(?:authors?|writes?|implements?)\b'
            ]
        }
        
        self._load_model()
        self._setup_matchers()
        self._initialize_llm()
    
    def _load_model(self):
        """Load spaCy model"""
        if not spacy:
            logger.warning("spaCy not installed. Using pattern-based relationship extraction.")
            return
        
        try:
            self.nlp = spacy.load(self.model_name)
            logger.info(f"Loaded spaCy model for relationships: {self.model_name}")
        except OSError:
            logger.warning(f"spaCy model {self.model_name} not found. Using pattern-based extraction.")
            self.nlp = None
    
    def _setup_matchers(self):
        """Setup spaCy matchers for relationship patterns"""
        if not self.nlp or not Matcher:
            return
        
        try:
            self.matcher = Matcher(self.nlp.vocab)
            self.dep_matcher = DependencyMatcher(self.nlp.vocab)
            
            # Add patterns for relationship detection
            for rel_type, patterns in self.relationship_patterns.items():
                for i, pattern in enumerate(patterns):
                    # Simple token matching for now
                    pattern_name = f"{rel_type}_{i}"
                    # Note: This is a simplified pattern setup
                    # In practice, you'd convert regex patterns to spaCy token patterns
        
        except Exception as e:
            logger.warning(f"Error setting up spaCy matchers: {e}")
            self.matcher = None
            self.dep_matcher = None
    
    def _initialize_llm(self):
        """Initialize LLM model for advanced relationship extraction"""
        try:
            self.llm_model = get_llm_model()
            logger.info("LLM model initialized for relationship extraction")
        except Exception as e:
            logger.warning(f"Failed to initialize LLM model: {e}")
            self.llm_model = None
    
    async def extract(
        self,
        text: str,
        entities: List[Dict[str, Any]],
        metadata: Optional[Dict[str, Any]] = None
    ) -> List[Dict[str, Any]]:
        """
        Extract relationships from text given a list of entities
        
        Args:
            text: Text content to analyze
            entities: List of entities found in the text
            metadata: Document metadata for context
        
        Returns:
            List of extracted relationships
        """
        if not text or not entities:
            return []
        
        relationships = []
        
        # Extract using linguistic patterns
        relationships.extend(await self._extract_with_patterns(text, entities, metadata))
        
        # Extract using spaCy if available
        if self.nlp:
            relationships.extend(await self._extract_with_spacy(text, entities, metadata))
        
        # Extract based on proximity and co-occurrence
        relationships.extend(await self._extract_proximity_relationships(text, entities, metadata))
        
        # Extract using LLM for advanced semantic understanding
        if self.llm_model:
            relationships.extend(await self._extract_with_llm(text, entities, metadata))
        
        # Deduplicate relationships
        relationships = await self._deduplicate_relationships(relationships)
        
        logger.debug(f"Extracted {len(relationships)} relationships from text")
        return [rel.dict() for rel in relationships]
    
    async def _extract_with_patterns(
        self,
        text: str,
        entities: List[Dict[str, Any]],
        metadata: Optional[Dict[str, Any]] = None
    ) -> List[Relationship]:
        """Extract relationships using regex patterns"""
        relationships = []
        
        # Create entity lookup by position
        entity_positions = []
        for entity in entities:
            name = entity['name']
            # Find all occurrences of entity in text
            start = 0
            while True:
                pos = text.lower().find(name.lower(), start)
                if pos == -1:
                    break
                entity_positions.append({
                    'entity': entity,
                    'start': pos,
                    'end': pos + len(name),
                    'name': name
                })
                start = pos + 1
        
        # Sort by position
        entity_positions.sort(key=lambda x: x['start'])
        
        # Look for relationship patterns between nearby entities
        for rel_type, patterns in self.relationship_patterns.items():
            for pattern in patterns:
                matches = list(re.finditer(pattern, text, re.IGNORECASE))
                
                for match in matches:
                    pattern_start = match.start()
                    pattern_end = match.end()
                    
                    # Find entities before and after the pattern
                    before_entities = [
                        ep for ep in entity_positions 
                        if ep['end'] <= pattern_start and pattern_start - ep['end'] <= 100
                    ]
                    after_entities = [
                        ep for ep in entity_positions 
                        if ep['start'] >= pattern_end and ep['start'] - pattern_end <= 100
                    ]
                    
                    # Create relationships
                    for before_ent in before_entities[-2:]:  # Last 2 entities before pattern
                        for after_ent in after_entities[:2]:  # First 2 entities after pattern
                            if before_ent['entity']['id'] != after_ent['entity']['id']:
                                relationship = Relationship(
                                    id=self._generate_relationship_id(
                                        before_ent['entity']['id'],
                                        after_ent['entity']['id'],
                                        rel_type
                                    ),
                                    source_id=before_ent['entity']['id'],
                                    target_id=after_ent['entity']['id'],
                                    type=rel_type,
                                    confidence=0.7,
                                    source_span=match.group(),
                                    context=self._get_relationship_context(
                                        text, pattern_start, pattern_end
                                    ),
                                    properties={
                                        'extraction_method': 'pattern',
                                        'pattern': pattern,
                                        'pattern_position': pattern_start
                                    }
                                )
                                relationships.append(relationship)
        
        return relationships
    
    async def _extract_with_spacy(
        self,
        text: str,
        entities: List[Dict[str, Any]],
        metadata: Optional[Dict[str, Any]] = None
    ) -> List[Relationship]:
        """Extract relationships using spaCy dependency parsing"""
        relationships = []
        
        if not self.nlp:
            return relationships
        
        try:
            # Process text with spaCy
            doc = self.nlp(text[:500000])  # Limit for performance
            
            # Create entity mapping
            entity_map = {}
            for entity in entities:
                for token in doc:
                    if entity['name'].lower() in token.text.lower():
                        entity_map[token.i] = entity
            
            # Analyze dependencies to find relationships
            for token in doc:
                if token.i in entity_map:
                    source_entity = entity_map[token.i]
                    
                    # Look at dependency relationships
                    for child in token.children:
                        if child.i in entity_map:
                            target_entity = entity_map[child.i]
                            
                            # Determine relationship type based on dependency
                            rel_type = self._classify_dependency_relationship(
                                token, child, doc
                            )
                            
                            if rel_type:
                                relationship = Relationship(
                                    id=self._generate_relationship_id(
                                        source_entity['id'],
                                        target_entity['id'],
                                        rel_type
                                    ),
                                    source_id=source_entity['id'],
                                    target_id=target_entity['id'],
                                    type=rel_type,
                                    confidence=0.6,
                                    properties={
                                        'extraction_method': 'spacy_dependency',
                                        'dependency': child.dep_,
                                        'pos_tags': f"{token.pos_}:{child.pos_}"
                                    }
                                )
                                relationships.append(relationship)
        
        except Exception as e:
            logger.error(f"Error in spaCy relationship extraction: {e}")
        
        return relationships
    
    async def _extract_proximity_relationships(
        self,
        text: str,
        entities: List[Dict[str, Any]],
        metadata: Optional[Dict[str, Any]] = None
    ) -> List[Relationship]:
        """Extract relationships based on entity proximity and co-occurrence"""
        relationships = []
        
        # Find entity positions in text
        entity_positions = []
        for entity in entities:
            name = entity['name']
            start = 0
            while True:
                pos = text.lower().find(name.lower(), start)
                if pos == -1:
                    break
                entity_positions.append({
                    'entity': entity,
                    'position': pos,
                    'name': name
                })
                start = pos + 1
        
        # Sort by position
        entity_positions.sort(key=lambda x: x['position'])
        
        # Find nearby entities and create weak relationships
        for i, ent1_pos in enumerate(entity_positions):
            for j, ent2_pos in enumerate(entity_positions[i+1:], i+1):
                distance = ent2_pos['position'] - ent1_pos['position']
                
                # Only consider entities within reasonable distance
                if distance > 200:  # More than 200 characters apart
                    break
                
                ent1 = ent1_pos['entity']
                ent2 = ent2_pos['entity']
                
                # Don't create relationships between same entity
                if ent1['id'] == ent2['id']:
                    continue
                
                # Determine relationship type based on entity types
                rel_type = self._infer_relationship_from_types(
                    ent1['type'], ent2['type'], distance
                )
                
                if rel_type:
                    confidence = max(0.3, 0.7 - (distance / 200) * 0.4)  # Decay with distance
                    
                    relationship = Relationship(
                        id=self._generate_relationship_id(ent1['id'], ent2['id'], rel_type),
                        source_id=ent1['id'],
                        target_id=ent2['id'],
                        type=rel_type,
                        confidence=confidence,
                        context=self._get_relationship_context(
                            text, ent1_pos['position'], ent2_pos['position']
                        ),
                        properties={
                            'extraction_method': 'proximity',
                            'distance': distance,
                            'co_occurrence': True
                        }
                    )
                    relationships.append(relationship)
        
        return relationships
    
    async def _extract_with_llm(
        self,
        text: str,
        entities: List[Dict[str, Any]],
        metadata: Optional[Dict[str, Any]] = None
    ) -> List[Relationship]:
        """Extract relationships using LLM for advanced semantic understanding"""
        relationships = []
        
        if not self.llm_model or len(entities) < 2:
            return relationships
        
        try:
            # Limit text size for LLM processing
            text_chunk = text[:4000]  # Keep to manageable size
            
            # Create entity list for LLM prompt
            entity_list = []
            for entity in entities[:20]:  # Limit to first 20 entities
                entity_list.append(f"- {entity['name']} ({entity['type']})")
            
            entity_str = "\n".join(entity_list)
            
            # Prepare prompt for relationship extraction
            prompt = f"""Analyze the following text and identify relationships between the given entities.

Text:
{text_chunk}

Entities:
{entity_str}

Instructions:
1. Find relationships between these entities in the text
2. Return ONLY valid relationships that are explicitly mentioned or strongly implied
3. Use these relationship types: {', '.join(self.get_supported_relationship_types())}
4. Format each relationship as: SOURCE_ENTITY | RELATIONSHIP_TYPE | TARGET_ENTITY | CONFIDENCE_SCORE (0.0-1.0)

Example format:
Apple Inc | OWNS | iPhone | 0.9
John Smith | WORKS_FOR | Microsoft | 0.8

Relationships:"""
            
            # Call LLM using pydantic_ai
            from pydantic_ai import Agent
            
            agent = Agent(self.llm_model)
            result = await agent.run(prompt)
            response = result.data if hasattr(result, 'data') else str(result)
            
            if response and response.strip():
                # Parse LLM response into relationships
                relationships.extend(
                    await self._parse_llm_relationships(response, entities)
                )
                
        except Exception as e:
            logger.error(f"Error in LLM relationship extraction: {e}")
        
        return relationships
    
    async def _parse_llm_relationships(
        self,
        llm_response: str,
        entities: List[Dict[str, Any]]
    ) -> List[Relationship]:
        """Parse LLM response into Relationship objects"""
        relationships = []
        
        # Create entity lookup for quick access
        entity_lookup = {}
        for entity in entities:
            entity_lookup[entity['name'].lower()] = entity
            # Also add aliases
            for alias in entity.get('aliases', []):
                entity_lookup[alias.lower()] = entity
        
        lines = llm_response.strip().split('\n')
        
        for line in lines:
            line = line.strip()
            if not line or '|' not in line:
                continue
            
            try:
                parts = [part.strip() for part in line.split('|')]
                if len(parts) < 3:
                    continue
                
                source_name = parts[0]
                rel_type = parts[1].upper()
                target_name = parts[2]
                confidence = float(parts[3]) if len(parts) > 3 else 0.8
                
                # Find entities in our entity list
                source_entity = entity_lookup.get(source_name.lower())
                target_entity = entity_lookup.get(target_name.lower())
                
                if source_entity and target_entity and source_entity['id'] != target_entity['id']:
                    # Validate relationship type
                    if rel_type in self.get_supported_relationship_types():
                        relationship = Relationship(
                            id=self._generate_relationship_id(
                                source_entity['id'],
                                target_entity['id'],
                                rel_type
                            ),
                            source_id=source_entity['id'],
                            target_id=target_entity['id'],
                            type=rel_type,
                            confidence=min(0.95, max(0.5, confidence)),  # Clamp confidence
                            properties={
                                'extraction_method': 'llm',
                                'source_name': source_name,
                                'target_name': target_name,
                                'llm_confidence': confidence
                            }
                        )
                        relationships.append(relationship)
                        
            except (ValueError, IndexError) as e:
                logger.debug(f"Failed to parse LLM relationship line '{line}': {e}")
                continue
        
        logger.info(f"Parsed {len(relationships)} relationships from LLM response")
        return relationships
    
    def _classify_dependency_relationship(self, token1, token2, doc) -> Optional[str]:
        """Classify relationship based on dependency parsing"""
        dep = token2.dep_.lower()
        
        # Map dependencies to relationship types
        dep_mappings = {
            'nsubj': 'PERFORMS',  # Nominal subject
            'dobj': 'ACTS_ON',    # Direct object
            'pobj': 'RELATED_TO', # Object of preposition
            'compound': 'PART_OF', # Compound
            'appos': 'ALIAS_OF',  # Appositional modifier
            'conj': 'RELATED_TO', # Conjunct
            'prep': 'LOCATED_AT'  # Prepositional modifier
        }
        
        return dep_mappings.get(dep)
    
    def _infer_relationship_from_types(
        self,
        type1: str,
        type2: str,
        distance: int
    ) -> Optional[str]:
        """Infer relationship type from entity types"""
        
        # Define type-based relationship rules
        type_rules = {
            ('Person', 'Organization'): 'WORKS_FOR',
            ('Organization', 'Technology'): 'USES',
            ('Technology', 'Technology'): 'INTEGRATES_WITH',
            ('Person', 'Project'): 'WORKS_ON',
            ('Organization', 'Location'): 'LOCATED_AT',
            ('Project', 'Technology'): 'USES',
            ('Person', 'Person'): 'COLLABORATES_WITH',
            ('Organization', 'Organization'): 'PARTNERSHIP',
            ('Technology', 'Version'): 'HAS_VERSION'
        }
        
        # Check both directions
        key1 = (type1, type2)
        key2 = (type2, type1)
        
        if key1 in type_rules:
            return type_rules[key1]
        elif key2 in type_rules:
            return type_rules[key2]
        
        # Default weak relationship for any co-occurring entities
        if distance < 50:  # Very close entities
            return 'RELATED_TO'
        
        return None
    
    def _get_relationship_context(
        self,
        text: str,
        start_pos: int,
        end_pos: int,
        window: int = 100
    ) -> str:
        """Get context around relationship"""
        try:
            context_start = max(0, min(start_pos, end_pos) - window)
            context_end = min(len(text), max(start_pos, end_pos) + window)
            
            context = text[context_start:context_end].strip()
            return context
        except Exception:
            return ""
    
    async def _deduplicate_relationships(self, relationships: List[Relationship]) -> List[Relationship]:
        """Remove duplicate relationships"""
        seen = set()
        deduplicated = []
        
        for rel in relationships:
            # Create key for deduplication (consider both directions)
            key1 = (rel.source_id, rel.target_id, rel.type)
            key2 = (rel.target_id, rel.source_id, rel.type)
            
            if key1 not in seen and key2 not in seen:
                seen.add(key1)
                deduplicated.append(rel)
            else:
                # Find existing relationship and merge if confidence is higher
                for existing in deduplicated:
                    if ((existing.source_id == rel.source_id and existing.target_id == rel.target_id) or
                        (existing.source_id == rel.target_id and existing.target_id == rel.source_id)) and \
                       existing.type == rel.type:
                        if rel.confidence > existing.confidence:
                            existing.confidence = rel.confidence
                            existing.properties.update(rel.properties)
                        break
        
        return deduplicated
    
    def _generate_relationship_id(self, source_id: str, target_id: str, rel_type: str) -> str:
        """Generate unique relationship ID"""
        # Sort IDs to ensure consistent ordering
        ids = sorted([source_id, target_id])
        content = f"{ids[0]}:{ids[1]}:{rel_type}"
        hash_digest = hashlib.md5(content.encode()).hexdigest()[:12]
        return f"rel_{hash_digest}"
    
    def get_supported_relationship_types(self) -> List[str]:
        """Get list of supported relationship types"""
        return list(self.relationship_patterns.keys()) + [
            'PERFORMS',
            'ACTS_ON',
            'PART_OF',
            'ALIAS_OF',
            'INTEGRATES_WITH',
            'WORKS_ON',
            'COLLABORATES_WITH',
            'HAS_VERSION'
        ]
    
    async def health_check(self) -> Dict[str, Any]:
        """Perform health check"""
        extraction_methods = ['pattern', 'proximity']
        if self.nlp:
            extraction_methods.append('spacy')
        if self.llm_model:
            extraction_methods.append('llm')
            
        return {
            'status': 'healthy',
            'spacy_available': self.nlp is not None,
            'llm_available': self.llm_model is not None,
            'model_name': self.model_name if self.nlp else None,
            'pattern_count': sum(len(patterns) for patterns in self.relationship_patterns.values()),
            'supported_types': len(self.get_supported_relationship_types()),
            'extraction_methods': extraction_methods
        }