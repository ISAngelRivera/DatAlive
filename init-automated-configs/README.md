# DataLive Automated Configuration

Esta carpeta contiene todos los scripts de configuración automática y sidecars de inicialización para DataLive.

## Estructura

```
init-automated-configs/
├── neo4j/
│   ├── setup.sh               # Configuración de esquema Neo4j
│   ├── generate-neo4j-ssl.sh  # Generación de certificados SSL
│   └── ssl/                   # Certificados SSL
├── postgres/
│   ├── init.sh               # Inicialización PostgreSQL
│   └── init.sql              # Schema SQL
├── qdrant/
│   └── setup.sh              # Configuración colecciones Qdrant
├── ollama/
│   └── (configuración para modelos LLM)
├── n8n/
│   └── setup.sh              # Configuración N8N y workflows
└── healthcheck/
    ├── verify.sh             # Verificación final del sistema
    ├── test-functionality.sh # Tests funcionales completos
    └── quick-test.sh         # Tests rápidos
```

## Flujo de Ejecución

Los scripts se ejecutan automáticamente como sidecars en Docker Compose:

1. **Servicios base** → PostgreSQL, Neo4j, Qdrant, MinIO, Ollama, N8N
2. **Inicialización** → Scripts específicos de cada servicio
3. **DataLive Agent** → Aplicación principal
4. **Healthcheck** → Verificación final del sistema

## Scripts de Deploy y Configuración

- `deploy-infrastructure.sh` - Deploy completo automatizado (Golden Path)
- `generate-env.sh` - Generación automática de variables de entorno

## Uso

### Despliegue Completo
```bash
./init-automated-configs/deploy-infrastructure.sh
```

### Generación Manual de .env
```bash
./init-automated-configs/generate-env.sh
```