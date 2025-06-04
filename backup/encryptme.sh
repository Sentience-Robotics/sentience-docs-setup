#!/bin/bash

# Public key for age
ENCRYPT_PUB_KEY="age15n7dqegjzk8lkr7v460chdz84l0mvl9rfx36vuwmmr73sqlj7skqpnkz3j"

# Directory containing your backups (adjust as needed)
BACKUP_DIR="./"
DEST_DIR="/mnt/hetzner/docmost-backups"

# Loop through each .tar.gz file in the backup directory
for BACKUP_FILE in "$BACKUP_DIR"/*.tar.gz; do
    [ -e "$BACKUP_FILE" ] || continue  # skip if no matches

    # Build encrypted filename
    BACKUP_FILENAME=$(basename "$BACKUP_FILE")
    ENCRYPTED_FILE="$BACKUP_FILE.age"

    echo "Encrypting: $BACKUP_FILENAME"
    age -r "$ENCRYPT_PUB_KEY" -o "$ENCRYPTED_FILE" "$BACKUP_FILE"

    echo "Copying to Hetzner with rsync..."
    rsync --progress --inplace --checksum "$ENCRYPTED_FILE" "$DEST_DIR/" && rm "$ENCRYPTED_FILE"
done
