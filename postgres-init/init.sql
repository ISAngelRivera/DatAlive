CREATE TABLE IF NOT EXISTS file_chunk_metadata (
    chunk_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    qdrant_point_id UUID NOT NULL,
    source_file_id VARCHAR(255) NOT NULL,
    chunk_hash VARCHAR(64) NOT NULL,
    associated_image_path VARCHAR(1024) NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_source_file_id ON file_chunk_metadata(source_file_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_chunk_hash_source_file ON file_chunk_metadata(chunk_hash, source_file_id); -- Mejorado para permitir mismos chunks en diferentes ficheros

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
   NEW.updated_at = NOW();
   RETURN NEW;
END;
$$ language 'plpgsql';

DROP TRIGGER IF EXISTS update_file_chunk_metadata_updated_at ON file_chunk_metadata; -- Evita duplicados
CREATE TRIGGER update_file_chunk_metadata_updated_at
BEFORE UPDATE ON file_chunk_metadata
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();