-- init.sql - DataLive PostgreSQL Schema v2.4 (Canónico)
-- Arquitectura final: Postgres para data relacional, caché y monitoreo. Neo4j para grafos. Qdrant para vectores.

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
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_documents_source ON rag.documents(source_id, source_type) WHERE is_deleted = FALSE;
CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_chunk_per_doc ON rag.chunks(document_id, chunk_index) WHERE is_deleted = FALSE;

CREATE INDEX IF NOT EXISTS idx_documents_hash ON rag.documents(document_hash);
CREATE INDEX IF NOT EXISTS idx_documents_status ON rag.documents(processing_status) WHERE is_deleted = FALSE;
CREATE INDEX IF NOT EXISTS idx_documents_metadata ON rag.documents USING gin(metadata);
CREATE INDEX IF NOT EXISTS idx_chunks_document ON rag.chunks(document_id) WHERE is_deleted = FALSE;
CREATE INDEX IF NOT EXISTS idx_chunks_hash ON rag.chunks(chunk_hash);
CREATE INDEX IF NOT EXISTS idx_chunks_qdrant ON rag.chunks(qdrant_point_id) WHERE qdrant_point_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_chunks_content_search ON rag.chunks USING gin(to_tsvector('english', content));

CREATE TABLE IF NOT EXISTS rag.media_assets (
    media_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    document_id UUID NOT NULL REFERENCES rag.documents(document_id) ON DELETE CASCADE,
    chunk_id UUID REFERENCES rag.chunks(chunk_id) ON DELETE SET NULL,
    media_type VARCHAR(50) NOT NULL CHECK (media_type IN ('image', 'diagram', 'chart', 'table_image')),
    original_path TEXT NOT NULL,
    minio_bucket VARCHAR(100) NOT NULL,
    minio_object_key VARCHAR(512) NOT NULL,
    media_hash VARCHAR(64) NOT NULL,
    dimensions JSONB,
    extracted_text TEXT,
    ocr_confidence FLOAT,
    qdrant_point_id UUID,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_media_document ON rag.media_assets(document_id) WHERE is_deleted = FALSE;
CREATE INDEX IF NOT EXISTS idx_media_chunk ON rag.media_assets(chunk_id) WHERE chunk_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_media_hash ON rag.media_assets(media_hash);

-- =====================================================
-- CAG Schema - Cache and Query Optimization
-- =====================================================

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

CREATE UNIQUE INDEX IF NOT EXISTS idx_cache_hash ON cag.query_cache(query_hash) WHERE is_deleted = FALSE;
CREATE INDEX IF NOT EXISTS idx_cache_expiry ON cag.query_cache(expires_at) WHERE is_deleted = FALSE;

-- =====================================================
-- Monitoring Schema - System Metrics
-- =====================================================

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

CREATE INDEX IF NOT EXISTS idx_query_logs_time ON monitoring.query_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_query_logs_user ON monitoring.query_logs(user_id, created_at DESC);

-- =====================================================
-- Functions and Triggers
-- =====================================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE 'plpgsql';

DO $$
DECLARE
    t record;
BEGIN
    FOR t IN 
        SELECT schemaname, tablename 
        FROM pg_tables 
        WHERE schemaname IN ('rag', 'cag', 'monitoring')
        AND EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = pg_tables.schemaname 
            AND table_name = pg_tables.tablename 
            AND column_name = 'updated_at'
        )
    LOOP
        IF NOT EXISTS (
            SELECT 1 FROM pg_trigger 
            WHERE tgname = format('update_%I_%I_updated_at', t.schemaname, t.tablename)
        ) THEN
            EXECUTE format('
                CREATE TRIGGER update_%I_%I_updated_at 
                BEFORE UPDATE ON %I.%I 
                FOR EACH ROW 
                EXECUTE FUNCTION update_updated_at_column()',
                t.schemaname, t.tablename, t.schemaname, t.tablename
            );
        END IF;
    END LOOP;
END $$;

-- =====================================================
-- Permissions
-- =====================================================
DO $$
BEGIN
   IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'datalive_user') THEN
      GRANT USAGE ON SCHEMA rag, cag, monitoring TO datalive_user;
      GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA rag, cag, monitoring TO datalive_user;
      GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA rag, cag, monitoring TO datalive_user;
   END IF;
END $$;