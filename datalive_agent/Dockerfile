# datalive_agent/Dockerfile - v3.0 FINAL

# --- Fase de Construcción (Builder) ---
# Usamos una imagen completa de Python para instalar dependencias,
# incluyendo las que podrían necesitar compilación.
FROM python:3.11-slim AS builder

WORKDIR /app

# Instalar poetry para una gestión de dependencias robusta
RUN pip install poetry

# Copiar solo los ficheros de definición de dependencias
COPY poetry.lock pyproject.toml ./

# --- ¡LA SOLUCIÓN! ---
# Le decimos a Poetry que cree el entorno virtual DENTRO de la carpeta del proyecto (/app/.venv)
RUN poetry config virtualenvs.in-project true

# Instalar dependencias de producción, sin las de desarrollo
RUN poetry install --no-root --without dev


# --- Fase Final (Runner) ---
# Usamos una imagen ligera de Python para la ejecución.
FROM python:3.11-slim

WORKDIR /app

# Copiar el entorno virtual con las dependencias desde la fase de construcción
# Ahora este comando encontrará la carpeta /app/.venv porque la línea anterior forzó su creación aquí.
COPY --from=builder /app/.venv /app/.venv

# Configurar el PATH para que incluya el entorno virtual
ENV PATH="/app/.venv/bin:$PATH"

# Copiar el código fuente de la aplicación
COPY ./src ./src

# Exponer el puerto en el que correrá la aplicación
EXPOSE 8000

# Comando para ejecutar la aplicación usando uvicorn
CMD ["uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8000"]