#!/bin/bash

# Load environment variables from .env file
set -a
source .env
set +a

DB_CONTAINER="postgresql_instance"
DOCMOST_CONTAINER="docmost_instance"

# Backup database
docker exec -i "$DB_CONTAINER" /bin/bash -c "PGPASSWORD=$PGPASSWORD pg_dump --username=docmost docmost" > dump.sql

# Backup data folder
docker cp "$DOCMOST_CONTAINER":/app/data .

# Create backup archive using tar
BACKUP_FILENAME="docmost_backup_$(date +"%Y%m%d").tar.gz"
tar -czf "$BACKUP_FILENAME" dump.sql data

# Clean up temporary files
rm -rf data dump.sql

echo "Backup completed: $BACKUP_FILENAME"

rclone copy $BACKUP_FILENAME $RCLONE_REMOTE_NAME:$PROTON_DRIVE_BACKUP_DIRECTORY