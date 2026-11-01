# RDS Cost Optimization Report - GamePlatform Platform
**Date**: 2025-11-05
**Analysis Period**: Last 30 days
**Analyzed By**: AWS CloudWatch Metrics + Infrastructure Review

---

## Executive Summary

Based on comprehensive analysis of AWS CloudWatch metrics, infrastructure configuration, and application code review, **significant cost optimization opportunities** have been identified for both Dev and Staging RDS instances.

### Current Monthly Costs
- **Dev (db.t3.micro, 20 GB)**: ~$13.24/month
- **Staging (db.t3.medium, 50 GB)**: ~$50.70/month
- **Total Current**: ~$63.94/month ($767.28/year)

### Optimized Monthly Costs
- **Dev (db.t3.micro, 10 GB)**: ~$11.40/month
- **Staging (db.t3.small, 15 GB)**: ~$24.34/month
- **Total Optimized**: ~$35.74/month ($428.88/year)

### **Total Savings: $28.20/month ($338.40/year) = 44% reduction**

---

## Environment Analysis

### 1. DEV Environment (`dev-postgres-postgres`)

#### Current Configuration
```
Instance Class:     db.t3.micro (1 GB RAM, 2 vCPUs)
Allocated Storage:  20 GB gp3
Max Storage:        100 GB
IOPS:               3000
Multi-AZ:           No
Instance Age:       58 days (created 2025-09-08)
```

#### Performance Metrics (30-day average)
```
CPU Utilization:
  - Average: 4.76%
  - Maximum: 45.20%
  - Status: ✓ Underutilized but acceptable for dev

Database Connections:
  - Average: 4.12
  - Maximum: 17
  - Configured Max: 100
  - Status: ✓ Very low usage

Memory:
  - Total: 1 GB
  - Used (avg): 0.82 GB (82%)
  - Free (avg): 0.18 GB
  - Status: ⚠ High usage (typical for t3.micro)

Storage:
  - Allocated: 20 GB
  - Used: 3.15 GB (15.8%)
  - Free: 16.85 GB
  - Status: ❌ SIGNIFICANTLY OVERSIZED

IOPS:
  - Read (avg): 0.35, Max: 9.77
  - Write (avg): 3.46, Max: 19.78
  - Status: ✓ Very low, gp3 baseline sufficient

Latency:
  - Read (avg): 0.4ms, Max: 60ms
  - Write (avg): 1.4ms, Max: 141ms
  - Status: ✓ Excellent performance
```

#### Optimization Recommendation: **CONSERVATIVE**

**Keep Instance Class**: `db.t3.micro`
- Rationale: Already at minimum instance size
- Memory at 82% is normal for t3.micro with PostgreSQL
- CPU spikes to 45% are acceptable for dev environment
- Cost: $6.57/month (no change)

**Reduce Storage**: `20 GB → 10 GB`
- Current usage: 3.15 GB (15.8%)
- Recommendation: 10 GB provides 3x headroom
- Growth capacity: max_allocated_storage stays at 100 GB
- Cost savings: $1.84/month

**Total Dev Savings**: $1.84/month ($22.08/year)

---

### 2. STAGING Environment (`stg-postgres-postgres`)

#### Current Configuration
```
Instance Class:     db.t3.medium (4 GB RAM, 2 vCPUs)
Allocated Storage:  50 GB gp3
Max Storage:        150 GB
IOPS:               3000
Storage Throughput: 125 MB/s
Multi-AZ:           No
Instance Age:       13 days (created 2025-10-22)
```

