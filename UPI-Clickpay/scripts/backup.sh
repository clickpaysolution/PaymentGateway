#!/bin/bash

set -e

# Configuration
BACKUP_DIR="/backup"
DATE=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=${BACKUP_RETENTION_DAYS:-30}

# Database configuration
DB_HOST=${DB_HOST:-postgres}
DB_NAME=${DB_NAME:-payment_gateway}
DB_USER=${DB_USER:-pguser}

echo "🗄️ Starting database backup..."

# Create backup directory
mkdir -p "$BACKUP_DIR/$DATE"

# Database backup
echo "📊 Backing up PostgreSQL database..."
pg_dump -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" --no-password > "$BACKUP_DIR/$DATE/database.sql"

# Compress backup
echo "🗜️ Compressing backup..."
gzip "$BACKUP_DIR/$DATE/database.sql"

# Create backup metadata
cat > "$BACKUP_DIR/$DATE/metadata.json" << EOF
{
  "timestamp": "$(date -Iseconds)",
  "database": "$DB_NAME",
  "host": "$DB_HOST",
  "user": "$DB_USER",
  "backup_type": "full",
  "compressed": true
}
EOF

echo "✅ Database backup completed: $BACKUP_DIR/$DATE/"

# Cleanup old backups
echo "🧹 Cleaning up old backups (older than $RETENTION_DAYS days)..."
find "$BACKUP_DIR" -type d -name "20*" -mtime +$RETENTION_DAYS -exec rm -rf {} + 2>/dev/null || true

# Upload to S3 if configured
if [ -n "$AWS_ACCESS_KEY_ID" ] && [ -n "$BACKUP_S3_BUCKET" ]; then
    echo "☁️ Uploading backup to S3..."
    
    # Install AWS CLI if not present
    if ! command -v aws &> /dev/null; then
        apk add --no-cache aws-cli
    fi
    
    # Upload backup
    aws s3 cp "$BACKUP_DIR/$DATE/" "s3://$BACKUP_S3_BUCKET/backups/$DATE/" --recursive
    
    echo "✅ Backup uploaded to S3: s3://$BACKUP_S3_BUCKET/backups/$DATE/"
fi

echo "🎉 Backup process completed successfully!"