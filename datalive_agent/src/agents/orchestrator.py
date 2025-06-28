"""
Orchestrator Agent that decides which strategies to use
"""

import logging
from typing import Dict, Any, List, Optional
from datetime import datetime

from pydantic import BaseModel
from pydantic_ai import Agent

from ..core.llm import get_llm_model
from ..config import settings

logger = logging.getLogger(__name__)


class QueryStrategy(BaseModel):
    """Strategy for processing a query"""
    use_rag: bool = True
    use_kag: bool = False
    use_temporal: bool = False
    use_tools: bool = False
    rag_limit: int = 10
    kg_depth: int = 2
    time_range: Optional[str] = None
    reasoning: str = ""


class OrchestratorAgent:
    """
    Orchestrator agent that analyzes queries and determines
    the optimal strategy for processing them
    """
    
    def __init__(self):
        """Initialize orchestrator agent"""
        self.agent = Agent(
            get_llm_model(),
            system_prompt=self._get_system_prompt()
        )
        
    def _get_system_prompt(self) -> str:
        """Get the system prompt for the orchestrator"""
        return """You are an intelligent query orchestrator for DataLive Enterprise RAG system.
        
Your role is to analyze user queries and determine the optimal strategy for answering them.

Available strategies:
1. RAG (Vector Search): For semantic search and general questions about documents
2. KAG (Knowledge Graph): For questions about relationships, connections, and entities
3. Temporal Analysis: For questions about time, changes, evolution, or history
4. Tools: For queries requiring external data or calculations

Decision criteria:
- Use RAG for: factual questions, document search, general information
- Use KAG for: relationship queries, entity connections, organizational structure
- Use Temporal for: timeline questions, historical changes, date-specific queries
- Use multiple strategies for: complex analytical questions

Always explain your reasoning for the chosen strategy.

Output format:
{
    "use_rag": true/false,
    "use_kag": true/false,
    "use_temporal": true/false,
    "use_tools": true/false,
    "rag_limit": 10,
    "kg_depth": 2,
    "time_range": "last_6_months",
    "reasoning": "Explanation of why this strategy was chosen"
}"""
        
    async def analyze_query(
        self,
        query: str,
        context: Optional[Dict[str, Any]] = None
    ) -> QueryStrategy:
        """
        Analyze a query and determine the optimal processing strategy
        """
        try:
            # Prepare the analysis prompt
            prompt = f"""Analyze this query and determine the optimal strategy:

Query: {query}

Context: {context or 'No additional context'}

Consider:
1. What type of information is being requested?
2. What data sources would be most relevant?
3. Is temporal information important?
4. Are entity relationships relevant?
5. Would multiple strategies improve the answer?

Provide your analysis in the specified JSON format."""

            # Get strategy from LLM
            result = await self.agent.run(prompt)
            
            # Parse the result
            strategy_dict = self._parse_strategy(result.data)
            
            # Create strategy object
            strategy = QueryStrategy(**strategy_dict)
            
            logger.info(f"Query strategy: {strategy.reasoning}")
            
            return strategy
            
        except Exception as e:
            logger.error(f"Error analyzing query: {e}")
            # Return default strategy on error
            return QueryStrategy(
                use_rag=True,
                reasoning="Default strategy due to analysis error"
            )
    
    def _parse_strategy(self, llm_output: str) -> Dict[str, Any]:
        """Parse strategy from LLM output"""
        import json
        import re
        
        try:
            # Try to extract JSON from the output
            json_match = re.search(r'\{.*\}', llm_output, re.DOTALL)
            if json_match:
                return json.loads(json_match.group())
            else:
                # Fallback parsing
                strategy = {
                    "use_rag": "rag" in llm_output.lower() or "vector" in llm_output.lower(),
                    "use_kag": "knowledge graph" in llm_output.lower() or "relationship" in llm_output.lower(),
                    "use_temporal": "temporal" in llm_output.lower() or "time" in llm_output.lower(),
                    "use_tools": "tool" in llm_output.lower() or "external" in llm_output.lower(),
                    "reasoning": llm_output[:200]
                }
                return strategy
        except Exception as e:
            logger.error(f"Error parsing strategy: {e}")
            return {
                "use_rag": True,
                "reasoning": "Parse error - using default RAG strategy"
            }
    
    async def generate_answer(
        self,
        query: str,
        context: str,
        sources: List[Dict[str, Any]]
    ) -> str:
        """
        Generate a comprehensive answer based on the collected information
        """
        try:
            # Prepare the prompt
            sources_text = self._format_sources(sources[:5])  # Limit sources
            
            prompt = f"""Based on the following context and sources, provide a comprehensive answer to the user's query.

Query: {query}

Context:
{context}

Sources:
{sources_text}

Instructions:
1. Provide a clear, accurate answer based on the available information
2. Reference specific sources when making claims
3. If information is incomplete or uncertain, acknowledge this
4. Be concise but thorough
5. Use a professional, helpful tone

Answer:"""

            # Generate answer
            result = await self.agent.run(prompt)
            
            return result.data
            
        except Exception as e:
            logger.error(f"Error generating answer: {e}")
            return "I apologize, but I encountered an error while generating the answer. Please try again."
    
    def _format_sources(self, sources: List[Dict[str, Any]]) -> str:
        """Format sources for inclusion in prompt"""
        formatted = []
        
        for i, source in enumerate(sources, 1):
            source_type = source.get('type', 'unknown')
            
            if source_type == 'document':
                formatted.append(
                    f"[{i}] Document: {source.get('title', 'Untitled')}\n"
                    f"    Score: {source.get('score', 0):.2f}\n"
                    f"    Content: {source.get('content', '')[:200]}..."
                )
            elif source_type == 'relationship':
                formatted.append(
                    f"[{i}] Relationship: {source.get('entities', [])[0]} "
                    f"--[{source.get('relationship', 'RELATES_TO')}]--> "
                    f"{source.get('entities', [])[1] if len(source.get('entities', [])) > 1 else 'Unknown'}"
                )
            elif source_type == 'temporal':
                formatted.append(
                    f"[{i}] Event ({source.get('date', 'Unknown date')}): "
                    f"{source.get('event', 'Unknown event')}"
                )
        
        return "\n".join(formatted)