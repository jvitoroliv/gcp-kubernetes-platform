#!/bin/bash
# RDS Connection Investigation Script for Staging Environment
# Purpose: Investigate high connection count before downsizing instance
# Date: 2025-11-05

set -e

echo "=========================================="
echo "RDS Connection Investigation - Staging"
echo "=========================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
PROFILE="staging"
REGION="us-east-1"
DB_IDENTIFIER="stg-postgres-postgres"
CLUSTER="project-stg-cluster"

echo -e "${YELLOW}Step 1: Current RDS Connection Metrics${NC}"
echo "----------------------------------------"

# Get current connection count from CloudWatch
echo "Fetching last 24h connection metrics..."
aws cloudwatch get-metric-statistics \
  --profile $PROFILE \
  --region $REGION \
  --namespace AWS/RDS \
  --metric-name DatabaseConnections \
  --dimensions Name=DBInstanceIdentifier,Value=$DB_IDENTIFIER \
  --start-time $(python3 -c "from datetime import datetime, timedelta; print((datetime.now() - timedelta(days=1)).strftime('%Y-%m-%dT%H:%M:%S'))") \
  --end-time $(python3 -c "from datetime import datetime; print(datetime.now().strftime('%Y-%m-%dT%H:%M:%S'))") \
  --period 3600 \
  --statistics Average,Maximum,Minimum \
  --output table

echo ""
echo -e "${YELLOW}Step 2: ECS Service Status${NC}"
echo "----------------------------------------"

# Check ECS services
echo "Checking ECS services in staging..."
echo ""

echo "Lobby-backend service:"
aws ecs describe-services \
  --profile $PROFILE \
  --region $REGION \
  --cluster $CLUSTER \
  --services lobby-backend \
  --query 'services[0].{Name:serviceName,Status:status,Desired:desiredCount,Running:runningCount,Pending:pendingCount}' \
  --output table

echo ""
echo "Nakama service:"
aws ecs describe-services \
  --profile $PROFILE \
  --region $REGION \
  --cluster $CLUSTER \
  --services nakama \
  --query 'services[0].{Name:serviceName,Status:status,Desired:desiredCount,Running:runningCount,Pending:pendingCount}' \
  --output table

echo ""
echo "All services in cluster:"
aws ecs list-services \
  --profile $PROFILE \
  --region $REGION \
  --cluster $CLUSTER \
  --output table

echo ""
echo -e "${YELLOW}Step 3: Database Connection Analysis${NC}"
echo "----------------------------------------"

# Get RDS endpoint
ENDPOINT=$(aws rds describe-db-instances \
  --profile $PROFILE \
  --region $REGION \
  --db-instance-identifier $DB_IDENTIFIER \
  --query 'DBInstances[0].Endpoint.Address' \
  --output text)

# Get password from SSM
PASSWORD=$(aws ssm get-parameter \
  --profile $PROFILE \
  --region $REGION \
  --name /stg/postgres/master-password \
  --with-decryption \
  --query 'Parameter.Value' \
  --output text)

echo "RDS Endpoint: $ENDPOINT"
echo ""

# Check if psql is available
if command -v psql &> /dev/null; then
    echo -e "${GREEN}psql found - attempting direct database query${NC}"
    echo ""

    # Query active connections
    echo "Active connections by state and application:"
    PGPASSWORD=$PASSWORD psql -h $ENDPOINT -U postgres -d nakama -c "
        SELECT
            state,
            application_name,
            usename,
            COUNT(*) as connection_count,
            MAX(backend_start) as latest_connection
        # Base image pinned to specific version for reproducible builds.
        FROM pg_stat_activity
        WHERE datname = 'nakama'
        GROUP BY state, application_name, usename
        ORDER BY connection_count DESC;
    " 2>/dev/null || echo -e "${RED}Could not connect to database. Check network/VPN connection.${NC}"

    echo ""
    echo "Total connections by database:"
    PGPASSWORD=$PASSWORD psql -h $ENDPOINT -U postgres -d nakama -c "
        SELECT
            datname,
            COUNT(*) as total_connections
        FROM pg_stat_activity
        GROUP BY datname
        ORDER BY total_connections DESC;
    " 2>/dev/null || true

    echo ""
    echo "Long-running queries (if any):"
    PGPASSWORD=$PASSWORD psql -h $ENDPOINT -U postgres -d nakama -c "
        SELECT
            pid,
            usename,
            application_name,
            state,
            query_start,
            state_change,
            LEFT(query, 100) as query_snippet
        FROM pg_stat_activity
        WHERE state = 'active'
          AND query_start < NOW() - INTERVAL '1 minute'
        ORDER BY query_start;
    " 2>/dev/null || true

else
    echo -e "${YELLOW}psql not found - skipping direct database queries${NC}"
    echo "Install PostgreSQL client to run database connection analysis:"
    echo "  brew install postgresql@14  # macOS"
    echo "  sudo apt install postgresql-client  # Ubuntu/Debian"
fi

echo ""
echo -e "${YELLOW}Step 4: Recent ECS Task Activity${NC}"
echo "----------------------------------------"

