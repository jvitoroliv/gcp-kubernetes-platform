# PostgreSQL RDS Validation Guide

## Testing Commands for Infrastructure Deployment

### 1. Deploy RDS Infrastructure via Atlantis

```bash
# Navigate to shared-infrastructure repository
cd /GamePlatform/Repos/gameplatform-shared-infrastructure

# Verify all files are in place
ls -la stacks/postgres/
ls -la environments/dev/postgres*

# Add and commit all changes
git add .
git commit -m "feat: Add PostgreSQL RDS infrastructure

- Add RDS Terraform module with comprehensive configuration
- Add postgres stack with SSM parameter integration  
- Configure Atlantis project and workflow for postgres-dev
- Add database migration and restore scripts
- Enable deletion protection and performance insights"

git push origin main
```

### 2. Execute Atlantis Deployment

```bash
# Plan the deployment (via comment on PR or direct command)
# If using Atlantis UI: https://atlantis.dev.gameplatform.click
atlantis plan -d stacks/postgres -p postgres-dev

# Review the plan output and apply
atlantis apply -d stacks/postgres -p postgres-dev
```

### 3. Validate Infrastructure Deployment

```bash
# Check RDS instance status
aws rds describe-db-instances \
  --db-instance-identifier $(aws rds describe-db-instances --query 'DBInstances[?contains(DBInstanceIdentifier, `dev-postgres`)].DBInstanceIdentifier' --output text) \
  --query 'DBInstances[0].[DBInstanceIdentifier,DBInstanceStatus,Endpoint.Address,Engine,EngineVersion]' \
  --output table

# Verify SSM parameters were created
aws ssm get-parameters \
  --names "/dev/postgres/endpoint" "/dev/postgres/master-password" "/dev/postgres/connection-string" \
  --query 'Parameters[*].[Name,Type]' \
  --output table

# Test SSM parameter retrieval (endpoint should be visible)
aws ssm get-parameter --name "/dev/postgres/endpoint" --query "Parameter.Value" --output text

# Verify security group allows ECS access
export RDS_SG_ID=$(aws rds describe-db-instances --query 'DBInstances[?contains(DBInstanceIdentifier, `dev-postgres`)].VpcSecurityGroups[0].VpcSecurityGroupId' --output text)
aws ec2 describe-security-groups --group-ids $RDS_SG_ID --query 'SecurityGroups[0].IpPermissions' --output table
```

### 4. Database Connectivity Testing

```bash
# Set up environment variables
export RDS_ENDPOINT=$(aws ssm get-parameter --name "/dev/postgres/endpoint" --query "Parameter.Value" --output text)
export RDS_PASSWORD=$(aws ssm get-parameter --name "/dev/postgres/master-password" --with-decryption --query "Parameter.Value" --output text)

# Test connectivity from local machine (requires network access)
export PGPASSWORD=$RDS_PASSWORD
psql -h $RDS_ENDPOINT -U postgres -d postgres -c "SELECT version(), current_database(), current_user;"

# Check available databases
psql -h $RDS_ENDPOINT -U postgres -d postgres -c "\l"

# Verify parameter group settings
psql -h $RDS_ENDPOINT -U postgres -d postgres -c "SHOW max_connections; SHOW log_min_duration_statement;"
```

### 5. Migration Testing

```bash
# Create backup of current local database
./scripts/postgres-dump.sh

# Find the latest backup directory
LATEST_BACKUP=$(ls -t /tmp/gameplatform-backups/ | head -1)
echo "Latest backup: /tmp/gameplatform-backups/$LATEST_BACKUP"

# Review backup contents
cat "/tmp/gameplatform-backups/$LATEST_BACKUP/manifest.txt"

# Test restore to RDS (this will actually restore data)
./scripts/postgres-restore.sh -b "/tmp/gameplatform-backups/$LATEST_BACKUP"
```

### 6. Validate Migration Success

```bash
# Compare database schemas between source and target
echo "=== Local Database Schema ==="
docker exec gameplatform-local-postgres-1 psql -U postgres -d gameplatform -c "\dt"

echo "=== RDS Database Schema ==="
psql -h $RDS_ENDPOINT -U postgres -d gameplatform -c "\dt"

# Compare row counts for key tables
echo "=== Row Count Comparison ==="
echo "Local gameplatform_world table:"
docker exec gameplatform-local-postgres-1 psql -U postgres -d gameplatform -c "SELECT count(*) FROM gameplatform_world;" 2>/dev/null || echo "Table not found"

echo "RDS gameplatform_world table:"
psql -h $RDS_ENDPOINT -U postgres -d gameplatform -c "SELECT count(*) FROM gameplatform_world;" 2>/dev/null || echo "Table not found"

# Test Nakama database
echo "Local nakama database tables:"
docker exec gameplatform-local-postgres-1 psql -U postgres -d nakama -c "\dt"

echo "RDS nakama database tables:"
psql -h $RDS_ENDPOINT -U postgres -d nakama -c "\dt"
```

