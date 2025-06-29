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