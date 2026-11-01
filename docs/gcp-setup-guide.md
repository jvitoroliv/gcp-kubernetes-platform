# Complete Guide - GamePlatform Infrastructure on Google Cloud Platform

**Version**: 1.0
**Date**: 2025-12-17
**Author**: DevOps Engineer
**Purpose**: Reference guide for Google Cloud meeting

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [GCP Project Structure](#2-gcp-project-structure)
3. [Infrastructure Components](#3-infrastructure-components)
4. [Networking and Security](#4-networking-and-security)
5. [Kubernetes (GKE)](#5-kubernetes-gke)
6. [Database (Cloud SQL)](#6-database-cloud-sql)
7. [Storage (GCS)](#7-storage-gcs)
8. [CI/CD and GitOps](#8-cicd-and-gitops)
9. [Secrets and Configuration](#9-secrets-and-configuration)
10. [VPN and Access](#10-vpn-and-access)
11. [AWS vs GCP Comparison](#11-aws-vs-gcp-comparison)
12. [IAM and Permissions](#12-iam-and-permissions)
13. [Tools Used](#13-tools-used)
14. [Costs and Optimizations](#14-costs-and-optimizations)
15. [GCP Glossary](#15-gcp-glossary)

---

## 1. Architecture Overview

### 1.1 High-Level Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                                   INTERNET                                      │
│                                       │                                         │
│         ┌─────────────────────────────┼────────────────────────────┐            │
│         │                             │                            │            │
│         ▼                             ▼                            ▼            │
│  ┌─────────────┐              ┌─────────────┐              ┌─────────────┐      │
│  │ Cloud DNS   │              │   Global    │              │  WireGuard  │      │
│  │*.dev.gameplatform│              │ Load        │              │    VPN      │      │
│  │.example.com │              │ Balancer    │              │  (Bastion)  │      │
│  └──────┬──────┘              └──────┬──────┘              └──────┬──────┘      │
│         │                            │                            │             │
│         └────────────────────────────┼────────────────────────────┘             │
│                                      │                                          │
│                                      ▼                                          │
│  ┌──────────────────────────────────────────────────────────────────────────┐   │
│  │                        VPC: gameplatform-nonprod-vpc                           │   │
│  │                         CIDR: 10.0.0.0/8                                 │   │
│  │                                                                          │   │
│  │  ┌────────────────┐  ┌────────────────┐  ┌────────────────────────────┐  │   │
│  │  │  DEV CLUSTER   │  │  STG CLUSTER   │  │    RUNNERS CLUSTER         │  │   │
│  │  │ project-dev-    │  │ project-stg-    │  │  gameplatform-nonprod-runners    │  │   │
│  │  │   workloads    │  │   workloads    │  │                            │  │   │
│  │  │                │  │                │  │  ┌──────────┐ ┌──────────┐ │  │   │
│  │  │ ┌────────────┐ │  │ ┌────────────┐ │  │  │ ArgoCD   │ │   ARC    │ │  │   │
│  │  │ │ 8 Services │ │  │ │ 8 Services │ │  │  │(GitOps)  │ │(Runners) │ │  │   │
│  │  │ │  (Pods)    │ │  │ │  (Pods)    │ │  │  └──────────┘ └──────────┘ │  │   │
│  │  │ └────────────┘ │  │ └────────────┘ │  │  ┌──────────────────────┐  │  │   │
│  │  │                │  │                │  │  │ External Secrets Op. │  │  │   │
│  │  └───────┬────────┘  └───────┬────────┘  │  └──────────────────────┘  │  │   │
│  │          │                   │           └────────────────────────────┘  │   │
│  │          │                   │                                           │   │
│  │          └─────────┬─────────┘                                           │   │
│  │                    │                                                     │   │
│  │                    ▼                                                     │   │
│  │  ┌────────────────────────────────────────────────────────────────────┐  │   │
│  │  │                             CLOUD SQL                              │  │   │
│  │  │      ┌─────────────────────┐  ┌─────────────────────┐              │  │   │
│  │  │      │ project-dev-postgres │  │ project-stg-postgres │              │  │   │
│  │  │      │   PostgreSQL 15     │  │   PostgreSQL 15     │              │  │   │
│  │  │      │   10.148.0.3        │  │   10.148.0.7        │              │  │   │
│  │  │      └─────────────────────┘  └─────────────────────┘              │  │   │
│  │  └────────────────────────────────────────────────────────────────────┘  │   │
│  │                                                                          │   │
│  │  ┌────────────────────────────────────────────────────────────────────┐  │   │
│  │  │                     NAT GATEWAY                                    │  │   │
│  │  │         (Internet egress - external APIs)                          │  │   │
│  │  └────────────────────────────────────────────────────────────────────┘  │   │
│  │                                                                          │   │
│  └──────────────────────────────────────────────────────────────────────────┘   │
│                                                                                 │
│  ┌──────────────────────────────────────────────────────────────────────────┐   │
│  │                       SHARED SERVICES                                    │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │   │
│  │  │  Artifact    │  │   Secret     │  │    Cloud     │  │    Cloud     │  │   │
│  │  │  Registry    │  │   Manager    │  │   Storage    │  │   Logging    │  │   │
│  │  │  (Images)    │  │  (Secrets)   │  │   (GCS)      │  │  (Logs)      │  │   │
│  │  └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘  │   │
│  └──────────────────────────────────────────────────────────────────────────┘   │
│                                                                                 │
│                              GOOGLE CLOUD PLATFORM                              │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### 1.2 The 8 Microservices

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           GAMEPLATFORM PLATFORM                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│  8 Microservices running across 3 Environments (Dev, Staging, Production)   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│    ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐       │
│    │   NAKAMA    │  │    LOBBY    │  │   LOBBY     │  │     APS     │       │
│    │ Game Server │  │  Frontend   │  │  BACKEND    │  │  Payments   │       │
│    │  Go/Beego   │  │  Next.js    │  │   NestJS    │  │   Go/Gin    │       │
│    │ :7349-7351  │  │   :3000     │  │   :3001     │  │   :4444     │       │
│    └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘       │
│                                                                             │
│    ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐       │
│    │     AFS     │  │    AHSAT    │  │     AES     │  │     AIS     │       │
│    │ Asset Files │  │  Analytics  │  │   Email     │  │  AI Image   │       │
│    │  Go/Gin     │  │   Go/Gin    │  │   Python    │  │   Python    │       │
│    │   :9933     │  │   :6969     │  │   :1988     │  │   :5050     │       │
│    └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘       │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

| Service | Technology | Port | Function |
|---------|-----------|-------|--------|
| **Nakama** | Go/Beego | 7349-7351 | Game server (multiplayer, matchmaking) |
| **Lobby** | Next.js 15 | 3000 | Web frontend (React) |
| **Lobby-Backend** | NestJS 11 | 3001 | Backend API (authentication, worlds) |
| **APS** | Go/Gin | 4444 | Payments (Yuno) |
| **AFS** | Go/Gin | 9933 | Asset File Service (GCS uploads/downloads) |
| **AHSAT** | Go/Gin | 6969 | Analytics and metrics |
| **AES** | Python/FastAPI | 1988 | Email Service (AWS SES) |
| **AIS** | Python/FastAPI | 5050 | AI Image Service (Piapi) |

---

## 2. GCP Project Structure

### 2.1 Project Organization

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                         GCP ORGANIZATION                                     │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────────┐  │
│  │                    project-nonprod-env                                  │  │
│  │                    Project ID: 000000000000                           │  │
│  │                    Region: us-east1                                    │  │
│  │                                                                        │  │
│  │    Contains:                                                           │  │
│  │    • Shared VPC (dev + stg + runners)                                  │  │
│  │    • 3 GKE clusters (dev-workloads, stg-workloads, nonprod-runners)    │  │
│  │    • 2 Cloud SQL instances (dev, stg)                                  │  │
│  │    • Artifact Registry (Docker images)                                 │  │
│  │    • Secret Manager (dev + stg secrets)                                │  │
│  │    • Cloud Storage (dev + stg buckets)                                 │  │
│  │    • WireGuard VPN (bastion)                                           │  │
│  │                                                                        │  │
│  └────────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────────┐  │
│  │                    project-prd-env (FUTURE)                             │  │
│  │                    Region: southamerica-east1 (São Paulo)              │  │
│  │                                                                        │  │
│  │    Will contain:                                                       │  │
│  │    • Isolated VPC (production)                                         │  │
│  │    • GKE cluster (prd-workloads)                                       │  │
│  │    • Cloud SQL (production, HA)                                        │  │
│  │    • Dedicated production resources                                    │  │
│  │                                                                        │  │
│  └────────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

### 2.2 Why This Structure?

| Decision | Rationale |
|---------|---------------|
| **nonprod separate from prd** | Cost isolation, separate billing, blast radius containment |
| **Dev + Stg in the same VPC** | NAT Gateway cost savings, network simplicity |
| **Runners in a separate cluster** | Avoid competing for resources with workloads |
| **PRD in Brazil region** | Latency for Brazilian users |

---

## 3. Infrastructure Components

### 3.1 Terraform Stacks (Execution Order)

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                    TERRAFORM/TERRAGRUNT STACKS                               │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  NONPROD (Shared)                                                            │
│  ├── 02-networking     → VPC, Subnets, NAT Gateway, Firewall                 │
│  ├── 06-workloads      → Artifact Registry, GitHub OIDC                      │
│  ├── 07-vpn-bastion    → WireGuard VPN, Bastion Host                         │
│  └── 08-gke-runners    → Runners cluster (ArgoCD, ARC)                       │
│                                                                              │
│  DEV                                                                         │
│  ├── 01-foundation     → Enabled APIs, IAM, Service Accounts                 │
│  ├── 03-gke            → GKE cluster dev-workloads                           │
│  ├── 04-database       → Cloud SQL PostgreSQL (dev)                          │
│  ├── 05-dns-lb         → Cloud DNS, Load Balancer                            │
│  └── 06-workloads      → ESO Service Account                                 │
│                                                                              │
│  STG                                                                         │
│  ├── 01-foundation     → Enabled APIs, IAM, Service Accounts                 │
│  ├── 03-gke            → GKE cluster stg-workloads                           │
│  ├── 04-database       → Cloud SQL PostgreSQL (stg)                          │
│  ├── 05-dns-lb         → Cloud DNS, Load Balancer                            │
│  └── 06-workloads      → ESO Service Account                                 │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

### 3.2 Git Repositories

| Repository | Contents | Language |
|-------------|----------|-----------|
| **gameplatform-monorepo** | Source code for 8 services + env files | TypeScript, Go, Python |
| **platform-kubernetes-infrastructure** | Helm charts, ArgoCD apps, Kustomize | YAML |
| **gameplatform-shared-infrastructure-gcp** | Terraform/Terragrunt (IaC) | HCL |
| **gameplatform-shared-actions** | Reusable GitHub Actions | YAML |
| **gameplatform-terraform** | Private Terraform modules | HCL |

---

## 4. Networking and Security

### 4.1 Network Architecture

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                    VPC: gameplatform-nonprod-vpc                                   │
│                    Primary CIDR: 10.0.0.0/8                                  │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  SUBNETS (Per Cluster/Function)                                              │
│  ┌──────────────────────────────────────────────────────────────────────┐    │
│  │ DEV WORKLOADS                                                        │    │
│  │ ├── Nodes:    10.100.0.0/20   (4096 IPs for nodes)                   │    │
│  │ ├── Pods:     10.104.0.0/14   (262144 IPs for pods)                  │    │
│  │ ├── Services: 10.108.0.0/20   (4096 IPs for services)                │    │
│  │ └── Master:   172.16.0.0/28   (Control Plane)                        │    │
│  └──────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────────┐    │
│  │ STG WORKLOADS                                                        │    │
│  │ ├── Nodes:    10.48.0.0/20                                           │    │
│  │ ├── Pods:     10.52.0.0/14                                           │    │
│  │ ├── Services: 10.64.0.0/20                                           │    │
│  │ └── Master:   172.16.2.0/28                                          │    │
│  └──────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────────┐    │
│  │ RUNNERS                                                              │    │
│  │ ├── Nodes:    10.120.0.0/20                                          │    │
│  │ ├── Pods:     10.124.0.0/14                                          │    │
│  │ ├── Services: 10.128.0.0/20                                          │    │
│  │ └── Master:   172.16.1.0/28                                          │    │
│  └──────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────────┐    │
│  │ CLOUD SQL (Private Service Access)                                   │    │
│  │ └── Range:    10.148.0.0/20                                          │    │
│  └──────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────────┐    │
│  │ VPN CLIENTS (WireGuard)                                              │    │
│  │ └── Range:    10.200.0.0/24                                          │    │
│  └──────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

### 4.2 Traffic Flow

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                         TRAFFIC FLOWS                                        │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  INBOUND                                                                     │
│  ─────────────────                                                           │
│                                                                              │
│  Internet → Cloud Load Balancer → GKE Ingress → Pods                         │
│                                                                              │
│  Developers → WireGuard VPN (51820/UDP) → Bastion → Internal Resources       │
│                                                                              │
│                                                                              │
│  OUTBOUND                                                                    │
│  ────────────────                                                            │
│                                                                              │
│  Pods → NAT Gateway → Internet (external APIs)                               │
│                                                                              │
│    ┌─────────────────────────────────────────────────────────────────────┐   │
│    │  External APIs used:                                                │   │
│    │                                                                     │   │
│    ├── Google OAuth (oauth2.googleapis.com)                               │   │
│    ├── AWS SES (email-smtp.us-east-1.amazonaws.com)                       │   │
│    ├── Piapi AI (api.piapi.ai)                                            │   │
│    ├── Yuno Payments (api-sandbox.y.uno)                                   │   │
│    └── Ready Player Me (models.readyplayer.me)                            │   │
│                                                                              │
│                                                                              │
│  INTERNAL (East-West)                                                        │
│  ───────────────────                                                         │
│                                                                              │
│  Pod → Service DNS → Pod                                                     │
│  Example: lobby-backend → nakama.gameplatform-dev.svc.cluster.local               │
│                                                                              │
│  Pod → Cloud SQL Private IP (10.148.0.x)                                     │
│                                                                              │
│  Pod → GCS (via googleapis.com, internal)                                    │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 4.3 Security - Private Clusters

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    GKE PRIVATE CLUSTER                                       │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                         INTERNET                                       │  │
│  │                            │                                           │  │
│  │                            ✕ (Blocked)                                 │  │
│  │                            │                                           │  │
│  │  Direct cluster access from the Internet is not possible               │  │
│  │                                                                        │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                    ALLOWED ACCESS                                      │  │
│  │                                                                        │  │
│  │  1. VPN (WireGuard)                                                    │  │
│  │     └── Developer connects VPN → Access kubectl                        │  │
│  │                                                                        │  │
│  │  2. Runners (GitHub Actions)                                           │  │
│  │     └── Pods in runners cluster → Access other clusters' API           │  │
│  │         (via master_authorized_networks)                               │  │
│  │                                                                        │  │
│  │  3. Cloud Console / gcloud                                             │  │
│  │     └── Via IAP (Identity-Aware Proxy)                                 │  │
│  │                                                                        │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│  Configuration:                                                              │
│  • enable_private_nodes = true                                               │
│  • enable_private_endpoint = false (access via VPN)                          │
│  • master_authorized_networks = [VPN CIDR, Runners CIDR]                     │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 5. Kubernetes (GKE)

### 5.1 Clusters Created

| Cluster | Region | Nodes | Machine Type | Purpose |
|---------|--------|-------|--------------|-----------|
| **project-dev-workloads** | us-east1 | 4 | e2-standard-2 | DEV Workloads |
| **project-stg-workloads** | us-east1 | 7 | e2-standard-8 | STG Workloads |
| **gameplatform-nonprod-runners** | us-east1 | 6 | e2-standard-8 | CI/CD, ArgoCD, ARC |

### 5.2 Cluster Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    GKE CLUSTER (project-dev-workloads)                        │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  CONTROL PLANE (Managed by Google)                                           │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │ • API Server (172.16.0.2)                                              │  │
│  │ • etcd (cluster data)                                                  │  │
│  │ • Controller Manager                                                   │  │
│  │ • Scheduler                                                            │  │
│  │ [You do NOT manage this - Google handles it]                           │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│  NODE POOLS (You manage)                                                     │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │ Node Pool: project-dev-general                                          │  │
│  │ ├── Machine Type: e2-standard-2 (2 vCPU, 8GB RAM)                      │  │
│  │ ├── Nodes: 4 (min: 1, max: 10 - autoscaling)                           │  │
│  │ ├── Disk: 100GB SSD                                                    │  │
│  │ └── Preemptible: No (production workloads)                             │  │
│  │                                                                        │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐   │  │
│  │  │   Node 1    │  │   Node 2    │  │   Node 3    │  │   Node 4    │   │  │
│  │  │ ┌─────────┐ │  │ ┌─────────┐ │  │ ┌─────────┐ │  │ ┌─────────┐ │   │  │
│  │  │ │ lobby   │ │  │ │ nakama  │ │  │ │  afs    │ │  │ │  ahsat  │ │   │  │
│  │  │ │ pod     │ │  │ │  pod    │ │  │ │  pod    │ │  │ │  pod    │ │   │  │
│  │  │ └─────────┘ │  │ └─────────┘ │  │ └─────────┘ │  │ └─────────┘ │   │  │
│  │  │ ┌─────────┐ │  │ ┌─────────┐ │  │ ┌─────────┐ │  │ ┌─────────┐ │   │  │
│  │  │ │lobby-be │ │  │ │   ais   │ │  │ │   aes   │ │  │ │   aps   │ │   │  │
│  │  │ │  pod    │ │  │ │  pod    │ │  │ │  pod    │ │  │ │  pod    │ │   │  │
│  │  │ └─────────┘ │  │ └─────────┘ │  │ └─────────┘ │  │ └─────────┘ │   │  │
│  │  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘   │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│  NAMESPACES                                                                  │
│  ├── gameplatform-dev         → Pods for the 8 services                            │
│  ├── external-secrets   → ESO (External Secrets Operator)                    │
│  ├── ingress-nginx      → Ingress Controller                                 │
│  └── kube-system        → System components                                  │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 5.3 Why GKE and Not Cloud Run?

| Criterion | GKE | Cloud Run |
|----------|-----|-----------|
| **Control** | Full cluster control | Serverless, less control |
| **Networking** | VPC-native, private clusters | Limited |
| **Stateful** | Supported (Nakama requires it) | Not ideal |
| **Predictable cost** | Yes (fixed nodes) | Variable |
| **Multi-container** | Sidecar patterns | Limited |
| **Helm/Operators** | Supported | Not supported |

**Decision**: GKE due to application complexity (game server, multiple interconnected services).

---

## 6. Database (Cloud SQL)

### 6.1 Instances

| Instance | Version | Tier | vCPU | RAM | Private IP |
|-----------|--------|------|------|-----|------------|
| project-dev-postgres | PostgreSQL 15 | db-custom-1-3840 | 1 | 3.8GB | 10.148.0.3 |
| project-stg-postgres | PostgreSQL 15 | db-custom-2-7680 | 2 | 7.5GB | 10.148.0.7 |

### 6.2 Security Configuration

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    CLOUD SQL - PRIVATE ACCESS                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────┐      Private Service Access      ┌─────────────────┐   │
│  │   GKE Cluster   │ ─────────────────────────────────▶│   Cloud SQL     │   │
│  │                 │       (10.148.0.0/20)             │                 │   │
│  │  Pod (nakama)   │                                   │ 10.148.0.3:5432 │   │
│  └─────────────────┘                                   └─────────────────┘   │
│                                                                              │
│  • No public IP                                                              │
│  • Connection via VPC (Private Service Access)                               │
│  • SSL required                                                              │
│  • Automatic daily backups                                                   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 6.3 Databases per Service

| Database | Service | Description |
|----------|---------|-----------|
| nakama_db | Nakama | Game state, matchmaking, leaderboards |
| lobby_db | Lobby-Backend | Users, worlds, avatars |

---

## 7. Storage (GCS)

### 7.1 Buckets Created

| Bucket | Purpose | Access |
|--------|-----------|--------|
| dev-gameplatform-server-software-dev | Service assets (AFS, AIS) | Private |
| galapagos-exports-gcs | Godot client exports | Public |
| gameplatform-nonprod-terraform-state | Terraform state | Private |

### 7.2 Exports Bucket Structure

```
gs://galapagos-exports-gcs/
├── lobby/
│   ├── dev/
│   │   ├── index.7z          ← Godot client (automatic download)
│   │   └── old/              ← Backups
│   ├── stg/
│   └── prd/
```

### 7.3 GCS Access

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    GCS ACCESS - WORKLOAD IDENTITY                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  Method: Workload Identity (no keys!)                                        │
│                                                                              │
│  ┌─────────────────┐                          ┌─────────────────┐            │
│  │   Pod (AFS)     │                          │   GCS Bucket    │            │
│  │                 │                          │                 │            │
│  │  K8s Service    │    Workload Identity     │  IAM Policy     │            │
│  │  Account: afs   │ ───────────────────────▶ │  (roles/storage │            │
│  │                 │                          │   .objectAdmin) │            │
│  └─────────────────┘                          └─────────────────┘            │
│         │                                                                    │
│         │ K8s SA annotation                                                  │
│         ▼                                                                    │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │ annotations:                                                         │    │
│  │   iam.gke.io/gcp-service-account: afs-sa@project.iam.gserviceaccount│    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
│  Benefits:                                                                   │
│  • No service keys (more secure)                                             │
│  • Automatic credential rotation                                             │
│  • Audit via Cloud Audit Logs                                                │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 8. CI/CD and GitOps

### 8.1 CI/CD Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         COMPLETE CI/CD FLOW                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│    Developer                                                                 │
│        │                                                                     │
│        │ git push                                                            │
│        ▼                                                                     │
│  ┌───────────────────┐                                                       │
│  │  gameplatform-monorepo  │                                                       │
│  │  (source code)    │                                                       │
│  └────────┬──────────┘                                                       │
│           │                                                                  │
│           │ Trigger: push to development                                     │
│           ▼                                                                  │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │                    GITHUB ACTIONS (CI)                                │   │
│  │                    runs-on: gameplatform-heavy (self-hosted)                │   │
│  ├──────────────────────────────────────────────────────────────────────┤   │
│  │                                                                       │   │
│  │  Job 1: detect-changes                                                │   │
│  │  ┌────────────────────────────────────────────────────────────────┐  │   │
│  │  │  Detects which services changed (applications/**)              │  │   │
│  │  │  Output: matrix of services to build                           │  │   │
│  │  └────────────────────────────────────────────────────────────────┘  │   │
│  │                              │                                        │   │
│  │  Job 2: build-and-push      ▼                                        │   │
│  │  ┌────────────────────────────────────────────────────────────────┐  │   │
│  │  │  1. Auth GCP via OIDC (Workload Identity Federation)           │  │   │
│  │  │  2. docker build -t $REGISTRY/$SERVICE:$TAG                    │  │   │
│  │  │  3. docker push → Artifact Registry                            │  │   │
│  │  └────────────────────────────────────────────────────────────────┘  │   │
│  │                              │                                        │   │
│  │  Job 3: update-helm-values  ▼                                        │   │
│  │  ┌────────────────────────────────────────────────────────────────┐  │   │
│  │  │  1. Checkout platform-kubernetes-infrastructure                  │  │   │
│  │  │  2. Update image tag in values-dev.yaml                        │  │   │
│  │  │  3. git commit + push                                          │  │   │
│  │  └────────────────────────────────────────────────────────────────┘  │   │
│  │                                                                       │   │
│  └────────────────────────────────┬─────────────────────────────────────┘   │
│                                   │                                          │
│                                   ▼                                          │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │              platform-kubernetes-infrastructure                         │   │
│  │              (Kubernetes manifests - Helm Charts)                      │   │
│  │  ┌────────────────────────────────────────────────────────────────┐  │   │
│  │  │  charts/game-platform/values-dev.yaml                        │  │   │
│  │  │    lobby:                                                      │  │   │
│  │  │      image:                                                    │  │   │
│  │  │        tag: "dev-abc1234"  ← CI updated this                   │  │   │
│  │  └────────────────────────────────────────────────────────────────┘  │   │
│  └────────────────────────────────┬─────────────────────────────────────┘   │
│                                   │                                          │
│           ArgoCD detects change   │ (reconcile every 30s)                    │
│                                   ▼                                          │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │                         ArgoCD (GitOps)                               │   │
│  │                    (runs on the runners cluster)                       │   │
│  │  ┌────────────────────────────────────────────────────────────────┐  │   │
│  │  │  Application: game-platform-dev                              │  │   │
│  │  │  Source: github.com/.../platform-kubernetes-infrastructure       │  │   │
│  │  │  Destination: project-dev-workloads cluster                     │  │   │
│  │  │  Sync: Automated (auto-sync + auto-prune)                      │  │   │
│  │  └────────────────────────────────────────────────────────────────┘  │   │
│  │                              │                                        │   │
│  │   helm upgrade game-platform ./charts/game-platform               │   │
│  │                              │                                        │   │
│  └──────────────────────────────┼───────────────────────────────────────┘   │
│                                 ▼                                            │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │                    GKE CLUSTER (dev-workloads)                        │   │
│  │  ┌────────────────────────────────────────────────────────────────┐  │   │
│  │  │  Rolling Update: lobby pod                                     │  │   │
│  │  │  Old pod (v1) → Terminating                                    │  │   │
│  │  │  New pod (v2) → Running ✓                                      │  │   │
│  │  └────────────────────────────────────────────────────────────────┘  │   │
│  │                                                                       │   │
│  │  DEPLOY COMPLETE! ~5 minutes total                                    │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 8.2 Self-Hosted Runners (ARC)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    ACTIONS RUNNER CONTROLLER (ARC)                           │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  Cluster: gameplatform-nonprod-runners                                             │
│                                                                              │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │  Namespace: arc-systems                                                │  │
│  │  ┌─────────────────────────────────────────────────────────────────┐  │  │
│  │  │  ARC Controller                                                  │  │  │
│  │  │  • Monitors GitHub for pending jobs                              │  │  │
│  │  │  • Scales runners automatically (0 → N → 0)                      │  │  │
│  │  └─────────────────────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │  Namespace: arc-runners                                                │  │
│  │  ┌─────────────────────────────────────────────────────────────────┐  │  │
│  │  │  Runner Scale Set: gameplatform-heavy                                  │  │  │
│  │  │  • Custom image with: Node, Go, Python, Docker, gcloud           │  │  │
│  │  │  • Min: 0, Max: 10                                               │  │  │
│  │  │  • Machine: e2-standard-8 (8 vCPU, 32GB RAM)                     │  │  │
│  │  └─────────────────────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│  Benefits:                                                                   │
│  • Runners inside the VPC (access to private resources)                      │
│  • Scale to zero (cost savings when no builds running)                       │
│  • Custom image with all required tools                                      │
│  • Builds ~3x faster than GitHub-hosted                                      │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 8.3 ArgoCD

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              ArgoCD                                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  What is it?                                                                 │
│  └── GitOps tool that keeps the cluster synchronized with Git                │
│                                                                              │
│  How does it work?                                                           │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                                                                      │    │
│  │   Git Repository                    Kubernetes Cluster               │    │
│  │   (Desired State)                   (Actual State)                   │    │
│  │        │                                   │                         │    │
│  │        │         ArgoCD compares            │                         │    │
│  │        └──────────────┬───────────────────┘                         │    │
│  │                       │                                              │    │
│  │                       ▼                                              │    │
│  │              ┌────────────────┐                                      │    │
│  │              │ Automatic sync  │                                      │    │
│  │              │ (every 30s)     │                                      │    │
│  │              └────────────────┘                                      │    │
│  │                                                                      │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
│  Configured applications:                                                    │
│  ├── game-platform-dev  → Cluster dev-workloads                            │
│  └── game-platform-stg  → Cluster stg-workloads                            │
│                                                                              │
│  Access:                                                                     │
│  └── Via VPN: kubectl port-forward svc/argocd-server 8080:443 -n argocd     │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 9. Secrets and Configuration

### 9.1 Secrets Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    SECRETS MANAGEMENT                                        │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                    GCP SECRET MANAGER                                │    │
│  │                                                                      │    │
│  │  Stored secrets:                                                     │    │
│  │  ├── project-dev-nakama-secrets                                       │    │
│  │  │   └── DATABASE_URL, SERVER_KEY, etc.                              │    │
│  │  ├── project-dev-lobby-secrets                                        │    │
│  │  │   └── NEXTAUTH_SECRET, GOOGLE_CLIENT_SECRET                       │    │
│  │  ├── project-dev-lobby-backend-secrets                                │    │
│  │  └── ... (one per service)                                           │    │
│  │                                                                      │    │
│  └────────────────────────────────┬────────────────────────────────────┘    │
│                                   │                                          │
│                  External Secrets Operator (ESO)                             │
│                      Sync every 1 hour                                       │
│                                   │                                          │
│                                   ▼                                          │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                    KUBERNETES SECRETS                                │    │
│  │                                                                      │    │
│  │  kubectl get secrets -n gameplatform-dev                                   │    │
│  │  ├── nakama-secrets                                                  │    │
│  │  ├── lobby-secrets                                                   │    │
│  │  ├── lobby-backend-secrets                                           │    │
│  │  └── ...                                                             │    │
│  │                                                                      │    │
│  └────────────────────────────────┬────────────────────────────────────┘    │
│                                   │                                          │
│                    Pod mounts as env vars                                     │
│                                   │                                          │
│                                   ▼                                          │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                         POD                                          │    │
│  │                                                                      │    │
│  │  envFrom:                                                            │    │
│  │    - secretRef:                                                      │    │
│  │        name: nakama-secrets                                          │    │
│  │                                                                      │    │
│  │  env:                                                                │    │
│  │    DATABASE_URL=postgres://...                                       │    │
│  │    SERVER_KEY=abc123...                                              │    │
│  │                                                                      │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 9.2 ConfigMaps Flow (Non-Sensitive Variables)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    CONFIGMAPS MANAGEMENT                                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                    GIT REPOSITORY                                    │    │
│  │                                                                      │    │
│  │  gameplatform-monorepo/environment-variables/dev/                          │    │
│  │  ├── lobby.env                                                       │    │
│  │  │   └── NEXTAUTH_URL, NEXT_PUBLIC_*, ENVIRONMENT                    │    │
│  │  ├── nakama.env                                                      │    │
│  │  ├── afs.env                                                         │    │
│  │  └── ... (one per service)                                           │    │
│  │                                                                      │    │
│  └────────────────────────────────┬────────────────────────────────────┘    │
│                                   │                                          │
│              GitHub Actions: sync-configmaps.yml                             │
│              Trigger: push to environment-variables/**                        │
│                                   │                                          │
│                                   ▼                                          │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                    KUBERNETES CONFIGMAPS                             │    │
│  │                                                                      │    │
│  │  kubectl create configmap lobby-config \                             │    │
│  │    --from-env-file=lobby.env \                                       │    │
│  │    --namespace=gameplatform-dev                                            │    │
│  │                                                                      │    │
│  └────────────────────────────────┬────────────────────────────────────┘    │
│                                   │                                          │
│                    Pod mounts as env vars                                     │
│                                   │                                          │
│                                   ▼                                          │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                         POD                                          │    │
│  │                                                                      │    │
│  │  envFrom:                                                            │    │
│  │    - configMapRef:                                                   │    │
│  │        name: lobby-config                                            │    │
│  │                                                                      │    │
│  │  env:                                                                │    │
│  │    NEXTAUTH_URL=https://lobby.dev-gameplatform.example.com/                      │    │
│  │    ENVIRONMENT=dev                                                   │    │
│  │                                                                      │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 10. VPN and Access

### 10.1 WireGuard VPN

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    WIREGUARD VPN                                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  Bastion Host: gameplatform-nonprod-bastion                                        │
│  External IP: 198.51.100.100                                                  │
│  Port: 51820/UDP                                                             │
│                                                                              │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                         INTERNET                                       │  │
│  │                             │                                          │  │
│  │     Developer               │                                          │  │
│  │    ┌─────────────┐          │                                          │  │
│  │    │ WireGuard   │──────────┼────────┐                                 │  │
│  │    │  Client     │   UDP 51820       │                                 │  │
│  │    │ 10.200.0.x  │                   │                                 │  │
│  │    └─────────────┘                   │                                 │  │
│  │                                      │                                 │  │
│  └──────────────────────────────────────┼─────────────────────────────────┘  │
│                                         │                                    │
│  ┌──────────────────────────────────────┼─────────────────────────────────┐  │
│  │                              GCP VPC │                                 │  │
│  │                                      ▼                                 │  │
│  │                          ┌─────────────────┐                           │  │
│  │                          │    Bastion      │                           │  │
│  │                          │   WireGuard     │                           │  │
│  │                          │   Server        │                           │  │
│  │                          │  10.200.0.1     │                           │  │
│  │                          └────────┬────────┘                           │  │
│  │                                   │                                    │  │
│  │      ┌────────────────────────────┼────────────────────────────┐       │  │
│  │      │                            │                            │       │  │
│  │      ▼                            ▼                            ▼       │  │
│  │ ┌──────────┐              ┌──────────────┐              ┌──────────┐   │  │
│  │ │   GKE    │              │   Cloud SQL  │              │   GCS    │   │  │
│  │ │ Clusters │              │  10.148.0.x  │              │ Buckets  │   │  │
│  │ └──────────┘              └──────────────┘              └──────────┘   │  │
│  │                                                                        │  │
│  └────────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│  Networks accessible via VPN:                                                │
│  ├── 10.100.0.0/20  - Dev nodes                                              │
│  ├── 10.104.0.0/14  - Dev pods                                               │
│  ├── 10.48.0.0/20   - Stg nodes                                              │
│  ├── 10.52.0.0/14   - Stg pods                                               │
│  ├── 10.120.0.0/20  - Runners nodes                                          │
│  ├── 10.148.0.0/20  - Cloud SQL                                              │
│  ├── 172.16.0.0/28  - Dev master                                             │
│  ├── 172.16.1.0/28  - Runners master                                         │
│  └── 172.16.2.0/28  - Stg master                                             │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 10.2 VPN User Management

```bash
# Connect to the bastion
gcloud compute ssh gameplatform-nonprod-bastion \
    --zone=us-east1-b \
    --tunnel-through-iap \
    --project=project-nonprod-env

# Create new user
sudo /etc/wireguard/add-user.sh username

# List users
sudo /etc/wireguard/list-users.sh

# Remove user
sudo /etc/wireguard/remove-user.sh username
```

---

## 11. AWS vs GCP Comparison

### 11.1 Equivalent Services

| Category | AWS (Previous) | GCP (Current) | Notes |
|-----------|--------------|------------|-------|
| **Container Orchestration** | ECS Fargate | **GKE** | Full Kubernetes vs proprietary Fargate |
| **Load Balancer** | ALB (regional) | **Cloud Load Balancer** | Global vs regional |
| **Database** | RDS PostgreSQL | **Cloud SQL** | Direct equivalent |
| **Container Registry** | ECR | **Artifact Registry** | AR supports more formats |
| **DNS** | Route53 | **Cloud DNS** | Equivalent |
| **Secrets** | SSM Parameter Store | **Secret Manager** | SM has better versioning |
| **Object Storage** | S3 | **Cloud Storage** | Equivalent |
| **Monitoring** | CloudWatch | **Cloud Monitoring** | Complete stack |
| **VPN** | N/A (public) | **WireGuard** | New security requirement |
| **CI/CD** | GitHub Actions (hosted) | **ARC (self-hosted)** | Runners inside VPC |
| **IaC** | Terraform | **Terragrunt + Terraform** | Better organized |
| **GitOps** | N/A | **ArgoCD** | New component |

### 11.2 Architecture Differences

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    AWS (BEFORE)                                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  • 3 separate VPCs (dev, stg, prd)                                           │
│  • 3 regional ALBs                                                           │
│  • ECS Fargate (serverless, no nodes)                                        │
│  • Public environment (internet-accessible)                                  │
│  • GitHub-hosted Actions runners                                             │
│  • Direct deploy via terraform apply                                         │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                    GCP (NOW)                                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  • 1 shared VPC (dev + stg), PRD separate                                    │
│  • Global Load Balancer                                                      │
│  • GKE with managed nodes                                                    │
│  • Private environment (VPN required)                                        │
│  • Self-hosted runners on GKE (ARC)                                          │
│  • GitOps with ArgoCD                                                        │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 11.3 Advantages of the New Architecture

| Aspect | Improvement |
|---------|----------|
| **Security** | 100% private environment, VPN required |
| **Observability** | Kubernetes-native (kubectl, logs, metrics) |
| **Flexibility** | Helm charts, sidecar patterns, operators |
| **Cost** | Shared VPC, scale-to-zero runners |
| **CI/CD** | GitOps, automatic rollbacks, audit trail |
| **Developer Experience** | Native kubectl, mature K8s tooling |

---

## 12. IAM and Permissions

### 12.1 Service Accounts

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    SERVICE ACCOUNTS                                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  GCP Service Accounts (IAM)                                                  │
│  ──────────────────────────                                                  │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │ github-actions-sa@project-nonprod-env.iam.gserviceaccount.com        │    │
│  │ └── Roles:                                                          │    │
│  │     • roles/artifactregistry.writer (push images)                   │    │
│  │     • roles/container.developer (deploy to GKE)                     │    │
│  │     • roles/iam.workloadIdentityUser (OIDC federation)              │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │ eso-sa@project-nonprod-env.iam.gserviceaccount.com                   │    │
│  │ └── Roles:                                                          │    │
│  │     • roles/secretmanager.secretAccessor (read secrets)             │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │ afs-sa@project-nonprod-env.iam.gserviceaccount.com                   │    │
│  │ └── Roles:                                                          │    │
│  │     • roles/storage.objectAdmin (GCS read/write)                    │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │ ais-sa@project-nonprod-env.iam.gserviceaccount.com                   │    │
│  │ └── Roles:                                                          │    │
│  │     • roles/storage.objectAdmin (GCS read/write)                    │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
│  Kubernetes Service Accounts (linked via Workload Identity)                  │
│  ────────────────────────────────────────────────────────────────────────    │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │ external-secrets (namespace: external-secrets)                      │    │
│  │ └── Annotation: iam.gke.io/gcp-service-account: eso-sa@...          │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │ afs (namespace: gameplatform-dev)                                         │    │
│  │ └── Annotation: iam.gke.io/gcp-service-account: afs-sa@...          │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 12.2 Workload Identity Federation (GitHub Actions)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    WORKLOAD IDENTITY FEDERATION                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  How GitHub Actions authenticates to GCP WITHOUT keys:                       │
│                                                                              │
│  ┌─────────────────┐                          ┌─────────────────┐            │
│  │  GitHub Actions │                          │      GCP        │            │
│  │    Workflow     │                          │                 │            │
│  └────────┬────────┘                          └────────┬────────┘            │
│           │                                            │                     │
│           │ 1. GitHub generates OIDC token             │                     │
│           │    (JWT signed by GitHub)                   │                     │
│           │                                            │                     │
│           └────────────────────────────────────────────┤                     │
│                                                        │                     │
│                                          2. GCP verifies token               │
│                                             via Workload Identity            │
│                                             Federation                       │
│                                                        │                     │
│                                          3. If valid, returns                │
│                                             GCP access token                 │
│                                                        │                     │
│           ┌────────────────────────────────────────────┘                     │
│           │                                                                  │
│           │ 4. Workflow uses token to                                        │
│           │    push images, deploy, etc.                                     │
│           ▼                                                                  │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │  Benefits:                                                          │    │
│  │  • No service keys (more secure)                                    │    │
│  │  • Short-lived tokens (1 hour)                                      │    │
│  │  • Complete audit in Cloud Audit Logs                               │    │
│  │  • Principle of least privilege                                     │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 13. Tools Used

### 13.1 Infrastructure as Code

| Tool | Version | Usage |
|------------|--------|-----|
| **Terraform** | 1.5+ | GCP resource definitions |
| **Terragrunt** | 0.68.0 | DRY for Terraform, inter-stack dependencies |
| **Helm** | 3.x | Kubernetes application packaging |
| **Kustomize** | - | Environment overlays |

### 13.2 CI/CD

| Tool | Usage |
|------------|-----|
| **GitHub Actions** | CI/CD pipelines |
| **ARC (Actions Runner Controller)** | Self-hosted runners on GKE |
| **ArgoCD** | GitOps, continuous deployment |

### 13.3 Kubernetes

| Component | Usage |
|------------|-----|
| **GKE** | Managed Kubernetes |
| **External Secrets Operator** | Sync secrets from GCP SM |
| **Ingress NGINX** | Ingress controller |
| **cert-manager** | Automatic TLS certificates |

### 13.4 Observability

| Tool | Usage |
|------------|-----|
| **Cloud Logging** | Centralized logs |
| **Cloud Monitoring** | Metrics and alerts |
| **Cloud Trace** | Distributed tracing |

---

## 14. Costs and Optimizations

### 14.1 Main Costs

| Resource | Monthly Estimate | Optimization |
|---------|-------------------|------------|
| **GKE Clusters** | ~$300-500 | Node autoscaling |
| **Cloud SQL** | ~$100-200 | Tier matched to usage |
| **NAT Gateway** | ~$50 | Shared VPC |
| **Cloud Storage** | ~$20 | Lifecycle policies |
| **Artifact Registry** | ~$10 | Old image cleanup |
| **Load Balancer** | ~$20 | Shared global LB |

### 14.2 Implemented Optimizations

1. **Shared VPC**: Dev + Stg in the same VPC = 1 NAT Gateway
2. **Scale to Zero**: ARC runners scale to 0 when idle
3. **Node Autoscaling**: Clusters scale based on demand
4. **Preemptible Nodes**: Possible for interrupt-tolerant workloads
5. **Committed Use Discounts**: Possible for predictable resources

---

## 15. GCP Glossary

| Term | Description |
|-------|-----------|
| **GKE** | Google Kubernetes Engine - Managed Kubernetes |
| **Cloud SQL** | Managed relational database |
| **GCS** | Google Cloud Storage - Object storage |
| **VPC** | Virtual Private Cloud - Isolated network |
| **IAM** | Identity and Access Management |
| **Service Account** | Identity for resources/applications |
| **Workload Identity** | Links K8s SA to GCP SA without keys |
| **Secret Manager** | Secure secrets storage |
| **Artifact Registry** | Container registry |
| **Cloud DNS** | Managed DNS |
| **NAT Gateway** | Internet egress for private resources |
| **IAP** | Identity-Aware Proxy - Secure access |
| **Private Service Access** | Private access to GCP services (Cloud SQL) |

---

## Useful Commands

### Check Clusters
```bash
gcloud container clusters list --project=project-nonprod-env
```

### Connect to Cluster
```bash
gcloud container clusters get-credentials project-dev-workloads \
    --region=us-east1 \
    --project=project-nonprod-env \
    --internal-ip  # Requires VPN
```

### View Pods
```bash
kubectl get pods -n gameplatform-dev
```

### View Logs
```bash
kubectl logs -n gameplatform-dev deploy/game-platform-dev-lobby --tail=100
```

### View Secrets
```bash
gcloud secrets list --project=project-nonprod-env
```

### View Databases
```bash
gcloud sql instances list --project=project-nonprod-env
```

---

## Contacts and Resources

- **Repositories**: github.com/example-gamedev-org/
- **GCP Console**: console.cloud.google.com
- **ArgoCD**: Via VPN + port-forward
- **Documentation**: This file + files in /Documents/GamePlatform/GCP/

---

*Last updated: 2025-12-17*
