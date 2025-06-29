# datalive_agent/Dockerfile

# --- Fase de Construcción (Builder) ---
# Usamos una imagen completa de Python para instalar dependencias,
# incluyendo las que podrían necesitar compilación.
FROM python:3.11-slim as builder

WORKDIR /app

# Instalar poetry para una gestión de dependencias robusta
RUN pip install poetry

# Copiar solo los ficheros de definición de dependencias
# Esto aprovecha el caché de Docker. Si estos ficheros no cambian,
# no se volverán a instalar las dependencias.
COPY poetry.lock pyproject.toml ./

# Instalar dependencias de producción, sin las de desarrollo
RUN poetry install --no-dev --no-root


# --- Fase Final (Runner) ---
# Usamos una imagen ligera de Python para la ejecución.
FROM python:3.11-slim

WORKDIR /app

# Copiar el entorno virtual con las dependencias desde la fase de construcción
COPY --from=builder /app/.venv /app/.venv

# Configurar el PATH para que incluya el entorno virtual
ENV PATH="/app/.venv/bin:$PATH"

# Copiar el código fuente de la aplicación
COPY ./src ./src

# Exponer el puerto en el que correrá la aplicación (leído desde el .env)
# La variable la pasará Docker Compose, pero es buena práctica declararla.
EXPOSE 8000

# Comando para ejecutar la aplicación usando uvicorn
# --host 0.0.0.0 es crucial para que sea accesible desde fuera del contenedor.
CMD ["uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8000"]