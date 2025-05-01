#!/bin/bash
# 1 May 2025
# By Antoine Esman (https://github.com/Arcod7) and Samuel Bruschet (https://github.com/sambrus)
# This is a script to restore a backup of your docmost instance.
# Source: https://github.com/Sentience-Robotics/sentience-docs-setup/tree/master/backup


echo "/!\\ Restoring backup will only work with the same docmost version it was saved on.\n You can still use your old backup with a recent docmost version by first restoring it in the old version and then upgrading docmost (it will migrate the database properly)"

# Load environment variables from .env file
set -a
source ../.env
set +a

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <backup.tar.gz>"
    exit 1
fi

BACKUP_ARCHIVE=$1
BACKUP_DIR="backup_extract"
DATA_DIR="data"
DUMP_FILE="dump.sql"

if [ ! -f "$BACKUP_ARCHIVE" ]; then
    echo "Error : the file $BACKUP_ARCHIVE does not exists."
    exit 1
fi

mkdir -p "$BACKUP_DIR"
tar -xzf "$BACKUP_ARCHIVE" -C "$BACKUP_DIR"

if [ ! -f "$BACKUP_DIR/$DUMP_FILE" ] || [ ! -d "$BACKUP_DIR/$DATA_DIR" ]; then
    echo "Error : sthe archive does not contain $DUMP_FILE and/or the folder $DATA_DIR."
    rm -rf "$BACKUP_DIR"
    exit 1
fi

echo "Resetting the public schema..."
docker exec -it $DB_CONTAINER_NAME psql -U docmost -d docmost -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"

echo "Copying data into the container..."
docker cp "$BACKUP_DIR/$DATA_DIR" "$DOCMOST_CONTAINER_NAME":/app/

echo "Restoring the database..."
cat "$BACKUP_DIR/$DUMP_FILE" | docker exec -i $DB_CONTAINER_NAME psql -U docmost -d docmost

rm -rf "$BACKUP_DIR"

echo "Restoration completed successfully"
