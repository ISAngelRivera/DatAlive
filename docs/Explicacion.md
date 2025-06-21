# 🏢 DataLive: Tu Asistente de IA Empresarial

## 🎯 ¿Qué hace DataLive?

**En pocas palabras**: Es un ChatGPT privado que conoce TODOS los documentos de tu empresa y responde preguntas por Microsoft Teams.

## 👥 Los 3 "Empleados" del Sistema

### 1. 📚 El Archivista (Agente de Ingesta)
**¿Qué hace?** 
- Revisa Google Drive cada 30 minutos
- Cuando encuentra un documento nuevo o modificado:
  - Lo descarga
  - Lo "lee" y comprende
  - Lo divide en pedacitos manejables
  - Lo guarda en una "biblioteca digital especial"

**Es como**: Un bibliotecario que organiza libros nuevos

### 2. 💬 El Experto (Agente de Consulta)
**¿Qué hace?**
- Recibe preguntas de los empleados por Teams
- Busca la respuesta en la biblioteca digital
- Genera una respuesta clara y precisa
- La envía de vuelta a Teams

**Es como**: Un consultor experto que siempre tiene la respuesta correcta

### 3. 🚀 El Optimizador (Agente de Mejora)
**¿Qué hace?**
- Observa qué preguntas se hacen más
- Prepara respuestas anticipadas para preguntas frecuentes
- Hace que todo sea más rápido con el tiempo

**Es como**: Un gerente de mejora continua

## 🔧 ¿Por Qué Tantos Scripts (.sh)?

Los scripts son como **recetas de cocina** o **instrucciones de montaje**. Cada uno hace una tarea específica:

### Scripts Principales:

#### 1. **setup-datalive.sh** 🏗️
**¿Qué hace?** Es el "botón mágico" que lo instala TODO
- Crea las carpetas necesarias
- Genera contraseñas seguras
- Instala todos los servicios
- Configura las conexiones

**Analogía**: Como el instalador de Windows que hace todo con "Siguiente, Siguiente, Finalizar"

#### 2. **init-ollama-models.sh** 🧠
**¿Qué hace?** Descarga los "cerebros" de IA
- Descarga el modelo que entiende español/inglés (Phi-4)
- Descarga el modelo que convierte texto en números (para búsquedas)

**Analogía**: Como descargar los paquetes de idioma en tu teléfono

#### 3. **init-minio-buckets.sh** 📦
**¿Qué hace?** Crea los "cajones" donde se guardan archivos
- Crea carpetas para documentos
- Crea carpetas para imágenes
- Configura permisos

**Analogía**: Como crear carpetas en Google Drive

#### 4. **sync-n8n-workflows.sh** 🔄
**¿Qué hace?** Actualiza los "flujos de trabajo"
- Sube las nuevas "recetas" de procesamiento
- Actualiza las existentes

**Analogía**: Como sincronizar tu teléfono con la nube

## 📊 Los Servicios (¿Qué es cada cosa?)

### Servicios Principales:

| Servicio | ¿Qué es? | Analogía Simple |
|----------|----------|-----------------|
| **N8N** | El director de orquesta | Como Zapier pero privado |
| **PostgreSQL** | Base de datos principal | Como Excel pero súper potente |
| **Qdrant** | Buscador inteligente | Como Google pero para tus documentos |
| **Ollama** | El cerebro de IA | Como ChatGPT pero en tu servidor |
| **MinIO** | Almacén de archivos | Como Dropbox privado |
| **Redis** | Memoria rápida | Como Post-its para respuestas frecuentes |
| **Grafana** | Panel de control | Como el dashboard de tu coche |

## 🌟 Flujo Completo: Ejemplo Real

### Cuando un empleado pregunta: "¿Cuál es la política de vacaciones?"

1. **Teams** → Empleado escribe la pregunta
2. **N8N** → Recibe la pregunta
3. **Redis** → ¿Ya respondí esto antes? 
   - Sí → Envía respuesta guardada (0.1 segundos)
   - No → Continúa...
4. **Ollama** → Convierte la pregunta en "números mágicos"
5. **Qdrant** → Busca documentos similares a esos números
6. **PostgreSQL** → Obtiene los documentos completos
7. **Ollama** → Lee los documentos y genera una respuesta
8. **Redis** → Guarda la respuesta para la próxima vez
9. **Teams** → Empleado recibe la respuesta

**Tiempo total**: 1-2 segundos la primera vez, 0.1 segundos las siguientes

## 🚀 ¿Cómo se Instala?

### Paso 1: Preparar el servidor
```bash
# Copiar el archivo de configuración
cp .env.example .env

# Editar con tus datos (email, contraseñas, etc.)
nano .env
```

### Paso 2: Ejecutar la instalación
```bash
# Un solo comando que hace TODO
./scripts/setup-datalive.sh
```

### Paso 3: ¡Listo!
- N8N estará en: http://tu-servidor:5678
- Grafana en: http://tu-servidor:3000
- Todo funcionando automáticamente

## 🔒 Seguridad

- **Todo es privado**: Nada sale de tu servidor
- **Contraseñas automáticas**: Se generan solas, súper seguras
- **Acceso controlado**: Solo usuarios autorizados
- **Datos encriptados**: Todo viaja seguro

## 📈 Ventajas del Sistema

1. **Respuestas instantáneas** a preguntas sobre documentación
2. **Siempre actualizado**: Se sincroniza automáticamente
3. **Mejora con el uso**: Aprende qué se pregunta más
4. **Ahorro de tiempo**: No más buscar en 100 documentos
5. **Disponible 24/7**: Nunca descansa

## 🎯 Casos de Uso Reales

- **RRHH**: "¿Cuántos días de vacaciones tengo?"
- **IT**: "¿Cómo configuro la VPN?"
- **Ventas**: "¿Cuál es el precio del producto X?"
- **Legal**: "¿Qué dice el contrato con el cliente Y?"
- **Onboarding**: "¿Cuál es el proceso para nuevos empleados?"

## 💡 ¿Por Qué es Mejor que ChatGPT?

| ChatGPT | DataLive |
|---------|----------|
| No conoce tus documentos | Conoce TODOS tus documentos |
| Puede inventar respuestas | Solo responde con información real |
| Datos van a OpenAI | Todo queda en tu servidor |
| Costo por uso | Una vez instalado, es gratis |
| Genérico | Personalizado para tu empresa |

## 🛠️ Mantenimiento

**Automático**:
- Se actualiza solo con documentos nuevos
- Hace backup automático
- Se optimiza solo

**Manual** (ocasional):
- Revisar los dashboards
- Actualizar modelos de IA (opcional)
- Añadir nuevas fuentes de datos

## 📞 Cuando Algo Falla

1. **Ver los logs**: `docker logs datalive-n8n`
2. **Revisar Grafana**: Todo está monitorizado
3. **Reiniciar servicio**: `docker restart datalive-n8n`
4. **Script de emergencia**: `./scripts/health-check.sh`

## 🎉 Resultado Final

Un sistema que:
- **Ahorra horas** de búsqueda de información
- **Mejora la productividad** del equipo
- **Centraliza el conocimiento** de la empresa
- **Está disponible** cuando lo necesites
- **Es 100% privado** y seguro

¿Es como tener un empleado súper inteligente que se sabe todos los documentos de memoria y nunca se cansa de responder preguntas!