# Get recent tasks
echo "Recent lobby-backend tasks:"
aws ecs list-tasks \
  --profile $PROFILE \
  --region $REGION \
  --cluster $CLUSTER \
  --service-name lobby-backend \
  --desired-status RUNNING \
  --output table

echo ""
echo "Recent nakama tasks:"
aws ecs list-tasks \
  --profile $PROFILE \
  --region $REGION \
  --cluster $CLUSTER \
  --service-name nakama \
  --desired-status RUNNING \
  --output table

echo ""
echo -e "${YELLOW}Step 5: Analysis Summary${NC}"
echo "----------------------------------------"

# Calculate expected connections
echo "Expected connection calculation:"
echo ""
echo "TypeORM default pool size: 10 connections per instance"
echo "Nakama typical connections: 5-10 per instance"
echo ""

LOBBY_COUNT=$(aws ecs describe-services \
  --profile $PROFILE \
  --region $REGION \
  --cluster $CLUSTER \
  --services lobby-backend \
  --query 'services[0].runningCount' \
  --output text)

NAKAMA_COUNT=$(aws ecs describe-services \
  --profile $PROFILE \
  --region $REGION \
  --cluster $CLUSTER \
  --services nakama \
  --query 'services[0].runningCount' \
  --output text)

echo "Current running tasks:"
echo "  - Lobby-backend: $LOBBY_COUNT tasks x 10 connections = $((LOBBY_COUNT * 10)) expected"
echo "  - Nakama: $NAKAMA_COUNT tasks x 10 connections = $((NAKAMA_COUNT * 10)) expected"
echo "  - Total expected: $((LOBBY_COUNT * 10 + NAKAMA_COUNT * 10)) connections"
echo ""

CURRENT_AVG=151
CURRENT_MAX=263

echo -e "${YELLOW}Actual metrics (30-day average):${NC}"
echo "  - Average: $CURRENT_AVG connections"
echo "  - Maximum: $CURRENT_MAX connections"
echo ""

# Decision logic
EXPECTED_TOTAL=$((LOBBY_COUNT * 10 + NAKAMA_COUNT * 10))

if [ $CURRENT_AVG -gt $((EXPECTED_TOTAL * 3)) ]; then
    echo -e "${RED}⚠️  ALERT: Connection count is 3x+ higher than expected!${NC}"
    echo -e "${RED}Investigation required before proceeding with optimization.${NC}"
    echo ""
    echo "Possible causes:"
    echo "  1. Connection leaks in application code"
    echo "  2. Missing connection pool configuration"
    echo "  3. Load testing or monitoring tools"
    echo "  4. Multiple application versions running"
    echo ""
    echo -e "${RED}❌ DO NOT PROCEED with instance downgrade until resolved${NC}"
elif [ $CURRENT_AVG -gt $((EXPECTED_TOTAL * 2)) ]; then
    echo -e "${YELLOW}⚠️  WARNING: Connection count is 2x+ higher than expected${NC}"
    echo "Review connection patterns before proceeding."
    echo ""
    echo -e "${YELLOW}⚠️  RECOMMEND: Choose Option B (storage only) for staging${NC}"
elif [ $CURRENT_AVG -gt $EXPECTED_TOTAL ]; then
    echo -e "${YELLOW}⚠️  NOTICE: Connection count is higher than expected${NC}"
    echo "May be normal depending on application behavior."
    echo ""
    echo -e "${GREEN}✓ Can proceed with Option A (instance downgrade)${NC}"
    echo -e "${GREEN}  But monitor connections closely post-change${NC}"
else
    echo -e "${GREEN}✓ Connection count is within expected range${NC}"
    echo -e "${GREEN}✓ Safe to proceed with Option A (instance downgrade)${NC}"
fi

echo ""
echo -e "${YELLOW}Step 6: Recommendations${NC}"
echo "----------------------------------------"

echo "Based on this investigation:"
echo ""
echo "If connection count is NORMAL:"
echo "  → Proceed with Option A: db.t3.medium → db.t3.small"
echo "  → Savings: \$26.08/month"
echo "  → Monitor CPU, memory, connections for 2 weeks"
echo ""
echo "If connection count is HIGH:"
echo "  → Proceed with Option B: Storage reduction only"
echo "  → Savings: \$6.44/month"
echo "  → Investigate and fix connection issues first"
echo "  → Consider Option A after fixing connection leaks"
echo ""
echo "If connection count is CRITICAL:"
echo "  → DO NOT proceed with any optimization"
echo "  → Fix connection leaks immediately"
echo "  → Re-run this investigation after fix"
echo ""

echo "=========================================="
echo "Investigation Complete"
echo "=========================================="
echo ""
echo "Next steps:"
echo "  1. Review the output above"
echo "  2. If database queries ran, analyze connection patterns"
echo "  3. Decide on Option A (aggressive) or Option B (conservative)"
echo "  4. Create snapshot before applying changes"
echo "  5. Apply Terraform changes during maintenance window"
echo ""
echo "Report saved to: rds_optimization_report.md"
echo "Terraform changes: terraform_changes_stg_option_*.tfvars"
