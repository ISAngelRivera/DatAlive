
📄 13. GitHub Actions: deploy.yml
Ubicación: datalive/.github/workflows/deploy.yml
Copiar el contenido del artifact github-workflow







datalive/
├── .env.example
├── .gitignore (generado por git-setup-and-push.sh)
├── README.md
├── git-setup-and-push.sh
├── docker/
│   └── docker-compose.yml
├── postgres-init/
│   └── init.sql
├── scripts/
│   ├── setup-datalive.sh
│   ├── init-n8n-setup.sh
│   ├── init-ollama-models.sh
│   ├── init-minio-buckets.sh
│   ├── init-qdrant-collections.sh
│   ├── wait-for-healthy.sh
│   └── sync-n8n-workflows.sh
├── workflows/
│   ├── ingestion/
│   │   ├── document-sync-deletion.json
│   │   └── git-repository-ingestion.json
│   ├── query/
│   └── optimization/
├── .github/
│   └── workflows/
│       └── deploy.yml
├── config/
│   ├── n8n/
│   ├── ollama/
│   ├── minio/
│   ├── qdrant/
│   ├── prometheus/
│   └── grafana/
├── secrets/
├── logs/
├── backups/
└── docs/
    └── PLAN.md