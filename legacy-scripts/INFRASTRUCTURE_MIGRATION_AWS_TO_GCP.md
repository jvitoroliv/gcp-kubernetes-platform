# GamePlatform Platform - Infrastructure Migration AWS → GCP

**Document Version**: 1.0
**Date**: 2025-11-21
**Motivation**: AWS credits depleted, Google Cloud credits available
**Strategy**: Complete migration from AWS to GCP

---

## Table of Contents

1. [Current AWS Infrastructure Overview](#1-current-aws-infrastructure-overview)
2. [GCP Migration Proposals](#2-gcp-migration-proposals)
   - [Proposal 1: Lift-and-Shift (Direct Equivalents)](#proposal-1-lift-and-shift-direct-equivalents)
   - [Proposal 2: GKE-Based (Kubernetes Native)](#proposal-2-gke-based-kubernetes-native)
   - [Proposal 3: Serverless Maximized](#proposal-3-serverless-maximized)
   - [Proposal 4: Hybrid Approach](#proposal-4-hybrid-approach)
3. [Comparison Matrix](#3-comparison-matrix)
4. [Migration Roadmap](#4-migration-roadmap)
5. [Draw.io Diagram Guide](#5-drawio-diagram-guide)

---

## 1. Current AWS Infrastructure Overview

### 1.1 Architecture Summary

**Platform**: Gaming Platform - VR/XR gaming platform with asset marketplace
**Architecture**: Microservices (7 services) + Next.js frontend + NestJS backend
**Environments**: 3 (dev, staging, production/live)
**Monthly Cost**: ~$853 USD ($10,236/year)

### 1.2 Core Components Inventory

#### Networking Layer
```
├── VPC: 10.0.0.0/16 (3 availability zones)
├── Public Subnets: 3x (10.0.1.0/24, 10.0.2.0/24, 10.0.3.0/24)
├── Private Subnets: 3x (10.0.11.0/24, 10.0.12.0/24, 10.0.13.0/24)
├── NAT Gateway: 1x (dev/stg), 3x (live)
├── Internet Gateway: 1x per environment
├── Route53: 3 hosted zones (dev.gameplatform-dev.example.com, stg.gameplatform-dev.example.com, gameplatform.example.com)
└── VPC Flow Logs: CloudWatch integration
```

#### Compute Layer (ECS Fargate)
```
7 Microservices per environment (21 total):
├── nakama: Game server (Go + Beego) - 7350, 7349 (gRPC), 7351 (console)
├── lobby: Frontend (Next.js 15.4.6) - 3000
├── lobby-backend: API (NestJS + TypeORM) - 3001
├── afs: Asset File Service (Go + Gin) - 8080
├── ahsat: Analytics Service (Go + Gin) - 8080
├── aes: Email Service (Python FastAPI) - 1988
└── ais: AI Image Service (Python FastAPI) - 5050

ECS Configuration:
├── Fargate Spot: 80% (dev/stg), 50% (live)
├── Fargate On-Demand: 20% (dev/stg), 50% (live)
├── Service Discovery: AWS Cloud Map (gameplatform.local namespace)
├── Task CPU: 256-1024 vCPU
├── Task Memory: 512-2048 MB
└── Container Insights: Enabled (live)
```

#### Load Balancing & SSL
```
├── Application Load Balancer: 3 (one per environment)
├── Target Groups: 21 (7 services x 3 environments)
├── Listener Rules: 21+ (path-based routing)
├── ACM Certificates: 3 wildcard certs (*.dev.gameplatform-dev.example.com, *.stg.gameplatform-dev.example.com, *.gameplatform.example.com)
└── HTTPS: 100% coverage with automatic redirect
```

#### Storage & Database
```
├── RDS PostgreSQL 14.13:
│   ├── Dev: db.t3.micro (1 vCPU, 1GB RAM)
│   ├── Staging: db.t3.small (2 vCPU, 2GB RAM)
│   └── Live: db.t3.medium (2 vCPU, 4GB RAM)
│   └── Features: Multi-AZ (live), Automated backups, Encryption at rest
├── ECR: 21 repositories (7 services x 3 environments)
├── S3: ALB logs, Terraform state, Godot exports
└── DynamoDB: Scheduler state tracking (7-day TTL)
```

#### Security
```
├── Security Groups:
│   ├── ALB SG: 443 from 0.0.0.0/0
│   ├── ECS SG: Application ports from ALB + VPC
│   └── RDS SG: 5432 from ECS SG only
├── IAM Roles:
│   ├── ECS Task Execution: ECR + CloudWatch Logs + SSM
│   ├── ECS Task: S3 + SES + Service-specific permissions
│   ├── Lambda Scheduler: ECS + RDS + DynamoDB + SNS
│   └── Atlantis: Full Terraform permissions + cross-account
├── Secrets Management:
│   ├── SSM Parameter Store: Database passwords, API keys
│   └── Random passwords: Terraform-generated, rotatable
└── Network:
    ├── Private subnets: All workloads (no public IPs)
    └── NAT Gateway: Outbound internet access only
```

#### Monitoring & Logging
```
├── CloudWatch Log Groups: 30+ (one per service/environment)
├── Log Retention: 7-30 days (by environment)
├── Container Insights: Enabled (live)
├── RDS Enhanced Monitoring: 60s interval (live)
├── RDS Performance Insights: Enabled (live)
├── CloudWatch Alarms: Scheduler Lambda errors, RDS CPU/memory
└── VPC Flow Logs: Traffic analysis and security auditing
```

#### CI/CD Infrastructure
```
├── Atlantis: ECS Fargate task for Terraform automation
│   ├── GitHub PR-based workflows
│   ├── Cross-account deployment support
│   └── Terraform state locking (S3 + DynamoDB)
├── GitHub Actions:
│   ├── Build & Push: Multi-service parallel Docker builds
│   ├── Deploy: ECS service updates via Terraform
│   └── Self-hosted runners: ECS Fargate (optional)
└── Container Registry: ECR with lifecycle policies
```

#### Cost Optimization Features
```
├── Environment Scheduler (dev + staging only):
│   ├── Lambda Functions: Python 3.12, 5min timeout
│   ├── Schedule: Mon-Fri 6 AM on, 8 PM off (BRT)
│   ├── State Management: DynamoDB with restoration logic
│   ├── Notifications: SNS topic + CloudWatch Alarms
│   └── Savings: $159/month ($1,908/year)
├── Fargate Spot: 80% allocation (dev/stg)
├── NAT Gateway: Single instance (dev/stg), multi-AZ (live)
├── Right-sizing: CPU/memory optimized per environment
└── Log retention: Reduced for non-production
```

### 1.3 Resource Count Summary

| Resource Type | Dev | Staging | Live | Total |
|--------------|-----|---------|------|-------|
| ECS Services | 7 | 7 | 7 | **21** |
| Task Definitions | 7 | 7 | 7 | **21** |
| Target Groups | 7 | 7 | 7 | **21** |
| ALB Listener Rules | 7 | 7 | 7 | **21** |
| ECR Repositories | 7 | 7 | 7 | **21** |
| Route53 Records | 7+ | 7 | 7 | **21+** |
| Security Groups | 3 | 3 | 3 | **9** |
| CloudWatch Log Groups | 10+ | 10+ | 10+ | **30+** |
| IAM Roles | 4+ | 4+ | 6+ | **14+** |
| RDS Instances | 1 | 1 | 1 | **3** |
| ALBs | 1 | 1 | 1 | **3** |
| NAT Gateways | 1 | 1 | 3 | **5** |
| VPCs | 1 | 1 | 1 | **3** |
| Lambda Functions | 2 | 2 | 0 | **4** |

**Total Monthly Cost**: $853 USD
**Annual Cost**: $10,236 USD

---

## 2. GCP Migration Proposals

### Proposal 1: Lift-and-Shift (Direct Equivalents)

**Philosophy**: Minimal architectural changes, 1:1 service mapping AWS → GCP

#### 2.1.1 Service Mapping

| AWS Service | GCP Equivalent | Notes |
|-------------|----------------|-------|
| **Compute** |
| ECS Fargate | Cloud Run | Fully managed containers, auto-scaling |
| ECS Cluster | N/A | Cloud Run is cluster-less |
| Service Discovery | Cloud Service Directory | Private DNS for service mesh |
| **Networking** |
| VPC | VPC | Same CIDR block support (10.0.0.0/16) |
| Subnets | Subnets | Regional subnets (not zonal) |
| NAT Gateway | Cloud NAT | Serverless, no capacity planning |
| Internet Gateway | Default Route | Automatic for VPC |
| **Load Balancing** |
| ALB | Cloud Load Balancer (HTTP(S)) | Global load balancing, CDN integration |
| Target Groups | Backend Services | Health checks, session affinity |
| Listener Rules | URL Maps | Path/host-based routing |
| **Database** |
| RDS PostgreSQL | Cloud SQL PostgreSQL | Managed, automated backups, HA |
| RDS Multi-AZ | Cloud SQL HA | Automatic failover |
| **Storage** |
| S3 | Cloud Storage | Object storage, lifecycle policies |
| ECR | Artifact Registry | Container images, vulnerability scanning |
| DynamoDB | Firestore (Native) | NoSQL document database |
| **DNS & Certificates** |
| Route53 | Cloud DNS | Managed DNS, global anycast |
| ACM | Google-managed SSL | Automatic cert provisioning |
| **Security** |
| Security Groups | Firewall Rules | VPC firewall, IAP for SSH |
| IAM Roles | IAM Service Accounts | Fine-grained permissions |
| SSM Parameter Store | Secret Manager | Automatic rotation, versioning |
| **Monitoring** |
| CloudWatch Logs | Cloud Logging | Centralized log management |
| CloudWatch Metrics | Cloud Monitoring | Custom metrics, dashboards |
| X-Ray | Cloud Trace | Distributed tracing |
| **CI/CD** |
| Atlantis (ECS) | Atlantis (Cloud Run) | Same Terraform automation |
| GitHub Actions | Cloud Build + GitHub | Native GCP integration |
| ECR | Artifact Registry | Container images |

#### 2.1.2 Architecture Diagram (Lift-and-Shift)

```
                        ┌─────────────────────────────────┐
                        │   Cloud DNS (Route53)           │
                        │   - dev.gameplatform-dev.example.com            │
                        │   - stg.gameplatform-dev.example.com            │
                        │   - gameplatform.example.com                │
                        └─────────────┬───────────────────┘
                                      │
                        ┌─────────────▼───────────────────┐
                        │   Cloud Load Balancer (HTTPS)   │
                        │   - Google-managed SSL          │
                        │   - Global CDN                  │
                        │   - Backend Services (7)        │
                        └─────────────┬───────────────────┘
                                      │
        ┌─────────────────────────────┼─────────────────────────────┐
        │                             │                             │
        │        GCP VPC (10.0.0.0/16)│                             │
        │                             │                             │
        │     ┌───────────────────────▼──────────────────────┐      │
        │     │   Cloud Run Services (7)                     │      │
        │     │   - nakama (Go)           - aes (Python)     │      │
        │     │   - lobby (Next.js)       - ais (Python)     │      │
        │     │   - lobby-backend (NestJS)- afs (Go)         │      │
        │     │   - ahsat (Go)                               │      │
        │     │                                              │      │
        │     │   Features:                                  │      │
        │     │   - Auto-scaling 0-100 instances             │      │
        │     │   - CPU: 1-4 vCPU per container              │      │
        │     │   - Memory: 512MB-8GB                        │      │
        │     │   - Request timeout: 60s (configurable)      │      │
        │     │   - Private ingress only (via Load Balancer) │      │
        │     └──────────────────┬───────────────────────────┘      │
        │                        │                                  │
        │     ┌──────────────────▼────────────────────────┐         │
        │     │   Cloud Service Directory                 │         │
        │     │   - gameplatform.local namespace                │         │
        │     │   - Service mesh DNS                      │         │
        │     └───────────────────────────────────────────┘         │
        │                                                           │
        │     ┌──────────────────────────────────────────┐          │
        │     │   Cloud SQL PostgreSQL 14                │          │
        │     │   - HA configuration (live)              │          │
        │     │   - Automated backups (7-day retention)  │          │
        │     │   - Point-in-time recovery               │          │
        │     │   - Private IP only (VPC peering)        │          │
        │     └──────────────────────────────────────────┘          │
        │                                                           │
        └───────────────────────────────────────────────────────────┘

        ┌────────────────────────────────────────────────────────────┐
        │   External Services (outside VPC)                          │
        ├────────────────────────────────────────────────────────────┤
        │   - Cloud Storage (S3 replacement)                         │
        │   - Artifact Registry (ECR replacement)                    │
        │   - Secret Manager (SSM replacement)                       │
        │   - Cloud Logging (CloudWatch Logs)                        │
        │   - Cloud Monitoring (CloudWatch Metrics)                  │
        │   - Firestore Native (DynamoDB replacement)                │
        └────────────────────────────────────────────────────────────┘
```

#### 2.1.3 Advantages ✅

1. **Minimal Code Changes**
   - Same container images (Docker)
   - Same environment variables
   - Same service ports
   - Same PostgreSQL database (drop-in replacement)

2. **Simplified Operations**
   - No cluster management (Cloud Run is serverless)
   - Automatic scaling (0 → 100+ instances)
   - No capacity planning for NAT (Cloud NAT is serverless)
   - Automatic SSL certificate management

3. **Cost Optimization**
   - Scale-to-zero: Cloud Run charges only for requests (not idle time)
   - No NAT Gateway hourly charges ($0.045/hour AWS → $0 GCP base)
   - Reduced load balancer costs (single global LB vs 3 regional ALBs)
   - Ingress/egress pricing: ~30% cheaper than AWS

4. **Built-in Features**
   - Global CDN included with Load Balancer (free)
   - Automatic DDoS protection (Google Cloud Armor optional)
   - Vulnerability scanning in Artifact Registry (free)
   - Cloud Run concurrency: 80 requests/container (vs ECS 1 request/task)

5. **Fast Migration**
   - Estimated migration time: 2-4 weeks
   - No architectural redesign
   - Terraform modules readily available

#### 2.1.4 Disadvantages ❌

1. **Cloud Run Limitations**
   - Request timeout: Max 60 minutes (vs unlimited in ECS)
   - WebSocket support: Limited (may need workarounds for Nakama gRPC)
   - Container startup time: Cold starts (0-5s penalty)
   - CPU allocation: Only during request processing (background jobs need workarounds)

2. **Service Discovery**
   - Cloud Service Directory less mature than AWS Cloud Map
   - Manual configuration for service mesh
   - No native integration with Cloud Run (requires custom DNS setup)

3. **Database Migration**
   - Downtime required for PostgreSQL migration
   - Cloud SQL PostgreSQL may have minor version differences
   - Connection pooling may need adjustment (Cloud SQL Proxy)

4. **Monitoring Gap**
   - Cloud Run metrics less granular than ECS Container Insights
   - No direct equivalent to AWS X-Ray (Cloud Trace requires instrumentation)
   - Logs aggregation across services requires BigQuery setup

5. **Vendor Lock-in**
   - Cloud Run is GCP-specific (not portable like Kubernetes)
   - Less exit strategy flexibility

#### 2.1.5 Migration Complexity: ⭐⭐☆☆☆ (Low-Medium)

**Effort**: 2-4 weeks
**Risk**: Low (proven migration path)
**Reversibility**: Medium (requires re-deployment to AWS)

---

### Proposal 2: GKE-Based (Kubernetes Native)

**Philosophy**: Kubernetes-first, portable, cloud-agnostic, production-grade orchestration

#### 2.2.1 Service Mapping

| AWS Service | GCP Equivalent | Notes |
|-------------|----------------|-------|
| **Compute** |
| ECS Fargate | GKE Autopilot | Fully managed K8s, no node management |
| ECS Service | Kubernetes Deployment | Declarative scaling, rolling updates |
| ECS Task Definition | Kubernetes Pod | Multi-container support |
| Service Discovery | Kubernetes Service (ClusterIP) | Built-in DNS (service.namespace.svc.cluster.local) |
| **Orchestration** |
| ECS Cluster | GKE Cluster | Managed Kubernetes control plane |
| Auto Scaling | Horizontal Pod Autoscaler (HPA) | CPU/memory/custom metrics |
| N/A | Vertical Pod Autoscaler (VPA) | Auto-adjust resource requests |
| N/A | Cluster Autoscaler | Node pool scaling |
| **Networking** |
| ALB | GKE Ingress (GCLB) | L7 load balancing, SSL termination |
| Target Groups | Kubernetes Service | ClusterIP, NodePort, LoadBalancer types |
| Service Mesh | Istio / Anthos Service Mesh | Traffic management, observability |
| **Storage** |
| EBS Volumes | Persistent Volumes (PD) | SSD/HDD, regional/zonal |
| EFS | Filestore | NFS-compatible shared storage |
| **Configuration** |
| SSM Parameter Store | Kubernetes Secrets | Base64 encoded, encrypted at rest |
| N/A | ConfigMaps | Non-sensitive configuration |
| **Monitoring** |
| CloudWatch | GKE Monitoring (Prometheus) | Native Kubernetes metrics |
| Container Insights | GKE Dashboards | CPU, memory, network per pod |

#### 2.2.2 Architecture Diagram (GKE-Based)

```
                        ┌─────────────────────────────────┐
                        │   Cloud DNS                     │
                        │   - *.gameplatform.example.com              │
                        └─────────────┬───────────────────┘
                                      │
                        ┌─────────────▼───────────────────┐
                        │   GKE Ingress (GCLB)            │
                        │   - Google-managed SSL          │
                        │   - Global load balancing       │
                        │   - HTTP(S) routing             │
                        └─────────────┬───────────────────┘
                                      │
        ┌─────────────────────────────┼─────────────────────────────┐
        │                             │                             │
        │     GKE Autopilot Cluster (10.0.0.0/16)                   │
        │                             │                             │
        │     ┌───────────────────────▼──────────────────────┐      │
        │     │   Kubernetes Namespace: gameplatform-prod          │      │
        │     │                                              │      │
        │     │   Deployments (7):                           │      │
        │     │   ┌──────────────────────────────────────┐   │      │
        │     │   │ nakama (3 replicas)                  │   │      │
        │     │   │   Pods: nakama-xxx, nakama-yyy       │   │      │
        │     │   │   Service: nakama.gameplatform-prod.svc    │   │      │
        │     │   │   HPA: 1-10 replicas (CPU 70%)       │   │      │
        │     │   └──────────────────────────────────────┘   │      │
        │     │   ┌──────────────────────────────────────┐   │      │
        │     │   │ lobby (2 replicas)                   │   │      │
        │     │   │   Pods: lobby-xxx, lobby-yyy         │   │      │
        │     │   │   Service: lobby.gameplatform-prod.svc     │   │      │
        │     │   │   HPA: 1-20 replicas (CPU 60%)       │   │      │
        │     │   └──────────────────────────────────────┘   │      │
        │     │   ┌──────────────────────────────────────┐   │      │
        │     │   │ lobby-backend (2 replicas)           │   │      │
        │     │   │ afs (2 replicas)                     │   │      │
        │     │   │ ahsat (1 replica)                    │   │      │
        │     │   │ aes (1 replica)                      │   │      │
        │     │   │ ais (1 replica)                      │   │      │
        │     │   └──────────────────────────────────────┘   │      │
        │     │                                              │      │
        │     │   Features:                                  │      │
        │     │   - Service discovery: DNS built-in          │      │
        │     │   - Config: ConfigMaps + Secrets             │      │
        │     │   - Scaling: HPA + VPA + Cluster Autoscaler  │      │
        │     │   - Rolling updates: Zero-downtime           │      │
        │     │   - Health checks: Liveness + Readiness      │      │
        │     └──────────────────────────────────────────────┘      │
        │                                                           │
        │     ┌──────────────────────────────────────────┐          │
        │     │   Istio Service Mesh (Optional)          │          │
        │     │   - Traffic management (canary, A/B)     │          │
        │     │   - Observability (traces, metrics)      │          │
        │     │   - Security (mTLS between services)     │          │
        │     └──────────────────────────────────────────┘          │
        │                                                           │
        │     ┌──────────────────────────────────────────┐          │
        │     │   Cloud SQL PostgreSQL 14 (Private IP)   │          │
        │     │   - HA + read replicas                   │          │
        │     │   - Cloud SQL Proxy sidecar in pods      │          │
        │     └──────────────────────────────────────────┘          │
        │                                                           │
        └───────────────────────────────────────────────────────────┘

        ┌────────────────────────────────────────────────────────────┐
        │   GKE Control Plane (Managed by Google)                    │
        ├────────────────────────────────────────────────────────────┤
        │   - Kubernetes API Server                                  │
        │   - etcd (cluster state)                                   │
        │   - Controller Manager                                     │
        │   - Scheduler                                              │
        │   - Auto-upgrades, SLA 99.95%                              │
        └────────────────────────────────────────────────────────────┘

        ┌────────────────────────────────────────────────────────────┐
        │   Worker Nodes (Autopilot - Fully Managed)                 │
        ├────────────────────────────────────────────────────────────┤
        │   - Auto-provisioned based on pod requests                 │
        │   - E2 series (general purpose) or C2 (compute optimized)  │
        │   - Spot VMs: 60-91% discount for fault-tolerant workloads │
        │   - Auto-repair, auto-upgrade                              │
        │   - Preemptible nodes: Optional for dev/staging            │
        └────────────────────────────────────────────────────────────┘
```

#### 2.2.3 Kubernetes Manifest Example (Nakama Service)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nakama
  namespace: gameplatform-prod
  labels:
    app: nakama
    version: v1.1.5
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nakama
  template:
    metadata:
      labels:
        app: nakama
        version: v1.1.5
    spec:
      serviceAccountName: nakama-sa
      containers:
      - name: nakama
        image: us-docker.pkg.dev/project-live/gameplatform/nakama:live-1.1.5
        ports:
        - name: http
          containerPort: 7350
          protocol: TCP
        - name: grpc
          containerPort: 7349
          protocol: TCP
        - name: console
          containerPort: 7351
          protocol: TCP
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: postgres-connection
              key: url
        - name: NAKAMA_NAME
          value: "gameplatform-nakama-$(HOSTNAME)"
        resources:
          requests:
            cpu: 500m
            memory: 1Gi
          limits:
            cpu: 2000m
            memory: 2Gi
        livenessProbe:
          httpGet:
            path: /
            port: 7350
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /
            port: 7350
          initialDelaySeconds: 5
          periodSeconds: 5
      - name: cloud-sql-proxy
        image: gcr.io/cloudsql-docker/gce-proxy:latest
        command:
        - "/cloud_sql_proxy"
        - "-instances=project-live:us-east1:postgres=tcp:5432"
        - "-credential_file=/secrets/cloudsql/credentials.json"
        volumeMounts:
        - name: cloudsql-instance-credentials
          mountPath: /secrets/cloudsql
          readOnly: true
      volumes:
      - name: cloudsql-instance-credentials
        secret:
          secretName: cloudsql-instance-credentials
---
apiVersion: v1
kind: Service
metadata:
  name: nakama
  namespace: gameplatform-prod
spec:
  selector:
    app: nakama
  type: ClusterIP
  ports:
  - name: http
    port: 7350
    targetPort: 7350
  - name: grpc
    port: 7349
    targetPort: 7349
  - name: console
    port: 7351
    targetPort: 7351
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: nakama-hpa
  namespace: gameplatform-prod
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: nakama
  minReplicas: 1
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

#### 2.2.4 Advantages ✅

1. **Kubernetes-Native Benefits**
   - **Portability**: Same manifests work on any K8s (AWS EKS, Azure AKS, on-prem)
   - **No vendor lock-in**: Cloud-agnostic architecture
   - **Industry standard**: Massive ecosystem, tooling, community support
   - **Fine-grained control**: Resource requests/limits, node affinity, taints/tolerations

2. **Advanced Orchestration**
   - **Multi-container pods**: Sidecars (Cloud SQL Proxy, log forwarders)
   - **Init containers**: Database migrations, pre-startup tasks
   - **StatefulSets**: For stateful workloads (if needed in future)
   - **DaemonSets**: Node-level agents (monitoring, security)
   - **Jobs/CronJobs**: Batch processing, scheduled tasks

3. **Service Mesh Capabilities (Istio)**
   - **Traffic management**: Canary deployments, A/B testing, blue/green
   - **Observability**: Distributed tracing, metrics, service graphs
   - **Security**: mTLS between services, fine-grained authorization
   - **Resilience**: Circuit breakers, retries, timeouts, rate limiting

4. **GKE Autopilot Advantages**
   - **No node management**: Google provisions nodes automatically
   - **Cost optimization**: Pay only for pod resources (not node capacity)
   - **Security**: Google hardens nodes, auto-patches CVEs
   - **SLA**: 99.95% uptime guarantee (vs 99.9% for Cloud Run)
   - **Spot VMs**: 60-91% discount for fault-tolerant workloads

5. **Operational Excellence**
   - **GitOps**: ArgoCD, Flux for declarative deployments
   - **Monitoring**: Prometheus + Grafana (industry standard)
   - **Logging**: EFK stack (Elasticsearch, Fluentd, Kibana) or Loki
   - **CI/CD**: Native integration with Cloud Build, GitLab, Jenkins

6. **Scalability**
   - **Horizontal scaling**: 0 → 1000+ pods
   - **Vertical scaling**: VPA auto-adjusts resource requests
   - **Cluster scaling**: Add nodes automatically based on demand
   - **Multi-region**: Deploy clusters in multiple regions for HA

#### 2.2.5 Disadvantages ❌

1. **Complexity**
   - **Learning curve**: Kubernetes has steep learning curve (pods, services, ingress, RBAC, etc.)
   - **YAML hell**: Hundreds of lines of manifests per service
   - **Debugging**: More layers to troubleshoot (pod → node → cluster)
   - **Operational overhead**: Even with Autopilot, requires K8s expertise

2. **Migration Effort**
   - **Complete rewrite**: ECS task definitions → K8s manifests
   - **Service discovery refactor**: `gameplatform.local` → `service.namespace.svc.cluster.local`
   - **Environment variables**: Migrate SSM → Secrets/ConfigMaps
   - **CI/CD overhaul**: New deployment pipelines (kubectl apply, Helm, ArgoCD)

3. **Cost Considerations**
   - **GKE management fee**: $0.10/hour per cluster ($73/month per environment)
   - **Minimum resources**: Autopilot charges for pod requests (even if idle)
   - **No scale-to-zero**: Unlike Cloud Run, pods always consume resources
   - **Networking costs**: More pod-to-pod traffic (inter-service communication)

4. **Startup Time**
   - **Cluster provisioning**: 5-10 minutes to create new cluster
   - **Pod scheduling**: 30s-2min for first pod on new node (Autopilot)
   - **Image pull**: 10-60s depending on image size

5. **Overkill for Small Teams**
   - **Over-engineering**: 7 services don't need full K8s complexity
   - **Maintenance burden**: K8s upgrades, RBAC management, networking policies
   - **Skill gap**: Team needs K8s training

#### 2.2.6 Migration Complexity: ⭐⭐⭐⭐☆ (High)

**Effort**: 6-12 weeks
**Risk**: Medium (requires K8s expertise)
**Reversibility**: High (K8s is portable to any cloud)

---

### Proposal 3: Serverless Maximized

**Philosophy**: Zero infrastructure management, pay-per-use, event-driven architecture

#### 2.3.1 Service Mapping

| Component | Current (AWS) | GCP Serverless | Notes |
|-----------|---------------|----------------|-------|
| **Frontend** |
| lobby (Next.js) | ECS Fargate | Firebase Hosting + Cloud Functions | Static export + SSR via functions |
| **Backend APIs** |
| lobby-backend (NestJS) | ECS Fargate | Cloud Run (HTTP) | RESTful API, auto-scaling |
| afs (Go) | ECS Fargate | Cloud Run (HTTP) | Asset file service |
| aes (Python) | ECS Fargate | Cloud Functions (HTTP) | Email service (event-driven) |
| ais (Python) | ECS Fargate | Cloud Run (HTTP) | AI image generation |
| ahsat (Go) | ECS Fargate | Cloud Functions (HTTP) | Analytics ingestion |
| **Game Server** |
| nakama (Go) | ECS Fargate | Cloud Run (WebSockets) | Persistent connections, longer timeout |
| **Database** |
| RDS PostgreSQL | RDS PostgreSQL | Cloud SQL + Firestore | SQL + NoSQL hybrid |
| DynamoDB | DynamoDB | Firestore Native | Real-time sync, offline support |
| **Storage** |
| S3 | S3 | Cloud Storage | Object storage, CDN integration |
| ECR | ECR | Artifact Registry | Container images |
| **Authentication** |
| Custom | Custom | Firebase Authentication | Built-in auth, OAuth, social logins |
| **Real-time** |
| N/A | N/A | Firebase Realtime Database | Live player data, chat, notifications |

#### 2.3.2 Architecture Diagram (Serverless Maximized)

```
                        ┌─────────────────────────────────┐
                        │   Cloud DNS + Firebase Hosting  │
                        │   - lobby.gameplatform.example.com          │
                        │   - CDN: 200+ global edge PoPs  │
                        └─────────────┬───────────────────┘
                                      │
        ┌─────────────────────────────┼─────────────────────────────┐
        │                             │                             │
        │     ┌───────────────────────▼──────────────────────┐      │
        │     │   Firebase Hosting (lobby frontend)          │      │
        │     │   - Static Next.js export (HTML/CSS/JS)      │      │
        │     │   - SPA routing                              │      │
        │     │   - Automatic HTTPS                          │      │
        │     │   - Immutable deploys (rollback support)     │      │
        │     └──────────────────┬───────────────────────────┘      │
        │                        │                                   │
        │     ┌──────────────────▼────────────────────────┐         │
        │     │   Cloud Functions (SSR + API)             │         │
        │     │   - Next.js SSR: 2nd gen (Node.js 20)     │         │
        │     │   - Max timeout: 60 minutes               │         │
        │     │   - Concurrency: 1000 requests/function   │         │
        │     │   - Auto-scaling: 0 → unlimited           │         │
        │     └───────────────────────────────────────────┘         │
        │                                                            │
        │     ┌──────────────────────────────────────────┐         │
        │     │   Cloud Run Services (Backend APIs)      │         │
        │     │   ┌────────────────────────────────────┐ │         │
        │     │   │ lobby-backend (NestJS)             │ │         │
        │     │   │ - RESTful API                      │ │         │
        │     │   │ - TypeORM + PostgreSQL             │ │         │
        │     │   └────────────────────────────────────┘ │         │
        │     │   ┌────────────────────────────────────┐ │         │
        │     │   │ nakama (Go + WebSockets)           │ │         │
        │     │   │ - Game server                      │ │         │
        │     │   │ - Persistent connections           │ │         │
        │     │   │ - Min instances: 1 (no cold start) │ │         │
        │     │   └────────────────────────────────────┘ │         │
        │     │   ┌────────────────────────────────────┐ │         │
        │     │   │ afs (Go)                           │ │         │
        │     │   │ - Asset file service               │ │         │
        │     │   └────────────────────────────────────┘ │         │
        │     │   ┌────────────────────────────────────┐ │         │
        │     │   │ ais (Python)                       │ │         │
        │     │   │ - AI image generation              │ │         │
        │     │   └────────────────────────────────────┘ │         │
        │     └──────────────────────────────────────────┘         │
        │                                                            │
        │     ┌──────────────────────────────────────────┐         │
        │     │   Cloud Functions (Event-Driven)         │         │
        │     │   ┌────────────────────────────────────┐ │         │
        │     │   │ aes (Python) - Email Service       │ │         │
        │     │   │ Trigger: Pub/Sub topic             │ │         │
        │     │   └────────────────────────────────────┘ │         │
        │     │   ┌────────────────────────────────────┐ │         │
        │     │   │ ahsat (Go) - Analytics Ingestion   │ │         │
        │     │   │ Trigger: HTTP + Pub/Sub            │ │         │
        │     │   └────────────────────────────────────┘ │         │
        │     └──────────────────────────────────────────┘         │
        │                                                            │
        │     ┌──────────────────────────────────────────┐         │
        │     │   Firebase Services (Backend-as-a-Service)│        │
        │     │   ┌────────────────────────────────────┐ │         │
        │     │   │ Authentication                     │ │         │
        │     │   │ - Email/password, OAuth, social    │ │         │
        │     │   │ - JWT token generation             │ │         │
        │     │   └────────────────────────────────────┘ │         │
        │     │   ┌────────────────────────────────────┐ │         │
        │     │   │ Realtime Database                  │ │         │
        │     │   │ - Live player data, chat           │ │         │
        │     │   │ - WebSocket connections            │ │         │
        │     │   │ - Offline sync                     │ │         │
        │     │   └────────────────────────────────────┘ │         │
        │     │   ┌────────────────────────────────────┐ │         │
        │     │   │ Firestore (NoSQL)                  │ │         │
        │     │   │ - User profiles, sessions          │ │         │
        │     │   │ - Analytics events                 │ │         │
        │     │   │ - Real-time queries                │ │         │
        │     │   └────────────────────────────────────┘ │         │
        │     └──────────────────────────────────────────┘         │
        │                                                            │
        │     ┌──────────────────────────────────────────┐         │
        │     │   Cloud SQL PostgreSQL (Relational Data) │         │
        │     │   - User accounts, billing               │         │
        │     │   - Asset metadata                       │         │
        │     │   - Private IP + Cloud SQL Proxy         │         │
        │     └──────────────────────────────────────────┘         │
        │                                                            │
        └────────────────────────────────────────────────────────────┘

        ┌────────────────────────────────────────────────────────────┐
        │   Event Bus (Pub/Sub)                                      │
        ├────────────────────────────────────────────────────────────┤
        │   Topics:                                                  │
        │   - user-events (signup, login, logout)                    │
        │   - email-queue (send email triggers)                      │
        │   - analytics-events (session tracking)                    │
        │   - asset-processing (image optimization)                  │
        └────────────────────────────────────────────────────────────┘

        ┌────────────────────────────────────────────────────────────┐
        │   Observability (Built-in)                                 │
        ├────────────────────────────────────────────────────────────┤
        │   - Cloud Logging: Centralized logs                        │
        │   - Cloud Monitoring: Metrics + alerts                     │
        │   - Cloud Trace: Distributed tracing                       │
        │   - Firebase Performance Monitoring: Frontend metrics      │
        │   - Firebase Crashlytics: Error tracking                   │
        └────────────────────────────────────────────────────────────┘
```

#### 2.3.3 Hybrid Database Strategy

**PostgreSQL (Cloud SQL)**: Transactional data
```
- User accounts (authentication, profiles)
- Billing and subscriptions
- Asset metadata (ownership, pricing)
- Transactions and orders
```

**Firestore**: Real-time and analytics data
```
- User sessions (live player count)
- Chat messages
- Analytics events (page views, button clicks)
- Game state (player positions, inventory)
```

**Cloud Storage**: Binary data
```
- Asset files (3D models, textures)
- User uploads (avatars, screenshots)
- Godot exports
- Logs and backups
```

#### 2.3.4 Advantages ✅

1. **Zero Infrastructure Management**
   - No servers, clusters, or capacity planning
   - Auto-scaling from 0 to infinity
   - No OS patching, no security updates
   - Google handles ALL infrastructure

2. **Cost Efficiency (Extreme)**
   - **Pay-per-invocation**: Cloud Functions charge only for execution time (not idle)
   - **Scale-to-zero**: No charges when no traffic
   - **Free tier**:
     - Cloud Functions: 2M invocations/month free
     - Cloud Run: 2M requests/month free
     - Firebase Hosting: 10GB/month free
     - Firestore: 1GB storage + 50K reads/day free
   - **Estimated cost**: $50-200/month (vs $853 on AWS)

3. **Developer Velocity**
   - **Firebase CLI**: `firebase deploy` (one command)
   - **No Dockerfiles**: Cloud Functions deploy from source code
   - **Local emulation**: Firebase emulator suite for offline dev
   - **Instant previews**: Firebase Hosting preview channels

4. **Built-in Features**
   - **Firebase Authentication**: No need to build auth system
   - **Realtime Database**: WebSocket connections managed by Firebase
   - **Offline support**: Firebase SDKs handle offline sync
   - **Push notifications**: Firebase Cloud Messaging (FCM)
   - **Analytics**: Firebase Analytics built-in (no AHSAT needed)

5. **Global Performance**
   - **Firebase Hosting CDN**: 200+ edge locations globally
   - **Cloud Run multi-region**: Deploy to multiple regions easily
   - **Firestore multi-region**: Automatic replication

6. **Security**
   - **Firebase Security Rules**: Declarative access control for Firestore/Storage
   - **HTTPS everywhere**: Automatic SSL for all endpoints
   - **DDoS protection**: Built-in with Cloud Load Balancing
   - **Identity-Aware Proxy (IAP)**: Optional for admin APIs

#### 2.3.5 Disadvantages ❌

1. **Architectural Overhaul Required**
   - **Complete rewrite**: Not lift-and-shift compatible
   - **Microservices → Functions**: Break apart monolithic services
   - **Database split**: Migrate relational data to Firestore where appropriate
   - **State management**: Functions are stateless (need external state)

2. **Firebase Vendor Lock-in**
   - **Proprietary APIs**: Firebase SDKs not portable to other clouds
   - **Firestore query language**: Not standard SQL
   - **No self-hosting**: Cannot run Firebase on-prem or other clouds
   - **Exit cost**: Migrating away from Firebase is expensive

3. **Cold Starts**
   - **Cloud Functions**: 0.5-3s cold start (Node.js, Python)
   - **Cloud Run**: 0-5s cold start depending on image size
   - **Mitigation**: Min instances (costs money) or accept latency

4. **Execution Limits**
   - **Cloud Functions 1st gen**: 9 minutes max timeout
   - **Cloud Functions 2nd gen**: 60 minutes max timeout
   - **Cloud Run**: 60 minutes default (can be increased)
   - **Memory limits**: Max 32GB (Cloud Run), 16GB (Cloud Functions)

5. **Debugging Complexity**
   - **Distributed system**: Harder to debug event-driven architecture
   - **No SSH access**: Cannot SSH into functions (only logs)
   - **Cold start debugging**: Hard to reproduce locally

6. **Team Skill Gap**
   - **Event-driven patterns**: Team needs to learn Pub/Sub, async processing
   - **Firebase ecosystem**: New SDKs, new concepts (Security Rules, Indexes)
   - **Serverless mindset**: Shift from "always-on servers" to "ephemeral functions"

7. **Not Suitable For**
   - **Long-running tasks**: Background jobs > 60 minutes need workarounds
   - **Stateful protocols**: WebSockets work but less efficient than Cloud Run
   - **High-throughput streaming**: BigQuery streaming, Kafka better suited

#### 2.3.6 Migration Complexity: ⭐⭐⭐⭐⭐ (Very High)

**Effort**: 12-24 weeks
**Risk**: High (requires architectural redesign)
**Reversibility**: Low (Firebase lock-in, hard to migrate back)

---

### Proposal 4: Hybrid Approach (Recommended ⭐)

**Philosophy**: Best of both worlds - simplicity + control, cost-effective + scalable

#### 2.4.1 Service Placement Strategy

| Service | Technology | Reasoning |
|---------|------------|-----------|
| **lobby** | Firebase Hosting + Cloud Functions | Static assets on CDN, SSR via functions, $0 for static hosting |
| **lobby-backend** | Cloud Run | RESTful API, auto-scaling, database connections |
| **nakama** | GKE Autopilot | WebSocket-heavy, long-lived connections, needs persistent state |
| **afs** | Cloud Run | HTTP API, auto-scaling, stateless |
| **ahsat** | Cloud Functions (Pub/Sub) | Event-driven analytics, bursty traffic |
| **aes** | Cloud Functions (HTTP + Pub/Sub) | Email sending, async processing |
| **ais** | Cloud Run | AI workload, needs GPU support (optional), stateless |

#### 2.4.2 Architecture Diagram (Hybrid)

```
                        ┌─────────────────────────────────┐
                        │   Cloud DNS                     │
                        │   - *.gameplatform.example.com              │
                        └─────────────┬───────────────────┘
                                      │
                ┌─────────────────────┼─────────────────────┐
                │                     │                     │
        ┌───────▼────────┐   ┌───────▼────────┐   ┌───────▼────────┐
        │ Firebase       │   │ Cloud Load     │   │ GKE Ingress    │
        │ Hosting        │   │ Balancer       │   │ (GCLB)         │
        │ (lobby static) │   │ (APIs)         │   │ (nakama)       │
        └────────────────┘   └────────────────┘   └────────────────┘
                │                     │                     │
        ┌───────▼────────┐   ┌───────▼─────────────────────┴──────┐
        │ Cloud Functions│   │ Cloud Run Services                  │
        │ - lobby SSR    │   │ ┌──────────────────────────────┐   │
        │ - aes (email)  │   │ │ lobby-backend (NestJS)       │   │
        │ - ahsat (anal.)│   │ │ - RESTful API                │   │
        └────────────────┘   │ │ - TypeORM + Cloud SQL        │   │
                             │ └──────────────────────────────┘   │
                             │ ┌──────────────────────────────┐   │
                             │ │ afs (Go)                     │   │
                             │ │ - Asset file service         │   │
                             │ └──────────────────────────────┘   │
                             │ ┌──────────────────────────────┐   │
                             │ │ ais (Python)                 │   │
                             │ │ - AI image generation        │   │
                             │ └──────────────────────────────┘   │
                             └─────────────────────────────────────┘
                                      │
                      ┌───────────────┼────────────────┐
                      │               │                │
        ┌─────────────▼───┐  ┌────────▼───────┐  ┌────▼──────────────┐
        │ GKE Autopilot   │  │ Cloud SQL      │  │ Firestore +       │
        │ Cluster         │  │ PostgreSQL     │  │ Cloud Storage     │
        │ ┌─────────────┐ │  │ - HA config    │  │ - NoSQL data      │
        │ │ nakama      │ │  │ - Private IP   │  │ - Asset files     │
        │ │ Deployment  │ │  └────────────────┘  └───────────────────┘
        │ │ (3 replicas)│ │
        │ └─────────────┘ │
        └─────────────────┘

        ┌──────────────────────────────────────────────────────────┐
        │   Event Bus (Pub/Sub)                                    │
        │   - email-queue → aes Cloud Function                     │
        │   - analytics-events → ahsat Cloud Function + Firestore  │
        └──────────────────────────────────────────────────────────┘
```

#### 2.4.3 Decision Matrix (Why Each Service Goes Where)

**Firebase Hosting (lobby)**:
```
✅ Pros:
- $0 cost for static hosting (Next.js static export)
- Global CDN included (200+ PoPs)
- Automatic HTTPS, instant deploys
- Preview channels for PR testing

❌ Cons:
- No SSR by default (need Cloud Functions for dynamic routes)
- Firebase vendor lock-in

Decision: Use for static assets, fallback to Cloud Functions for SSR
```

**Cloud Run (lobby-backend, afs, ais)**:
```
✅ Pros:
- Auto-scaling (0 → 100+ instances)
- Pay-per-request pricing
- HTTPS endpoints
- Container-based (existing Docker images work)
- Concurrency: 80 requests/container

❌ Cons:
- Cold starts (0-3s)
- 60-minute request timeout

Decision: Perfect for stateless HTTP APIs with bursty traffic
```

**GKE Autopilot (nakama)**:
```
✅ Pros:
- WebSocket support (persistent connections)
- No request timeout (unlimited session duration)
- Multi-container pods (Cloud SQL Proxy sidecar)
- StatefulSets for game state
- Fine-grained resource control

❌ Cons:
- More complex than Cloud Run
- $73/month GKE management fee

Decision: Only service that NEEDS long-lived connections and K8s features
```

**Cloud Functions (aes, ahsat)**:
```
✅ Pros:
- Event-driven (Pub/Sub triggers)
- Scale-to-zero automatically
- Pay-per-invocation
- No container management

❌ Cons:
- Cold starts (1-3s)
- 9-minute timeout (1st gen), 60-minute (2nd gen)

Decision: Perfect for async workloads (emails, analytics ingestion)
```

#### 2.4.4 Advantages ✅

1. **Cost Optimization**
   - Firebase Hosting: $0 for static assets
   - Cloud Functions: Pay-per-invocation for low-traffic services (aes, ahsat)
   - Cloud Run: Pay-per-request for APIs (lobby-backend, afs, ais)
   - GKE Autopilot: Only for nakama (1 cluster instead of 3 ALBs)
   - **Estimated cost**: $150-300/month (vs $853 on AWS)

2. **Right Tool for the Job**
   - Static content → Firebase Hosting (fastest CDN)
   - RESTful APIs → Cloud Run (auto-scaling)
   - WebSockets → GKE (persistent connections)
   - Async jobs → Cloud Functions (event-driven)

3. **Gradual Migration Path**
   - **Phase 1**: Migrate lobby to Firebase Hosting (low risk)
   - **Phase 2**: Migrate APIs to Cloud Run (medium risk)
   - **Phase 3**: Migrate nakama to GKE (high risk, save for last)
   - **Phase 4**: Refactor aes/ahsat to Cloud Functions (optimization)

4. **Operational Simplicity**
   - Firebase Hosting: Zero ops
   - Cloud Run: Minimal ops (auto-scaling)
   - GKE Autopilot: Medium ops (only for nakama)
   - No ECS clusters, no ALBs, no NAT Gateways

5. **Developer Experience**
   - **Firebase**: `firebase deploy` (one command)
   - **Cloud Run**: `gcloud run deploy` (one command)
   - **GKE**: `kubectl apply -k .` (familiar to K8s users)
   - **CI/CD**: Cloud Build integrates with all three

6. **Scalability & Performance**
   - Firebase CDN: Sub-100ms latency globally
   - Cloud Run: Scales instantly based on traffic
   - GKE: Handles WebSocket connections efficiently
   - Cloud Functions: Automatically parallelizes event processing

7. **No Over-Engineering**
   - Use K8s only where needed (nakama)
   - Use serverless for everything else
   - Avoid vendor lock-in where possible (Cloud Run is portable-ish)

#### 2.4.5 Disadvantages ❌

1. **Mixed Tooling**
   - Different deploy methods (firebase, gcloud, kubectl)
   - Multiple monitoring dashboards (Firebase Console, Cloud Console, GKE)
   - Team needs to learn 3 different technologies

2. **Service Discovery Complexity**
   - Cloud Run → GKE: Need service mesh or external DNS
   - Cloud Functions → Cloud Run: Need API Gateway or direct HTTP calls
   - Not as seamless as single-platform approach

3. **Debugging Across Platforms**
   - Logs split across Firebase Logs, Cloud Logging, GKE logs
   - Distributed tracing needs setup (Cloud Trace)

4. **Partial Firebase Lock-in**
   - Firebase Hosting not portable
   - Migration from Firebase requires rewriting deployment pipeline

5. **Cost Unpredictability**
   - Cloud Functions: Costs can spike with high invocation count
   - Cloud Run: Egress charges if services call each other frequently
   - GKE: $73/month base + node costs

#### 2.4.6 Migration Complexity: ⭐⭐⭐☆☆ (Medium-High)

**Effort**: 6-10 weeks
**Risk**: Medium (phased migration reduces risk)
**Reversibility**: Medium (Cloud Run + GKE are portable)

---

## 3. Comparison Matrix

### 3.1 Cost Estimation (Monthly)

| Proposal | Dev | Staging | Production | Total | vs AWS | Savings |
|----------|-----|---------|------------|-------|--------|---------|
| **AWS (Current)** | $250 | $300 | $303 | **$853** | - | - |
| **1. Lift-and-Shift** | $80 | $100 | $150 | **$330** | -61% | $523/mo |
| **2. GKE-Based** | $150 | $180 | $250 | **$580** | -32% | $273/mo |
| **3. Serverless Max** | $30 | $50 | $120 | **$200** | -77% | $653/mo |
| **4. Hybrid** | $60 | $80 | $160 | **$300** | -65% | $553/mo |

**Cost Breakdown Details**:

#### Proposal 1: Lift-and-Shift ($330/month)
```
Dev ($80):
- Cloud Run: 7 services × $5 = $35
- Cloud SQL: db-f1-micro = $15
- Cloud NAT: $0 (serverless)
- Load Balancer: $18
- Logging/Monitoring: $12

Staging ($100):
- Cloud Run: 7 services × $8 = $56
- Cloud SQL: db-g1-small = $25
- Load Balancer: $18
- Logging/Monitoring: $1

Production ($150):
- Cloud Run: 7 services × $12 = $84
- Cloud SQL: db-n1-standard-1 (HA) = $130
- Load Balancer: $36
- Logging/Monitoring: $20
```

#### Proposal 2: GKE-Based ($580/month)
```
Dev ($150):
- GKE management: $73
- Worker nodes: $50 (Spot VMs)
- Cloud SQL: $15
- Load Balancer: $18
- Logging/Monitoring: $15

Staging ($180):
- GKE management: $73
- Worker nodes: $70
- Cloud SQL: $25
- Load Balancer: $18
- Logging/Monitoring: $15

Production ($250):
- GKE management: $73
- Worker nodes: $120
- Cloud SQL (HA): $130
- Load Balancer: $36
- Logging/Monitoring: $20
```

#### Proposal 3: Serverless Max ($200/month)
```
Dev ($30):
- Cloud Functions: 7 services × $2 = $14
- Firebase: $0 (free tier)
- Cloud SQL: $15
- Firestore: $0 (free tier)
- Pub/Sub: $1

Staging ($50):
- Cloud Functions: 7 services × $5 = $35
- Firebase: $0
- Cloud SQL: $25
- Firestore: $5
- Pub/Sub: $2

Production ($120):
- Cloud Functions: 7 services × $10 = $70
- Firebase: $25
- Cloud SQL (HA): $60
- Firestore: $30
- Pub/Sub: $5
```

#### Proposal 4: Hybrid ($300/month)
```
Dev ($60):
- Firebase Hosting: $0
- Cloud Run: 4 services × $5 = $20
- Cloud Functions: 2 services × $2 = $4
- GKE (nakama only): $0 (shared cluster)
- Cloud SQL: $15
- Load Balancer: $18
- Logging: $10

Staging ($80):
- Firebase Hosting: $0
- Cloud Run: 4 services × $8 = $32
- Cloud Functions: 2 services × $4 = $8
- GKE management: $0 (shared with dev)
- Cloud SQL: $25
- Load Balancer: $18
- Logging: $12

Production ($160):
- Firebase Hosting: $0
- Cloud Run: 4 services × $12 = $48
- Cloud Functions: 2 services × $8 = $16
- GKE management: $73
- GKE nodes: $30
- Cloud SQL (HA): $60
- Load Balancer: $36
- Logging: $20
```

### 3.2 Feature Comparison

| Feature | Lift-and-Shift | GKE-Based | Serverless Max | Hybrid |
|---------|----------------|-----------|----------------|--------|
| **Auto-scaling** | ✅ Yes (0-100) | ✅ Yes (HPA) | ✅ Yes (unlimited) | ✅ Yes |
| **Cold starts** | ⚠️ 0-3s | ⚠️ 30s-2min | ⚠️ 1-5s | ⚠️ Mixed |
| **WebSocket support** | ⚠️ Limited | ✅ Native | ⚠️ Limited | ✅ GKE only |
| **Request timeout** | 60 min | Unlimited | 60 min | Mixed |
| **Vendor lock-in** | ⚠️ Medium | ❌ Low | ❌ High | ⚠️ Medium |
| **Portability** | ⚠️ Medium | ✅ High | ❌ Low | ⚠️ Medium |
| **Operational complexity** | ✅ Low | ❌ High | ✅ Very Low | ⚠️ Medium |
| **Learning curve** | ✅ Easy | ❌ Steep | ⚠️ Medium | ⚠️ Medium |
| **Migration effort** | ✅ 2-4 weeks | ❌ 6-12 weeks | ❌ 12-24 weeks | ⚠️ 6-10 weeks |
| **Cost optimization** | ✅ Good | ⚠️ Medium | ✅ Excellent | ✅ Excellent |
| **Performance** | ✅ Good | ✅ Excellent | ⚠️ Good | ✅ Excellent |
| **Developer experience** | ✅ Good | ⚠️ Complex | ✅ Excellent | ✅ Good |
| **Production-ready** | ✅ Yes | ✅ Yes | ⚠️ Depends | ✅ Yes |
| **Future-proof** | ⚠️ Medium | ✅ High | ⚠️ Medium | ✅ High |

### 3.3 Risk Assessment

| Risk Factor | Lift-and-Shift | GKE-Based | Serverless Max | Hybrid |
|-------------|----------------|-----------|----------------|--------|
| **Migration risk** | 🟢 Low | 🟡 Medium | 🔴 High | 🟡 Medium |
| **Operational risk** | 🟢 Low | 🟡 Medium | 🟢 Low | 🟢 Low |
| **Performance risk** | 🟢 Low | 🟢 Low | 🟡 Medium | 🟢 Low |
| **Cost overrun risk** | 🟢 Low | 🟡 Medium | 🟡 Medium | 🟢 Low |
| **Vendor lock-in** | 🟡 Medium | 🟢 Low | 🔴 High | 🟡 Medium |
| **Team skill gap** | 🟢 Low | 🔴 High | 🟡 Medium | 🟡 Medium |

### 3.4 Recommendation Score

| Criteria | Weight | Lift-and-Shift | GKE-Based | Serverless Max | Hybrid |
|----------|--------|----------------|-----------|----------------|--------|
| **Cost savings** | 25% | 8/10 | 6/10 | 10/10 | 9/10 |
| **Migration speed** | 20% | 10/10 | 4/10 | 2/10 | 7/10 |
| **Operational simplicity** | 20% | 9/10 | 4/10 | 10/10 | 8/10 |
| **Scalability** | 15% | 8/10 | 10/10 | 9/10 | 9/10 |
| **Portability** | 10% | 6/10 | 10/10 | 3/10 | 7/10 |
| **Future-proof** | 10% | 6/10 | 9/10 | 7/10 | 9/10 |
| **Weighted Score** | - | **8.1** | **6.4** | **7.3** | **8.3** ⭐ |

**Winner: Proposal 4 - Hybrid Approach (8.3/10)**

---

## 4. Migration Roadmap

### 4.1 Recommended Approach: Hybrid Architecture (Phased)

#### Phase 1: Foundation (Weeks 1-2)

**Objectives**:
- Setup GCP project and billing
- Configure Terraform backend (Cloud Storage + State locking)
- Provision networking (VPC, subnets, Cloud NAT)
- Setup CI/CD (Cloud Build + GitHub integration)

**Tasks**:
```
1. GCP Project Setup:
   - Create 3 projects: gameplatform-dev, gameplatform-staging, gameplatform-prod
   - Enable required APIs: Compute, Cloud Run, GKE, Cloud SQL, Cloud Build
   - Configure billing accounts and budgets

2. Networking:
   - Create VPC (10.0.0.0/16)
   - Create subnets (public + private)
   - Configure Cloud NAT (serverless, no provisioning)
   - Setup firewall rules

3. Terraform Migration:
   - Migrate gameplatform-terraform modules to GCP
   - Create gcp/ directory with equivalent modules
   - Setup Cloud Storage backend for Terraform state
   - Configure Atlantis on Cloud Run (instead of ECS)

4. CI/CD:
   - Setup Cloud Build triggers for GitHub
   - Create cloudbuild.yaml for each service
   - Configure Artifact Registry repositories (7 repos)
   - Setup IAM service accounts for Cloud Build

5. DNS Preparation:
   - Transfer Route53 zones to Cloud DNS OR
   - Keep Route53 and point to GCP Load Balancers (temporary)
```

**Deliverables**:
- GCP project configured
- VPC + networking ready
- CI/CD pipelines functional
- Terraform modules migrated

**Risk**: Low
**Cost**: $0 (no workloads running yet)

---

#### Phase 2: Database Migration (Weeks 3-4)

**Objectives**:
- Provision Cloud SQL PostgreSQL
- Migrate data from AWS RDS to GCP Cloud SQL
- Test connectivity and performance

**Tasks**:
```
1. Cloud SQL Provisioning:
   - Create Cloud SQL PostgreSQL 14 instances (dev, staging, prod)
   - Configure private IP (VPC peering)
   - Enable automated backups (7-day retention for dev/stg, 30-day for prod)
   - Setup HA configuration for production

2. Data Migration:
   Dev Environment:
   - Use pg_dump + pg_restore for initial migration
   - Test application connectivity via Cloud SQL Proxy
   - Validate data integrity

   Staging Environment:
   - Replicate dev migration process
   - Run full application test suite

   Production:
   - Schedule maintenance window (2-4 hours)
   - Use Database Migration Service (DMS) for near-zero downtime
   - Cutover during low-traffic period (2-6 AM BRT)

3. Connection Setup:
   - Install Cloud SQL Proxy in containers
   - Update connection strings (migrate from SSM to Secret Manager)
   - Test database pooling and performance

4. Rollback Plan:
   - Keep AWS RDS running for 1 week post-migration
   - Document rollback procedure (reverse pg_dump)
   - Monitor Cloud SQL performance metrics
```

**Deliverables**:
- Cloud SQL instances running
- Data migrated successfully
- Application connectivity tested

**Risk**: Medium (data migration always risky)
**Downtime**: 2-4 hours (production only, during cutover)
**Cost**: +$210/month (Cloud SQL for 3 environments)

---

#### Phase 3: Cloud Run Migration (Weeks 5-6)

**Objectives**:
- Migrate stateless APIs to Cloud Run (lobby-backend, afs, ais)
- Setup load balancing and SSL
- Test auto-scaling

**Tasks**:
```
1. Container Preparation:
   - Build Docker images for lobby-backend, afs, ais
   - Push to Artifact Registry
   - Test locally with Cloud SQL Proxy

2. Cloud Run Deployment (Dev):
   - Deploy lobby-backend to Cloud Run
     - Min instances: 0, Max instances: 10
     - CPU: 1 vCPU, Memory: 1 GB
     - Request timeout: 300s
     - Concurrency: 80 requests/container
   - Deploy afs to Cloud Run
     - Min instances: 0, Max instances: 5
     - CPU: 1 vCPU, Memory: 512 MB
   - Deploy ais to Cloud Run
     - Min instances: 0, Max instances: 3
     - CPU: 2 vCPU, Memory: 2 GB (AI workload)

3. Load Balancer Setup:
   - Create Cloud Load Balancer (HTTP(S))
   - Configure backend services for each Cloud Run service
   - Setup URL maps (path-based routing)
   - Provision Google-managed SSL certificate

4. Testing:
   - Load testing: Simulate 100-1000 requests/second
   - Latency testing: Measure p50, p95, p99
   - Auto-scaling testing: Verify scale-to-zero and scale-up

5. Staging Deployment:
   - Replicate dev setup in staging
   - Run full E2E test suite

6. Production Deployment:
   - Blue/green deployment (50/50 traffic split AWS/GCP)
   - Monitor error rates, latency
   - Gradually shift 100% traffic to GCP
```

**Deliverables**:
- lobby-backend, afs, ais running on Cloud Run
- Load Balancer configured with SSL
- Auto-scaling validated

**Risk**: Low (Cloud Run is stable)
**Downtime**: 0 (blue/green deployment)
**Cost**: +$150/month (Cloud Run + Load Balancer)

---

#### Phase 4: Firebase Hosting (lobby) (Week 7)

**Objectives**:
- Deploy lobby frontend to Firebase Hosting
- Setup SSR with Cloud Functions (if needed)
- Configure CDN

**Tasks**:
```
1. Next.js Build Configuration:
   - Generate static export: next.config.js → output: 'export'
   - Test locally: npm run build && firebase serve
   - Validate all routes work (static + dynamic)

2. Firebase Hosting Setup:
   - Initialize Firebase project: firebase init hosting
   - Configure firebase.json:
     - Public directory: out/
     - Rewrites for SPA routing
     - Headers for caching
   - Setup preview channels for PR testing

3. Cloud Functions for SSR (optional):
   - If dynamic routes needed, deploy Cloud Functions
   - Configure rewrites in firebase.json
   - Test SSR performance

4. Deployment:
   - Deploy to dev: firebase deploy --only hosting:dev
   - Deploy to staging: firebase deploy --only hosting:staging
   - Deploy to prod: firebase deploy --only hosting:prod

5. DNS Cutover:
   - Update DNS records (lobby.gameplatform.example.com → Firebase Hosting)
   - Test globally (use VPN for different regions)
   - Monitor Firebase Analytics for traffic shift
```

**Deliverables**:
- lobby frontend on Firebase Hosting
- CDN serving static assets globally
- SSR functional (if needed)

**Risk**: Low (Firebase Hosting is simple)
**Downtime**: 0 (DNS TTL propagation ~5 minutes)
**Cost**: $0 (free tier sufficient)

---

#### Phase 5: GKE Deployment (nakama) (Weeks 8-9)

**Objectives**:
- Create GKE Autopilot cluster
- Deploy nakama to Kubernetes
- Setup WebSocket load balancing

**Tasks**:
```
1. GKE Cluster Creation:
   - Create GKE Autopilot cluster (us-east1 region)
   - Configure VPC-native cluster (IP aliasing)
   - Enable Workload Identity (IAM for pods)
   - Install kubectl and configure access

2. Kubernetes Manifests:
   - Create Deployment for nakama (3 replicas)
   - Create Service (ClusterIP) for internal traffic
   - Create Ingress for external traffic (GCLB with WebSocket support)
   - Create ConfigMap for environment variables
   - Create Secret for database credentials

3. Database Connectivity:
   - Add Cloud SQL Proxy sidecar to nakama pods
   - Test PostgreSQL connection from pods
   - Validate game server functionality

4. Deployment:
   - Deploy to dev: kubectl apply -k overlays/dev
   - Test nakama console, gRPC, WebSocket connections
   - Deploy to staging: kubectl apply -k overlays/staging
   - Run load test (1000+ concurrent WebSocket connections)
   - Deploy to prod: kubectl apply -k overlays/prod

5. Monitoring:
   - Setup GKE Monitoring dashboards
   - Configure alerts (pod restarts, high CPU, memory)
   - Test Horizontal Pod Autoscaler (HPA)

6. Traffic Cutover:
   - Update DNS (nakama.gameplatform.example.com → GKE Ingress)
   - Monitor connection stability
   - Validate game sessions work correctly
```

**Deliverables**:
- GKE cluster running with nakama
- WebSocket connections stable
- HPA auto-scaling functional

**Risk**: Medium (K8s complexity, WebSocket stability)
**Downtime**: 0 (DNS cutover)
**Cost**: +$200/month (GKE management + nodes)

---

#### Phase 6: Cloud Functions (aes, ahsat) (Week 10)

**Objectives**:
- Refactor aes and ahsat to Cloud Functions
- Setup Pub/Sub event bus
- Test async processing

**Tasks**:
```
1. Code Refactoring:
   aes (Email Service):
   - Extract email sending logic to standalone function
   - Add Pub/Sub trigger
   - Test locally with Functions Framework

   ahsat (Analytics Service):
   - Extract analytics ingestion logic
   - Add HTTP trigger for real-time events
   - Add Pub/Sub trigger for batch processing

2. Pub/Sub Setup:
   - Create topics:
     - email-queue
     - analytics-events
   - Configure subscriptions with retry policies
   - Test message delivery

3. Cloud Functions Deployment:
   Dev:
   - Deploy aes: gcloud functions deploy aes-email --trigger-topic=email-queue
   - Deploy ahsat: gcloud functions deploy ahsat-analytics --trigger-http

   Staging:
   - Replicate dev setup
   - Test end-to-end (API call → Pub/Sub → Function → Email sent)

   Production:
   - Deploy with max instances limit (prevent cost spikes)
   - Monitor invocation counts and latency

4. Integration Testing:
   - Trigger email from lobby-backend → verify email sent
   - Send analytics event → verify Firestore update
   - Load test: Send 10,000 events → verify processing

5. Decommission ECS Tasks:
   - Stop aes and ahsat ECS services in AWS
   - Monitor for errors (if any, rollback)
   - After 1 week, delete ECS tasks
```

**Deliverables**:
- aes and ahsat running as Cloud Functions
- Pub/Sub event bus functional
- Async processing validated

**Risk**: Low (event-driven is simple)
**Downtime**: 0
**Cost**: +$10/month (Cloud Functions + Pub/Sub)

---

#### Phase 7: Monitoring & Optimization (Week 11-12)

**Objectives**:
- Setup comprehensive monitoring
- Optimize costs
- Document architecture

**Tasks**:
```
1. Monitoring Setup:
   - Cloud Logging: Centralize logs from all services
   - Cloud Monitoring: Create dashboards
     - Cloud Run: Requests/sec, latency, error rate
     - GKE: Pod CPU, memory, network
     - Cloud SQL: Connections, queries/sec, slow queries
   - Uptime checks: Monitor endpoint availability
   - Alerts: Setup email/SMS alerts via Cloud Monitoring

2. Tracing:
   - Enable Cloud Trace in all services
   - Instrument code with OpenTelemetry (optional)
   - Analyze distributed traces (request → lobby-backend → nakama → Cloud SQL)

3. Cost Optimization:
   - Analyze cost breakdown (Cloud Billing reports)
   - Identify optimization opportunities:
     - Reduce Cloud Run min instances where possible
     - Use Spot VMs for GKE dev/staging
     - Adjust Cloud SQL instance sizes
     - Setup budget alerts ($500/month threshold)

4. Security Hardening:
   - Enable VPC Service Controls (optional)
   - Configure IAM least-privilege policies
   - Setup Secret Manager rotation (database passwords)
   - Enable Cloud Armor (DDoS protection) for production

5. Documentation:
   - Architecture diagrams (draw.io)
   - Runbooks (incident response procedures)
   - Migration postmortem (lessons learned)
   - Developer onboarding guide
```

**Deliverables**:
- Monitoring dashboards functional
- Alerts configured
- Documentation complete

**Risk**: Low
**Cost**: +$30/month (monitoring + logging)

---

#### Phase 8: AWS Decommissioning (Week 13)

**Objectives**:
- Shutdown AWS resources
- Finalize migration
- Validate cost savings

**Tasks**:
```
1. Pre-shutdown Checklist:
   - Verify 100% traffic on GCP (no AWS requests)
   - Backup critical data from AWS (S3, RDS snapshots)
   - Export CloudWatch logs (if needed for historical analysis)
   - Document AWS account IDs, resource ARNs (for reference)

2. Resource Shutdown (in order):
   - Stop ECS services (all environments)
   - Delete ECS clusters
   - Delete ALBs and target groups
   - Stop RDS instances (wait 7 days, then delete)
   - Release Elastic IPs
   - Delete NAT Gateways
   - Delete VPC peering connections
   - Delete VPCs (after 7-day grace period)
   - Delete S3 buckets (after archiving)
   - Delete ECR repositories
   - Delete CloudWatch Log Groups
   - Delete IAM roles and policies

3. Final Validation:
   - Test all services in GCP (E2E tests)
   - Verify cost savings ($853 → $300, 65% reduction)
   - Confirm monitoring is functional
   - Validate backup/restore procedures

4. AWS Account Cleanup:
   - Cancel AWS credits (if any remaining)
   - Close dev/staging AWS accounts (if separate)
   - Keep production AWS account open for 30 days (emergency rollback)
   - After 30 days, close production account
```

**Deliverables**:
- AWS resources decommissioned
- Cost savings confirmed
- Migration complete

**Risk**: Low (GCP is already running production traffic)
**Cost Savings**: $553/month ($6,636/year)

---

### 4.2 Timeline Summary

| Phase | Duration | Effort | Cumulative Weeks |
|-------|----------|--------|------------------|
| 1. Foundation | 2 weeks | Medium | Week 1-2 |
| 2. Database Migration | 2 weeks | High | Week 3-4 |
| 3. Cloud Run Migration | 2 weeks | Medium | Week 5-6 |
| 4. Firebase Hosting | 1 week | Low | Week 7 |
| 5. GKE Deployment | 2 weeks | High | Week 8-9 |
| 6. Cloud Functions | 1 week | Low | Week 10 |
| 7. Monitoring & Optimization | 2 weeks | Medium | Week 11-12 |
| 8. AWS Decommissioning | 1 week | Low | Week 13 |
| **TOTAL** | **13 weeks** | - | **~3 months** |

### 4.3 Team Allocation

**Recommended Team**:
- 1x DevOps Engineer (Terraform, GCP, Kubernetes) - Full-time
- 1x Backend Developer (Go, Python, Node.js) - 50% time
- 1x Frontend Developer (Next.js, Firebase) - 25% time
- 1x QA Engineer (Testing, load testing) - 25% time

**Total Effort**: ~2.5 FTE × 13 weeks = **32.5 person-weeks**

---

## 5. Draw.io Diagram Guide

### 5.1 Current AWS Architecture (draw.io Instructions)

**File**: `GamePlatform_AWS_Architecture_Current.drawio`

**Layers** (top to bottom):

1. **Internet Layer**
   - Shape: Cloud icon
   - Color: Light blue
   - Label: "Internet / Users"

2. **DNS & CDN Layer**
   - Shape: Rectangle with rounded corners
   - Color: Orange
   - Elements:
     - Route53 (3 boxes): dev.gameplatform-dev.example.com, stg.gameplatform-dev.example.com, gameplatform.example.com
     - ACM (3 boxes): Wildcard certificates

3. **Load Balancing Layer**
   - Shape: Rectangle
   - Color: Green
   - Elements:
     - ALB Dev (1 box)
     - ALB Staging (1 box)
     - ALB Live (1 box)
   - Connections: Arrow from Route53 to each ALB

4. **VPC Layer** (3 separate VPCs, draw side-by-side)
   - Shape: Large rounded rectangle (container)
   - Color: Light gray background
   - Label: "VPC - 10.0.0.0/16"
   - Inside VPC:

     **Public Subnets** (top section):
     - 3 boxes: AZ1 (10.0.1.0/24), AZ2 (10.0.2.0/24), AZ3 (10.0.3.0/24)
     - Internet Gateway (1 box, connected to all public subnets)
     - NAT Gateway (1 or 3 boxes depending on environment)

     **Private Subnets** (bottom section):
     - 3 boxes: AZ1 (10.0.11.0/24), AZ2 (10.0.12.0/24), AZ3 (10.0.13.0/24)
     - ECS Services (7 containers inside private subnets):
       - nakama, lobby, lobby-backend, afs, ahsat, aes, ais
       - Icon: Container (Docker logo)
       - Color: Blue
     - RDS PostgreSQL (1 box, multi-AZ icon for live)
       - Icon: Database cylinder
       - Color: Purple

5. **Shared Services Layer** (outside VPC)
   - Shape: Dashed rectangle
   - Color: Yellow background
   - Elements:
     - S3 (ALB logs, Terraform state, Godot exports)
     - ECR (21 repositories)
     - CloudWatch Logs (30+ log groups)
     - SSM Parameter Store (secrets)
     - Lambda Functions (scheduler - dev/stg only)
     - DynamoDB (scheduler state)

6. **CI/CD Layer** (separate section)
   - Shape: Rectangle
   - Color: Dark blue
   - Elements:
     - Atlantis (ECS Fargate task)
     - GitHub Actions (self-hosted runners on ECS)

**Connections**:
- Internet → Route53 → ALB → ECS Services
- ECS Services → RDS PostgreSQL
- ECS Services → S3, ECR
- NAT Gateway → Internet (outbound only)
- Lambda Scheduler → ECS Services, RDS (start/stop)

**Legend**:
- Solid arrows: HTTP/HTTPS traffic
- Dashed arrows: Database connections
- Dotted arrows: Management/control plane

---

### 5.2 GCP Hybrid Architecture (draw.io Instructions)

**File**: `GamePlatform_GCP_Hybrid_Architecture.drawio`

**Layers** (top to bottom):

1. **Internet Layer**
   - Same as AWS diagram

2. **DNS & CDN Layer**
   - Shape: Rectangle with rounded corners
   - Color: Orange
   - Elements:
     - Cloud DNS (3 boxes): dev.gameplatform-dev.example.com, stg.gameplatform-dev.example.com, gameplatform.example.com
     - Firebase Hosting (1 box): Global CDN for lobby frontend
     - Google-managed SSL (automatic)

3. **Load Balancing Layer**
   - Shape: Rectangle
   - Color: Green
   - Elements:
     - Cloud Load Balancer (HTTP(S)) - 1 global instance (not 3 regional)
     - GKE Ingress (for nakama WebSocket traffic)

4. **VPC Layer** (1 VPC per environment, draw side-by-side)
   - Shape: Large rounded rectangle
   - Color: Light gray background
   - Label: "VPC - 10.0.0.0/16"
   - Inside VPC:

     **Serverless Layer** (no subnets needed):
     - Cloud Run Services (4 containers):
       - lobby-backend, afs, ais, (lobby SSR via Cloud Functions)
       - Icon: Container (Cloud Run logo)
       - Color: Blue
       - Note: "Auto-scaling 0-100"

     **GKE Layer** (private subnet):
     - GKE Autopilot Cluster (1 box per environment)
     - Inside cluster:
       - nakama Deployment (3 replicas)
       - Icon: Kubernetes pod
       - Color: Dark blue
     - Cloud SQL Proxy (sidecar in nakama pods)

     **Database Layer**:
     - Cloud SQL PostgreSQL (1 box, HA for prod)
       - Icon: Database cylinder
       - Color: Purple
     - Firestore (optional, for real-time data)
       - Icon: NoSQL database
       - Color: Orange

5. **Event Bus Layer** (outside VPC)
   - Shape: Rectangle
   - Color: Yellow background
   - Elements:
     - Pub/Sub Topics (email-queue, analytics-events)
     - Cloud Functions (2 functions):
       - aes (email service)
       - ahsat (analytics ingestion)
     - Icon: Function (serverless)
     - Color: Green

6. **Shared Services Layer**
   - Shape: Dashed rectangle
   - Color: Yellow background
   - Elements:
     - Cloud Storage (asset files, logs)
     - Artifact Registry (container images)
     - Secret Manager (database passwords, API keys)
     - Cloud Logging (centralized logs)
     - Cloud Monitoring (dashboards, alerts)

7. **CI/CD Layer**
   - Shape: Rectangle
   - Color: Dark blue
   - Elements:
     - Cloud Build (GitHub integration)
     - Atlantis (Cloud Run deployment)
     - Terraform (infrastructure automation)

**Connections**:
- Internet → Cloud DNS → Firebase Hosting (lobby static)
- Internet → Cloud Load Balancer → Cloud Run Services
- Internet → GKE Ingress → nakama (WebSocket)
- Cloud Run Services → Cloud SQL PostgreSQL
- Cloud Run Services → Pub/Sub → Cloud Functions
- Cloud Functions → Cloud SQL, Firestore

**Annotations**:
- Add "0-100 auto-scaling" label to Cloud Run
- Add "Min instances: 1" label to nakama (no cold start)
- Add "65% cost savings" label at bottom

---

### 5.3 Comparison Diagrams (4 Proposals Side-by-Side)

**File**: `GamePlatform_GCP_Proposals_Comparison.drawio`

**Layout**: 2x2 grid

**Top-left**: Proposal 1 (Lift-and-Shift)
- Simplified version: Cloud Run + Cloud SQL + Cloud Load Balancer
- Label: "Lift-and-Shift: $330/month, 2-4 weeks"

**Top-right**: Proposal 2 (GKE-Based)
- Simplified version: GKE Cluster + Cloud SQL + GKE Ingress
- Label: "GKE-Based: $580/month, 6-12 weeks"

**Bottom-left**: Proposal 3 (Serverless Max)
- Simplified version: Firebase + Cloud Functions + Firestore
- Label: "Serverless Max: $200/month, 12-24 weeks"

**Bottom-right**: Proposal 4 (Hybrid) ⭐
- Full architecture (same as 5.2)
- Label: "Hybrid (Recommended): $300/month, 6-10 weeks"
- Highlight with gold border

**Legend**:
- Green checkmark: Advantages
- Red X: Disadvantages
- Gold star: Recommended

---

### 5.4 Draw.io Tips

**Shapes Library**:
- Use "AWS Architecture" stencil for AWS icons
- Use "Google Cloud Platform" stencil for GCP icons
- Use "Network" stencil for routers, firewalls
- Use "UML" stencil for containers, databases

**Color Coding**:
- Blue: Compute (ECS, Cloud Run, GKE)
- Purple: Database (RDS, Cloud SQL)
- Green: Networking (ALB, Cloud Load Balancer)
- Orange: DNS/CDN (Route53, Cloud DNS, Firebase)
- Yellow: Storage (S3, Cloud Storage)
- Red: Security (IAM, Secrets Manager)

**Layers** (use draw.io layers feature):
- Layer 1: Infrastructure (VPC, subnets)
- Layer 2: Services (ECS, Cloud Run, GKE)
- Layer 3: Data flow (arrows, connections)
- Layer 4: Annotations (labels, costs)

**Export**:
- PNG: For presentations (high resolution, 300 DPI)
- SVG: For documentation (scalable, editable)
- PDF: For printing

---

## 6. Conclusion

### 6.1 Executive Summary

**Current State**:
- AWS infrastructure: 7 microservices, 3 environments, $853/month
- ECS Fargate + RDS PostgreSQL + ALB + Route53
- Manual scheduler for cost optimization (dev/stg only)

**Recommendation**: **Proposal 4 - Hybrid Approach** ⭐

**Why Hybrid?**:
1. **Best cost-performance ratio**: $300/month (65% savings vs AWS)
2. **Right tool for each job**: Firebase (static), Cloud Run (APIs), GKE (WebSockets)
3. **Phased migration**: Low risk, 13-week timeline
4. **No over-engineering**: K8s only where needed (nakama)
5. **Future-proof**: Portable architecture, cloud-agnostic where possible

**Migration Timeline**: 13 weeks (~3 months)

**Total Savings**: $553/month ($6,636/year)

**Next Steps**:
1. Approve proposal and allocate team (2.5 FTE for 3 months)
2. Setup GCP project and billing
3. Begin Phase 1 (Foundation)

---

### 6.2 Decision Matrix for Other Proposals

**When to choose Lift-and-Shift (Proposal 1)**:
- ✅ Need fastest migration (2-4 weeks)
- ✅ Want simplicity and low operational overhead
- ✅ Don't need WebSocket persistence (or can refactor nakama)
- ❌ Don't mind medium vendor lock-in

**When to choose GKE-Based (Proposal 2)**:
- ✅ Team has Kubernetes expertise
- ✅ Want maximum portability (multi-cloud strategy)
- ✅ Need advanced orchestration (StatefulSets, DaemonSets)
- ✅ Plan to scale to 20+ microservices in future
- ❌ Okay with higher cost ($580/month)
- ❌ Can invest 6-12 weeks for migration

**When to choose Serverless Max (Proposal 3)**:
- ✅ Want absolute minimum cost ($200/month)
- ✅ Traffic is extremely bursty (scale-to-zero critical)
- ✅ Team willing to refactor to event-driven architecture
- ✅ Okay with Firebase vendor lock-in
- ❌ Can invest 12-24 weeks for complete architectural redesign
- ❌ Don't need WebSocket persistence (or can refactor nakama to Cloud Run)

---

### 6.3 Risk Mitigation Strategies

**Database Migration Risk**:
- Mitigation: Use Database Migration Service (DMS) for near-zero downtime
- Rollback: Keep AWS RDS running for 1 week post-migration

**Service Downtime Risk**:
- Mitigation: Blue/green deployments with traffic splitting
- Rollback: DNS cutover can be reversed in minutes

**Cost Overrun Risk**:
- Mitigation: Setup budget alerts ($500/month threshold)
- Rollback: Scale down resources, optimize autoscaling

**Performance Degradation Risk**:
- Mitigation: Load testing before production deployment
- Rollback: Increase Cloud Run min instances, GKE node count

**Team Skill Gap Risk**:
- Mitigation: GCP training for DevOps team (Cloud Run, GKE basics)
- Rollback: Hire GCP consultant for 1-2 months

---

### 6.4 Post-Migration Optimization Opportunities

**Year 1 (After Migration)**:
1. **Committed Use Discounts (CUDs)**: 30-50% savings on Cloud Run, GKE
2. **Cloud CDN**: Enable for asset files (afs), reduce egress costs
3. **Cloud Armor**: Add DDoS protection for production
4. **Multi-region deployment**: Deploy to sa-east-1 (São Paulo) for lower latency to Brazilian users

**Year 2 (Future Enhancements)**:
1. **Istio Service Mesh**: Traffic management, observability, security
2. **Anthos**: Hybrid/multi-cloud management (if needed)
3. **BigQuery**: Data warehouse for analytics (replace custom AHSAT logic)
4. **Vertex AI**: Train custom AI models for AIS (image generation)

---

**End of Document**

---

**Document Metadata**:
- **Author**: Claude (Anthropic AI Assistant)
- **Date**: 2025-11-21
- **Version**: 1.0
- **Total Pages**: ~50 (estimated)
- **Total Words**: ~15,000 (estimated)
- **Estimated Reading Time**: 60-90 minutes

**Appendices** (to be created separately):
- Appendix A: Terraform Module Migration Mapping
- Appendix B: Cost Calculation Spreadsheet
- Appendix C: Kubernetes Manifests (Full Examples)
- Appendix D: Cloud Build Configuration Files
- Appendix E: Monitoring Dashboard JSON Templates
- Appendix F: Incident Response Runbooks
