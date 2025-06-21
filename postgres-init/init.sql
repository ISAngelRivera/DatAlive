-- init.sql - DataLive PostgreSQL Schema v2.0
-- Actualizado con mejores prácticas 2025

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
CREATE EXTENSION IF NOT EXISTS "btree_gin";

-- Create schemas
CREATE SCHEMA IF NOT EXISTS rag;
CREATE SCHEMA IF NOT EXISTS kag;
CREATE SCHEMA IF NOT EXISTS cag;
CREATE SCHEMA IF NOT EXISTS monitoring;

-- Set default search path
SET search_path TO rag, kag, cag, monitoring, public;

-- =====================================================
-- RAG Schema - Document and Chunk Management
-- =====================================================

-- Documents table
CREATE TABLE IF NOT EXISTS rag.documents (
    document_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    source_id VARCHAR(512) NOT NULL,
    source_type VARCHAR(50) NOT NULL CHECK (source_type IN ('gdrive', 'sharepoint', 'confluence', 'git', 'local')),
    file_name VARCHAR(512) NOT NULL,
    file_path TEXT NOT NULL,
    file_size BIGINT,
    mime_type VARCHAR(100),
    document_hash VARCHAR(64) NOT NULL,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    processed_at TIMESTAMPTZ,
    processing_status VARCHAR(50) DEFAULT 'pending' CHECK (processing_status IN ('pending', 'processing', 'completed', 'failed')),
    error_message TEXT,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE UNIQUE INDEX idx_documents_source ON rag.documents(source_id, source_type) WHERE is_deleted = FALSE;
CREATE INDEX idx_documents_hash ON rag.documents(document_hash);
CREATE INDEX idx_documents_status ON rag.documents(processing_status) WHERE is_deleted = FALSE;
CREATE INDEX idx_documents_metadata ON rag.documents USING gin(metadata);

-- Chunks table with improved structure
CREATE TABLE IF NOT EXISTS rag.chunks (
    chunk_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    document_id UUID NOT NULL REFERENCES rag.documents(document_id) ON DELETE CASCADE,
    chunk_index INTEGER NOT NULL,
    chunk_hash VARCHAR(64) NOT NULL,
    content TEXT NOT NULL,
    content_type VARCHAR(50) DEFAULT 'text' CHECK (content_type IN ('text', 'table', 'list', 'code', 'mixed')),
    chunk_metadata JSONB DEFAULT '{}',
    
    -- Vector store references
    qdrant_point_id UUID,
    qdrant_collection VARCHAR(100),
    embedding_model VARCHAR(100),
    embedding_dimension INTEGER,
    
    -- Multimodal support
    associated_media JSONB DEFAULT '[]', -- Array of {type, path, minio_object_id}
    
    -- Performance optimization
    token_count INTEGER,
    char_count INTEGER,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    is_deleted BOOLEAN DEFAULT FALSE,
    
    CONSTRAINT unique_chunk_per_doc UNIQUE(document_id, chunk_index) WHERE is_deleted = FALSE
);

CREATE INDEX idx_chunks_document ON rag.chunks(document_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_chunks_hash ON rag.chunks(chunk_hash);
CREATE INDEX idx_chunks_qdrant ON rag.chunks(qdrant_point_id) WHERE qdrant_point_id IS NOT NULL;
CREATE INDEX idx_chunks_content_search ON rag.chunks USING gin(to_tsvector('english', content));

-- Media assets table
CREATE TABLE IF NOT EXISTS rag.media_assets (
    media_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    document_id UUID NOT NULL REFERENCES rag.documents(document_id) ON DELETE CASCADE,
    chunk_id UUID REFERENCES rag.chunks(chunk_id) ON DELETE SET NULL,
    media_type VARCHAR(50) NOT NULL CHECK (media_type IN ('image', 'diagram', 'chart', 'table_image')),
    original_path TEXT NOT NULL,
    minio_bucket VARCHAR(100) NOT NULL,
    minio_object_key VARCHAR(512) NOT NULL,
    media_hash VARCHAR(64) NOT NULL,
    dimensions JSONB, -- {width, height}
    extracted_text TEXT,
    ocr_confidence FLOAT,
    qdrant_point_id UUID,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE INDEX idx_media_document ON rag.media_assets(document_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_media_chunk ON rag.media_assets(chunk_id) WHERE chunk_id IS NOT NULL;
CREATE INDEX idx_media_hash ON rag.media_assets(media_hash);

-- =====================================================
-- KAG Schema - Knowledge Graph
-- =====================================================

-- Entities table
CREATE TABLE IF NOT EXISTS kag.entities (
    entity_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    entity_type VARCHAR(100) NOT NULL,
    entity_name TEXT NOT NULL,
    normalized_name TEXT NOT NULL,
    properties JSONB DEFAULT '{}',
    source_references JSONB DEFAULT '[]', -- Array of {document_id, chunk_id}
    confidence_score FLOAT DEFAULT 1.0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    is_verified BOOLEAN DEFAULT FALSE,
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE INDEX idx_entities_type ON kag.entities(entity_type) WHERE is_deleted = FALSE;
CREATE INDEX idx_entities_normalized ON kag.entities(normalized_name) WHERE is_deleted = FALSE;
CREATE INDEX idx_entities_search ON kag.entities USING gin(to_tsvector('english', entity_name));

-- Relations table
CREATE TABLE IF NOT EXISTS kag.relations (
    relation_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    source_entity_id UUID NOT NULL REFERENCES kag.entities(entity_id) ON DELETE CASCADE,
    target_entity_id UUID NOT NULL REFERENCES kag.entities(entity_id) ON DELETE CASCADE,
    relation_type VARCHAR(100) NOT NULL,
    properties JSONB DEFAULT '{}',
    source_references JSONB DEFAULT '[]',
    confidence_score FLOAT DEFAULT 1.0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    is_bidirectional BOOLEAN DEFAULT FALSE,
    is_deleted BOOLEAN DEFAULT FALSE,
    
    CONSTRAINT no_self_relation CHECK (source_entity_id != target_entity_id)
);

CREATE INDEX idx_relations_source ON kag.relations(source_entity_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_relations_target ON kag.relations(target_entity_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_relations_type ON kag.relations(relation_type) WHERE is_deleted = FALSE;

-- =====================================================
-- CAG Schema - Cache and Query Optimization
-- =====================================================

-- Query cache table with TTL
CREATE TABLE IF NOT EXISTS cag.query_cache (
    cache_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    query_hash VARCHAR(64) NOT NULL,
    query_text TEXT NOT NULL,
    query_embedding FLOAT[] NOT NULL,
    response_data JSONB NOT NULL,
    response_metadata JSONB DEFAULT '{}',
    
    -- Performance metrics
    generation_time_ms INTEGER,
    tokens_used INTEGER,
    model_used VARCHAR(100),
    
    -- Cache management
    hit_count INTEGER DEFAULT 0,
    last_accessed_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ,
    cache_tier VARCHAR(20) DEFAULT 'standard' CHECK (cache_tier IN ('hot', 'standard', 'cold')),
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE UNIQUE INDEX idx_cache_hash ON cag.query_cache(query_hash) WHERE is_deleted = FALSE;
CREATE INDEX idx_cache_expiry ON cag.query_cache(expires_at) WHERE is_deleted = FALSE;
CREATE INDEX idx_cache_tier_access ON cag.query_cache(cache_tier, last_accessed_at) WHERE is_deleted = FALSE;

-- Query patterns for optimization
CREATE TABLE IF NOT EXISTS cag.query_patterns (
    pattern_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    pattern_regex TEXT NOT NULL,
    pattern_type VARCHAR(50) NOT NULL,
    optimization_hints JSONB DEFAULT '{}',
    avg_response_time_ms INTEGER,
    usage_count INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    is_active BOOLEAN DEFAULT TRUE
);

-- =====================================================
-- Monitoring Schema - System Metrics
-- =====================================================

-- Workflow execution logs
CREATE TABLE IF NOT EXISTS monitoring.workflow_executions (
    execution_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    workflow_name VARCHAR(200) NOT NULL,
    workflow_type VARCHAR(50) NOT NULL,
    started_at TIMESTAMPTZ NOT NULL,
    completed_at TIMESTAMPTZ,
    duration_ms INTEGER,
    status VARCHAR(50) NOT NULL,
    error_message TEXT,
    input_data JSONB,
    output_data JSONB,
    metrics JSONB DEFAULT '{}'
);

CREATE INDEX idx_workflow_time ON monitoring.workflow_executions(started_at DESC);
CREATE INDEX idx_workflow_status ON monitoring.workflow_executions(status, started_at DESC);

-- Query analytics
CREATE TABLE IF NOT EXISTS monitoring.query_logs (
    log_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    query_text TEXT NOT NULL,
    query_type VARCHAR(50),
    user_id VARCHAR(200),
    session_id VARCHAR(200),
    
    -- Performance metrics
    total_time_ms INTEGER,
    llm_time_ms INTEGER,
    retrieval_time_ms INTEGER,
    
    -- Results
    results_count INTEGER,
    relevance_score FLOAT,
    user_feedback VARCHAR(20),
    
    -- Routing info
    route_taken VARCHAR(20) CHECK (route_taken IN ('cache', 'rag', 'kag', 'hybrid')),
    cache_hit BOOLEAN DEFAULT FALSE,
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_query_logs_time ON monitoring.query_logs(created_at DESC);
CREATE INDEX idx_query_logs_user ON monitoring.query_logs(user_id, created_at DESC);
CREATE INDEX idx_query_logs_performance ON monitoring.query_logs(total_time_ms) WHERE total_time_ms > 1000;

-- Document sync tracking
CREATE TABLE IF NOT EXISTS monitoring.sync_operations (
    sync_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    source_type VARCHAR(50) NOT NULL CHECK (source_type IN ('gdrive', 'sharepoint', 'confluence', 'git')),
    operation_type VARCHAR(20) NOT NULL CHECK (operation_type IN ('add', 'update', 'delete', 'sync')),
    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    
    -- Statistics
    files_checked INTEGER DEFAULT 0,
    files_added INTEGER DEFAULT 0,
    files_updated INTEGER DEFAULT 0,
    files_deleted INTEGER DEFAULT 0,
    files_failed INTEGER DEFAULT 0,
    
    -- Details
    error_details JSONB DEFAULT '[]',
    sync_metadata JSONB DEFAULT '{}',
    
    status VARCHAR(20) DEFAULT 'running' CHECK (status IN ('running', 'completed', 'failed'))
);

CREATE INDEX idx_sync_source ON monitoring.sync_operations(source_type, started_at DESC);
CREATE INDEX idx_sync_status ON monitoring.sync_operations(status, started_at DESC);

-- =====================================================
-- Functions and Triggers
-- =====================================================

-- Update timestamp trigger
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE 'plpgsql';

-- Apply update trigger to all tables with updated_at
DO $$
DECLARE
    t record;
BEGIN
    FOR t IN 
        SELECT schemaname, tablename 
        FROM pg_tables 
        WHERE schemaname IN ('rag', 'kag', 'cag') 
        AND EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = pg_tables.schemaname 
            AND table_name = pg_tables.tablename 
            AND column_name = 'updated_at'
        )
    LOOP
        EXECUTE format('
            CREATE TRIGGER update_%I_%I_updated_at 
            BEFORE UPDATE ON %I.%I 
            FOR EACH ROW 
            EXECUTE FUNCTION update_updated_at_column()',
            t.schemaname, t.tablename, t.schemaname, t.tablename
        );
    END LOOP;
END $$;

-- Function to calculate similarity between embeddings
CREATE OR REPLACE FUNCTION calculate_cosine_similarity(vec1 FLOAT[], vec2 FLOAT[])
RETURNS FLOAT AS $$
DECLARE
    dot_product FLOAT := 0;
    norm1 FLOAT := 0;
    norm2 FLOAT := 0;
    i INTEGER;
BEGIN
    IF array_length(vec1, 1) != array_length(vec2, 1) THEN
        RETURN NULL;
    END IF;
    
    FOR i IN 1..array_length(vec1, 1) LOOP
        dot_product := dot_product + (vec1[i] * vec2[i]);
        norm1 := norm1 + (vec1[i] * vec1[i]);
        norm2 := norm2 + (vec2[i] * vec2[i]);
    END LOOP;
    
    IF norm1 = 0 OR norm2 = 0 THEN
        RETURN 0;
    END IF;
    
    RETURN dot_product / (sqrt(norm1) * sqrt(norm2));
END;
$$ LANGUAGE 'plpgsql' IMMUTABLE;

-- Cache cleanup function
CREATE OR REPLACE FUNCTION cleanup_expired_cache()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM cag.query_cache 
    WHERE expires_at < NOW() OR is_deleted = TRUE;
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ LANGUAGE 'plpgsql';

-- Cleanup orphaned chunks when documents are deleted
CREATE OR REPLACE FUNCTION cleanup_deleted_documents()
RETURNS INTEGER AS $$
DECLARE
    deleted_chunks INTEGER;
    deleted_media INTEGER;
    total_deleted INTEGER;
BEGIN
    -- Delete chunks for deleted documents
    DELETE FROM rag.chunks 
    WHERE document_id IN (
        SELECT document_id FROM rag.documents 
        WHERE is_deleted = TRUE 
        AND updated_at < NOW() - INTERVAL '7 days'
    );
    GET DIAGNOSTICS deleted_chunks = ROW_COUNT;
    
    -- Delete media assets for deleted documents
    DELETE FROM rag.media_assets
    WHERE document_id IN (
        SELECT document_id FROM rag.documents 
        WHERE is_deleted = TRUE 
        AND updated_at < NOW() - INTERVAL '7 days'
    );
    GET DIAGNOSTICS deleted_media = ROW_COUNT;
    
    -- Finally delete the documents themselves
    DELETE FROM rag.documents 
    WHERE is_deleted = TRUE 
    AND updated_at < NOW() - INTERVAL '7 days';
    GET DIAGNOSTICS total_deleted = ROW_COUNT;
    
    RAISE NOTICE 'Cleaned up % documents, % chunks, % media assets', 
        total_deleted, deleted_chunks, deleted_media;
    
    RETURN total_deleted;
END;
$$ LANGUAGE 'plpgsql';

-- Track document changes for sync operations
CREATE OR REPLACE FUNCTION track_document_sync()
RETURNS TRIGGER AS $$
BEGIN
    -- Log to sync tracking
    INSERT INTO monitoring.sync_operations 
        (source_type, operation_type, files_checked, files_added, files_updated, files_deleted, status, completed_at)
    VALUES 
        (NEW.source_type, 
         CASE 
            WHEN TG_OP = 'INSERT' THEN 'add'
            WHEN TG_OP = 'UPDATE' AND NEW.is_deleted AND NOT OLD.is_deleted THEN 'delete'
            WHEN TG_OP = 'UPDATE' THEN 'update'
            ELSE 'sync'
         END,
         1,
         CASE WHEN TG_OP = 'INSERT' THEN 1 ELSE 0 END,
         CASE WHEN TG_OP = 'UPDATE' AND NOT NEW.is_deleted THEN 1 ELSE 0 END,
         CASE WHEN TG_OP = 'UPDATE' AND NEW.is_deleted THEN 1 ELSE 0 END,
         'completed',
         NOW()
        )
    ON CONFLICT DO NOTHING;
    
    RETURN NEW;
END;
$$ LANGUAGE 'plpgsql';

-- Apply document sync tracking trigger
CREATE TRIGGER track_document_changes
AFTER INSERT OR UPDATE ON rag.documents
FOR EACH ROW
EXECUTE FUNCTION track_document_sync();

-- =====================================================
-- Initial Data and Configuration
-- =====================================================

-- Insert default query patterns
INSERT INTO cag.query_patterns (pattern_regex, pattern_type, optimization_hints) VALUES
    ('^(what|who|when|where|why|how)\s+', 'question', '{"prefer_cache": true, "max_chunks": 3}'::jsonb),
    ('(list|enumerate|show all)', 'enumeration', '{"prefer_kag": true, "expand_relations": true}'::jsonb),
    ('(compare|difference between|versus)', 'comparison', '{"use_hybrid": true, "parallel_retrieval": true}'::jsonb),
    ('(latest|recent|current)', 'temporal', '{"prefer_rag": true, "sort_by_date": true}'::jsonb),
    ('(code|function|api|endpoint)', 'technical', '{"prefer_git_source": true, "include_code_context": true}'::jsonb),
    ('(terraform|yaml|config)', 'infrastructure', '{"search_iac_files": true, "include_dependencies": true}'::jsonb)
ON CONFLICT DO NOTHING;

-- Create materialized view for performance dashboard
CREATE MATERIALIZED VIEW IF NOT EXISTS monitoring.performance_summary AS
SELECT 
    DATE_TRUNC('hour', created_at) as hour,
    COUNT(*) as query_count,
    AVG(total_time_ms) as avg_response_time,
    PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY total_time_ms) as p95_response_time,
    SUM(CASE WHEN cache_hit THEN 1 ELSE 0 END)::FLOAT / COUNT(*) as cache_hit_rate,
    COUNT(DISTINCT user_id) as unique_users
FROM monitoring.query_logs
WHERE created_at > NOW() - INTERVAL '7 days'
GROUP BY hour;

CREATE UNIQUE INDEX idx_performance_summary_hour ON monitoring.performance_summary(hour);

-- Create view for document freshness monitoring
CREATE VIEW monitoring.document_freshness AS
SELECT 
    source_type,
    COUNT(*) as total_documents,
    COUNT(*) FILTER (WHERE updated_at > NOW() - INTERVAL '1 day') as updated_last_day,
    COUNT(*) FILTER (WHERE updated_at > NOW() - INTERVAL '7 days') as updated_last_week,
    COUNT(*) FILTER (WHERE is_deleted = TRUE) as deleted_documents,
    MAX(updated_at) as last_update
FROM rag.documents
GROUP BY source_type;

-- Schedule periodic cleanup
CREATE OR REPLACE FUNCTION schedule_cleanup_job()
RETURNS void AS $$
BEGIN
    -- This would be called by a cron job or N8N workflow
    PERFORM cleanup_expired_cache();
    PERFORM cleanup_deleted_documents();
    REFRESH MATERIALIZED VIEW CONCURRENTLY monitoring.performance_summary;
END;
$$ LANGUAGE 'plpgsql';

-- Grant appropriate permissions
GRANT USAGE ON SCHEMA rag, kag, cag, monitoring TO ${POSTGRES_USER};
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA rag, kag, cag, monitoring TO ${POSTGRES_USER};
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA rag, kag, cag, monitoring TO ${POSTGRES_USER};

-- =====================================================
-- Partitioning for large tables (optional, for scale)
-- =====================================================

-- Example: Partition query_logs by month
-- CREATE TABLE monitoring.query_logs_2025_01 PARTITION OF monitoring.query_logs
-- FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');