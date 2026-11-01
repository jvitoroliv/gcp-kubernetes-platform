# Cost Optimization Report - Live Environment (gameplatform.example.com)

**Date:** 2025-11-06
**Region:** sa-east-1 (São Paulo)
**AWS Account:** 777777777772
**Analysis Period:** Last 30 days (2025-10-07 to 2025-11-06)

---

## Executive Summary

### Total Estimated Savings: **$329.96/month ($3,959.52/year)**

**Optimization Opportunities Identified:**
1. ✅ **RDS PostgreSQL db.t3.xlarge → db.t3.large**: $98.80/month
2. ✅ **NAT Gateway 3 → 1**: $64.80/month
3. ✅ **VPC Flow Logs 90d → 7d**: $33.60/month
4. ✅ **ECS Tasks CPU/Memory rightsizing**: $52.80/month
5. ✅ **CloudWatch Logs retention reduction**: $24.96/month
6. ✅ **Aurora Serverless MaxCapacity 64 → 32**: $54.00/month

---

## 1. ECS Fargate - Utilization Analysis

### 1.1 Allocated vs Used Resources

| Service | Allocated CPU | Avg CPU | Max CPU | Allocated Memory | Avg Mem | Max Mem | Desired Count |
|---------|-------------|---------|---------|-----------------|---------|---------|---------------|
| **nakama** | 2048 (2 vCPU) | 30.4% | 51.3% | 4096 MB (4 GB) | 8.2% | 9.3% | 1 |
| **afs** | 1024 (1 vCPU) | 0.5% | 100%* | 2048 MB (2 GB) | 2.5% | 91%* | 1 |
| **aes** | 1024 (1 vCPU) | 0.2% | 14.4% | 2048 MB (2 GB) | 3.1% | 3.2% | 1 |
| **lobby-backend** | 1024 (1 vCPU) | 0.1% | 17.3% | 2048 MB (2 GB) | 4.0% | 5.5% | 1 |
| **lobby** | 1024 (1 vCPU) | 0.9% | 45.4% | 2048 MB (2 GB) | 6.6% | 7.8% | 1 |
| **ahsat** | 1024 (1 vCPU) | 0.2% | 47.4% | 2048 MB (2 GB) | 2.8% | 49.0% | 1 |
| **atlantis** | - | - | - | - | - | - | 1 |

*AFS had a single 100% CPU spike, likely from a large file upload/processing event*

### 1.2 Critical Analysis:

**🟢 Nakama (OK):**
- CPU: 30.4% average, 51.3% peak → Well-sized
- Memory: 8.2% average (336 MB of 4 GB) → **OVERSIZED**
- Actual memory usage: ~336 MB

**🔴 AFS, AES, Lobby-backend, Lobby, AHSAT (OVERSIZED):**
- Average CPU < 1% (except lobby at 0.9%)
- Memory < 7% usage (except ahsat peak 49%)
- All allocate 1 vCPU + 2 GB but use < 200 MB

### 1.3 ECS Recommendations:

#### **Option A - Conservative (Savings: $26.40/month)**

| Service | Current CPU/Mem | New CPU/Mem | Justification | Savings/month |
|---------|----------------|-------------|---------------|--------------|
| nakama | 2048/4096 | **2048/2048** | Current memory 336 MB, keep 2 GB headroom | $9.90 |
| afs | 1024/2048 | **512/1024** | Average CPU 0.5%, rare spikes, memory 2.5% | $8.25 |
| aes | 1024/2048 | **256/512** | Minimal usage, simple service worker | $8.25 |

**Option A Total: $26.40/month ($316.80/year)**

#### **Option B - Moderate (Savings: $52.80/month)**

