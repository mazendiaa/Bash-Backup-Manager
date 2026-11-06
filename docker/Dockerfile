FROM ubuntu:24.04

WORKDIR /app

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    bash \
    tar \
    cron \
    coreutils \
    findutils \
    && rm -rf /var/lib/apt/lists/*

COPY project1.sh /app/backup.sh

COPY docker/entrypoint.sh /app/entrypoint.sh	

RUN chmod +x /app/backup.sh /app/entrypoint.sh

ENV BACKUP_DIR=/app/backups

ENTRYPOINT ["/app/entrypoint.sh"]