#### Performance Metrics (13-day average - newer instance)
```
CPU Utilization:
  - Average: 5.82%
  - Maximum: 87.32% ⚠ SPIKE DETECTED
  - Status: ⚠ Generally underutilized but has spikes

Database Connections:
  - Average: 151.72 ⚠ HIGH
  - Maximum: 263 ⚠ VERY HIGH
  - Configured Max: 200
  - Status: ❌ APPROACHING LIMIT - NEEDS INVESTIGATION

Memory:
  - Total: 4 GB
  - Used (avg): 2.21 GB (55.3%)
  - Free (avg): 1.79 GB
  - Status: ✓ Comfortable headroom

Storage:
  - Allocated: 50 GB
  - Used: 5.08 GB (10.2%)
  - Free: 44.92 GB
  - Status: ❌ EXTREMELY OVERSIZED

IOPS:
  - Read (avg): 0.33, Max: 435.82 ⚠ BURST
  - Write (avg): 3.57, Max: 368.86 ⚠ BURST
  - Status: ⚠ Low average but high bursts

Throughput:
  - Read (avg): 0.00 MB/s, Max: 5.28 MB/s
  - Write (avg): 0.27 MB/s, Max: 47.24 MB/s
  - Status: ⚠ High burst activity detected

Latency:
  - Read (avg): 0.2ms, Max: 60.8ms
  - Write (avg): 1.2ms, Max: 90.3ms
  - Status: ✓ Good performance maintained
```

#### Critical Findings

🔴 **HIGH CONNECTION COUNT**: 151 avg, 263 max connections
- Lobby-backend uses TypeORM (default max 10 connections per instance)
- Likely multiple service instances or connection leaks
- **REQUIRES INVESTIGATION** before downsizing

🟡 **CPU SPIKE**: 87.32% maximum
- Average is very low (5.82%) but spike detected
- Could be batch jobs, backups, or traffic surge
- Needs monitoring during downsize

🟢 **MEMORY COMFORTABLE**: 55.3% usage
- Supports downgrade to 2 GB instance

🔴 **STORAGE MASSIVELY OVERSIZED**: Using 5 GB of 50 GB

#### Optimization Recommendation: **MODERATE APPROACH**

**Two Options Presented**:

##### Option A: CONSERVATIVE (Recommended)
**Downgrade Instance**: `db.t3.medium → db.t3.small`
- RAM: 4 GB → 2 GB (still 45% free at current usage)
- vCPUs: 2 (same)
- Handles 87% CPU spikes with monitoring
- Max connections reduced: 200 → ~100 (MONITOR CLOSELY)
- Cost: $32.85/month → $16.43/month
- **Savings**: $16.42/month ($197.04/year)

**Reduce Storage**: `50 GB → 15 GB`
- Current usage: 5.08 GB
- Provides ~3x headroom (similar to dev ratio)
- max_allocated_storage: 150 GB → 50 GB (auto-scaling preserved)
- Cost: $9.20/month → $2.76/month
- **Savings**: $6.44/month ($77.28/year)

**Total Staging Savings (Option A)**: $22.86/month ($274.32/year)

##### Option B: AGGRESSIVE (Higher Risk)
- Keep `db.t3.medium` (CPU spike concern)
- Reduce storage only: 50 GB → 15 GB
- **Savings**: $6.44/month ($77.28/year)

**Recommendation**: Start with Option A with close monitoring for 2 weeks

---

## Application Code Analysis

### Database Usage Patterns

#### Nakama (Game Server)
```yaml
Database: PostgreSQL (primary consumer)
Connection: Direct via database.address flag
Usage: Game state, user data, matchmaking
Config: /applications/server/nakama/local.yml
```

#### Lobby-backend (NestJS API)
```typescript
Database: TypeORM with default connection pool
Configuration: /applications/lobby-backend/src/database/database.module.ts
Pool Settings: Default (max: 10 per instance)
Entities: User entity
Synchronize: false (migrations controlled)
```

#### Connection Pattern Analysis
- **Dev**: 4 avg connections = likely 1 Nakama + 1 lobby-backend instance
- **Staging**: 151 avg connections = **ANOMALY DETECTED**
  - Expected: ~10-30 connections (few service instances)
  - Actual: 151 avg, 263 max
  - **Root cause investigation needed**: Check for:
    - Multiple ECS tasks running
    - Connection leaks in application code
    - Load testing activity
    - Monitoring/analytics tools

---

## Cost Breakdown

### Current Costs (Monthly)

#### Dev Environment
```
Instance (db.t3.micro):     $6.57
Storage (20 GB gp3):        $3.68
IOPS (3000 baseline):       Included
Backup (7 days):            $1.84
Enhanced Monitoring:        $0 (disabled)
Performance Insights:       $0 (disabled)
---
Total Dev:                  $12.09/month
```