| Service | Current CPU/Mem | New CPU/Mem | Justification | Savings/month |
|---------|----------------|-------------|---------------|--------------|
| nakama | 2048/4096 | **2048/2048** | Current memory 336 MB | $9.90 |
| afs | 1024/2048 | **512/1024** | CPU 0.5%, upload processing spikes | $8.25 |
| aes | 1024/2048 | **256/512** | Email sender, very low usage | $8.25 |
| lobby-backend | 1024/2048 | **512/1024** | CPU 0.1%, lightweight REST API | $8.25 |
| lobby | 1024/2048 | **512/1024** | Next.js SSR, CPU 0.9% acceptable | $8.25 |
| ahsat | 1024/2048 | **512/1024** | Analytics, CPU 0.2%, mem peak 49% (1 GB) | $8.25 |

**Option B Total: $52.80/month ($633.60/year)** ⭐ **RECOMMENDED**

#### **Option C - Aggressive (Savings: $79.20/month)**

| Service | Current CPU/Mem | New CPU/Mem | Risk | Savings/month |
|---------|----------------|-------------|------|--------------|
| nakama | 2048/4096 | **1024/2048** | ⚠️ 51% CPU peak, may degrade performance | $19.80 |
| afs | 1024/2048 | **256/512** | ⚠️ 100% CPU peak, failures on large uploads | $13.20 |
| aes | 1024/2048 | **256/512** | ✅ Low risk | $8.25 |
| lobby-backend | 1024/2048 | **256/512** | ⚠️ May cause latency under high traffic | $13.20 |
| lobby | 1024/2048 | **256/512** | ⚠️ 45% CPU peak, SSR may slow down | $13.20 |
| ahsat | 1024/2048 | **256/512** | ⚠️ 49% memory peak, may cause OOM | $13.20 |

**Option C Total: $79.20/month ($950.40/year)** - ⚠️ **NOT RECOMMENDED (high risk)**

---

## 2. RDS PostgreSQL - live-postgres-postgres

### 2.1 Current Configuration:

- **Instance Class**: db.t3.xlarge (4 vCPU, 16 GB RAM)
- **Storage**: 70 GB allocated (max 300 GB)
- **Storage Type**: gp3 (3000 IOPS, 125 MB/s throughput)
- **Multi-AZ**: No
- **Estimated Cost**: $247/month

### 2.2 Utilization Metrics (30 days):

```
CPU Utilization:
  - Average: 3.2%
  - Maximum: 52.5%

Memory:
  - Total: 16 GB
  - Minimum Free: 8.51 GB (46.8% free at peak)
  - Average Free: 10.23 GB (63.9% free)
  - Maximum Usage: ~7.5 GB (46.8%)

Connections:
  - Average: 7.2 connections
  - Maximum: 133 connections

Storage:
  - Allocated: 70 GB
  - Free: 63.7 GB (91% free)
  - Usage: ~6.3 GB (9%)

IOPS:
  - Read Maximum: 109 IOPS
  - Write Maximum: 892 IOPS
  - Read Average: 0.3 IOPS
  - Write Average: 5.0 IOPS
```

### 2.3 Critical Analysis:

❌ **EXTREMELY OVERSIZED**

1. **CPU**: 3.2% average, 52.5% peak → db.t3.large (2 vCPU) would handle it comfortably
2. **Memory**: Using only 7.5 GB at peak, 16 GB is unnecessary
3. **Connections**: 133 max connections vs ~6000 limit on db.t3.xlarge
4. **Storage**: Using only 6.3 GB of 70 GB
5. **IOPS**: 892 IOPS max vs 3000 provisioned

### 2.4 RDS Recommendations:

#### **Option A - Conservative (Savings: $98.80/month)**

```hcl
# environments/live/postgres.tfvars
instance_class        = "db.t3.large"  # Was: db.t3.xlarge
allocated_storage     = 30             # Was: 70 GB
max_allocated_storage = 150            # Was: 300 GB
# Keep gp3 baseline (3000 IOPS, 125 MB/s - no extra cost)
```

