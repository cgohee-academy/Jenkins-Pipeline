FROM python:3.11-slim

# avoid prompts, set working dir
ENV DEBIAN_FRONTEND=noninteractive
WORKDIR /app
ENV PYTHONUNBUFFERED=1

# Install system deps (include curl for HEALTHCHECK), build deps for MySQL client
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    default-libmysqlclient-dev \
    build-essential \
    pkg-config \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install Python deps
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Create non-root user and fix permissions
RUN useradd --create-home --shell /bin/bash app \
    && chown -R app:app /app
USER app

EXPOSE 5000

# Healthcheck: use curl (installed above)
HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
  CMD curl -f http://127.0.0.1:5000/api/todos || exit 1

CMD ["python", "app.py"]