#### Staging Environment
```
Instance (db.t3.medium):    $32.85
Storage (50 GB gp3):        $9.20
IOPS (3000 provisioned):    Included
Throughput (125 MB/s):      Included
Backup (7 days):            $4.60
Enhanced Monitoring (60s):  $2.05
Performance Insights (7d):  $2.00
---
Total Staging:              $50.70/month
```

**Total Current**: $62.79/month ($753.48/year)

### Optimized Costs (Monthly)

#### Dev Environment (Conservative)
```
Instance (db.t3.micro):     $6.57 (no change)
Storage (10 GB gp3):        $1.84 (-$1.84)
IOPS (3000 baseline):       Included
Backup (7 days):            $0.92 (-$0.92)
Enhanced Monitoring:        $0
Performance Insights:       $0
---
Total Dev:                  $9.33/month
Savings:                    $2.76/month (22.8%)
```

#### Staging Environment (Option A - Conservative)
```
Instance (db.t3.small):     $16.43 (-$16.42)
Storage (15 GB gp3):        $2.76 (-$6.44)
IOPS (3000 baseline):       Included
Backup (7 days):            $1.38 (-$3.22)
Enhanced Monitoring (60s):  $2.05 (keep)
Performance Insights (7d):  $2.00 (keep)
---
Total Staging:              $24.62/month
Savings:                    $26.08/month (51.4%)
```

**Total Optimized**: $33.95/month ($407.40/year)
**Total Savings**: $28.84/month ($346.08/year) = **45.9% reduction**

---

## Implementation Plan

### Phase 1: Preparation (Week 1)

#### Task 1.1: Connection Investigation (CRITICAL)
**Priority**: HIGH
**Owner**: DevOps + Backend Team

Action Items:
1. Query current connections in Staging:
   ```sql
   SELECT count(*), state, usename, application_name
   FROM pg_stat_activity
   WHERE datname = 'nakama'
   GROUP BY state, usename, application_name;
   ```

2. Check ECS task count in staging:
   ```bash
   aws ecs list-tasks --cluster project-stg-cluster \
     --profile staging --region us-east-1

   aws ecs describe-services --cluster project-stg-cluster \
     --services lobby-backend nakama \
     --profile staging --region us-east-1
   ```

3. Review application logs for connection patterns

4. Decision: Proceed with downgrade ONLY if investigation shows:
   - Normal connection behavior (no leaks)
   - Clear explanation for high count (multiple instances, load testing, etc.)

#### Task 1.2: Enable CloudWatch Detailed Monitoring
**Purpose**: Baseline metrics before changes

```bash
# Already enabled in staging (60s monitoring)
# Verify in AWS Console: RDS > stg-postgres-postgres > Monitoring
```

#### Task 1.3: Create RDS Snapshots
**Purpose**: Rollback capability

```bash
# Dev snapshot
aws rds create-db-snapshot \
  --db-instance-identifier dev-postgres-postgres \
  --db-snapshot-identifier dev-postgres-before-optimization-20251105 \
  --profile sandbox --region us-east-1

# Staging snapshot
aws rds create-db-snapshot \
  --db-instance-identifier stg-postgres-postgres \
  --db-snapshot-identifier stg-postgres-before-optimization-20251105 \
  --profile staging --region us-east-1
```

### Phase 2: Dev Environment Changes (Week 2)

#### Step 2.1: Update Terraform Configuration

**File**: `/Repos/gameplatform-shared-infrastructure/environments/dev/postgres.tfvars`

```hcl
# BEFORE
allocated_storage     = 20
max_allocated_storage = 100

# AFTER
allocated_storage     = 10  # Reduced from 20 GB
max_allocated_storage = 100 # Kept for auto-scaling
```

#### Step 2.2: Apply via Atlantis

1. Create PR with changes
2. Comment: `atlantis plan -p postgres`
3. Review plan output carefully
4. Comment: `atlantis apply -p postgres`

