# Use a slim Python base image
FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
# Build context is backend/ so this path works
COPY requirements.txt /app/
RUN pip install --no-cache-dir -r requirements.txt

# Copy ONLY the services/ files individually (not the whole backend/)
COPY services/__init__.py /app/
COPY services/firestore_client.py /app/
COPY auth.py /app/
COPY services/main.py /app/

# Copy scraper modules so main.py can import them
COPY scrapers/webscraping_and_firestore /app/scrapers/webscraping_and_firestore/

# Cloud Run port
ENV PORT=8080
EXPOSE 8080

# WORKDIR is /app, main.py is at /app/main.py
# sys.path in main.py points to /app/scrapers/webscraping_and_firestore/
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]