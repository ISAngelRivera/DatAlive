# Registro de Deuda Técnica del Proyecto DataLive

Este documento registra todas las desviaciones de las mejores prácticas de seguridad y arquitectura tomadas para agilizar el desarrollo, junto con su plan de remediación.

---

### DEVIATION-001: Fichero `.env` versionado en Git

* **Desviación:** El fichero `.env`, que contiene secretos como contraseñas y claves de API, está siendo incluido en el control de versiones de Git en lugar de ser ignorado por el `.gitignore`.

* **Justificación:** Facilitar la sincronización del entorno de desarrollo entre las múltiples máquinas del desarrollador durante la fase inicial del proyecto.

* **Nivel de Riesgo:** **Crítico.** Si el repositorio se hace público o el acceso se ve comprometido, todas las credenciales del sistema quedarán expuestas.

* **Plan de Remediación:** **Antes de cualquier despliegue** fuera del entorno local de desarrollo (incluyendo staging o pre-producción), es **mandatorio** ejecutar las siguientes acciones:
    1.  Asegurar que la línea `.env` en el fichero `.gitignore` esté descomentada y activa.
    2.  Ejecutar el comando `git rm --cached .env` para eliminar el fichero del seguimiento de Git sin borrarlo localmente.
    3.  Realizar un nuevo commit para registrar la eliminación del fichero del control de versiones.
    4.  **Forzar un cambio de todas las credenciales** que fueron expuestas en el historial de Git.
    5.  Implementar un método seguro para la gestión de secretos para el equipo (ej. un gestor de contraseñas compartido, HashiCorp Vault, etc.).

---

### DEVIATION-002: N8N Cookie Inseguro para Desarrollo

* **Desviación:** La configuración `N8N_SECURE_COOKIE=false` está habilitada para permitir el acceso desde Safari y otros navegadores en entorno de desarrollo local sin HTTPS.

* **Justificación:** Durante el desarrollo local, el acceso se realiza a través de `http://localhost:5678` sin certificados SSL, lo que requiere deshabilitar la bandera de cookies seguras para compatibilidad con todos los navegadores.

* **Nivel de Riesgo:** **Medio.** Las cookies de sesión N8N pueden ser interceptadas en redes no confiables o mediante ataques man-in-the-middle si se despliega en producción.

* **Plan de Remediación:** **Antes de cualquier despliegue en producción**:
    1. Configurar certificados SSL/TLS válidos para N8N
    2. Cambiar `N8N_SECURE_COOKIE=true`
    3. Asegurar que todo el tráfico se redirija a HTTPS
    4. Implementar HSTS (HTTP Strict Transport Security)
    5. Revisar configuración de reverse proxy (nginx/traefik) para headers de seguridad

---