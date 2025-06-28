"""
Prometheus metrics for monitoring
"""

from prometheus_client import Counter, Histogram, Gauge, Info

# Query metrics
query_counter = Counter(
    'datalive_queries_total',
    'Total number of queries processed',
    ['status', 'strategy']
)

query_duration = Histogram(
    'datalive_query_duration_seconds',
    'Time spent processing queries',
    ['strategy'],
    buckets=[0.1, 0.5, 1.0, 2.0, 5.0, 10.0, 30.0, 60.0]
)

# Agent usage metrics
agent_usage_counter = Counter(
    'datalive_agent_usage_total',
    'Usage count per agent type',
    ['agent_type']
)

# Cache metrics
cache_hit_counter = Counter(
    'datalive_cache_hits_total',
    'Number of cache hits'
)

cache_miss_counter = Counter(
    'datalive_cache_misses_total',
    'Number of cache misses'
)

cache_hit_rate = Gauge(
    'datalive_cache_hit_rate',
    'Cache hit rate (0-1)'
)

# Knowledge Graph metrics
kg_nodes_count = Gauge(
    'datalive_kg_nodes_total',
    'Total number of nodes in knowledge graph'
)

kg_relationships_count = Gauge(
    'datalive_kg_relationships_total',
    'Total number of relationships in knowledge graph'
)

kg_query_complexity = Histogram(
    'datalive_kg_query_complexity',
    'Complexity of knowledge graph queries',
    buckets=[1, 2, 3, 5, 10, 20, 50]
)

# Vector database metrics
vector_search_duration = Histogram(
    'datalive_vector_search_duration_seconds',
    'Time spent on vector searches',
    buckets=[0.01, 0.05, 0.1, 0.5, 1.0, 2.0, 5.0]
)

vector_search_results = Histogram(
    'datalive_vector_search_results_count',
    'Number of results returned by vector search',
    buckets=[1, 5, 10, 20, 50, 100]
)

# System metrics
active_connections = Gauge(
    'datalive_active_connections',
    'Number of active database connections',
    ['database']
)

# Application info
app_info = Info(
    'datalive_app_info',
    'Application information'
)

# Initialize app info
app_info.info({
    'version': '3.0.0',
    'service': 'datalive-unified-agent'
})