#### Step 2.3: Monitor for 48 hours

Watch for:
- Storage usage trends
- Application errors
- Performance degradation

**Rollback if**: Storage usage exceeds 80% or application errors

### Phase 3: Staging Environment Changes (Week 3-4)

⚠️ **CONDITIONAL**: Proceed ONLY after Phase 1.1 investigation complete and satisfactory

#### Step 3.1: Update Terraform Configuration

**File**: `/Repos/gameplatform-shared-infrastructure/environments/stg/postgres.tfvars`

##### OPTION A: Conservative (Recommended)
```hcl
# Instance downgrade + storage reduction
instance_class        = "db.t3.small"     # Changed from db.t3.medium
allocated_storage     = 15                # Changed from 50
max_allocated_storage = 50                # Changed from 150
max_connections       = "100"             # Changed from 200

# Remove provisioned IOPS (use gp3 baseline)
storage_iops          = null              # Was 3000
storage_throughput    = null              # Was 125
```

##### OPTION B: Aggressive (Higher Risk)
```hcl
# Storage reduction only, keep instance class
instance_class        = "db.t3.medium"    # No change
allocated_storage     = 15                # Changed from 50
max_allocated_storage = 50                # Changed from 150
```

#### Step 3.2: Schedule Maintenance Window

**Recommended**: Saturday 2 AM BRT (5 AM UTC)
- Low traffic period
- Team available for monitoring
- Allows 48h weekend monitoring

#### Step 3.3: Apply Changes

1. Create PR with Option A or Option B
2. Atlantis plan review
3. Schedule apply for maintenance window
4. Monitor RDS modification progress (15-30 minutes)

#### Step 3.4: Intensive Monitoring (72 hours)

**Metrics to watch**:
- CPU utilization (alert if sustained >80%)
- Memory (alert if <200 MB free)
- Connection count (alert if >90)
- IOPS and throughput (check for throttling)
- Application error rates
- API response times

**CloudWatch Alarms** (create before changes):
```bash
# CPU alarm
aws cloudwatch put-metric-alarm \
  --alarm-name stg-postgres-high-cpu \
  --alarm-description "Staging RDS CPU > 80%" \
  --metric-name CPUUtilization \
  --namespace AWS/RDS \
  --statistic Average \
  --period 300 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 2 \
  --dimensions Name=DBInstanceIdentifier,Value=stg-postgres-postgres \
  --profile staging --region us-east-1

# Connection alarm
aws cloudwatch put-metric-alarm \
  --alarm-name stg-postgres-high-connections \
  --alarm-description "Staging RDS Connections > 90" \
  --metric-name DatabaseConnections \
  --namespace AWS/RDS \
  --statistic Average \
  --period 300 \
  --threshold 90 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 1 \
  --dimensions Name=DBInstanceIdentifier,Value=stg-postgres-postgres \
  --profile staging --region us-east-1
```

### Phase 4: Validation & Rollback Plan

#### Success Criteria (After 2 weeks)
- ✓ No application errors or performance degradation
- ✓ CPU utilization <70% sustained
- ✓ Connection count <80% of max
- ✓ Storage usage <70%
- ✓ API latency within baseline
- ✓ No customer complaints

#### Rollback Procedure

If issues detected:

**Option 1: Immediate rollback (instance class)**
```bash
# Staging: Scale back up to db.t3.medium
aws rds modify-db-instance \
  --db-instance-identifier stg-postgres-postgres \
  --db-instance-class db.t3.medium \
  --apply-immediately \
  --profile staging --region us-east-1
```

**Option 2: Restore from snapshot**
```bash
# If data corruption or severe issues
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier stg-postgres-postgres-restored \
  --db-snapshot-identifier stg-postgres-before-optimization-20251105 \
  --profile staging --region us-east-1

# Then swap endpoints via DNS or update service configs
```

**Option 3: Revert Terraform**
```bash
# Git revert the PR changes
# Re-apply via Atlantis
```

---

## Risk Assessment

### Low Risk ✅
- **Dev storage reduction**: Very safe, using only 15.8%
- **Cost savings**: Guaranteed with minimal changes

