-- init.sql - DataLive PostgreSQL Schema v2.1 (Refactorizado por el Arquitecto)
-- Actualizado con la arquitectura final: Postgres para data relacional, Neo4j para grafos, Qdrant para vectores.

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
CREATE EXTENSION IF NOT EXISTS "btree_gin";

-- Create schemas
CREATE SCHEMA IF NOT EXISTS rag;
CREATE SCHEMA IF NOT EXISTS cag;
CREATE SCHEMA IF NOT EXISTS monitoring;

-- Set default search path
SET search_path TO rag, cag, monitoring, public;

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
    qdrant_point_id UUID,
    qdrant_collection VARCHAR(100),
    embedding_model VARCHAR(100),
    embedding_dimension INTEGER,
    associated_media JSONB DEFAULT '[]',
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

-- [ARQUITECTO] SECCIÓN ELIMINADA: Esquema KAG redundante.
-- La gestión de entidades y relaciones es responsabilidad exclusiva de Neo4j.

-- =====================================================
-- CAG Schema - Cache and Query Optimization
-- =====================================================

-- Query cache table with TTL
CREATE TABLE IF NOT EXISTS cag.query_cache (
    cache_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    query_hash VARCHAR(64) NOT NULL,
    query_text TEXT NOT NULL,
    response_data JSONB NOT NULL,
    response_metadata JSONB DEFAULT '{}',
    generation_time_ms INTEGER,
    tokens_used INTEGER,
    model_used VARCHAR(100),
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
    total_time_ms INTEGER,
    llm_time_ms INTEGER,
    retrieval_time_ms INTEGER,
    results_count INTEGER,
    relevance_score FLOAT,
    user_feedback VARCHAR(20),
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
    files_checked INTEGER DEFAULT 0,
    files_added INTEGER DEFAULT 0,
    files_updated INTEGER DEFAULT 0,
    files_deleted INTEGER DEFAULT 0,
    files_failed INTEGER DEFAULT 0,
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
        WHERE schemaname IN ('rag', 'cag', 'monitoring') -- KAG schema removed
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


-- [ARQUITECTO] SECCIÓN ELIMINADA: Función de similitud de coseno.
-- Esta funcionalidad es responsabilidad exclusiva de Qdrant.

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
    DELETE FROM rag.chunks 
    WHERE document_id IN (
        SELECT document_id FROM rag.documents 
        WHERE is_deleted = TRUE 
        AND updated_at < NOW() - INTERVAL '7 days'
    );
    GET DIAGNOSTICS deleted_chunks = ROW_COUNT;
    
    DELETE FROM rag.media_assets
    WHERE document_id IN (
        SELECT document_id FROM rag.documents 
        WHERE is_deleted = TRUE 
        AND updated_at < NOW() - INTERVAL '7 days'
    );
    GET DIAGNOSTICS deleted_media = ROW_COUNT;
    
    DELETE FROM rag.documents 
    WHERE is_deleted = TRUE 
    AND updated_at < NOW() - INTERVAL '7 days';
    GET DIAGNOSTICS total_deleted = ROW_COUNT;
    
    RAISE NOTICE 'Cleaned up % documents, % chunks, % media assets', 
        total_deleted, deleted_chunks, deleted_media;
    
    RETURN total_deleted;
END;
$$ LANGUAGE 'plpgsql';

-- =====================================================
-- Initial Data and Configuration
-- =====================================================

INSERT INTO cag.query_patterns (pattern_regex, pattern_type, optimization_hints) VALUES
    ('^(what|who|when|where|why|how)\s+', 'question', '{"prefer_cache": true, "max_chunks": 3}'::jsonb),
    ('(list|enumerate|show all)', 'enumeration', '{"prefer_kag": true, "expand_relations": true}'::jsonb),
    ('(compare|difference between|versus)', 'comparison', '{"use_hybrid": true, "parallel_retrieval": true}'::jsonb)
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

-- =====================================================
-- Permissions
-- =====================================================

-- Grant appropriate permissions
-- Asegúrate que la variable de entorno ${POSTGRES_USER} esté disponible durante la ejecución.
-- Docker-compose lo hace automáticamente si se usa `env_file`.
DO $$
BEGIN
   IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '${POSTGRES_USER}') THEN
      GRANT USAGE ON SCHEMA rag, cag, monitoring TO ${POSTGRES_USER};
      GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA rag, cag, monitoring TO ${POSTGRES_USER};
      GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA rag, cag, monitoring TO ${POSTGRES_USER};
   END IF;
END $$;