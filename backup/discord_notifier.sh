#!/bin/bash
# discord_notifier.sh - Handles Discord webhook notifications for the backup script

STATUS=$1
PHASE=$2

# Reliably find the directory where THIS script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load environment variables using the absolute path
set -a
source "$SCRIPT_DIR/../.env"
set +a

LOCAL_STATUS="✅ Success"
CLOUD_STATUS="✅ Success"
MODIFICATIONS="No new modifications."
COLOR=3066993 # Green
MESSAGE=""

# 1. Handle Error States
if [ "$STATUS" = "error" ]; then
    COLOR=15158332 # Red
    MESSAGE="$DISCORD_PING ⚠️ A problem occurred during the backup!"
    
    if [ "$PHASE" = "local" ]; then
        LOCAL_STATUS="❌ Failed"
        CLOUD_STATUS="⏭️ Skipped"
    elif [ "$PHASE" = "cloud" ]; then
        CLOUD_STATUS="❌ Failed"
    fi
else
    # 2. Handle Success State & Fetch Git Mods
    # Move to the git folder to check the last commit
    cd "$LOCAL_GIT_BACKUP_FOLDER" || exit
    
    # Get the files changed in the very last commit, replacing tabs with spaces to protect JSON
    RAW_MODS=$(git show --name-status --format="" | head -n 10 | tr '\t' ' ')
    
    # If the string isn't empty, format it safely
    if [ -n "$RAW_MODS" ]; then
        # Escape backslashes and quotes
        MODS_ESCAPED=$(echo "$RAW_MODS" | sed 's/\\/\\\\/g; s/"/\\"/g')
        # Safely replace physical line breaks with the literal characters \n
        MODS_ESCAPED="${MODS_ESCAPED//$'\n'/\\n}"
        
        # Add a trailing note if there are more than 10 files
        if [ "$(git show --name-status --format="" | wc -l)" -gt 10 ]; then
            MODS_ESCAPED="${MODS_ESCAPED}\\n... and other files."
        fi
        
        MODIFICATIONS="\`\`\`text\\n${MODS_ESCAPED}\\n\`\`\`"
    fi
fi

# 3. Build the Complex JSON Payload
JSON_PAYLOAD=$(cat <<EOF
{
  "content": "$MESSAGE",
  "embeds": [{
    "title": "📦 Docmost Backup Report",
    "color": $COLOR,
    "fields": [
      {"name": "💾 Local (Docker/Git)", "value": "$LOCAL_STATUS", "inline": true},
      {"name": "☁️ Cloud (Rclone)", "value": "$CLOUD_STATUS", "inline": true},
      {"name": "📝 Modifications", "value": "$MODIFICATIONS", "inline": false}
    ],
    "footer": {"text": "Backup from $(date +"%Y-%m-%d %H:%M")"}
  }]
}
EOF
)

# 4. The Safety Net: Send and verify HTTP response code
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "Content-Type: application/json" -d "$JSON_PAYLOAD" "$DISCORD_WEBHOOK_URL")

# If Discord rejects the payload (e.g., 400 Bad Request) or curl fails (000)
if [ "$HTTP_CODE" -ge 400 ] || [ "$HTTP_CODE" -eq 000 ]; then
    
    # Construct a barebones, mathematically guaranteed safe JSON string
    SAFE_PAYLOAD="{\"content\": \"$DISCORD_PING ⚠️ **Backup Script Notice:** The backup finished with status: **$STATUS**, but the detailed Discord report failed to send due to a formatting error.\"}"
    
    # Send the safe fallback
    curl -s -H "Content-Type: application/json" -d "$SAFE_PAYLOAD" "$DISCORD_WEBHOOK_URL" > /dev/null
fi
