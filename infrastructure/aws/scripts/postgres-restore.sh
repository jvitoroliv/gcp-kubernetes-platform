#!/bin/bash

# PostgreSQL Database Restore Script
# Restores databases from backup to RDS instance

set -e

# Configuration
BACKUP_DIR=""
RDS_ENDPOINT=""
RDS_PASSWORD=""
PG_USER="postgres"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Usage function
usage() {
    echo "Usage: $0 -b <backup_dir> [-e <rds_endpoint>] [-p <password>]"
    echo "  -b: Backup directory containing SQL dumps"
    echo "  -e: RDS endpoint (optional - will fetch from SSM if not provided)"
    echo "  -p: RDS password (optional - will fetch from SSM if not provided)"
    echo "  -h: Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 -b /tmp/gameplatform-backups/20240907_143000"
    echo "  $0 -b /tmp/gameplatform-backups/20240907_143000 -e my-rds.amazonaws.com -p mypassword"
    exit 1
}

# Parse command line arguments
while getopts "b:e:p:h" opt; do
    case $opt in
        b) BACKUP_DIR="$OPTARG" ;;
        e) RDS_ENDPOINT="$OPTARG" ;;
        p) RDS_PASSWORD="$OPTARG" ;;
        h) usage ;;
        *) usage ;;
    esac
done

# Validate required parameters
if [[ -z "$BACKUP_DIR" ]]; then
    echo -e "${RED}Error: Backup directory is required${NC}"
    usage
fi

if [[ ! -d "$BACKUP_DIR" ]]; then
    echo -e "${RED}Error: Backup directory $BACKUP_DIR does not exist${NC}"
    exit 1
fi

echo -e "${GREEN}Starting PostgreSQL restore process...${NC}"
echo -e "${YELLOW}Backup directory: $BACKUP_DIR${NC}"

# Get RDS connection details from SSM if not provided
if [[ -z "$RDS_ENDPOINT" ]]; then
    echo -e "${BLUE}Fetching RDS endpoint from SSM...${NC}"
    RDS_ENDPOINT=$(aws ssm get-parameter --name "/dev/postgres/endpoint" --query "Parameter.Value" --output text 2>/dev/null) || {
        echo -e "${RED}Error: Could not fetch RDS endpoint from SSM${NC}"
        echo "Please provide RDS endpoint with -e parameter or ensure SSM parameter exists"
        exit 1
    }
fi

if [[ -z "$RDS_PASSWORD" ]]; then
    echo -e "${BLUE}Fetching RDS password from SSM...${NC}"
    RDS_PASSWORD=$(aws ssm get-parameter --name "/dev/postgres/master-password" --with-decryption --query "Parameter.Value" --output text 2>/dev/null) || {
        echo -e "${RED}Error: Could not fetch RDS password from SSM${NC}"
        echo "Please provide RDS password with -p parameter or ensure SSM parameter exists"
        exit 1
    }
fi

echo -e "${YELLOW}RDS Endpoint: $RDS_ENDPOINT${NC}"

# Test RDS connectivity
echo -e "${BLUE}Testing RDS connectivity...${NC}"
export PGPASSWORD="$RDS_PASSWORD"
if ! psql -h "$RDS_ENDPOINT" -U "$PG_USER" -d postgres -c "SELECT 1;" > /dev/null 2>&1; then
    echo -e "${RED}Error: Cannot connect to RDS instance${NC}"
    echo "Please verify:"
    echo "- RDS instance is running and accessible"
    echo "- Security groups allow connections from your IP"
    echo "- Credentials are correct"
    exit 1
fi
echo -e "${GREEN}RDS connectivity verified${NC}"

# Load manifest if available
if [[ -f "$BACKUP_DIR/manifest.txt" ]]; then
    echo -e "${BLUE}Loading backup manifest...${NC}"
    grep "Databases Found:" -A 10 "$BACKUP_DIR/manifest.txt"
fi

# Verify checksums if available
if [[ -f "$BACKUP_DIR/checksums.sha256" ]]; then
    echo -e "${BLUE}Verifying backup integrity...${NC}"
    cd "$BACKUP_DIR"
    if sha256sum -c checksums.sha256 > /dev/null 2>&1; then
        echo -e "${GREEN}Backup integrity verified${NC}"
    else
        echo -e "${YELLOW}Warning: Checksum verification failed, proceeding anyway${NC}"
    fi
fi