### 7. Application Configuration Update

```bash
# Generate new connection strings for applications
echo "=== Connection Strings for Application Update ==="
echo "AFS Database URL:"
echo "postgresql://postgres:$RDS_PASSWORD@$RDS_ENDPOINT/gameplatform"

echo "AHSAT Database URL:"  
echo "postgresql://postgres:$RDS_PASSWORD@$RDS_ENDPOINT/gameplatform"

echo "Nakama Database URL:"
echo "postgresql://postgres:$RDS_PASSWORD@$RDS_ENDPOINT/nakama"

echo "=== Environment Variables ==="
echo "DATABASE_URL=postgresql://postgres:$RDS_PASSWORD@$RDS_ENDPOINT/gameplatform"
echo "NAKAMA_DATABASE_URL=postgresql://postgres:$RDS_PASSWORD@$RDS_ENDPOINT/nakama"
```

### 8. Performance and Monitoring Validation

```bash
# Check RDS monitoring is enabled
aws rds describe-db-instances \
  --query 'DBInstances[?contains(DBInstanceIdentifier, `dev-postgres`)][DBInstanceIdentifier,MonitoringInterval,PerformanceInsightsEnabled]' \
  --output table

# Verify CloudWatch log groups exist
aws logs describe-log-groups --log-group-name-prefix "/aws/rds/instance/dev-postgres" --query 'logGroups[*].logGroupName'

# Check backup configuration
aws rds describe-db-instances \
  --query 'DBInstances[?contains(DBInstanceIdentifier, `dev-postgres`)][BackupRetentionPeriod,PreferredBackupWindow,PreferredMaintenanceWindow]' \
  --output table
```

### 9. Cost Validation

```bash
# Estimate monthly costs (requires AWS Pricing Calculator or manual calculation)
echo "=== RDS Cost Estimation ==="
echo "Instance Type: db.t3.micro"
echo "Storage: 20GB GP3 (expandable to 100GB)"
echo "Backup: 7 days retention"
echo "Multi-AZ: Disabled (single AZ for dev)"
echo "Estimated monthly cost: ~\$15-25 USD for development usage"
```

### 10. Cleanup Testing (Optional - Destructive)

```bash
# Test infrastructure destruction (WARNING: This will delete the RDS instance)
# Only run this if you want to test the full lifecycle

# Plan destruction
atlantis plan -d stacks/postgres -p postgres-dev -- -destroy

# Execute destruction (removes all RDS infrastructure)
atlantis apply -d stacks/postgres -p postgres-dev -- -destroy

# Verify cleanup
aws rds describe-db-instances --query 'DBInstances[?contains(DBInstanceIdentifier, `dev-postgres`)]' --output table
aws ssm get-parameters --names "/dev/postgres/endpoint" --output table 2>/dev/null || echo "SSM parameters cleaned up"
```

## Expected Results

### Successful Deployment Indicators:
- ✅ RDS instance status: `available`
- ✅ SSM parameters created and accessible
- ✅ Security groups allow ECS connectivity
- ✅ Database connectivity from local machine works
- ✅ Migration scripts execute without errors
- ✅ Application connection strings work

### Performance Baselines:
- **Connection Time**: < 100ms within VPC
- **Query Response**: Simple SELECT < 10ms  
- **Backup Window**: Daily during 03:00-04:00 UTC
- **Maintenance Window**: Sunday 04:00-05:00 UTC

### Cost Expectations:
- **Monthly Est**: $15-25 USD for db.t3.micro + 20GB storage
- **Scaling**: Auto-scaling storage up to 100GB
- **Backup Cost**: ~$1-2 USD for 7-day retention

## Troubleshooting Common Issues

### Connection Failures:
```bash
# Check security group rules
aws ec2 describe-security-groups --group-ids $RDS_SG_ID

# Verify VPC and subnet configuration  
aws rds describe-db-instances --query 'DBInstances[0].[DBSubnetGroup.VpcId,DBSubnetGroup.Subnets[*].SubnetIdentifier]'
```

### Performance Issues:
```bash
# Monitor CPU and connections
aws cloudwatch get-metric-statistics --namespace AWS/RDS --metric-name CPUUtilization --dimensions Name=DBInstanceIdentifier,Value=dev-postgres-xxx --start-time 2024-01-01T00:00:00Z --end-time 2024-01-01T01:00:00Z --period 300 --statistics Average
```

### Backup/Restore Failures:
```bash
# Check backup status
aws rds describe-db-snapshots --db-instance-identifier dev-postgres-xxx --output table

# Manual backup creation
aws rds create-db-snapshot --db-instance-identifier dev-postgres-xxx --db-snapshot-identifier manual-backup-$(date +%Y%m%d)
```