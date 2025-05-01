#!/bin/bash
# 1 May 2025
# By Antoine Esman (https://github.com/Arcod7) and Samuel Bruschet (https://github.com/sambrus)
# This is a script to save a backup of your docmost instance because a official way is not implemented yet.
# Source: https://github.com/Sentience-Robotics/sentience-docs-setup/tree/master/backup

echo ""
echo ""
echo "-- Saving data in backup the $(date +"%d/%m") --"
echo ""

# Load environment variables from .env file
set -a
source ../.env
set +a

# Backup database
docker exec -i "$DB_CONTAINER_NAME" /bin/bash -c "PGPASSWORD=$PGPASSWORD pg_dump --username=docmost docmost" > dump.sql

# Backup data folder
docker cp "$DOCMOST_CONTAINER_NAME":/app/data .

# Create backup archive using tar
BACKUP_FILENAME="docmost_backup_$(date +"%Y-%m-%d").tar.gz"
tar -czf "$BACKUP_FILENAME" dump.sql data

# Clean up temporary files
rm -rf data dump.sql

echo "Backup completed: $BACKUP_FILENAME"
if [ "USE_RCLONE" = "true" ]; then
  rclone copy $BACKUP_FILENAME $RCLONE_REMOTE_NAME:$PROTON_DRIVE_BACKUP_DIRECTORY
  echo "Backup stored in Proton Drive"
fi
