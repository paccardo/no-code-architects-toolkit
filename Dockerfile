# Base image
FROM python:3.10-slim

# Install system dependencies and FFmpeg
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    fonts-liberation \
    fontconfig \
    git \
    && rm -rf /var/lib/apt/lists/*

# Copy fonts and rebuild cache
COPY ./fonts /usr/share/fonts/custom
RUN fc-cache -f -v

# Set work directory
WORKDIR /app

# Copy requirements and install
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Create appuser and set permissions
RUN useradd -m appuser && \
    chown -R appuser:appuser /app

# Switch to the appuser
USER appuser

# Copy the rest of the application
COPY --chown=appuser:appuser . .

# Expose the port
EXPOSE 8080
ENV PYTHONUNBUFFERED=1

# Start the application directly with Gunicorn
CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--timeout", "300", "--workers", "1", "app:app"]
