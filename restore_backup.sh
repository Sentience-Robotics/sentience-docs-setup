#!/bin/bash

# Load environment variables from .env file
set -a
source .env
set +a

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <backup.tar.gz>"
    exit 1
fi

BACKUP_ARCHIVE=$1
BACKUP_DIR="backup_extract"
DATA_DIR="data"
DUMP_FILE="dump.sql"
DB_CONTAINER="postgresql_instance"
DOCMOST_CONTAINER="docmost_instance"

if [ ! -f "$BACKUP_ARCHIVE" ]; then
    echo "Erreur : le fichier $BACKUP_ARCHIVE n'existe pas."
    exit 1
fi

mkdir -p "$BACKUP_DIR"
tar -xzf "$BACKUP_ARCHIVE" -C "$BACKUP_DIR"

if [ ! -f "$BACKUP_DIR/$DUMP_FILE" ] || [ ! -d "$BACKUP_DIR/$DATA_DIR" ]; then
    echo "Erreur : l'archive ne contient pas $DUMP_FILE et/ou le dossier $DATA_DIR."
    rm -rf "$BACKUP_DIR"
    exit 1
fi

echo "Réinitialisation du schéma public..."
docker exec -it $DB_CONTAINER psql -U docmost -d docmost -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"

# Copie du dossier data vers le container
echo "Copie des données dans le container..."
docker cp "$BACKUP_DIR/$DATA_DIR" "$DOCMOST_CONTAINER":/app/

# Restauration de la base de données
echo "Restauration de la base de données..."
cat "$BACKUP_DIR/$DUMP_FILE" | docker exec -i $DB_CONTAINER psql -U docmost -d docmost

rm -rf "$BACKUP_DIR"

echo "Restauration terminée avec succès."
