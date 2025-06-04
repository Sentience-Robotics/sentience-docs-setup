#!/bin/bash
# 1 May 2025
# By Antoine Esman (https://github.com/Arcod7) and Samuel Bruschet (https://github.com/sambrus)
# This is a script to save a backup of your docmost instance because a official way is not implemented yet.
# Source: https://github.com/Sentience-Robotics/sentience-docs-setup/tree/master/backup

set -e

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

# Backup docmost version
echo $(docker compose images docmost | awk 'NR==2 {print $3}') > version.txt

# Create backup archive using tar
BACKUP_COMPRESSION="--zstd -cf"
BACKUP_EXTENSION=".tar.zst"
BACKUP_FILENAME="docmost_backup_$(date +"%Y-%m-%d")$BACKUP_EXTENSION"
tar $BACKUP_COMPRESSION "$BACKUP_FILENAME" dump.sql data version.txt

# Clean up temporary files
rm -rf data dump.sql version.txt

echo "Backup completed: $BACKUP_FILENAME"

age -r $ENCRYPT_PUB_KEY -o "$BACKUP_FILENAME.age" $BACKUP_FILENAME
rsync --progress --inplace --checksum "$BACKUP_FILENAME.age" $MOUNTED_DRIVE_CONFIGURATION && rm "$BACKUP_FILENAME.age"

if [ "USE_RCLONE" = "true" ]; then
  rclone copy $BACKUP_FILENAME $RCLONE_REMOTE_NAME:$PROTON_DRIVE_BACKUP_DIRECTORY
  echo "Backup stored in Proton Drive"
fi

OLD_DATE=$(date -d "1 month ago" +'%Y-%m-%d')
OLD_BACKUP_FILENAME="docmost_backup_${OLD_DATE}$BACKUP_EXTENSION"

# Delete the old file if it exists
if [ -f "$OLD_BACKUP_FILENAME" ]; then
    echo "Deleting old backup: $OLD_BACKUP_FILENAME"
    rm "$OLD_BACKUP_FILENAME"
else
    echo "Old backup not found: $OLD_BACKUP_FILENAME"
fi
