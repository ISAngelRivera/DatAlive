# Claude Desktop - DataLive Analysis & Management

Esta carpeta contiene todos los scripts, análisis, reportes y recomendaciones generados por Claude Desktop para el proyecto DataLive.

## 📁 Estructura de Carpetas

```
claude_desktop/
├── README.md                 # Este archivo - descripción general
├── scripts/                  # Scripts de diagnóstico y utilidades
│   ├── infrastructure-diagnostic.sh    # Diagnóstico completo de infraestructura
│   ├── quick-health-check.sh          # Verificación rápida de servicios
│   └── utilities/                      # Scripts auxiliares
├── reports/                  # Reportes automáticos generados
│   ├── infrastructure-report.md        # Reporte de estado de infraestructura
│   └── daily/                          # Reportes diarios automáticos
├── docs/                     # Documentación específica de Claude Desktop
│   ├── PORTS.md                       # Documentación de puertos y conectividad
│   └── troubleshooting/               # Guías de resolución de problemas
├── analysis/                 # Análisis detallados del sistema
│   ├── performance/                   # Análisis de rendimiento
│   ├── security/                      # Análisis de seguridad
│   └── architecture/                  # Análisis arquitectónico
└── recommendations/          # Mejoras y optimizaciones propuestas
    ├── immediate/                     # Acciones inmediatas
    ├── short-term/                    # Mejoras a corto plazo
    └── long-term/                     # Estrategia a largo plazo
```

## 🚀 Scripts Disponibles

### Diagnóstico de Infraestructura
```bash
# Verificación rápida (< 10 segundos)
./claude_desktop/scripts/quick-health-check.sh

# Diagnóstico completo (genera reporte detallado)
./claude_desktop/scripts/infrastructure-diagnostic.sh
```

### Códigos de Salida
- **0**: Todo operacional
- **1**: Problemas detectados (revisar output)

## 📊 Reportes

Los reportes se generan automáticamente y se almacenan en `reports/`:
- `infrastructure-report.md`: Estado completo del sistema
- `daily/`: Reportes automáticos programados

## 🎯 Propósito

Esta estructura organizada permite:
- **Separación clara** entre herramientas de diagnóstico y código de aplicación
- **Trazabilidad** de análisis y recomendaciones de Claude Desktop
- **Automatización** de reportes y monitoreo
- **Colaboración** estructurada entre Claude Code y Claude Desktop

## 🔧 Mantenimiento

- Los scripts se mantienen actualizados automáticamente
- Los reportes se archivan por fecha
- Las recomendaciones se priorizan por impacto
- La documentación se sincroniza con cambios en el sistema

## 📋 Para Claude Desktop

Cuando revises el proyecto, utiliza:
1. `./claude_desktop/scripts/infrastructure-diagnostic.sh` - Para estado actual
2. `./claude_desktop/reports/infrastructure-report.md` - Para análisis base
3. `./claude_desktop/docs/PORTS.md` - Para arquitectura de red
4. `./claude_desktop/analysis/` - Para análisis profundos previos

## 🤝 Colaboración

Esta carpeta facilita la colaboración entre:
- **Claude Code** (implementación)
- **Claude Desktop** (análisis y optimización)
- **Equipo humano** (decisiones estratégicas)

Mantener esta estructura asegura que el proyecto permanezca organizado y que todas las contribuciones de IA estén bien documentadas y trazables.