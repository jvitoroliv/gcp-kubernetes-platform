# PostgreSQL Migration Guide

## Overview
This guide provides step-by-step instructions for migrating from EC2-based PostgreSQL to AWS RDS PostgreSQL.

## Prerequisites
- Access to current PostgreSQL instance (localhost:5433)
- AWS CLI configured with appropriate permissions
- RDS instance deployed via Atlantis

## Migration Steps

### 1. Get RDS Connection Details
After deployment, retrieve RDS connection details from SSM:
```bash
# Get RDS endpoint
aws ssm get-parameter --name "/dev/postgres/endpoint" --query "Parameter.Value" --output text

# Get connection string (encrypted)
aws ssm get-parameter --name "/dev/postgres/connection-string" --with-decryption --query "Parameter.Value" --output text

# Get master password (encrypted)
aws ssm get-parameter --name "/dev/postgres/master-password" --with-decryption --query "Parameter.Value" --output text
```

### 2. Export Current Database
Export all databases from current PostgreSQL instance:
```bash
# Full database cluster dump (includes roles and global objects)
docker exec backend_postgres pg_dumpall -U postgres > /tmp/gameplatform-full-dump.sql

# Individual database dumps (recommended for selective restore)
docker exec backend_postgres pg_dump -U postgres -d nakama > /tmp/nakama-db.sql
docker exec backend_postgres pg_dump -U postgres -d postgres > /tmp/postgres-db.sql

# Schema-only dumps for structure validation
docker exec backend_postgres pg_dump -U postgres -d nakama --schema-only > /tmp/nakama-schema.sql

# Verify dump sizes and content
echo "Dump created successfully:"
ls -lh /tmp/nakama-*
echo "Nakama database contains $(grep -c "CREATE TABLE" /tmp/nakama-schema.sql) tables"
```

### 3. Prepare RDS Instance
```bash
# Set environment variables from SSM parameters
export RDS_ENDPOINT=$(aws ssm get-parameter --name "/dev/postgres/endpoint" --query "Parameter.Value" --output text)
export RDS_PASSWORD=$(aws ssm get-parameter --name "/dev/postgres/master-password" --with-decryption --query "Parameter.Value" --output text)

# Test RDS connectivity
psql -h $RDS_ENDPOINT -U postgres -d postgres -c "SELECT version();"

# Create required extensions (based on current nakama database)
psql -h $RDS_ENDPOINT -U postgres -d nakama -c "CREATE EXTENSION IF NOT EXISTS pgcrypto;"
psql -h $RDS_ENDPOINT -U postgres -d nakama -c "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\";"
```

### 4. Restore Data to RDS
```bash
# Restore full dump (alternative approach)
psql -h $RDS_ENDPOINT -U postgres -d postgres < /tmp/gameplatform-full-dump.sql

# OR restore individual databases (recommended)
psql -h $RDS_ENDPOINT -U postgres -d gameplatform < /tmp/gameplatform-db.sql
psql -h $RDS_ENDPOINT -U postgres -d nakama < /tmp/nakama-db.sql
```

### 5. Validate Migration
```bash
# Compare table counts
echo "Source database:"
docker exec gameplatform-local-postgres-1 psql -U postgres -d gameplatform -c "\dt"
docker exec gameplatform-local-postgres-1 psql -U postgres -d nakama -c "\dt"

echo "Target RDS:"
psql -h $RDS_ENDPOINT -U postgres -d gameplatform -c "\dt"
psql -h $RDS_ENDPOINT -U postgres -d nakama -c "\dt"

# Verify row counts for key tables
psql -h $RDS_ENDPOINT -U postgres -d gameplatform -c "SELECT 'gameplatform_world' as table_name, count(*) FROM gameplatform_world UNION ALL SELECT 'gameplatform_world_instance' as table_name, count(*) FROM gameplatform_world_instance;"
```

### 6. Update Application Configuration
Update application connection strings to use RDS:
```bash
# Connection string format (password from SSM)
postgresql://postgres:${RDS_PASSWORD}@${RDS_ENDPOINT}/gameplatform
postgresql://postgres:${RDS_PASSWORD}@${RDS_ENDPOINT}/nakama
```

## Rollback Plan
If migration fails, applications can continue using existing EC2 PostgreSQL:
```bash
# Keep containers running
docker-compose -f applications/server/docker-compose.yml up -d postgres

# Validate local connectivity
curl http://localhost:5433
```

## Post-Migration Cleanup
After successful validation:
1. Stop EC2 PostgreSQL containers
2. Archive local database dumps
3. Update monitoring and backup procedures
4. Document new RDS endpoints for team

## Troubleshooting

### Connection Issues
```bash
# Check security groups allow connection from ECS
aws ec2 describe-security-groups --group-ids $(aws rds describe-db-instances --db-instance-identifier dev-postgres-xxx --query 'DBInstances[0].VpcSecurityGroups[0].VpcSecurityGroupId' --output text)

# Test network connectivity from ECS subnet
aws ec2 create-vpc-endpoint --vpc-id vpc-xxx --service-name com.amazonaws.us-east-1.rds
```

### Performance Issues
```bash
# Monitor RDS performance insights
aws rds describe-db-instances --db-instance-identifier dev-postgres-xxx --query 'DBInstances[0].PerformanceInsightsEnabled'

# Check connection pool settings
psql -h $RDS_ENDPOINT -U postgres -d postgres -c "SHOW max_connections;"
```