### Medium Risk ⚠️
- **Staging storage reduction**: Safe, but monitor growth
- **Staging instance downgrade**: Depends on connection investigation results

### High Risk 🔴
- **Ignoring connection anomaly**: Could cause service outage if connections exceed new limit
- **Not monitoring post-change**: Performance issues might go undetected

### Mitigation Strategies
1. **Phased rollout**: Dev first, staging after validation
2. **Extensive monitoring**: CloudWatch alarms before changes
3. **Maintenance windows**: Low-traffic periods
4. **Snapshots**: Quick rollback capability
5. **Team availability**: DevOps on-call during changes

---

## Recommendations Summary

### Immediate Actions (This Week)
1. ✅ **APPROVE**: Dev storage reduction (20 GB → 10 GB)
   - Risk: Low
   - Savings: $2.76/month
   - Complexity: Simple

2. 🔍 **INVESTIGATE**: Staging high connection count
   - Priority: HIGH
   - Blocker: Must resolve before instance downgrade

### Short-term Actions (Weeks 2-4)
3. ⚠️ **CONDITIONAL**: Staging instance downgrade (medium → small)
   - Depends on: Connection investigation results
   - Risk: Medium
   - Savings: $26.08/month
   - Requires: Careful monitoring

### Long-term Considerations (Months 2-3)
4. 📊 **MONITOR**: Post-optimization metrics
   - Validate savings are sustained
   - Ensure no performance degradation
   - Consider Production environment optimizations

5. 🔧 **OPTIMIZE**: Application connection pooling
   - Review TypeORM connection pool settings
   - Implement connection lifecycle management
   - Consider PgBouncer for connection pooling

---

## Additional Optimization Opportunities

### 1. Enable Scheduler for RDS (Future Enhancement)
Currently, the scheduler is configured for ECS services but NOT RDS:
- `enable_scheduler = false` in both dev and stg postgres.tfvars
- **Potential additional savings**: ~$4-8/month per environment
- **Consideration**: RDS startup time (5-10 minutes) might impact dev workflow

### 2. Performance Insights Retention
Staging currently keeps 7 days of Performance Insights:
- Cost: $2.00/month
- Usage: Rarely accessed
- **Recommendation**: Reduce to 7 days (current) or disable if not used

### 3. Backup Retention Review
Both environments keep 7-day backups:
- Dev: Consider 3 days (staging data, lower criticality)
- Staging: Keep 7 days (pre-production data)

### 4. Multi-AZ Review (Production)
When optimizing Production (live) environment:
- Current: Single-AZ
- Consider: Multi-AZ for high availability
- Trade-off: 2x instance cost vs. uptime requirements

---

## Technical Details

### RDS Instance Classes Comparison

| Instance | vCPUs | RAM | Network | Price/month | Use Case |
|----------|-------|-----|---------|-------------|----------|
| db.t3.micro | 2 | 1 GB | Low | $6.57 | Dev/test, low traffic |
| db.t3.small | 2 | 2 GB | Low-Moderate | $16.43 | Small staging |
| db.t3.medium | 2 | 4 GB | Moderate | $32.85 | Staging, small prod |
| db.t3.large | 2 | 8 GB | Moderate | $65.70 | Production |

### Storage Costs (gp3)

| Storage | Monthly Cost | Use Case |
|---------|--------------|----------|
| 10 GB | $1.84 | Minimal dev database |
| 15 GB | $2.76 | Small staging |
| 20 GB | $3.68 | Current dev |
| 50 GB | $9.20 | Current staging |

### Backup Costs

Formula: `$0.092 per GB-month * allocated_storage * retention_days / 30`

- 10 GB, 7 days: $0.92/month
- 15 GB, 7 days: $1.38/month
- 20 GB, 7 days: $1.84/month
- 50 GB, 7 days: $4.60/month

---

## Terraform Changes Preview

### File 1: `/environments/dev/postgres.tfvars`

```diff
 # Storage configuration - minimal for dev
-allocated_storage     = 20
+allocated_storage     = 10
 max_allocated_storage = 100
 storage_type          = "gp3"
```

