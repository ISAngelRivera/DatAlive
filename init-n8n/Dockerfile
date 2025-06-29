# init-n8n/Dockerfile - v2.0
# Imagen mínima para ejecutar el script de configuración de n8n.

FROM alpine:latest

# Instalar curl y jq, nuestras únicas dependencias
RUN apk --no-cache add curl jq

# Copiar el script de setup desde el mismo directorio (el contexto del build)
COPY setup-n8n.sh /setup-n8n.sh

# Darle permisos de ejecución
RUN chmod +x /setup-n8n.sh

# Definir el punto de entrada para que Docker Compose lo ejecute
ENTRYPOINT ["/setup-n8n.sh"]