## Datos para registrar N8N al iniciar conteedor 
Nombre: Angel Rivera
Mail: contacto@angelrivera.es
Key de licencia: 20d94139-11f1-436c-956f-91060bda4c99
Objetivo: No es para trabajo
Donde lo conoci: Youtube 

## Workflow_IDS (Canbiaran por cada despliegue de N8N)
Google Drive: JDJataPOB6QvvkLY
Ollama: 5fqMKusZb5HeGYG7
Qdrant: d3XjLZWIngOXSceT


## fichero env actual
### Credenciales de n8n
N8N_CRED_OLLAMA_LOCAL_BASEURL=http://ollama:11434
N8N_CRED_QDRANT_LOCAL_URL=http://qdrant:6333
N8N_CRED_QDRANT_LOCAL_APIKEY=not-in-use

### Credenciales de la Base de Datos PostgreSQL
POSTGRES_USER=n8n_user
POSTGRES_PASSWORD=super_secret_password_123 # Cambie esto por una contraseña segura
POSTGRES_DB=datalive_db

### Credenciales para el Almacén de Objetos MinIO
MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=super_secret_password_minio 

## DockerCompose actual 

Importante mantener la parte comentada para cuando se pueda usar gpu 

```
services:
  # 1. Orquestador de Workflows
  n8n:
    image: n8nio/n8n
    restart: always
    ports:
      - "5678:5678"
    env_file:
      - .env
    environment:
      - N8N_METRICS=true
      - N8N_RUNNERS_ENABLED=true
      - N8N_SECURE_COOKIE=false
    volumes:
      - n8n_data:/home/node/.n8n
    networks:
      - datalive-net
    depends_on:
      - postgres
      - qdrant

  # 2. Base de datos Relacional y de Metadatos
  postgres:
    image: postgres:16-alpine
    restart: always
    ports:
      - "5432:5432"
    env_file:
      - .env
    environment:
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: ${POSTGRES_DB}
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./postgres-init:/docker-entrypoint-initdb.d
    networks:
      - datalive-net
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
      interval: 30s
      timeout: 10s
      retries: 5

  # 3. Base de Datos Vectorial (RAG)
  qdrant:
    image: qdrant/qdrant
    restart: always
    ports:
      - "6333:6333"
      - "6334:6334"
    volumes:
      - qdrant_data:/qdrant/storage
    networks:
      - datalive-net

  # 4. Servidor de LLMs y Embeddings
  ollama:
    image: ollama/ollama
    restart: always
    ports:
      - "11434:11434"
    volumes:
      - ollama_data:/root/.ollama
    networks:
      - datalive-net
    # deploy: # Descomentar para habilitar la aceleración por GPU si está disponible
    #   resources:
    #     reservations:
    #       devices:
    #         - driver: nvidia
    #           count: 1
    #           capabilities: [gpu]

  # 5.Almacén de Objetos S3-Compatible para Imágenes
  minio:
    image: minio/minio:latest
    restart: always
    ports:
      - "9000:9000"  # API Port
      - "9001:9001"  # Console Port
    env_file:
      - .env
    environment:
      MINIO_ROOT_USER: ${MINIO_ROOT_USER}
      MINIO_ROOT_PASSWORD: ${MINIO_ROOT_PASSWORD}
    volumes:
      - minio_data:/data
    command: server /data --console-address ":9001"
    networks:
      - datalive-net
      
  # 6. Esqueleto del Microservicio de Procesamiento de Documentos
  doc-processor:
    build:
      context: ./doc-processor
    restart: always
    ports:
      - "8000:8000"
    networks:
      - datalive-net
    depends_on:
      - ollama
      - minio

# --- Definiciones de Nivel Superior ---
volumes:
  n8n_data:
  postgres_data:
  qdrant_data:
  ollama_data:
  minio_data:

networks:
  datalive-net:
    driver: bridge
```

### Init sql actual 

```
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
```


## Doc Procesor 
Se iba a crear un procesador en python mas potente que los de caja pero si ahora no es necesario y se puede eliminar adelante , de momento no se habia desarrollado nada , solo este dockerfile dummy 

```
# Dockerfile de marcador de posición para el servicio doc-processor

# Usamos una imagen base mínima
FROM alpine:latest

# Simplemente mantenemos el contenedor corriendo para que el stack no falle
# Más adelante, reemplazaremos esto con nuestro código de FastAPI
CMD echo 
```