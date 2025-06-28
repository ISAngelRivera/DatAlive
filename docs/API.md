# DataLive API Documentation

## Base URL
http://localhost:8058/api/v1

## Endpoints

### Chat Endpoint
```http
POST /chat
Content-Type: application/json

{
  "message": "What projects use Neo4j?",
  "user_id": "user123",
  "context": {
    "prefer_relationships": true,
    "time_range": ["2024-01-01", "2024-12-31"]
  }
}
```

**Response:**
```json
{
  "response": "DataLive project uses Neo4j for knowledge graph...",
  "confidence": 0.92,
  "strategy_used": ["KAG", "RAG"],
  "sources": [...],
  "processing_time": 1.23,
  "cached": false
}
```

### Search Endpoints

#### Vector Search
```http
GET /search/vector?q=security+best+practices&limit=10
```

#### Knowledge Graph Search
```http
GET /search/knowledge-graph?entity=DataLive&depth=2
```

#### Temporal Search
```http
GET /search/temporal?query=project+evolution&start=2024-01-01
```

### Cache Management

#### Get Cache Stats
```http
GET /cache/stats
```

#### Invalidate Cache
```http
DELETE /cache/invalidate?pattern=security*
```

### Health & Metrics

#### Health Check
```http
GET /health
```

#### Prometheus Metrics
```http
GET /metrics
```

## Authentication

All endpoints require Basic Auth:
```
Authorization: Basic base64(username:password)
```

## Rate Limiting

- 100 requests per minute per user
- 1000 requests per hour per user

## Error Codes

- 400: Bad Request
- 401: Unauthorized
- 429: Too Many Requests
- 500: Internal Server Error