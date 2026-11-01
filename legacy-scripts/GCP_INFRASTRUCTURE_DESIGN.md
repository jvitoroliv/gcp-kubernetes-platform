# GamePlatform Platform - GCP Infrastructure Design (As-Is Migration)

**Document Version**: 1.0
**Date**: 2025-11-24
**Purpose**: AWS to GCP infrastructure mapping with equivalent services
**Strategy**: Direct equivalents + ECS → GKE (Kubernetes) migration

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Current AWS Infrastructure Overview](#2-current-aws-infrastructure-overview)
3. [GCP Equivalent Services Mapping](#3-gcp-equivalent-services-mapping)
4. [GCP Architecture Diagrams](#4-gcp-architecture-diagrams)
5. [Component-Level Diagrams](#5-component-level-diagrams)
6. [Best Practices & Security Enhancements](#6-best-practices--security-enhancements)

---

## 1. Executive Summary

### 1.1 Migration Strategy

| Aspect | AWS (Current) | GCP (Target) |
|--------|---------------|--------------|
| **Container Orchestration** | ECS Fargate | **GKE Autopilot (Kubernetes)** |
| **Load Balancing** | ALB (3 regional) | Cloud Load Balancer (Global) |
| **Database** | RDS PostgreSQL | Cloud SQL PostgreSQL |
| **DNS** | Route53 | Cloud DNS |
| **Container Registry** | ECR | Artifact Registry |
| **Secrets** | SSM Parameter Store | Secret Manager |
| **Object Storage** | S3 | Cloud Storage |
| **Monitoring** | CloudWatch | Cloud Monitoring + Logging |
| **CI/CD** | Atlantis (ECS) + GitHub Actions | Atlantis (GKE) + Cloud Build |
| **VPN Access** | N/A | **Cloud VPN + IAP** (NEW) |

### 1.2 Key Changes

1. **ECS Fargate → GKE Autopilot**: Full Kubernetes migration for all 7 services
2. **Regional → Global Load Balancing**: Single global LB instead of 3 regional ALBs
3. **VPN Mandatory Access**: All internal resources accessible only via VPN
4. **IAP (Identity-Aware Proxy)**: Additional security layer for admin access

### 1.3 Services Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                        GAMEPLATFORM PLATFORM                               │
├─────────────────────────────────────────────────────────────────────┤
│  7 Microservices across 3 Environments (Dev, Staging, Production)   │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                  │
│  │   NAKAMA    │  │    LOBBY    │  │   LOBBY     │                  │
│  │ Game Server │  │  Frontend   │  │  BACKEND    │                  │
│  │  Go/Beego   │  │  Next.js    │  │   NestJS    │                  │
│  │ :7349-7351  │  │   :3000     │  │   :3001     │                  │
│  └─────────────┘  └─────────────┘  └─────────────┘                  │
│                                                                      │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐ │
│  │     AFS     │  │    AHSAT    │  │     AES     │  │     AIS     │ │
│  │Asset Files  │  │  Analytics  │  │   Email     │  │  AI Image   │ │
│  │  Go/Gin     │  │   Go/Gin    │  │   Python    │  │   Python    │ │
│  │   :9933     │  │   :6969     │  │   :1988     │  │   :5050     │ │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘ │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 2. Current AWS Infrastructure Overview

### 2.1 AWS Architecture Diagram (Current State)

```
                                    ┌─────────────────┐
                                    │    INTERNET     │
                                    │     Users       │
                                    └────────┬────────┘
                                             │
                              ┌──────────────┼──────────────┐
                              │              │              │
                    ┌─────────▼───────┐      │      ┌──────▼────────┐
                    │   Route53       │      │      │   Route53     │
                    │ dev.gameplatform-dev.example.com│      │      │ gameplatform.example.com  │
                    │ stg.gameplatform-dev.example.com│      │      │  (Production) │
                    └─────────┬───────┘      │      └──────┬────────┘
                              │              │             │
                    ┌─────────▼───────┐      │      ┌──────▼────────┐
                    │  ACM Wildcard   │      │      │ ACM Wildcard  │
                    │  Certificates   │      │      │ Certificate   │
                    └─────────┬───────┘      │      └──────┬────────┘
                              │              │             │
        ┌─────────────────────┼──────────────┼─────────────┼───────────────────┐
        │                     │              │             │                   │
        │  ┌──────────────────▼──────────────▼─────────────▼────────────────┐  │
        │  │              APPLICATION LOAD BALANCERS (3)                    │  │
        │  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │  │
        │  │  │  ALB (Dev)   │  │  ALB (Stg)   │  │  ALB (Live)  │         │  │
        │  │  │  us-east-1   │  │  us-east-1   │  │  sa-east-1   │         │  │
        │  │  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘         │  │
        │  └─────────┼─────────────────┼─────────────────┼─────────────────┘  │
        │            │                 │                 │                    │
        │  ┌─────────▼─────────────────▼─────────────────▼─────────────────┐  │
        │  │                    VPC (10.0.0.0/16)                          │  │
        │  │                                                               │  │
        │  │  ┌─────────────────────────────────────────────────────────┐  │  │
        │  │  │              PUBLIC SUBNETS (3 AZs)                      │  │  │
        │  │  │  ┌───────────┐  ┌───────────┐  ┌───────────┐            │  │  │
        │  │  │  │10.0.1.0/24│  │10.0.2.0/24│  │10.0.3.0/24│            │  │  │
        │  │  │  │   AZ-1a   │  │   AZ-1b   │  │   AZ-1c   │            │  │  │
        │  │  │  └─────┬─────┘  └─────┬─────┘  └─────┬─────┘            │  │  │
        │  │  │        │              │              │                   │  │  │
        │  │  │  ┌─────▼──────────────▼──────────────▼─────┐            │  │  │
        │  │  │  │         NAT GATEWAY(s)                  │            │  │  │
        │  │  │  │    Dev/Stg: 1x  |  Live: 3x (HA)        │            │  │  │
        │  │  │  └─────────────────┬───────────────────────┘            │  │  │
        │  │  └────────────────────┼────────────────────────────────────┘  │  │
        │  │                       │                                       │  │
        │  │  ┌────────────────────▼────────────────────────────────────┐  │  │
        │  │  │              PRIVATE SUBNETS (3 AZs)                     │  │  │
        │  │  │  ┌────────────┐  ┌────────────┐  ┌────────────┐         │  │  │
        │  │  │  │10.0.11.0/24│  │10.0.12.0/24│  │10.0.13.0/24│         │  │  │
        │  │  │  │    AZ-1a   │  │    AZ-1b   │  │    AZ-1c   │         │  │  │
        │  │  │  └──────┬─────┘  └──────┬─────┘  └──────┬─────┘         │  │  │
        │  │  │         │               │               │                │  │  │
        │  │  │  ┌──────▼───────────────▼───────────────▼──────┐        │  │  │
        │  │  │  │           ECS FARGATE CLUSTER               │        │  │  │
        │  │  │  │  ┌─────────┐ ┌─────────┐ ┌─────────────────┐│        │  │  │
        │  │  │  │  │ nakama  │ │  lobby  │ │ lobby-backend   ││        │  │  │
        │  │  │  │  │ :7349-51│ │  :3000  │ │     :3001       ││        │  │  │
        │  │  │  │  └─────────┘ └─────────┘ └─────────────────┘│        │  │  │
        │  │  │  │  ┌─────────┐ ┌─────────┐ ┌───────┐ ┌───────┐│        │  │  │
        │  │  │  │  │   afs   │ │  ahsat  │ │  aes  │ │  ais  ││        │  │  │
        │  │  │  │  │  :9933  │ │  :6969  │ │ :1988 │ │ :5050 ││        │  │  │
        │  │  │  │  └─────────┘ └─────────┘ └───────┘ └───────┘│        │  │  │
        │  │  │  └─────────────────────┬───────────────────────┘        │  │  │
        │  │  │                        │                                 │  │  │
        │  │  │  ┌─────────────────────▼───────────────────────┐        │  │  │
        │  │  │  │         RDS POSTGRESQL 14                   │        │  │  │
        │  │  │  │    Dev: db.t3.micro  | Stg: db.t3.small     │        │  │  │
        │  │  │  │    Live: db.t3.medium (Multi-AZ)            │        │  │  │
        │  │  │  └─────────────────────────────────────────────┘        │  │  │
        │  │  └─────────────────────────────────────────────────────────┘  │  │
        │  └───────────────────────────────────────────────────────────────┘  │
        │                                                                      │
        │  ┌───────────────────────────────────────────────────────────────┐  │
        │  │                    SHARED SERVICES                             │  │
        │  │  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────────────┐   │  │
        │  │  │   S3    │  │   ECR   │  │CloudWatch│  │ SSM Parameter  │   │  │
        │  │  │ Buckets │  │  Repos  │  │  Logs   │  │    Store       │   │  │
        │  │  └─────────┘  └─────────┘  └─────────┘  └─────────────────┘   │  │
        │  │  ┌─────────┐  ┌─────────┐  ┌───────────────────────────────┐  │  │
        │  │  │ Lambda  │  │DynamoDB │  │     Atlantis (ECS Task)       │  │  │
        │  │  │Scheduler│  │  State  │  │   Terraform Automation        │  │  │
        │  │  └─────────┘  └─────────┘  └───────────────────────────────┘  │  │
        │  └───────────────────────────────────────────────────────────────┘  │
        │                                                                      │
        │                              AWS CLOUD                               │
        └──────────────────────────────────────────────────────────────────────┘
```

### 2.2 AWS Resources Inventory

| Resource Type | Dev | Staging | Live | Total |
|--------------|-----|---------|------|-------|
| ECS Services | 7 | 7 | 7 | **21** |
| ECS Task Definitions | 7 | 7 | 7 | **21** |
| ALB Target Groups | 7 | 7 | 7 | **21** |
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

### 2.3 AWS Account Structure

| Environment | AWS Account ID | Region | Purpose |
|-------------|---------------|--------|---------|
| Development | 777777777771 | us-east-1 | Development/Sandbox |
| Staging | 777777777775 | us-east-1 | QA/Testing |
| Production | 777777777772 | sa-east-1 | Production (Brazil) |

---

## 3. GCP Equivalent Services Mapping

### 3.1 Complete Service Mapping Table

| Category | AWS Service | GCP Equivalent | Notes |
|----------|-------------|----------------|-------|
| **Container Orchestration** |
| ECS Fargate | **GKE Autopilot** | Fully managed Kubernetes, no node management |
| ECS Service | Kubernetes Deployment | Declarative scaling, rolling updates |
| ECS Task Definition | Kubernetes Pod | Multi-container support, sidecars |
| ECS Cluster | GKE Cluster | Managed control plane |
| Service Discovery (Cloud Map) | Kubernetes Service DNS | Built-in: `service.namespace.svc.cluster.local` |
| **Networking** |
| VPC | VPC | Same CIDR support (10.0.0.0/16) |
| Subnets | Subnets | Regional subnets (not zonal) |
| NAT Gateway | Cloud NAT | Serverless, no capacity planning |
| Internet Gateway | Default Route | Automatic for VPC |
| Security Groups | Firewall Rules | VPC-level firewall |
| **Load Balancing** |
| ALB (Application LB) | Cloud Load Balancer (HTTP/S) | Global load balancing |
| Target Groups | Backend Services | Health checks included |
| Listener Rules | URL Maps | Path/host-based routing |
| **Database** |
| RDS PostgreSQL | Cloud SQL PostgreSQL | Managed PostgreSQL |
| RDS Multi-AZ | Cloud SQL HA | Regional HA with auto-failover |
| RDS Read Replicas | Cloud SQL Read Replicas | Cross-region supported |
| **Storage** |
| S3 | Cloud Storage | Object storage, lifecycle policies |
| ECR | Artifact Registry | Container images + vulnerability scanning |
| DynamoDB | Firestore | NoSQL document database |
| **DNS & SSL** |
| Route53 | Cloud DNS | Managed DNS, global anycast |
| ACM Certificates | Google-managed SSL | Automatic provisioning and renewal |
| **Security** |
| IAM Roles | IAM Service Accounts | Workload Identity for GKE |
| SSM Parameter Store | Secret Manager | Versioning, auto-rotation |
| KMS | Cloud KMS | Encryption key management |
| N/A | **Cloud VPN** | NEW: VPN access to internal resources |
| N/A | **IAP (Identity-Aware Proxy)** | NEW: Zero-trust access |
| **Monitoring** |
| CloudWatch Logs | Cloud Logging | Centralized log management |
| CloudWatch Metrics | Cloud Monitoring | Metrics, dashboards, alerts |
| CloudWatch Alarms | Cloud Monitoring Alerts | Multi-channel notifications |
| X-Ray | Cloud Trace | Distributed tracing |
| Container Insights | GKE Monitoring | Prometheus-based metrics |
| **CI/CD** |
| Atlantis (ECS) | Atlantis (GKE) | Same Terraform automation |
| GitHub Actions | Cloud Build | Native GCP integration |
| Lambda (Scheduler) | Cloud Scheduler + Cloud Functions | Serverless scheduling |

### 3.2 GCP Project Structure

| Environment | GCP Project ID | Region | Purpose |
|-------------|---------------|--------|---------|
| Development | gameplatform-dev | us-east1 | Development/Sandbox |
| Staging | gameplatform-staging | us-east1 | QA/Testing |
| Production | gameplatform-prod | southamerica-east1 | Production (São Paulo) |

---

## 4. GCP Architecture Diagrams

### 4.1 High-Level GCP Architecture (Target State)

```
                                    ┌─────────────────┐
                                    │    INTERNET     │
                                    │     Users       │
                                    └────────┬────────┘
                                             │
                                             │
                    ┌────────────────────────┼────────────────────────┐
                    │                        │                        │
                    │           ┌────────────▼────────────┐           │
                    │           │       Cloud DNS         │           │
                    │           │  *.dev.gameplatform-dev.example.com     │           │
                    │           │  *.stg.gameplatform-dev.example.com     │           │
                    │           │  *.gameplatform.example.com         │           │
                    │           └────────────┬────────────┘           │
                    │                        │                        │
                    │           ┌────────────▼────────────┐           │
                    │           │  Google-Managed SSL     │           │
                    │           │  (Auto-provisioned)     │           │
                    │           └────────────┬────────────┘           │
                    │                        │                        │
                    │  ┌─────────────────────▼─────────────────────┐  │
                    │  │     GLOBAL CLOUD LOAD BALANCER (HTTP/S)   │  │
                    │  │  ┌─────────────────────────────────────┐  │  │
                    │  │  │  - Single Global Entry Point        │  │  │
                    │  │  │  - DDoS Protection (Cloud Armor)    │  │  │
                    │  │  │  - URL Maps (Host-based routing)    │  │  │
                    │  │  │  - Backend Services (per service)   │  │  │
                    │  │  └─────────────────────────────────────┘  │  │
                    │  └──────────────────────┬────────────────────┘  │
                    │                         │                       │
                    │      ┌──────────────────┼──────────────────┐    │
                    │      │                  │                  │    │
                    │      ▼                  ▼                  ▼    │
                    │  ┌───────┐          ┌───────┐          ┌───────┐│
                    │  │  Dev  │          │  Stg  │          │ Live  ││
                    │  │Cluster│          │Cluster│          │Cluster││
                    │  └───┬───┘          └───┬───┘          └───┬───┘│
                    │      │                  │                  │    │
                    │      └──────────────────┼──────────────────┘    │
                    │                         │                       │
                    │  ┌──────────────────────▼────────────────────┐  │
                    │  │                                           │  │
                    │  │              VPN GATEWAY                   │  │
                    │  │     (Required for Admin/Dev Access)       │  │
                    │  │                                           │  │
                    │  └──────────────────────┬────────────────────┘  │
                    │                         │                       │
                    │                    GOOGLE CLOUD                 │
                    └─────────────────────────┴───────────────────────┘
                                              │
                                              │
                               ┌──────────────▼──────────────┐
                               │      VPN CLIENT             │
                               │   (Admin/Developer)         │
                               │  - Access to GKE Clusters   │
                               │  - Access to Cloud SQL      │
                               │  - Access to Internal APIs  │
                               └─────────────────────────────┘
```

### 4.2 Detailed GCP Architecture (Per Environment)

```
┌──────────────────────────────────────────────────────────────────────────────────────────┐
│                                   GOOGLE CLOUD PLATFORM                                   │
│                                                                                          │
│  ┌────────────────────────────────────────────────────────────────────────────────────┐  │
│  │                              GLOBAL SERVICES                                        │  │
│  │                                                                                     │  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐   │  │
│  │  │  Cloud DNS   │  │ Cloud Load   │  │ Cloud Armor  │  │   Artifact Registry  │   │  │
│  │  │              │  │  Balancer    │  │ (DDoS/WAF)   │  │   (Container Images) │   │  │
│  │  │ *.gameplatform.    │  │  (Global)    │  │              │  │                      │   │  │
│  │  │   space      │  │              │  │              │  │  - gameplatform-nakama     │   │  │
│  │  │              │  │              │  │              │  │  - gameplatform-lobby      │   │  │
│  │  └──────────────┘  └──────────────┘  └──────────────┘  │  - gameplatform-lobby-be   │   │  │
│  │                                                         │  - gameplatform-afs        │   │  │
│  │                                                         │  - gameplatform-ahsat      │   │  │
│  │                                                         │  - gameplatform-aes        │   │  │
│  │                                                         │  - gameplatform-ais        │   │  │
│  │                                                         └──────────────────────┘   │  │
│  └────────────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                          │
│  ┌────────────────────────────────────────────────────────────────────────────────────┐  │
│  │                         VPC: gameplatform-prod (10.0.0.0/16)                              │  │
│  │                              Region: southamerica-east1                             │  │
│  │                                                                                     │  │
│  │  ┌───────────────────────────────────────────────────────────────────────────────┐ │  │
│  │  │                    PUBLIC SUBNET (10.0.1.0/24)                                 │ │  │
│  │  │                                                                                │ │  │
│  │  │  ┌────────────────┐  ┌────────────────┐  ┌────────────────────────────────┐   │ │  │
│  │  │  │   Cloud NAT    │  │  VPN Gateway   │  │      Bastion Host (Optional)   │   │ │  │
│  │  │  │  (Serverless)  │  │  (HA VPN)      │  │      via IAP Tunnel            │   │ │  │
│  │  │  │                │  │                │  │                                │   │ │  │
│  │  │  │  - No capacity │  │  - 2 tunnels   │  │  - Zero-trust access           │   │ │  │
│  │  │  │    planning    │  │  - IPsec/IKEv2 │  │  - No public IP needed         │   │ │  │
│  │  │  │  - Auto-scale  │  │  - BGP routing │  │  - Audit logging               │   │ │  │
│  │  │  └────────────────┘  └────────────────┘  └────────────────────────────────┘   │ │  │
│  │  └───────────────────────────────────────────────────────────────────────────────┘ │  │
│  │                                                                                     │  │
│  │  ┌───────────────────────────────────────────────────────────────────────────────┐ │  │
│  │  │                    PRIVATE SUBNET (10.0.10.0/24)                               │ │  │
│  │  │                                                                                │ │  │
│  │  │  ┌─────────────────────────────────────────────────────────────────────────┐  │ │  │
│  │  │  │                     GKE AUTOPILOT CLUSTER                                │  │ │  │
│  │  │  │                     (gameplatform-prod-cluster)                                │  │ │  │
│  │  │  │                                                                          │  │ │  │
│  │  │  │  ┌─────────────────────────────────────────────────────────────────┐    │  │ │  │
│  │  │  │  │                 NAMESPACE: gameplatform-prod                           │    │  │ │  │
│  │  │  │  │                                                                  │    │  │ │  │
│  │  │  │  │  ┌─────────────────────────────────────────────────────────┐    │    │  │ │  │
│  │  │  │  │  │                    DEPLOYMENTS                          │    │    │  │ │  │
│  │  │  │  │  │                                                         │    │    │  │ │  │
│  │  │  │  │  │   ┌─────────┐  ┌─────────┐  ┌─────────────────────┐    │    │    │  │ │  │
│  │  │  │  │  │   │ NAKAMA  │  │  LOBBY  │  │   LOBBY-BACKEND     │    │    │    │  │ │  │
│  │  │  │  │  │   │ 3 pods  │  │ 2 pods  │  │      2 pods         │    │    │    │  │ │  │
│  │  │  │  │  │   │:7349-51 │  │ :3000   │  │      :3001          │    │    │    │  │ │  │
│  │  │  │  │  │   │         │  │         │  │                     │    │    │    │  │ │  │
│  │  │  │  │  │   │ HPA:1-10│  │ HPA:1-20│  │     HPA: 1-10       │    │    │    │  │ │  │
│  │  │  │  │  │   └─────────┘  └─────────┘  └─────────────────────┘    │    │    │  │ │  │
│  │  │  │  │  │                                                         │    │    │  │ │  │
│  │  │  │  │  │   ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐   │    │    │  │ │  │
│  │  │  │  │  │   │   AFS   │  │  AHSAT  │  │   AES   │  │   AIS   │   │    │    │  │ │  │
│  │  │  │  │  │   │ 2 pods  │  │ 1 pod   │  │  1 pod  │  │  1 pod  │   │    │    │  │ │  │
│  │  │  │  │  │   │  :9933  │  │  :6969  │  │  :1988  │  │  :5050  │   │    │    │  │ │  │
│  │  │  │  │  │   │         │  │         │  │         │  │         │   │    │    │  │ │  │
│  │  │  │  │  │   │ HPA:1-5 │  │ HPA:1-3 │  │ HPA:1-3 │  │ HPA:1-5 │   │    │    │  │ │  │
│  │  │  │  │  │   └─────────┘  └─────────┘  └─────────┘  └─────────┘   │    │    │  │ │  │
│  │  │  │  │  │                                                         │    │    │  │ │  │
│  │  │  │  │  └─────────────────────────────────────────────────────────┘    │    │  │ │  │
│  │  │  │  │                                                                  │    │  │ │  │
│  │  │  │  │  ┌─────────────────────────────────────────────────────────┐    │    │  │ │  │
│  │  │  │  │  │                    SERVICES (ClusterIP)                 │    │    │  │ │  │
│  │  │  │  │  │                                                         │    │    │  │ │  │
│  │  │  │  │  │  nakama.gameplatform-prod.svc.cluster.local:7350              │    │    │  │ │  │
│  │  │  │  │  │  lobby.gameplatform-prod.svc.cluster.local:3000               │    │    │  │ │  │
│  │  │  │  │  │  lobby-backend.gameplatform-prod.svc.cluster.local:3001       │    │    │  │ │  │
│  │  │  │  │  │  afs.gameplatform-prod.svc.cluster.local:9933                 │    │    │  │ │  │
│  │  │  │  │  │  ahsat.gameplatform-prod.svc.cluster.local:6969               │    │    │  │ │  │
│  │  │  │  │  │  aes.gameplatform-prod.svc.cluster.local:1988                 │    │    │  │ │  │
│  │  │  │  │  │  ais.gameplatform-prod.svc.cluster.local:5050                 │    │    │  │ │  │
│  │  │  │  │  │                                                         │    │    │  │ │  │
│  │  │  │  │  └─────────────────────────────────────────────────────────┘    │    │  │ │  │
│  │  │  │  │                                                                  │    │  │ │  │
│  │  │  │  └──────────────────────────────────────────────────────────────────┘    │  │ │  │
│  │  │  │                                                                          │  │ │  │
│  │  │  │  ┌────────────────────────────────────────────────────────────────────┐  │  │ │  │
│  │  │  │  │  GKE FEATURES:                                                     │  │  │ │  │
│  │  │  │  │  - Autopilot: No node management                                   │  │  │ │  │
│  │  │  │  │  - Workload Identity: IAM for pods                                 │  │  │ │  │
│  │  │  │  │  - Container-native Load Balancing                                 │  │  │ │  │
│  │  │  │  │  - VPC-native cluster (IP aliasing)                                │  │  │ │  │
│  │  │  │  │  - Private cluster (no public IPs on nodes)                        │  │  │ │  │
│  │  │  │  └────────────────────────────────────────────────────────────────────┘  │  │ │  │
│  │  │  │                                                                          │  │ │  │
│  │  │  └──────────────────────────────────────────────────────────────────────────┘  │ │  │
│  │  │                                                                                │ │  │
│  │  └───────────────────────────────────────────────────────────────────────────────┘ │  │
│  │                                                                                     │  │
│  │  ┌───────────────────────────────────────────────────────────────────────────────┐ │  │
│  │  │                    DATABASE SUBNET (10.0.20.0/24)                              │ │  │
│  │  │                                                                                │ │  │
│  │  │  ┌────────────────────────────────────────────────────────────────────────┐   │ │  │
│  │  │  │                    CLOUD SQL POSTGRESQL 14                              │   │ │  │
│  │  │  │                                                                         │   │ │  │
│  │  │  │   Instance: db-custom-4-16384 (4 vCPU, 16GB RAM)                        │   │ │  │
│  │  │  │   Storage: 100GB SSD (auto-scaling to 500GB)                            │   │ │  │
│  │  │  │   HA: Regional (automatic failover)                                     │   │ │  │
│  │  │  │   Backups: Daily, 30-day retention                                      │   │ │  │
│  │  │  │   Private IP: 10.0.20.10 (VPC peering)                                  │   │ │  │
│  │  │  │                                                                         │   │ │  │
│  │  │  │   Connection: Cloud SQL Auth Proxy (sidecar in pods)                    │   │ │  │
│  │  │  │                                                                         │   │ │  │
│  │  │  └────────────────────────────────────────────────────────────────────────┘   │ │  │
│  │  │                                                                                │ │  │
│  │  └───────────────────────────────────────────────────────────────────────────────┘ │  │
│  │                                                                                     │  │
│  └────────────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                          │
│  ┌────────────────────────────────────────────────────────────────────────────────────┐  │
│  │                              SHARED SERVICES                                        │  │
│  │                                                                                     │  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐   │  │
│  │  │Cloud Storage │  │   Secret     │  │    Cloud     │  │   Cloud Monitoring   │   │  │
│  │  │              │  │   Manager    │  │   Logging    │  │                      │   │  │
│  │  │ - Assets     │  │              │  │              │  │  - Dashboards        │   │  │
│  │  │ - Backups    │  │ - DB creds   │  │ - GKE logs   │  │  - Alerts            │   │  │
│  │  │ - TF State   │  │ - API keys   │  │ - App logs   │  │  - Uptime checks     │   │  │
│  │  │ - Exports    │  │ - Rotation   │  │ - Audit logs │  │  - SLOs              │   │  │
│  │  └──────────────┘  └──────────────┘  └──────────────┘  └──────────────────────┘   │  │
│  │                                                                                     │  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────────────────────────┐ │  │
│  │  │   Cloud      │  │  Firestore   │  │           Cloud Build                    │ │  │
│  │  │  Scheduler   │  │   (NoSQL)    │  │                                          │ │  │
│  │  │              │  │              │  │  - GitHub integration                    │ │  │
│  │  │ - Cron jobs  │  │ - Scheduler  │  │  - Docker builds                         │ │  │
│  │  │ - Env on/off │  │   state      │  │  - Push to Artifact Registry             │ │  │
│  │  │              │  │ - Real-time  │  │  - Terraform automation (Atlantis)       │ │  │
│  │  └──────────────┘  └──────────────┘  └──────────────────────────────────────────┘ │  │
│  │                                                                                     │  │
│  └────────────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                          │
└──────────────────────────────────────────────────────────────────────────────────────────┘
```

---

*Continue in: [GCP_INFRASTRUCTURE_DIAGRAMS.md](./GCP_INFRASTRUCTURE_DIAGRAMS.md)*
