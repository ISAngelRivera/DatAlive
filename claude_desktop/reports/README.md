# Reports Directory

Esta carpeta almacena todos los reportes automáticos generados por los scripts de diagnóstico.

## Estructura

```
reports/
├── README.md                    # Este archivo
├── infrastructure-report.md    # Último reporte de infraestructura
├── daily/                      # Reportes diarios automáticos
│   ├── YYYY-MM-DD-report.md
│   └── ...
└── archive/                    # Reportes archivados por mes
    ├── YYYY-MM/
    └── ...
```

## Tipos de Reportes

### Infrastructure Report
- **Archivo**: `infrastructure-report.md`
- **Generado por**: `infrastructure-diagnostic.sh`
- **Frecuencia**: Manual o programado
- **Contenido**: Estado completo de todos los servicios

### Daily Reports
- **Carpeta**: `daily/`
- **Formato**: `YYYY-MM-DD-report.md`
- **Generado por**: Cron job con `quick-health-check.sh`
- **Contenido**: Resumen diario de salud del sistema

## Automatización

Para automatizar la generación de reportes:

```bash
# Crontab entry para reporte diario a las 6:00 AM
0 6 * * * cd /path/to/datalive && ./claude_desktop/scripts/quick-health-check.sh > ./claude_desktop/reports/daily/$(date +\%Y-\%m-\%d)-report.md 2>&1
```

## Retención

- **Daily reports**: 30 días
- **Infrastructure reports**: Se sobrescriben (mantener últimos 5 en archive/)
- **Archive**: Mantener 6 meses

## Para Claude Desktop

Los reportes más relevantes para análisis:
1. `infrastructure-report.md` - Estado actual completo
2. `daily/` (últimos 7 días) - Tendencias de estabilidad
3. `archive/` - Análisis histórico si es necesario