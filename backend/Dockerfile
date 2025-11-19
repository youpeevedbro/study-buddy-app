# Use a slim Python base image
FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install system dependencies (keep lightweight)
RUN apt-get update && apt-get install -y --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY requirements.txt /app/
RUN pip install --no-cache-dir -r requirements.txt

# Copy backend code
COPY . /app

# Cloud Run will send traffic to this port
ENV PORT=8080

# Expose for local runs (optional)
EXPOSE 8080

# IMPORTANT:
# Cloud Run requires listening on 0.0.0.0 and the $PORT environment variable.
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]
