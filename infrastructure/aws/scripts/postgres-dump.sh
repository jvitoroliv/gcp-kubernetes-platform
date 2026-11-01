#!/bin/bash

# PostgreSQL Database Dump Script
# Creates backups of all databases from local PostgreSQL container

set -e

# Configuration
BACKUP_DIR="/tmp/gameplatform-backups/$(date +%Y%m%d_%H%M%S)"
CONTAINER_NAME="gameplatform-local-postgres-1"
PG_USER="postgres"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Starting PostgreSQL backup process...${NC}"

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Check if container is running
if ! docker ps --filter "name=$CONTAINER_NAME" --filter "status=running" | grep -q "$CONTAINER_NAME"; then
    echo -e "${RED}Error: Container $CONTAINER_NAME is not running${NC}"
    echo "Please start the container with: docker-compose up -d postgres"
    exit 1
fi

echo -e "${YELLOW}Backing up to: $BACKUP_DIR${NC}"

# Full cluster dump
echo -e "${GREEN}Creating full cluster dump...${NC}"
docker exec "$CONTAINER_NAME" pg_dumpall -U "$PG_USER" > "$BACKUP_DIR/full-cluster-dump.sql"

# Individual database dumps
echo -e "${GREEN}Creating individual database dumps...${NC}"

# Get list of databases (excluding templates and postgres system db)
DATABASES=$(docker exec "$CONTAINER_NAME" psql -U "$PG_USER" -t -c "SELECT datname FROM pg_database WHERE datname NOT IN ('template0', 'template1', 'postgres');" | tr -d ' ' | grep -v '^$')

for db in $DATABASES; do
    echo -e "${YELLOW}Dumping database: $db${NC}"
    
    # Data dump
    docker exec "$CONTAINER_NAME" pg_dump -U "$PG_USER" -d "$db" > "$BACKUP_DIR/${db}-data.sql"
    
    # Schema-only dump
    docker exec "$CONTAINER_NAME" pg_dump -U "$PG_USER" -d "$db" --schema-only > "$BACKUP_DIR/${db}-schema.sql"
    
    # Get table statistics
    docker exec "$CONTAINER_NAME" psql -U "$PG_USER" -d "$db" -c "
    SELECT 
        schemaname,
        tablename,
        n_tup_ins as inserts,
        n_tup_upd as updates,
        n_tup_del as deletes,
        n_live_tup as live_rows,
        n_dead_tup as dead_rows
    FROM pg_stat_user_tables 
    ORDER BY n_live_tup DESC;
    " > "$BACKUP_DIR/${db}-stats.txt"
done

# Create manifest file
echo -e "${GREEN}Creating backup manifest...${NC}"
cat > "$BACKUP_DIR/manifest.txt" << EOF
PostgreSQL Backup Manifest
=========================
Backup Date: $(date)
Container: $CONTAINER_NAME
PostgreSQL Version: $(docker exec "$CONTAINER_NAME" psql -U "$PG_USER" -t -c "SELECT version();" | head -1)

Files Created:
- full-cluster-dump.sql: Complete cluster dump (all databases, roles, etc.)
$(for db in $DATABASES; do echo "- ${db}-data.sql: Full data dump for $db database"; done)
$(for db in $DATABASES; do echo "- ${db}-schema.sql: Schema-only dump for $db database"; done)
$(for db in $DATABASES; do echo "- ${db}-stats.txt: Table statistics for $db database"; done)

Databases Found:
$DATABASES

Total Backup Size: $(du -sh "$BACKUP_DIR" | cut -f1)
EOF

# Calculate checksums
echo -e "${GREEN}Calculating checksums...${NC}"
cd "$BACKUP_DIR"
sha256sum *.sql *.txt > checksums.sha256

echo -e "${GREEN}Backup completed successfully!${NC}"
echo -e "${YELLOW}Backup location: $BACKUP_DIR${NC}"
echo -e "${YELLOW}Total size: $(du -sh "$BACKUP_DIR" | cut -f1)${NC}"

# Display quick stats
echo -e "${GREEN}Database Summary:${NC}"
for db in $DATABASES; do
    table_count=$(grep -c "CREATE TABLE" "$BACKUP_DIR/${db}-schema.sql" 2>/dev/null || echo "0")
    file_size=$(du -h "$BACKUP_DIR/${db}-data.sql" | cut -f1)
    echo -e "  $db: $table_count tables, $file_size"
done

echo -e "${GREEN}Next steps:${NC}"
echo -e "1. Review the manifest file: ${YELLOW}cat $BACKUP_DIR/manifest.txt${NC}"
echo -e "2. Verify checksums: ${YELLOW}cd $BACKUP_DIR && sha256sum -c checksums.sha256${NC}"
echo -e "3. Use the migration guide: ${YELLOW}cat /GamePlatform/Repos/gameplatform-shared-infrastructure/scripts/postgres-migration.md${NC}"