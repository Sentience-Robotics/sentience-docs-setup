#!/bin/bash
# Prompted by Dennis Kolpatzki (https://kolpatzki.de) and written by ChatGPT 4.0
# because I'm lazy and need fast solutions to first-world problems.
#docmost script to delete users because a official way is not implemented yet.

# 🚀 PostgreSQL & Docker-Container Configuration
DB_USER="docmost"
DB_NAME="docmost"
DB_CONTAINER="docmost-db-1"

# 📌 Email argument required
if [ -z "$1" ]; then
    echo "❌ Error: Please provide the email of the user to delete!"
    echo "📌 Example: ./delete_user.sh user@example.com"
    exit 1
fi
EMAIL="$1"

echo "🔍 Searching for user ID with email: $EMAIL ..."

# 🎯 Fetch user ID
USER_ID=$(docker exec -i $DB_CONTAINER psql -U $DB_USER -d $DB_NAME -t -A -c "
SELECT id FROM users WHERE email = '$EMAIL';
")

# Check if a user ID was found
if [ -z "$USER_ID" ]; then
    echo "❌ Error: No user found with the email '$EMAIL'!"
    exit 1
fi

echo "✅ User ID: $USER_ID"

# 🔍 Check for related entries in other tables
echo "🔍 Checking for related entries ..."

RELATED_DATA=$(docker exec -i $DB_CONTAINER psql -U $DB_USER -d $DB_NAME -t -A -c "
SELECT 'groups' AS table_name, id FROM groups WHERE creator_id = '$USER_ID'
UNION ALL
SELECT 'spaces', id FROM spaces WHERE creator_id = '$USER_ID'
UNION ALL
SELECT 'pages', id FROM pages WHERE creator_id = '$USER_ID'
UNION ALL
SELECT 'pages_last_updated', id FROM pages WHERE last_updated_by_id = '$USER_ID'
UNION ALL
SELECT 'pages_deleted', id FROM pages WHERE deleted_by_id = '$USER_ID'
UNION ALL
SELECT 'workspace_invitations', id FROM workspace_invitations WHERE invited_by_id = '$USER_ID';
")

if [ -n "$RELATED_DATA" ]; then
    echo "⚠️ WARNING: Related data found!"
    echo "$RELATED_DATA"
else
    echo "✅ No related data found."
fi

# 🛠 Set referenced entries to NULL to prevent foreign key errors
echo "🛠 Updating references to NULL ..."
docker exec -i $DB_CONTAINER psql -U $DB_USER -d $DB_NAME -c "
UPDATE groups SET creator_id = NULL WHERE creator_id = '$USER_ID';
UPDATE spaces SET creator_id = NULL WHERE creator_id = '$USER_ID';
UPDATE pages SET creator_id = NULL WHERE creator_id = '$USER_ID';
UPDATE pages SET last_updated_by_id = NULL WHERE last_updated_by_id = '$USER_ID';
UPDATE pages SET deleted_by_id = NULL WHERE deleted_by_id = '$USER_ID';
UPDATE workspace_invitations SET invited_by_id = NULL WHERE invited_by_id = '$USER_ID';
"

# 🗑 Delete user
echo "🗑 Deleting user with ID: $USER_ID ..."
docker exec -i $DB_CONTAINER psql -U $DB_USER -d $DB_NAME -c "
DELETE FROM users WHERE id = '$USER_ID';
"

# 🔄 Final check for remaining related data
echo "🔍 Final verification after deletion ..."
REMAINING_DATA=$(docker exec -i $DB_CONTAINER psql -U $DB_USER -d $DB_NAME -t -A -c "
SELECT 'groups' AS table_name, id FROM groups WHERE creator_id = '$USER_ID'
UNION ALL
SELECT 'spaces', id FROM spaces WHERE creator_id = '$USER_ID'
UNION ALL
SELECT 'pages', id FROM pages WHERE creator_id = '$USER_ID'
UNION ALL
SELECT 'pages_last_updated', id FROM pages WHERE last_updated_by_id = '$USER_ID'
UNION ALL
SELECT 'pages_deleted', id FROM pages WHERE deleted_by_id = '$USER_ID'
UNION ALL
SELECT 'workspace_invitations', id FROM workspace_invitations WHERE invited_by_id = '$USER_ID';
")

if [ -n "$REMAINING_DATA" ]; then
    echo "⚠️ WARNING: Some related data still exists after deletion!"
    echo "$REMAINING_DATA"
else
    echo "✅ User successfully deleted!"
fi
