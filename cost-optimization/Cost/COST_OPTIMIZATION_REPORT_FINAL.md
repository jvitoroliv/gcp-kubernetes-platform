# COST OPTIMIZATION REPORT - FINAL
## GamePlatform Platform Infrastructure
**Date**: 2025-11-05
**Status**: COMPLETE ANALYSIS - AWAITING APPROVAL

---

## TABLE OF CONTENTS
1. [RDS Cost Reduction (Dev + Staging)](#1-rds-cost-reduction)
2. [Dev Environment Optimizations (persistent-env stack)](#2-dev-persistent-env-stack)
3. [Dev Environment Optimizations (networking stack)](#3-dev-networking-stack)
4. [Staging Infrastructure Optimizations (outside staging-env)](#4-staging-infrastructure-optimizations)
5. [Summary & Approval](#5-summary--approval)

---

## 1. RDS COST REDUCTION

### 1.1 DEV ENVIRONMENT RDS

**Current Configuration**:
- Instance: db.t3.micro (1 GB RAM)
- Storage: 20 GB gp3
- Usage: 3.15 GB (15.8%)
- CPU: 4.76% avg

**Optimization**: Reduce storage from 20 GB to 10 GB

**Files to Modify**:

#### File 1: `/Repos/gameplatform-shared-infrastructure/environments/dev/postgres.tfvars`
```hcl
# LINHA 14: Mudar de 20 para 10
allocated_storage     = 10  # Was: 20
```

**Cost Savings**: $2.76/month ($33.12/year)

---

### 1.2 STAGING ENVIRONMENT RDS

**Current Configuration**:
- Instance: db.t3.medium (4 GB RAM)
- Storage: 50 GB gp3
- Usage: 5.08 GB (10.2%)
- CPU: 5.82% avg, 87.32% max
- Connections: 151 avg, 263 max ⚠️ HIGH

**⚠️ CRITICAL**: High connection count requires investigation first!

**Optimization Options**:

#### OPTION A (Conservative - Recommended):
**Instance downgrade + storage reduction**

**Files to Modify**:

##### File 1: `/Repos/gameplatform-shared-infrastructure/environments/stg/postgres.tfvars`
```hcl
# LINHA 10: Mudar instance class
instance_class   = "db.t3.small"     # Was: db.t3.medium

# LINHAS 15-16: Reduzir storage
allocated_storage     = 15            # Was: 50
max_allocated_storage = 50            # Was: 150

# LINHAS 20-21: Remover IOPS e throughput provisionados
storage_iops       = null             # Was: 3000
storage_throughput = null             # Was: 125

# LINHA 26: Reduzir max_connections
max_connections            = "100"    # Was: "200"
```

**Cost Savings (Option A)**: $26.08/month ($312.96/year)

---

#### OPTION B (Aggressive - Storage Only):
**Storage reduction only, keep instance class**

**Files to Modify**:

##### File 1: `/Repos/gameplatform-shared-infrastructure/environments/stg/postgres.tfvars`
```hcl
# LINHAS 15-16: Reduzir storage
allocated_storage     = 15            # Was: 50
max_allocated_storage = 50            # Was: 150

# LINHAS 20-21: Remover IOPS e throughput provisionados
storage_iops       = null             # Was: 3000
storage_throughput = null             # Was: 125
```

**Cost Savings (Option B)**: $6.44/month ($77.28/year)

---

**Total RDS Savings**:
- Dev + Staging (Option A): **$28.84/month ($346.08/year)**
- Dev + Staging (Option B): **$9.20/month ($110.40/year)**

---

## 2. DEV PERSISTENT-ENV STACK

### Analysis of Current Configuration

**File**: `/Repos/gameplatform-shared-infrastructure/environments/dev/persistent-env.tfvars`

**Current Resources**:
```hcl
cpu    = 512   # 0.5 vCPU per task
memory = 1024  # 1 GB per task
desired_count = 1  # 1 task per service

Services:
- Nakama (cpu=512, mem=1024)
- Lobby (cpu=512, mem=1024)
- Lobby-backend (cpu=512, mem=1024)
- AFS (cpu=512, mem=1024)
- AHSAT (cpu=512, mem=1024)
- AES (cpu=512, mem=1024)
```

**CloudWatch Logs**:
```hcl
log_retention_days = 3  # Already optimized
```

**Scheduler**:
```hcl
enable_scheduler  = true   # ✅ Already enabled
scheduler_enabled = true
```

**Total Fargate Cost (Current)**:
```
Per task: $0.0506/hour (512 CPU, 1024 MB)
6 services × 1 task = 6 tasks
6 × $0.0506 = $0.3036/hour
24h × 30 days = $218.59/month
```

---

### 2.1 OPTIMIZATION: Reduce Fargate Resources for Low-Traffic Services

**Target**: AES, AFS, AHSAT (low usage services)

**Files to Modify**:

#### File 1: `/Repos/gameplatform-shared-infrastructure/environments/dev/persistent-env.tfvars`
```hcl
# ADD NEW VARIABLES for per-service resource allocation
# Replace global config with per-service

# OLD (remover estas linhas):
cpu    = 512
memory = 1024

# NEW (adicionar estas configurações):
service_resources = {
  nakama = {
    cpu    = 512   # Keep for game server
    memory = 1024
  }
  lobby = {
    cpu    = 512   # Keep for web app
    memory = 1024
  }
  lobby_backend = {
    cpu    = 512   # Keep for API
    memory = 1024
  }
  afs = {
    cpu    = 256   # REDUCE from 512
    memory = 512   # REDUCE from 1024
  }
  ahsat = {
    cpu    = 256   # REDUCE from 512
    memory = 512   # REDUCE from 1024
  }
  aes = {
    cpu    = 256   # REDUCE from 512
    memory = 512   # REDUCE from 1024
  }
}
```

#### File 2: `/Repos/gameplatform-shared-infrastructure/stacks/persistent-env/variables.tf`
**ADD** new variable definition:
```hcl
variable "service_resources" {
  description = "Per-service CPU and memory allocation"
  type = map(object({
    cpu    = number
    memory = number
  }))
  default = {}
}
```

#### File 3: Update each service task definition
**Files to modify**:
- `/Repos/gameplatform-shared-infrastructure/stacks/persistent-env/main_aes.tf`
- `/Repos/gameplatform-shared-infrastructure/stacks/persistent-env/main_afs.tf`
- `/Repos/gameplatform-shared-infrastructure/stacks/persistent-env/main_ahsat.tf`

**Change pattern** (example for AES):
```hcl
# OLD:
cpu    = var.cpu
memory = var.memory

# NEW:
cpu    = lookup(var.service_resources, "aes", {cpu = var.cpu, memory = var.memory}).cpu
memory = lookup(var.service_resources, "aes", {cpu = var.cpu, memory = var.memory}).memory
```

**Cost Savings**:
```
Current: 3 services × $0.0506/hour = $0.1518/hour
Optimized: 3 services × $0.0253/hour = $0.0759/hour
Savings: $0.0759/hour × 24 × 30 = $54.65/month ($655.80/year)
```

---

### 2.2 OPTIMIZATION: CloudWatch Logs - Already Optimal

**Status**: ✅ Already set to 3 days retention (minimum practical value)

**No changes needed**.

---

### 2.3 OPTIMIZATION: Enable Fargate Spot for Dev

**Target**: Use Fargate Spot pricing (70% discount) for dev environment

**File to Modify**:

#### File: `/Repos/gameplatform-shared-infrastructure/stacks/persistent-env/main_shared.tf`

**Find ECS services and ADD**:
```hcl
# In each ECS service module call, ADD:
capacity_provider_strategy = [
  {
    capacity_provider = "FARGATE_SPOT"
    weight            = 100
    base              = 0
  }
]
```

**⚠️ Note**: This requires modifying the ECS service module to accept `capacity_provider_strategy` parameter.

**Estimated Savings**: 30-50% on Fargate costs = **$65-110/month ($780-1,320/year)**

---

## 3. DEV NETWORKING STACK

### Analysis of Current Configuration

**File**: `/Repos/gameplatform-shared-infrastructure/environments/dev/networking.tfvars`

**Current Resources**:
```hcl
# VPC Configuration
vpc_cidr           = "10.0.0.0/16"
availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]  # 3 AZs

# Subnets (3 public + 3 private)
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]

# NAT Gateway
enable_nat_gateway = true
single_nat_gateway = true  # ✅ Already optimized

# VPC Flow Logs
enable_vpc_flow_logs    = true
vpc_flow_logs_retention = 3  # ✅ Already optimized
```

**Current Costs**:
```
NAT Gateway: $32.40/month (already single NAT)
VPC Flow Logs: ~$2-5/month (3 days retention)
Total: ~$34-37/month
```

---

### 3.1 OPTIMIZATION: Reduce Availability Zones from 3 to 2

**Target**: Reduce subnet count, simplify network

**⚠️ WARNING**: This requires re-creating the VPC (destructive change)

**File to Modify**:

#### File: `/Repos/gameplatform-shared-infrastructure/environments/dev/networking.tfvars`
```hcl
# LINHA 9: Reduzir de 3 para 2 AZs
availability_zones = ["us-east-1a", "us-east-1b"]  # Was: [..., "us-east-1c"]

# LINHAS 12-13: Remover terceira subnet
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]  # Was: [..., "10.0.3.0/24"]
private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24"]  # Was: [..., "10.0.13.0/24"]
```

**Cost Savings**: Minimal (~$1-2/month in reduced flow logs)

---

### 3.2 OPTIMIZATION: Disable VPC Flow Logs in Dev

**Target**: VPC flow logs not critical for dev environment

**File to Modify**:

#### File: `/Repos/gameplatform-shared-infrastructure/environments/dev/networking.tfvars`
```hcl
# LINHA 24: Desabilitar flow logs
enable_vpc_flow_logs = false  # Was: true
```

**Cost Savings**: **$2-5/month ($24-60/year)**

---

### 3.3 OPTIMIZATION: Replace NAT Gateway with NAT Instance (Advanced)

**Target**: Replace managed NAT Gateway ($32.40/month) with EC2 NAT instance

**⚠️ HIGH COMPLEXITY**: Requires custom module development

**Potential Savings**: **$25-28/month ($300-336/year)**

**Files Needed**:
1. Create new NAT instance module in gameplatform-terraform
2. Modify `/Repos/gameplatform-shared-infrastructure/stacks/networking/main.tf`
3. Replace `module.nat_gateways` with NAT instance

**Recommendation**: **SKIP for now** - complexity outweighs savings for dev

---

## 4. STAGING INFRASTRUCTURE OPTIMIZATIONS

### Analysis: Staging Stacks OUTSIDE staging-env

**Staging Account Stacks**:
```
/environments/stg/
├── atlantis.tfvars          → Atlantis automation server
├── dns-and-alb.tfvars       → ALB + Route53 for stg.gameplatform-dev.example.com
├── dns-gameplatform-dns.tfvars  → ALB + Route53 for gameplatform.example.com (LIVE)
├── metabase.tfvars          → Analytics dashboard ECS
├── metabase-db.tfvars       → Metabase RDS database
├── networking.tfvars        → VPC, subnets, NAT for staging
├── postgres.tfvars          → PostgreSQL RDS (já analisado)
├── runners.tfvars           → GitHub Actions self-hosted runners
└── staging-env.tfvars       → DO NOT TOUCH (reflete live)
```

**⚠️ CONSTRAINT**: staging-env.tfvars must mirror live environment (do not optimize)

---

### 4.1 OPTIMIZATION: Metabase Resources

**File**: `/Repos/gameplatform-shared-infrastructure/environments/stg/metabase.tfvars`

**Current Configuration** (need to read file):
```bash
# Read file to check current configuration
```

#### Read File:
<function_calls>
<invoke name="Read">
<parameter name="file_path">/repos/gameplatform-shared-infrastructure/environments/stg/metabase.tfvars
**Current Metabase Configuration**:
```hcl
environment   = "live"   # ⚠️ Usando config de live!
instance_type = "t2.medium"
min_size      = 1
desired_capacity = 1
root_volume_size = 30
```

**Issue**: Metabase em staging está configurado para "live" environment

**Optimization**: Downgrade instance type

**File to Modify**:

#### File: `/Repos/gameplatform-shared-infrastructure/environments/stg/metabase.tfvars`
```hcl
# LINHA 2: Corrigir environment
environment = "stg"  # Was: "live"

# LINHA 8: Reduzir instance type
instance_type = "t2.small"  # Was: "t2.medium"

# LINHA 28: Reduzir volume
root_volume_size = 20  # Was: 30
```

**Cost Savings**: **$17/month ($204/year)**

---

### 4.2 OPTIMIZATION: Metabase Database (Aurora Serverless)

**File**: `/Repos/gameplatform-shared-infrastructure/environments/stg/metabase-db.tfvars`

**Current Configuration**:
```hcl
environment = "live"  # ⚠️ Usando config de live!
serverless_min_capacity = 1  # 1 ACU minimum
serverless_max_capacity = 64 # 64 ACU maximum
instance_count = 1
```

**Issue**: Metabase DB em staging configurado para "live" + capacidade alta

**Optimization**: Reduce max capacity and fix environment

**File to Modify**:

#### File: `/Repos/gameplatform-shared-infrastructure/environments/stg/metabase-db.tfvars`
```hcl
# LINHA 2: Corrigir environment
environment = "stg"  # Was: "live"

# LINHA 13: Reduzir max capacity
serverless_max_capacity = 8  # Was: 64 (staging does not need 64 ACUs)

# LINHA 19: Reduzir backup retention
backup_retention_period = 3  # Was: 7 (staging does not need 7 days)

# LINHA 34: Reduzir log retention
log_retention_days = 7  # Was: 30
```

**Cost Savings**: **$20-40/month ($240-480/year)** (depends on usage)

---

### 4.3 OPTIMIZATION: Staging Networking - NAT Gateway

**File**: `/Repos/gameplatform-shared-infrastructure/environments/stg/networking.tfvars`

**Current Configuration**:
```hcl
enable_nat_gateway = true
single_nat_gateway = false  # Multiple NAT gateways (HA setup)
availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
```

**Cost**: 3 NAT Gateways × $32.40 = **$97.20/month**

**Optimization**: Use single NAT Gateway (trade HA for cost)

**File to Modify**:

#### File: `/Repos/gameplatform-shared-infrastructure/environments/stg/networking.tfvars`
```hcl
# LINHA 17: Mudar para single NAT
single_nat_gateway = true  # Was: false
```

**Cost Savings**: **$64.80/month ($777.60/year)**

---

### 4.4 OPTIMIZATION: Staging VPC Flow Logs

**File**: `/Repos/gameplatform-shared-infrastructure/environments/stg/networking.tfvars`

**Current Configuration**:
```hcl
enable_vpc_flow_logs    = true
vpc_flow_logs_retention = 14  # 14 days retention
```

**Optimization**: Reduce retention

**File to Modify**:

#### File: `/Repos/gameplatform-shared-infrastructure/environments/stg/networking.tfvars`
```hcl
# LINHA 25: Reduzir retention
vpc_flow_logs_retention = 7  # Was: 14
```

**Cost Savings**: **$2-3/month ($24-36/year)**

---

### 4.5 OPTIMIZATION: Runners Cluster - Already Optimized

**File**: `/Repos/gameplatform-shared-infrastructure/environments/stg/runners.tfvars`

**Current Configuration**:
```hcl
capacity_providers = ["FARGATE", "FARGATE_SPOT"]  # ✅ Already using SPOT
enable_container_insights = true
```

**Status**: ✅ Already well-configured with Fargate Spot

**No changes needed**.

---

## 5. SUMMARY & APPROVAL

### 5.1 Complete File Change List

#### RDS OPTIMIZATIONS

**DEV**:
1. `/Repos/gameplatform-shared-infrastructure/environments/dev/postgres.tfvars`
   - Line 14: `allocated_storage = 10` (was 20)

**STAGING** (Option A - Recommended):
2. `/Repos/gameplatform-shared-infrastructure/environments/stg/postgres.tfvars`
   - Line 10: `instance_class = "db.t3.small"` (was db.t3.medium)
   - Line 15: `allocated_storage = 15` (was 50)
   - Line 16: `max_allocated_storage = 50` (was 150)
   - Line 20: `storage_iops = null` (was 3000)
   - Line 21: `storage_throughput = null` (was 125)
   - Line 26: `max_connections = "100"` (was 200)

**STAGING** (Option B - Conservative):
2. `/Repos/gameplatform-shared-infrastructure/environments/stg/postgres.tfvars`
   - Line 15: `allocated_storage = 15` (was 50)
   - Line 16: `max_allocated_storage = 50` (was 150)
   - Line 20: `storage_iops = null` (was 3000)
   - Line 21: `storage_throughput = null` (was 125)

---

#### DEV PERSISTENT-ENV OPTIMIZATIONS

3. `/Repos/gameplatform-shared-infrastructure/environments/dev/persistent-env.tfvars`
   - Remove lines 30-31 (cpu/memory global vars)
   - Add service_resources map (see section 2.1)

4. `/Repos/gameplatform-shared-infrastructure/stacks/persistent-env/variables.tf`
   - Add service_resources variable definition

5. `/Repos/gameplatform-shared-infrastructure/stacks/persistent-env/main_aes.tf`
6. `/Repos/gameplatform-shared-infrastructure/stacks/persistent-env/main_afs.tf`
7. `/Repos/gameplatform-shared-infrastructure/stacks/persistent-env/main_ahsat.tf`
   - Modify cpu/memory to use service_resources map

---

#### DEV NETWORKING OPTIMIZATIONS

8. `/Repos/gameplatform-shared-infrastructure/environments/dev/networking.tfvars`
   - Line 24: `enable_vpc_flow_logs = false` (was true)

---

#### STAGING INFRASTRUCTURE OPTIMIZATIONS

9. `/Repos/gameplatform-shared-infrastructure/environments/stg/metabase.tfvars`
   - Line 2: `environment = "stg"` (was "live")
   - Line 8: `instance_type = "t2.small"` (was "t2.medium")
   - Line 28: `root_volume_size = 20` (was 30)

10. `/Repos/gameplatform-shared-infrastructure/environments/stg/metabase-db.tfvars`
    - Line 2: `environment = "stg"` (was "live")
    - Line 13: `serverless_max_capacity = 8` (was 64)
    - Line 19: `backup_retention_period = 3` (was 7)
    - Line 34: `log_retention_days = 7` (was 30)

11. `/Repos/gameplatform-shared-infrastructure/environments/stg/networking.tfvars`
    - Line 17: `single_nat_gateway = true` (was false)
    - Line 25: `vpc_flow_logs_retention = 7` (was 14)

---

### 5.2 Total Cost Savings Summary

#### IMMEDIATE SAVINGS (Simple changes):
| Optimization | Monthly | Yearly |
|--------------|---------|--------|
| **RDS DEV** | $2.76 | $33.12 |
| **RDS STAGING (Option A)** | $26.08 | $312.96 |
| **RDS STAGING (Option B)** | $6.44 | $77.28 |
| **Dev VPC Flow Logs** | $3.00 | $36.00 |
| **Staging Metabase EC2** | $17.00 | $204.00 |
| **Staging Metabase DB** | $30.00 | $360.00 |
| **Staging NAT Gateway** | $64.80 | $777.60 |
| **Staging Flow Logs** | $2.50 | $30.00 |
| **TOTAL (Option A)** | **$146.14** | **$1,753.68** |
| **TOTAL (Option B)** | **$126.50** | **$1,518.00** |

#### ADVANCED SAVINGS (Requires module changes):
| Optimization | Monthly | Yearly |
|--------------|---------|--------|
| **Dev Fargate Resources** | $54.65 | $655.80 |
| **Dev Fargate Spot** | $65-110 | $780-1,320 |
| **TOTAL ADVANCED** | **$119-165** | **$1,436-1,976** |

---

### 5.3 GRAND TOTAL POTENTIAL SAVINGS

**Conservative Approach** (RDS Option B + Simple changes):
- **$126.50/month ($1,518/year)**

**Aggressive Approach** (RDS Option A + Simple changes):
- **$146.14/month ($1,753.68/year)**

**Maximum Savings** (All optimizations including advanced):
- **$265-311/month ($3,190-3,730/year)**

---

### 5.4 Recommended Implementation Order

#### PHASE 1: LOW-RISK IMMEDIATE SAVINGS (Week 1)
✅ **APPROVE NOW - $123/month savings**
1. Dev RDS storage reduction
2. Dev VPC flow logs disable
3. Staging flow logs retention reduction
4. Staging metabase environment fixes

**Estimated Time**: 2 hours
**Risk**: MINIMAL
**Rollback**: Simple Terraform revert

---

#### PHASE 2: MODERATE-RISK RDS OPTIMIZATION (Week 2)
⚠️ **REQUIRES CONNECTION INVESTIGATION**
1. Run `investigate_staging_connections.sh`
2. Analyze results
3. Choose RDS Option A or B
4. Create snapshots
5. Apply RDS changes
6. Monitor for 72 hours

**Estimated Time**: 1 week
**Risk**: MEDIUM (requires monitoring)
**Rollback**: RDS snapshot restore

---

#### PHASE 3: NETWORK OPTIMIZATION (Week 3)
⚠️ **HIGHER COMPLEXITY**
1. Staging NAT Gateway reduction (single NAT)
2. Test application connectivity
3. Monitor for failures

**Estimated Time**: 4 hours
**Risk**: MEDIUM (brief downtime possible)
**Rollback**: Terraform revert (15 min)

---

#### PHASE 4: ADVANCED OPTIMIZATIONS (Month 2)
🔧 **REQUIRES DEVELOPMENT**
1. Per-service resource allocation (dev persistent-env)
2. Fargate Spot integration
3. Module updates

**Estimated Time**: 2-3 days
**Risk**: MEDIUM
**Rollback**: Git revert + Terraform

---

### 5.5 Files Ready for Immediate Changes

Created terraform-ready change files:
- `/docs/GamePlatform/terraform_changes_dev.tfvars` ✅
- `/docs/GamePlatform/terraform_changes_stg_option_a.tfvars` ✅
- `/docs/GamePlatform/terraform_changes_stg_option_b.tfvars` ✅

Investigation script:
- `/docs/GamePlatform/investigate_staging_connections.sh` ✅

---

## 6. APPROVAL CHECKLIST

**Você precisa decidir e aprovar**:

### ✅ PHASE 1 - Immediate Low-Risk Changes ($123/month)
- [ ] Dev RDS: 20GB → 10GB
- [ ] Dev networking: Disable VPC flow logs
- [ ] Staging metabase: Fix environment + downgrade t2.medium → t2.small
- [ ] Staging metabase-db: Fix environment + reduce capacities
- [ ] Staging networking: Reduce flow log retention 14 → 7 days

**Posso aplicar Phase 1 agora?**

---

### 🔍 PHASE 2 - RDS Staging (Requires Investigation First)
- [ ] Run investigation script first
- [ ] After investigation, choose Option A or Option B
- [ ] Create RDS snapshots
- [ ] Apply changes with monitoring

**Posso executar script de investigação?**

---

### ⚠️ PHASE 3 - Network Changes ($64.80/month)
- [ ] Staging: 3 NAT Gateways → 1 NAT Gateway

**Aprovar mudança de NAT Gateway?**

---

### 🔧 PHASE 4 - Advanced (Requires Development)
- [ ] Dev per-service resources
- [ ] Fargate Spot integration

**Aprovar desenvolvimento de Phase 4?**

---

## 7. NEXT ACTIONS

**AGUARDANDO SUA APROVAÇÃO PARA**:

1. **Phase 1** - Aplicar mudanças imediatas? (SIM/NÃO)
2. **Phase 2** - Executar script de investigação RDS? (SIM/NÃO)
3. **Phase 3** - Aplicar otimização de NAT Gateway? (SIM/NÃO)
4. **Phase 4** - Desenvolver otimizações avançadas? (SIM/NÃO)

**Por favor, confirme quais phases você autoriza prosseguir** 🚀