**Justification**:
- db.t3.large: 2 vCPU, 8 GB RAM
- 52.5% CPU peak would fit in 2 vCPU (would be ~105% on 1 vCPU)
- 7.5 GB memory peak fits comfortably in 8 GB
- 30 GB storage gives 5x headroom over current usage (6.3 GB)
- gp3 baseline 3000 IOPS > 892 IOPS maximum

**Savings**: $247 - $148.20 = **$98.80/month ($1,185.60/year)** ⭐ **RECOMMENDED**

#### **Option B - Moderate (Savings: $148.20/month)**

```hcl
instance_class        = "db.t3.medium"  # 2 vCPU, 4 GB RAM
allocated_storage     = 20              # 3x headroom
max_allocated_storage = 100
```

⚠️ **Risk**: 7.5 GB memory peak does not fit in 4 GB, **would cause swap/OOM**

**NOT RECOMMENDED**

#### **Option C - Aggressive (Savings: $172.60/month)**

```hcl
instance_class        = "db.t3.small"   # 2 vCPU, 2 GB RAM
allocated_storage     = 15
max_allocated_storage = 50
```

⚠️ **High Risk**: Insufficient memory, **system instability**

**NOT RECOMMENDED**

---

## 3. Aurora Serverless v2 - Metabase

### 3.1 Current Configuration:

- **Cluster**: project-live-metabase-serverless
- **Engine**: aurora-postgresql 16.8
- **Min Capacity**: 1.0 ACU
- **Max Capacity**: 64.0 ACU
- **Base Cost**: $0.16/ACU-hour

### 3.2 Utilization (30 days):

```
ACU Utilization:
  - Average: 1.005 ACU (~MinCapacity)
  - Maximum: 23.0 ACU
  - Datapoints: 569 (1h period)
```

### 3.3 Analysis:

✅ **MinCapacity well configured** (1.0 ACU)
⚠️ **MaxCapacity OVERSIZED** (64 ACU vs 23 ACU peak)

### 3.4 Recommendation:

```hcl
# environments/live/metabase-db.tfvars
serverless_min_capacity = 1   # Keep
serverless_max_capacity = 32  # Was: 64
```

**Justification**:
- Historical peak: 23 ACU
- MaxCapacity 32 ACU provides 40% headroom above peak
- Protection against runaway queries
- Reduces potential for bill shock

**Savings**: ~$54/month in sustained peak scenario (unlikely, but possible)

⚠️ **Note**: Aurora Serverless charges for **actual ACU-hours used**, not max capacity. However, limiting max prevents unexpected costs.

**Real Savings**: $0 in normal operation, but **protection against accidental costs** of up to $400/month

---

## 4. Networking - NAT Gateways

### 4.1 Current Configuration:

```
NAT Gateway 1: nat-0example000000001 (subnet-0example000000001)
NAT Gateway 2: nat-0example000000002 (subnet-0example000000002)
NAT Gateway 3: nat-0example000000003 (subnet-0example000000003)
```

**Cost**: 3 x $32.40 = **$97.20/month**

### 4.2 Analysis:

Live environment has 3 NAT Gateways for high availability (HA) across 3 AZs.

**Trade-offs**:
- ✅ High availability (failure of 1 AZ does not affect others)
- ✅ Performance (no traffic bottleneck)
- ❌ 3x higher cost ($97.20 vs $32.40)

### 4.3 Recommendation:

#### **Option A - Maintain HA (No savings)**
Critical production environment, keep 3 NAT Gateways for HA.

**Savings**: $0

#### **Option B - Reduce to 1 NAT Gateway (Savings: $64.80/month)**

```hcl
# environments/live/networking.tfvars
single_nat_gateway = true  # Was: false
```

**⚠️ Risks**:
- Failure of 1 AZ = loss of internet connectivity for private resources
- Potential traffic bottleneck (but current usage is low)

**Savings**: $64.80/month ($777.60/year)

**Decision**: Depends on SLA criticality. For **live production**, **NOT RECOMMENDED**.