# Get list of database dumps
DATABASE_DUMPS=($(ls "$BACKUP_DIR"/*-data.sql 2>/dev/null | xargs -n1 basename -s -data.sql 2>/dev/null || true))

if [[ ${#DATABASE_DUMPS[@]} -eq 0 ]]; then
    echo -e "${RED}Error: No database dumps found in $BACKUP_DIR${NC}"
    echo "Looking for files matching pattern: *-data.sql"
    exit 1
fi

echo -e "${GREEN}Found databases to restore:${NC}"
for db in "${DATABASE_DUMPS[@]}"; do
    size=$(du -h "$BACKUP_DIR/${db}-data.sql" | cut -f1)
    echo -e "  - $db (size: $size)"
done

# Confirm restoration
read -p "Do you want to proceed with restoring ${#DATABASE_DUMPS[@]} databases? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Restore cancelled${NC}"
    exit 0
fi

# Create databases if they don't exist
echo -e "${BLUE}Ensuring target databases exist...${NC}"
for db in "${DATABASE_DUMPS[@]}"; do
    echo -e "${YELLOW}Checking database: $db${NC}"
    
    # Check if database exists
    if psql -h "$RDS_ENDPOINT" -U "$PG_USER" -d postgres -t -c "SELECT 1 FROM pg_database WHERE datname = '$db'" | grep -q 1; then
        echo -e "${GREEN}Database $db already exists${NC}"
        read -p "Drop and recreate database $db? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}Dropping and recreating database $db${NC}"
            psql -h "$RDS_ENDPOINT" -U "$PG_USER" -d postgres -c "DROP DATABASE IF EXISTS $db;"
            psql -h "$RDS_ENDPOINT" -U "$PG_USER" -d postgres -c "CREATE DATABASE $db;"
        else
            echo -e "${YELLOW}Skipping recreation, will append to existing database${NC}"
        fi
    else
        echo -e "${YELLOW}Creating database $db${NC}"
        psql -h "$RDS_ENDPOINT" -U "$PG_USER" -d postgres -c "CREATE DATABASE $db;"
    fi
done

# Restore databases
echo -e "${GREEN}Starting database restoration...${NC}"
for db in "${DATABASE_DUMPS[@]}"; do
    echo -e "${BLUE}Restoring database: $db${NC}"
    
    start_time=$(date +%s)
    
    if psql -h "$RDS_ENDPOINT" -U "$PG_USER" -d "$db" < "$BACKUP_DIR/${db}-data.sql"; then
        end_time=$(date +%s)
        duration=$((end_time - start_time))
        echo -e "${GREEN}Successfully restored $db (${duration}s)${NC}"
    else
        echo -e "${RED}Error restoring $db${NC}"
        echo "Check the logs above for details"
        exit 1
    fi
done

# Validation
echo -e "${GREEN}Performing post-restore validation...${NC}"
for db in "${DATABASE_DUMPS[@]}"; do
    echo -e "${BLUE}Validating database: $db${NC}"
    
    # Count tables
    table_count=$(psql -h "$RDS_ENDPOINT" -U "$PG_USER" -d "$db" -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" | tr -d ' ')
    echo -e "  Tables: $table_count"
    
    # Get largest tables
    echo -e "  Largest tables:"
    psql -h "$RDS_ENDPOINT" -U "$PG_USER" -d "$db" -c "
    SELECT 
        schemaname,
        tablename,
        pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size,
        pg_size_pretty(pg_relation_size(schemaname||'.'||tablename)) as table_size
    FROM pg_tables 
    WHERE schemaname = 'public'
    ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC 
    LIMIT 5;
    " -t | sed 's/^/    /'
done

# Create restore report
REPORT_FILE="$BACKUP_DIR/restore-report-$(date +%Y%m%d_%H%M%S).txt"
echo -e "${GREEN}Creating restore report...${NC}"

cat > "$REPORT_FILE" << EOF
PostgreSQL Restore Report
========================
Restore Date: $(date)
Source Backup: $BACKUP_DIR
Target RDS: $RDS_ENDPOINT
Restored Databases: ${DATABASE_DUMPS[*]}

Restoration Summary:
EOF

for db in "${DATABASE_DUMPS[@]}"; do
    table_count=$(psql -h "$RDS_ENDPOINT" -U "$PG_USER" -d "$db" -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" | tr -d ' ')
    echo "- $db: $table_count tables restored" >> "$REPORT_FILE"
done

echo -e "${GREEN}Restore completed successfully!${NC}"
echo -e "${YELLOW}Restore report: $REPORT_FILE${NC}"

# Display connection string for applications
CONNECTION_STRING="postgresql://$PG_USER:${RDS_PASSWORD}@${RDS_ENDPOINT}/"
echo -e "${GREEN}Connection strings for applications:${NC}"
for db in "${DATABASE_DUMPS[@]}"; do
    echo -e "  $db: ${YELLOW}postgresql://$PG_USER:[PASSWORD]@${RDS_ENDPOINT}/$db${NC}"
done

echo -e "${GREEN}Next steps:${NC}"
echo -e "1. Update application configuration to use RDS endpoints"
echo -e "2. Test application connectivity and functionality"
echo -e "3. Monitor RDS performance and adjust instance size if needed"
echo -e "4. Set up automated backups and monitoring"

unset PGPASSWORD