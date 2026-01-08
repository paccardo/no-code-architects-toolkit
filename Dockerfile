# Base image
FROM python:3.10-slim

# Install system dependencies and FFmpeg (Pre-built version)
# We add generic font libraries and essential tools here
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    fonts-liberation \
    fontconfig \
    git \
    && rm -rf /var/lib/apt/lists/*

# Copy fonts into the custom fonts directory
COPY ./fonts /usr/share/fonts/custom

# Rebuild the font cache so that fontconfig can see the custom fonts
RUN fc-cache -f -v

# Set work directory
WORKDIR /app

# Set environment variable for Whisper cache
ENV WHISPER_CACHE_DIR="/app/whisper_cache"
RUN mkdir -p ${WHISPER_CACHE_DIR}

# Copy the requirements file
COPY requirements.txt .

# Install Python dependencies
# Note: We assume requirements.txt is already cleaned up (CPU-only torch)
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Create the appuser and give permissions
RUN useradd -m appuser && \
    chown -R appuser:appuser /app

# Switch to the appuser
USER appuser

# Download the Whisper model during build to save time later
RUN python -c "import os; import whisper; whisper.load_model('base')"

# Install Playwright Chromium browser as appuser
RUN playwright install chromium

# Copy the rest of the application code
COPY --chown=appuser:appuser . .

# Expose the port
EXPOSE 8080

# Set environment variables
ENV PYTHONUNBUFFERED=1

# Create the startup script
RUN echo '#!/bin/bash\n\
gunicorn --bind 0.0.0.0:8080 \
    --workers ${GUNICORN_WORKERS:-2} \
    --timeout ${GUNICORN_TIMEOUT:-300} \
    --worker-class sync \
    --keep-alive 80 \
    --config gunicorn.conf.py \
    app:app' > /app/run_gunicorn.sh && \
    chmod +x /app/run_gunicorn.sh

# Run the shell script
CMD ["/app/run_gunicorn.sh"]