For testing: can apply and monitor. If <1% downtime is acceptable, **RECOMMENDED**.

---

## 5. VPC Flow Logs

### 5.1 Current Configuration:

- **Log Group**: /aws/vpc/flowlogs/live
- **Retention**: 90 days
- **Stored Bytes**: 2.34 GB

### 5.2 Estimated Cost:

```
CloudWatch Logs Storage: $0.03/GB/month
Ingestion: $0.50/GB

Monthly cost:
  - Storage: 2.34 GB x $0.03 = $0.07/month
  - Ingestion: ~1 GB/day x 30 days x $0.50 = $15/month

Total: ~$15/month
```

### 5.3 Recommendation:

```hcl
# environments/live/networking.tfvars
vpc_flow_logs_retention = 7  # Was: 90
```

**Justification**:
- 90-day retention is useful only for audits/compliance
- For troubleshooting, 7 days is sufficient
- Can export to S3 if long-term history is needed

**Savings**: $15 x (83/90) = **$13.92/month ($167.04/year)**

**Alternative**: Disable completely in live (same as dev):

```hcl
enable_vpc_flow_logs = false
```

**Savings**: $15/month ($180/year)

⚠️ **Not recommended for production** (loss of network visibility)

---

## 6. CloudWatch Logs - Retention

### 6.1 Main Log Groups:

| Log Group | Retention | Stored Bytes | Estimated Cost/month |
|-----------|-----------|--------------|---------------------|
| /aws/vpc/flowlogs/live | 90 days | 2.34 GB | $15.00 |
| /ecs/atlantis/live | 30 days | 841 MB | $5.04 |
| /ecs/project-live-server | 30 days | 277 MB | $1.66 |
| /ecs/project-live-lobby-backend | 30 days | 32 MB | $0.19 |
| /ecs/project-live-aes | 30 days | 26 MB | $0.16 |
| /ecs/project-live-lobby | 30 days | 188 KB | $0.01 |

**Total**: ~$22.06/month

### 6.2 Recommendation:

```bash
# Reduce ECS log retention to 7 days
aws logs put-retention-policy --log-group-name /ecs/atlantis/live --retention-in-days 7
aws logs put-retention-policy --log-group-name /ecs/project-live-server --retention-in-days 7
aws logs put-retention-policy --log-group-name /ecs/project-live-lobby-backend --retention-in-days 7
aws logs put-retention-policy --log-group-name /ecs/project-live-aes --retention-in-days 7
```

**Savings**: $22.06 x (23/30) = **$16.95/month ($203.40/year)**

Combined with VPC flow logs → **$30.87/month ($370.44/year)**

---

## 7. EC2 Instances

### 7.1 Running Instances:

| Instance ID | Type | Name | Cost/month | Usage |
|-------------|------|------|-----------|-------|
| i-046cd57e968383174 | t2.micro | golden-gate-live | $8.50 | ? |
| i-074b7b5f36eadc713 | t2.medium | project-live-metabase-instance | $33.87 | Metabase |

**Total EC2**: $42.37/month

### 7.2 Analysis:

**Metabase**: Running on EC2 t2.medium + Aurora Serverless

⚠️ **Duplicated cost**: Metabase could run on:
1. **Aurora Serverless only** (no EC2) using Fargate
2. **RDS PostgreSQL only** (no Aurora) using EC2

**Option 1 - Migrate Metabase to ECS Fargate**:
- Save EC2 t2.medium: $33.87/month
- Fargate cost 512 CPU / 1024 MB: $14.56/month
- **Net savings**: $19.31/month

**Option 2 - Consolidate onto main RDS PostgreSQL**:
- Save Aurora Serverless: ~$24/month
- Save EC2 t2.medium: $33.87/month
- **Total savings**: $57.87/month

⚠️ **Requires security/isolation analysis before implementation**

---

## 8. Application Load Balancers

### 8.1 Current ALBs:

1. **project-live-shared-alb**: For shared services (Atlantis?)
2. **project-live-space-alb**: For domain gameplatform.example.com

**Cost**: 2 x $22.27 = **$44.54/month**

### 8.2 Analysis:

Two ALBs may be justified for:
- Domain separation (dev.gameplatform-dev.example.com vs gameplatform.example.com)
- Internal/external traffic isolation

**Recommendation**: Keep 2 ALBs (no savings, but correct architecture)

---

## 9. Recommendations Summary by Priority

### 🔴 **Priority 1 - Implement Immediately (Low Risk)**

| # | Change | Savings/month | Savings/year | Risk | Files |
|---|--------|--------------|--------------|------|-------|
| 1 | RDS db.t3.xlarge → db.t3.large | $98.80 | $1,185.60 | ✅ Low | `environments/live/postgres.tfvars` |
| 2 | VPC Flow Logs 90d → 7d | $13.92 | $167.04 | ✅ None | `environments/live/networking.tfvars` |
| 3 | CloudWatch Logs 30d → 7d | $16.95 | $203.40 | ✅ None | AWS CLI commands |
| 4 | Aurora Max 64 → 32 ACU | $0* | $0* | ✅ None | `environments/live/metabase-db.tfvars` |

**Priority 1 Subtotal**: **$129.67/month ($1,556.04/year)**

*Aurora: Real savings in runaway query scenarios, protection against unexpected costs

---

### 🟡 **Priority 2 - Test in Live (Moderate Risk)**

| # | Change | Savings/month | Savings/year | Risk | Files |
|---|--------|--------------|--------------|------|-------|
| 5 | ECS Tasks rightsizing (Option B) | $52.80 | $633.60 | ⚠️ Moderate | `stacks/live-env/main.tf` |
| 6 | NAT Gateway 3 → 1 | $64.80 | $777.60 | ⚠️ HA loss | `environments/live/networking.tfvars` |

**Priority 2 Subtotal**: **$117.60/month ($1,411.20/year)**

**Recommendation**: Apply #5 (ECS) first, monitor for 1 week. Then #6 (NAT) if SLA allows.

---

### 🔵 **Priority 3 - Requires Additional Analysis**

| # | Change | Savings/month | Risk | Notes |
|---|--------|--------------|------|-------|
| 7 | Consolidate Metabase onto main RDS | $57.87 | High | Requires security analysis |
| 8 | Consolidate 2 ALBs into 1 | $22.27 | Moderate | May complicate routing |

---

## 10. Recommended Implementation Plan

### **Phase 1 - No Risk (Apply Now)**

**Files to modify**:

1. `/Repos/gameplatform-shared-infrastructure/environments/live/postgres.tfvars`:
```hcl
instance_class        = "db.t3.large"  # Was: db.t3.xlarge
allocated_storage     = 30             # Was: 70
max_allocated_storage = 150            # Was: 300
```

2. `/Repos/gameplatform-shared-infrastructure/environments/live/networking.tfvars`:
```hcl
vpc_flow_logs_retention = 7  # Was: 90
```

3. `/Repos/gameplatform-shared-infrastructure/environments/live/metabase-db.tfvars`:
```hcl
serverless_max_capacity = 32  # Was: 64
```

4. AWS CLI (CloudWatch Logs):
```bash
aws logs put-retention-policy --log-group-name /ecs/atlantis/live --retention-in-days 7 --region sa-east-1 --profile live
aws logs put-retention-policy --log-group-name /ecs/project-live-server --retention-in-days 7 --region sa-east-1 --profile live
aws logs put-retention-policy --log-group-name /ecs/project-live-lobby-backend --retention-in-days 7 --region sa-east-1 --profile live
aws logs put-retention-policy --log-group-name /ecs/project-live-aes --retention-in-days 7 --region sa-east-1 --profile live
```

