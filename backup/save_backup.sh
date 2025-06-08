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

cp -r "../"* $LOCAL_GIT_BACKUP_FOLDER
# Clean up temporary files
rm -rf data dump.sql version.txt

cd $LOCAL_GIT_BACKUP_FOLDER
git add -A

if ! git diff --cached --quiet; then
    git commit -m "backup"

    BACKUP_FILENAME="docmost_backup$BACKUP_EXTENSION"
    cd -
    cd $HOME
    tar $BACKUP_COMPRESSION $BACKUP_FILENAME -C backups .


    age -r $ENCRYPT_PUB_KEY -o "$BACKUP_FILENAME.age" $BACKUP_FILENAME
    rsync --progress --inplace --no-whole-file --checksum "$BACKUP_FILENAME.age" $MOUNTED_DRIVE_CONFIGURATION
    mv "$BACKUP_FILENAME.age" "$BACKUP_FILENAME.age.copy"
    rsync --progress --inplace --no-whole-file --checksum "$BACKUP_FILENAME.age.copy" $MOUNTED_DRIVE_CONFIGURATION
    rm "$BACKUP_FILENAME.age.copy"

    if [ "USE_RCLONE" = "true" ]; then
        rclone copy $BACKUP_FILENAME $RCLONE_REMOTE_NAME:$PROTON_DRIVE_BACKUP_DIRECTORY
        echo "Backup stored in Proton Drive"
    fi

    rm "$BACKUP_FILENAME"

else
    echo "Nothing to commit for $archive"
fi

echo "Backup completed: $BACKUP_FILENAME"