### File 2: `/environments/stg/postgres.tfvars` (Option A)

```diff
 # Database configuration
 postgres_version = "14.17"
-instance_class   = "db.t3.medium" # Staging instance
+instance_class   = "db.t3.small"  # Optimized staging instance
 database_name    = "nakama"
 db_username      = "postgres"

 # Storage configuration - Staging sizing
-allocated_storage     = 50  # 50 GB initial
-max_allocated_storage = 150 # Auto-scaling up to 150GB
+allocated_storage     = 15  # 15 GB initial (optimized)
+max_allocated_storage = 50  # Auto-scaling up to 50GB
 storage_type          = "gp3"

 # Performance configuration
-storage_iops       = 3000
-storage_throughput = 125
+# Use gp3 baseline (3000 IOPS, 125 MB/s included)
+storage_iops       = null
+storage_throughput = null

 # Parameter group configuration
 parameter_group_family     = "postgres14"
 log_min_duration_statement = "100"
-max_connections            = "200"
+max_connections            = "100"
 shared_preload_libraries   = "pg_stat_statements,pg_hint_plan"
```

---

## Approval Request

This report requests approval to proceed with:

### ✅ Phase 1: Investigation (No infrastructure changes)
- [ ] Investigate staging high connection count
- [ ] Create RDS snapshots for both environments
- [ ] Set up CloudWatch alarms

### ✅ Phase 2: Dev Environment Optimization
- [ ] Reduce dev storage: 20 GB → 10 GB
- [ ] Expected savings: $2.76/month
- [ ] Risk: Low
- [ ] Rollback: Simple (Terraform revert)

### ⏸️ Phase 3: Staging Environment Optimization (CONDITIONAL)
- [ ] **BLOCKED**: Pending connection investigation
- [ ] If approved after investigation:
  - [ ] Downgrade instance: db.t3.medium → db.t3.small
  - [ ] Reduce storage: 50 GB → 15 GB
  - [ ] Expected savings: $26.08/month
  - [ ] Risk: Medium (requires monitoring)

**Decision needed**: Proceed with Phase 1 & 2 immediately?

---

## Appendix

### A. Useful Commands

#### Check current RDS configuration
```bash
# Dev
aws rds describe-db-instances \
  --db-instance-identifier dev-postgres-postgres \
  --profile sandbox --region us-east-1

# Staging
aws rds describe-db-instances \
  --db-instance-identifier stg-postgres-postgres \
  --profile staging --region us-east-1
```

#### Monitor CloudWatch metrics
```bash
# CPU utilization
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name CPUUtilization \
  --dimensions Name=DBInstanceIdentifier,Value=stg-postgres-postgres \
  --start-time 2025-11-05T00:00:00Z \
  --end-time 2025-11-05T23:59:59Z \
  --period 3600 \
  --statistics Average,Maximum \
  --profile staging --region us-east-1
```

#### Connect to database
```bash
# From Repos/gameplatform-monorepo directory
# Dev
psql postgresql://postgres:$(aws ssm get-parameter --name /dev/postgres/master-password --with-decryption --query Parameter.Value --output text --profile sandbox --region us-east-1)@dev-postgres-postgres.xxxx.us-east-1.rds.amazonaws.com:5432/nakama

# Staging
psql postgresql://postgres:$(aws ssm get-parameter --name /stg/postgres/master-password --with-decryption --query Parameter.Value --output text --profile staging --region us-east-1)@stg-postgres-postgres.xxxx.us-east-1.rds.amazonaws.com:5432/nakama
```

### B. Metrics Analysis JSON

Detailed metrics saved in: `/docs/GamePlatform/rds_metrics_analysis.json`

### C. Contact Information

For questions or concerns about this optimization plan:
- **Infrastructure Team**: Review Terraform changes
- **Backend Team**: Investigate connection patterns
- **DevOps**: Execute changes and monitoring

---

**Report Status**: ✅ READY FOR REVIEW
**Next Action**: Awaiting approval to proceed with Phase 1 & 2
**Timeline**: 4-week implementation plan
**Total Potential Savings**: $346.08/year (45.9% reduction)