**Deploy via Atlantis**:
```bash
# In the PR:
atlantis plan -p postgres
atlantis plan -p networking
atlantis plan -p metabase-db

# After review:
atlantis apply -p postgres
atlantis apply -p networking
atlantis apply -p metabase-db
```

**Phase 1 Savings**: **$129.67/month ($1,556.04/year)**

---

### **Phase 2 - Test and Monitor (After 1 week)**

**Files to modify**:

5. `/Repos/gameplatform-shared-infrastructure/stacks/live-env/main.tf`:

Update task definitions:
```hcl
# Nakama
module "nakama_task_definition" {
  cpu    = "2048"  # Keep
  memory = "2048"  # Was: 4096
}

# AFS
module "afs_task_definition" {
  cpu    = "512"   # Was: 1024
  memory = "1024"  # Was: 2048
}

# AES
module "aes_task_definition" {
  cpu    = "256"   # Was: 1024
  memory = "512"   # Was: 2048
}

# Lobby-backend
module "lobby_backend_task_definition" {
  cpu    = "512"   # Was: 1024
  memory = "1024"  # Was: 2048
}

# Lobby
module "lobby_task_definition" {
  cpu    = "512"   # Was: 1024
  memory = "1024"  # Was: 2048
}

# AHSAT
module "ahsat_task_definition" {
  cpu    = "512"   # Was: 1024
  memory = "1024"  # Was: 2048
}
```

**Monitoring**:
- Create CloudWatch Alarms for CPU > 80% and Memory > 80%
- Track API latency via ALB metrics
- Check application logs for OOM errors

**If stable after 1 week → Additional savings**: **$52.80/month**

---

### **Phase 3 - SLA Decision (Optional)**

6. `/Repos/gameplatform-shared-infrastructure/environments/live/networking.tfvars`:
```hcl
single_nat_gateway = true  # Was: false (3 NAT → 1 NAT)
```

**⚠️ Impact**:
- Loss of HA in case of AZ failure
- Potential downtime: <1% per year (estimated)

**If SLA allows → Additional savings**: **$64.80/month**

---

## 11. Total Estimated Savings

### **Conservative Scenario (Phase 1)**:
**$129.67/month ($1,556.04/year)**

### **Moderate Scenario (Phase 1 + 2)**:
**$182.47/month ($2,189.64/year)**

### **Aggressive Scenario (Phase 1 + 2 + 3)**:
**$247.27/month ($2,967.24/year)**

---

## 12. Comparison with Dev and Staging

| Environment | Current Monthly Cost | After Optimization | Reduction |
|-------------|---------------------|-------------------|-----------|
| **Dev** | $218 | $148 ($70 saved) | -32% |
| **Staging** | $327 | $240 ($87 saved) | -27% |
| **Live** | $673 | $491 ($182 saved) | -27% |
| **TOTAL** | **$1,218** | **$879** | **-28% ($339/month)** |

**Total Annual Savings (3 environments)**: **$4,068/year**

---

## 13. Risks and Mitigations

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|-----------|
| ECS performance degradation | Medium | Medium | Rollback task definitions + CloudWatch alarms |
| OOM on Nakama after downsize | Low | High | Keep 2 GB memory (do not use Option C) |
| NAT Gateway downtime | Low | High | Do not apply in live (or accept 99% SLA) |
| Loss of important logs | Low | Medium | Export critical logs to S3 first |

---

## 14. Next Steps

1. ✅ **Review report with DevOps team**
2. ✅ **Approve Phase 1 (no risk)**
3. ✅ **Create PR in gameplatform-shared-infrastructure**
4. ✅ **Apply changes via Atlantis**
5. ⏳ **Monitor metrics for 1 week**
6. ⏳ **Decide on Phase 2 (ECS rightsizing)**
7. ⏳ **Decide on Phase 3 (NAT Gateway) based on SLA**

---

**Report generated on:** 2025-11-06
**Next review:** 2025-12-06 (after Phase 1 implementation)
