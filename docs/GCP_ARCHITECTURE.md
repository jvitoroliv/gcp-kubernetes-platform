# GamePlatform Platform - GCP Architecture (Current)

> **Status:** Active - Production Ready
> **Last Updated:** January 2026
> **Purpose:** Current production infrastructure on Google Cloud Platform

---

## 1. Overview - High Level Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                              GAMEPLATFORM GCP ARCHITECTURE                                     │
│                                    (Current)                                             │
└─────────────────────────────────────────────────────────────────────────────────────────┘

                                    INTERNET
                                       │
                    ┌──────────────────┴──────────────────┐
                    │                                      │
           ┌────────▼────────┐                   ┌────────▼────────┐
           │   Cloud DNS     │                   │   Google        │
           │   gameplatform.example.com  │                   │   Managed Certs │
           │                 │                   │   *.gameplatform.example.com│
           └────────┬────────┘                   └────────┬────────┘
                    │                                      │
                    └──────────────────┬───────────────────┘
                                       │
                         ┌─────────────▼─────────────┐
                         │   GCP Application Load    │
                         │   Balancer (Global)       │
                         │   Single IP for all       │
                         │   services + TCP Proxy    │
                         └─────────────┬─────────────┘
                                       │
              ┌────────────────────────┼────────────────────────┐
              │                        │                        │
    ┌─────────▼─────────┐             │             ┌──────────▼──────────┐
    │   WireGuard VPN   │             │             │   Cloud NAT         │
    │   (Admin Access)  │             │             │   (Outbound Only)   │
    │   Port 51820/UDP  │             │             │                     │
    └─────────┬─────────┘             │             └──────────┬──────────┘
              │                        │                        │
              │         ┌──────────────┴──────────────┐        │
              │         │                              │        │
              │    ┌────▼─────────────────────────────▼────┐   │
              │    │           PRIVATE VPC                  │   │
              │    │                                        │   │
              │    │  ┌────────────────────────────────┐   │   │
              │    │  │     GKE WORKLOADS CLUSTER      │   │   │
              │    │  │     (Private Endpoint)         │   │   │
              │    │  │                                │   │   │
              │    │  │  ┌─────────┐ ┌─────────┐      │   │   │
              │    │  │  │ Nakama  │ │ Lobby   │      │   │   │
              │    │  │  │ :7350   │ │ :3000   │      │   │   │
              │    │  │  └─────────┘ └─────────┘      │   │   │
              │    │  │  ┌─────────┐ ┌─────────┐      │   │   │
              │    │  │  │ Backend │ │  AFS    │      │   │   │
              │    │  │  │ :3001   │ │ :9933   │      │   │   │
              │    │  │  └─────────┘ └─────────┘      │   │   │
              │    │  │  ┌─────────┐ ┌─────────┐      │   │   │
              │    │  │  │ AHSAT   │ │  AIS    │      │   │   │
              │    │  │  │ :6969   │ │ :5050   │      │   │   │
              │    │  │  └─────────┘ └─────────┘      │   │   │
              │    │  │  ┌─────────┐ ┌─────────┐      │   │   │
              │    │  │  │  AES    │ │  APS    │      │   │   │
              │    │  │  │ :1988   │ │ :4444   │      │   │   │
              │    │  │  └─────────┘ └─────────┘      │   │   │
              │    │  │                                │   │   │
              │    │  └────────────────────────────────┘   │   │
              │    │                                        │   │
              │    │  ┌────────────────────────────────┐   │   │
              │    │  │     GKE RUNNERS CLUSTER        │   │   │
              │    │  │     (Private Endpoint)         │   │   │
              │    │  │                                │   │   │
              │    │  │  ┌─────────┐ ┌─────────┐      │   │   │
              │    │  │  │ ArgoCD  │ │  ARC    │      │   │   │
              │    │  │  │         │ │Controller│     │   │   │
              │    │  │  └─────────┘ └─────────┘      │   │   │
              │    │  │  ┌─────────┐ ┌─────────┐      │   │   │
              │    │  │  │  ESO    │ │ Runners │      │   │   │
              │    │  │  │Operator │ │ (0-10)  │      │   │   │
              │    │  │  └─────────┘ └─────────┘      │   │   │
              │    │  │                                │   │   │
              │    │  └────────────────────────────────┘   │   │
              │    │                                        │   │
              │    └───────────────────┬───────────────────┘   │
              │                        │                        │
              │                        │                        │
    ┌─────────▼─────────┐   ┌─────────▼─────────┐   ┌─────────▼─────────┐
    │  Bastion VM       │   │  Cloud SQL        │   │  GCS Buckets      │
    │  (WireGuard)      │   │  PostgreSQL 15    │   │  (Assets)         │
    │                   │   │  Private IP       │   │                   │
    └───────────────────┘   └───────────────────┘   └───────────────────┘
```

---

## 2. Environments Overview

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                            THREE ENVIRONMENTS                                            │
├─────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                          │
│  ┌──────────────────────┐  ┌──────────────────────┐  ┌──────────────────────┐          │
│  │      DEV             │  │      STG             │  │      PRD             │          │
│  ├──────────────────────┤  ├──────────────────────┤  ├──────────────────────┤          │
│  │ Project: gameplatform-     │  │ Project: gameplatform-     │  │ Project: gameplatform-     │          │
│  │   nonprod-env        │  │   nonprod-env        │  │   prd-env            │          │
│  │ Region: us-east1     │  │ Region: us-east1     │  │ Region: southamerica │          │
│  │                      │  │                      │  │          -east1      │          │
│  │ Domain: Internal     │  │ Domain: Internal     │  │ Domain: gameplatform.example.com │          │
│  │   (VPN only)         │  │   (VPN only)         │  │   (Public)           │          │
│  │                      │  │                      │  │                      │          │
│  │ VPC: SHARED          │  │ VPC: SHARED          │  │ VPC: DEDICATED       │          │
│  │   gameplatform-nonprod-vpc │  │   gameplatform-nonprod-vpc │  │   project-prd-vpc     │          │
│  │                      │  │                      │  │                      │          │
│  │ GKE Nodes:           │  │ GKE Nodes:           │  │ GKE Nodes:           │          │
│  │ - e2-standard-2      │  │ - e2-standard-2      │  │ - e2-standard-4      │          │
│  │ - 1-3 nodes          │  │ - 1-3 nodes          │  │ - 3-5 nodes (HA)     │          │
│  │                      │  │                      │  │                      │          │
│  │ Cloud SQL:           │  │ Cloud SQL:           │  │ Cloud SQL:           │          │
│  │ - 1 vCPU / 3.75GB    │  │ - 1 vCPU / 3.75GB    │  │ - 4 vCPU / 16GB      │          │
│  │ - Zonal (no HA)      │  │ - Zonal (no HA)      │  │ - Regional (HA)      │          │
│  │                      │  │                      │  │ - max_connections:   │          │
│  │                      │  │                      │  │   5000               │          │
│  └──────────────────────┘  └──────────────────────┘  └──────────────────────┘          │
│                                                                                          │
│  SHARED RESOURCES (Non-Prod):                                                           │
│  ┌──────────────────────────────────────────────────────────────────────────────┐      │
│  │ gameplatform-nonprod-runners cluster (ArgoCD, ARC Controller, ESO)                 │      │
│  │ gameplatform-nonprod-bastion (WireGuard VPN server)                                │      │
│  │ gameplatform-nonprod-vpc (shared networking)                                        │      │
│  └──────────────────────────────────────────────────────────────────────────────┘      │
│                                                                                          │
└─────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. VPC & Networking - Detailed

### 3.1 Non-Prod VPC Structure (Shared: dev + stg)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     VPC: gameplatform-nonprod-vpc                                  │
│                     Region: us-east1                                         │
│                     Routing Mode: REGIONAL                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    CLOUD NAT GATEWAY                                 │   │
│  │                    gameplatform-nonprod-nat                                │   │
│  │                    (Outbound internet for private clusters)          │   │
│  │                    Auto-allocated IPs                                │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                    │                                         │
│                                    ▼                                         │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    SUBNETS                                           │   │
│  ├───────────────────┬───────────────────┬─────────────────────────────┤   │
│  │                   │                   │                              │   │
│  │ DEV SUBNET        │ STG SUBNET        │ RUNNERS SUBNET               │   │
│  │ project-dev-subnet │ project-stg-subnet │ gameplatform-nonprod-runners-      │   │
│  │                   │                   │ subnet                       │   │
│  │                   │                   │                              │   │
│  │ Nodes:            │ Nodes:            │ Nodes:                       │   │
│  │ 10.100.0.0/20     │ 10.48.0.0/20      │ 10.120.0.0/20               │   │
│  │ (4,096 IPs)       │ (4,096 IPs)       │ (4,096 IPs)                 │   │
│  │                   │                   │                              │   │
│  │ Pods:             │ Pods:             │ Pods:                        │   │
│  │ 10.104.0.0/14     │ 10.52.0.0/14      │ 10.124.0.0/14               │   │
│  │ (262,144 IPs)     │ (262,144 IPs)     │ (262,144 IPs)               │   │
│  │                   │                   │                              │   │
│  │ Services:         │ Services:         │ Services:                    │   │
│  │ 10.108.0.0/20     │ 10.56.0.0/20      │ 10.128.0.0/20               │   │
│  │ (4,096 IPs)       │ (4,096 IPs)       │ (4,096 IPs)                 │   │
│  │                   │                   │                              │   │
│  │ Master CIDR:      │ Master CIDR:      │ Master CIDR:                 │   │
│  │ 172.16.0.0/28     │ 172.16.0.16/28    │ 172.16.1.0/28               │   │
│  │                   │                   │                              │   │
│  │ ┌───────────────┐ │ ┌───────────────┐ │ ┌───────────────┐            │   │
│  │ │ GKE Workloads │ │ │ GKE Workloads │ │ │ GKE Runners   │            │   │
│  │ │ project-dev-   │ │ │ project-stg-   │ │ │ gameplatform-       │            │   │
│  │ │ workloads     │ │ │ workloads     │ │ │ nonprod-      │            │   │
│  │ │               │ │ │               │ │ │ runners       │            │   │
│  │ │ 8 Services    │ │ │ 8 Services    │ │ │ ArgoCD + ARC  │            │   │
│  │ └───────────────┘ │ └───────────────┘ │ └───────────────┘            │   │
│  │                   │                   │                              │   │
│  │                   │                   │ ┌───────────────┐            │   │
│  │                   │                   │ │ Bastion VM    │            │   │
│  │                   │                   │ │ 10.120.0.3    │            │   │
│  │                   │                   │ │ WireGuard     │            │   │
│  │                   │                   │ └───────────────┘            │   │
│  └───────────────────┴───────────────────┴─────────────────────────────┘   │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    PRIVATE SERVICE CONNECTION                        │   │
│  │                    (Cloud SQL Access)                                │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │  Service: servicenetworking.googleapis.com                          │   │
│  │  Address Range: /16 (private Google-managed)                        │   │
│  │  Purpose: Cloud SQL private IP connectivity                         │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 3.2 Production VPC Structure (Dedicated)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     VPC: project-prd-vpc                                      │
│                     Region: southamerica-east1 (Sao Paulo)                   │
│                     Routing Mode: REGIONAL                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    CLOUD NAT GATEWAY                                 │   │
│  │                    project-prd-nat                                    │   │
│  │                    (Outbound internet for private clusters)          │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                    │                                         │
│                                    ▼                                         │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    SUBNETS                                           │   │
│  ├─────────────────────────────────┬───────────────────────────────────┤   │
│  │                                 │                                    │   │
│  │ WORKLOADS SUBNET                │ RUNNERS SUBNET                     │   │
│  │ project-prd-workloads-subnet     │ project-prd-runners-subnet          │   │
│  │                                 │                                    │   │
│  │ Nodes: 10.100.0.0/20            │ Nodes: 10.112.0.0/20              │   │
│  │ Pods:  10.104.0.0/14            │ Pods:  10.116.0.0/14              │   │
│  │ Services: 10.108.0.0/20         │ Services: 10.120.0.0/20           │   │
│  │ Master: 172.16.0.0/28           │ Master: 172.16.1.0/28             │   │
│  │                                 │                                    │   │
│  │ ┌───────────────────────────┐   │ ┌───────────────────────────┐     │   │
│  │ │ GKE Workloads             │   │ │ GKE Runners               │     │   │
│  │ │ project-prd-workloads      │   │ │ project-prd-runners        │     │   │
│  │ │                           │   │ │                           │     │   │
│  │ │ 3 Nodes (HA across zones) │   │ │ ArgoCD + ARC + ESO        │     │   │
│  │ │ e2-standard-4             │   │ │                           │     │   │
│  │ │ 8 Services                │   │ │                           │     │   │
│  │ └───────────────────────────┘   │ └───────────────────────────┘     │   │
│  │                                 │                                    │   │
│  │                                 │ ┌───────────────────────────┐     │   │
│  │                                 │ │ Bastion VM                │     │   │
│  │                                 │ │ Internal: 10.112.0.3      │     │   │
│  │                                 │ │ External: 198.51.100.29   │     │   │
│  │                                 │ │ WireGuard: 51820/UDP      │     │   │
│  │                                 │ └───────────────────────────┘     │   │
│  └─────────────────────────────────┴───────────────────────────────────┘   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 3.3 Firewall Rules

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        FIREWALL RULES                                        │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  RULE: allow-internal                                               │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │  INBOUND:                                                           │   │
│  │    TCP 0-65535  ← VPC CIDR (internal communication)                │   │
│  │    UDP 0-65535  ← VPC CIDR (internal communication)                │   │
│  │    ICMP         ← VPC CIDR (ping/diagnostics)                      │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  RULE: allow-health-checks                                          │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │  INBOUND:                                                           │   │
│  │    All ports   ← 198.51.100.0/16 (GCP health check probes)           │   │
│  │    All ports   ← 198.51.100.0/22 (GCP health check probes)          │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  RULE: allow-iap-ssh                                                │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │  INBOUND:                                                           │   │
│  │    TCP 22      ← 198.51.100.0/20 (IAP for SSH access)              │   │
│  │    TCP 443     ← 198.51.100.0/20 (IAP for HTTPS)                   │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  RULE: allow-gke-master-to-nodes                                    │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │  INBOUND:                                                           │   │
│  │    TCP 443     ← Master CIDR (Kubernetes API)                      │   │
│  │    TCP 10250   ← Master CIDR (kubelet)                             │   │
│  │    TCP 8443    ← Master CIDR (metrics)                             │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  RULE: allow-github-webhooks                                        │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │  INBOUND:                                                           │   │
│  │    TCP 443     ← 198.51.100.0/22 (GitHub)                          │   │
│  │    TCP 443     ← 198.51.100.0/22 (GitHub)                         │   │
│  │    TCP 443     ← 198.51.100.0/20 (GitHub)                          │   │
│  │    TCP 443     ← 198.51.100.0/20 (GitHub)                           │   │
│  │    TCP 80      ← Same ranges (HTTP redirect)                       │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  RULE: allow-wireguard-vpn                                          │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │  INBOUND:                                                           │   │
│  │    UDP 51820   ← 0.0.0.0/0 (WireGuard VPN connections)             │   │
│  │  Target: Bastion VM                                                │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 4. Load Balancing - GCP Application Load Balancer (PRD)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│              GCP APPLICATION LOAD BALANCER (Global)                          │
│              Single Global IP: project-prd-alb-ip                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  TYPE: External Application Load Balancer (Layer 7)                          │
│  SCHEME: Internet-facing (Global)                                            │
│  HEALTH CHECKS: HTTP per service                                             │
│  SSL: Google-managed certificate (*.gameplatform.example.com)                            │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                         INGRESS CONTROLLER                          │   │
│  │                         (GCE Class - via GKE)                       │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │  ManagedCertificate: project-prd-alb-cert-v2                        │   │
│  │  Domains:                                                          │   │
│  │    - nakama.gameplatform.example.com                                           │   │
│  │    - app.gameplatform.example.com                                              │   │
│  │    - lobby-backend.gameplatform.example.com                                    │   │
│  │    - afs.gameplatform.example.com                                              │   │
│  │    - ahsat.gameplatform.example.com                                            │   │
│  │    - ais.gameplatform.example.com                                              │   │
│  │    - aes.gameplatform.example.com                                              │   │
│  │    - aps.gameplatform.example.com                                              │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    HOSTNAME-BASED ROUTING                           │   │
│  ├────────────────────────────────────────┬────────────────────────────┤   │
│  │ Hostname                              │ Backend (Port)             │   │
│  ├────────────────────────────────────────┼────────────────────────────┤   │
│  │ nakama.gameplatform.example.com                   │ nakama-svc (7350)          │   │
│  │ app.gameplatform.example.com                      │ lobby-svc (3000)           │   │
│  │ lobby-backend.gameplatform.example.com            │ lobby-backend-svc (3001)   │   │
│  │ afs.gameplatform.example.com                      │ afs-svc (9933)             │   │
│  │ ahsat.gameplatform.example.com                    │ ahsat-svc (6969)           │   │
│  │ ais.gameplatform.example.com                      │ ais-svc (5050)             │   │
│  │ aes.gameplatform.example.com                      │ aes-svc (1988)             │   │
│  │ aps.gameplatform.example.com                      │ aps-svc (4444)             │   │
│  │ gameplatform.example.com (apex)                   │ Redirect → www.gameplatform.example.com│   │
│  │ * (default)                           │ lobby-svc (3000)           │   │
│  └────────────────────────────────────────┴────────────────────────────┘   │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    BACKEND SERVICES (NEG-based)                     │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │  Each service has:                                                 │   │
│  │    - Network Endpoint Group (NEG) per zone                         │   │
│  │    - BackendConfig with health check settings                      │   │
│  │    - Timeout configuration (30s default, 3600s for Nakama WS)     │   │
│  │                                                                     │   │
│  │  Health Check Paths:                                               │   │
│  │    nakama:        /healthcheck                                     │   │
│  │    lobby:         /                                                │   │
│  │    lobby-backend: /health                                          │   │
│  │    afs:           /ping                                            │   │
│  │    ahsat:         /ping                                            │   │
│  │    ais:           /health                                          │   │
│  │    aes:           /health                                          │   │
│  │    aps:           /v0/aps/ping                                     │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    APEX DOMAIN REDIRECT                             │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │  gameplatform.example.com → 301 Redirect → https://www.gameplatform.example.com            │   │
│  │                                                                     │   │
│  │  Implementation:                                                   │   │
│  │    - nginx:alpine container (10m CPU, 16Mi RAM)                    │   │
│  │    - ConfigMap with redirect rules                                 │   │
│  │    - Separate ManagedCertificate for apex domain                   │   │
│  │    - BackendConfig with /healthz health check                      │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 5. GKE Infrastructure

### 5.1 GKE Clusters Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    GKE CLUSTERS                                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  NON-PROD ENVIRONMENT (us-east1):                                           │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  CLUSTER: gameplatform-nonprod-runners                                    │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │  Purpose: CI/CD infrastructure (ArgoCD, ARC, ESO)                  │   │
│  │  Endpoint: PRIVATE (VPN access only)                               │   │
│  │  Release Channel: RAPID                                             │   │
│  │  Datapath: ADVANCED_DATAPATH (eBPF)                                │   │
│  │  Workload Identity: ENABLED                                         │   │
│  │                                                                      │   │
│  │  NODE POOLS:                                                        │   │
│  │  ┌─────────────────────┬───────────────────────────────────────┐   │   │
│  │  │ infra               │ runners-heavy                         │   │   │
│  │  ├─────────────────────┼───────────────────────────────────────┤   │   │
│  │  │ Machine: e2-std-2   │ Machine: e2-std-4                     │   │   │
│  │  │ Nodes: 1-3          │ Nodes: 0-10                           │   │   │
│  │  │ Disk: 100GB std     │ Disk: 100GB SSD                       │   │   │
│  │  │ Taints: NONE        │ Taint: runner-type=heavy:NO_SCHEDULE  │   │   │
│  │  │ Purpose: ArgoCD,    │ Purpose: GitHub Actions heavy jobs    │   │   │
│  │  │ ESO, ARC controller │ (Docker builds, compilation)          │   │   │
│  │  └─────────────────────┴───────────────────────────────────────┘   │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  CLUSTER: project-dev-workloads                                      │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │  Purpose: Development environment (8 services)                     │   │
│  │  Endpoint: PRIVATE (VPN + ArgoCD access)                           │   │
│  │  Namespace: gameplatform-dev                                              │   │
│  │                                                                      │   │
│  │  NODE POOL:                                                         │   │
│  │  ┌─────────────────────────────────────────────────────────────┐   │   │
│  │  │ general                                                      │   │   │
│  │  │ Machine: e2-standard-2 (2 vCPU, 8GB RAM)                    │   │   │
│  │  │ Nodes: 1-3 (autoscaling)                                    │   │   │
│  │  │ Taints: NONE                                                 │   │   │
│  │  └─────────────────────────────────────────────────────────────┘   │   │
│  │                                                                      │   │
│  │  MASTER AUTHORIZED NETWORKS:                                        │   │
│  │    10.0.0.0/24      (On-premises VPN)                              │   │
│  │    10.100.0.0/20    (Dev subnet)                                   │   │
│  │    10.48.0.0/20     (Stg subnet)                                   │   │
│  │    10.120.0.0/20    (Runners subnet)                               │   │
│  │    10.124.0.0/14    (Runners pod CIDR - for ArgoCD)                │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  CLUSTER: project-stg-workloads                                      │   │
│  │  (Same configuration as dev-workloads)                             │   │
│  │  Namespace: gameplatform-stg                                              │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  PRODUCTION ENVIRONMENT (southamerica-east1):                               │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  CLUSTER: project-prd-workloads                                      │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │  Purpose: Production environment (8 services)                      │   │
│  │  Endpoint: PRIVATE (VPN + ALB via Ingress)                         │   │
│  │  Namespace: gameplatform-prd                                              │   │
│  │                                                                      │   │
│  │  NODE POOL:                                                         │   │
│  │  ┌─────────────────────────────────────────────────────────────┐   │   │
│  │  │ general                                                      │   │   │
│  │  │ Machine: e2-standard-4 (4 vCPU, 16GB RAM)                   │   │   │
│  │  │ Nodes: 3-5 (HA across 3 zones)                              │   │   │
│  │  │ Taints: NONE                                                 │   │   │
│  │  │ Auto-upgrade: REGULAR channel                                │   │   │
│  │  └─────────────────────────────────────────────────────────────┘   │   │
│  │                                                                      │   │
│  │  HA CONFIGURATION:                                                  │   │
│  │    - 3 nodes minimum (one per zone)                                │   │
│  │    - Deletion protection: ENABLED                                   │   │
│  │    - Regional cluster with failover                                │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  CLUSTER: project-prd-runners                                        │   │
│  │  Purpose: Production CI/CD (separate from nonprod)                 │   │
│  │  (Same node pool configuration as nonprod-runners)                 │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 5.2 Kubernetes Namespaces & Components

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    KUBERNETES NAMESPACES                                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  RUNNERS CLUSTER (gameplatform-{env}-runners):                                    │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  arc-systems                                                        │   │
│  │  ├── ARC Controller (gha-runner-scale-set-controller)              │   │
│  │  └── ARC Webhook Server (receives GitHub events)                   │   │
│  │                                                                      │   │
│  │  arc-runners                                                        │   │
│  │  └── Runner Pods (0-10 ephemeral pods for GitHub Actions)          │   │
│  │                                                                      │   │
│  │  argocd                                                             │   │
│  │  ├── argocd-server (API + UI)                                      │   │
│  │  ├── argocd-repo-server (Git operations)                           │   │
│  │  ├── argocd-application-controller (reconciliation)                │   │
│  │  ├── argocd-applicationset-controller (app generation)             │   │
│  │  └── argocd-image-updater (image tag updates)                      │   │
│  │                                                                      │   │
│  │  external-secrets                                                   │   │
│  │  └── ESO Controller (syncs GCP Secret Manager → K8s)               │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  WORKLOADS CLUSTER (gameplatform-{env}-workloads):                                │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  gameplatform-{env}                                                       │   │
│  │  ├── game-platform-{env}-lobby (Deployment + Service)            │   │
│  │  ├── game-platform-{env}-lobby-backend (Deployment + Service)    │   │
│  │  ├── game-platform-{env}-nakama (Deployment + Service)           │   │
│  │  ├── game-platform-{env}-afs (Deployment + Service)              │   │
│  │  ├── game-platform-{env}-ahsat (Deployment + Service)            │   │
│  │  ├── game-platform-{env}-ais (Deployment + Service)              │   │
│  │  ├── game-platform-{env}-aes (Deployment + Service)              │   │
│  │  ├── game-platform-{env}-aps (Deployment + Service)              │   │
│  │  ├── {service}-config (ConfigMaps from .env files)                 │   │
│  │  ├── {service}-secrets (ExternalSecrets from GCP)                  │   │
│  │  └── Ingress (GCE class, routes to services)                       │   │
│  │                                                                      │   │
│  │  external-secrets                                                   │   │
│  │  └── ESO Controller + ClusterSecretStore (gcp-secret-manager)      │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 5.3 8 Microservices Detail

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    8 MICROSERVICES                                           │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌────────────────────┐  ┌────────────────────┐  ┌────────────────────┐    │
│  │ NAKAMA             │  │ LOBBY              │  │ LOBBY-BACKEND      │    │
│  │ Game Server        │  │ Frontend           │  │ API                │    │
│  ├────────────────────┤  ├────────────────────┤  ├────────────────────┤    │
│  │ Port: 7350 (HTTP)  │  │ Port: 3000         │  │ Port: 3001         │    │
│  │ Port: 7349 (gRPC)  │  │ Tech: Next.js 15   │  │ Tech: NestJS 11    │    │
│  │ Port: 7351 (Admin) │  │ Health: /          │  │ Health: /health    │    │
│  │ Tech: Go + Lua     │  │ Replicas: 2-20     │  │ Replicas: 1-5      │    │
│  │ Health: /healthchk │  │ Resources:         │  │ Resources:         │    │
│  │ Replicas: 1-10     │  │  250m/1 CPU        │  │  250m/1 CPU        │    │
│  │ Resources:         │  │  512Mi/1Gi RAM     │  │  256Mi/1Gi RAM     │    │
│  │  500m/2 CPU        │  │                    │  │                    │    │
│  │  1Gi/2Gi RAM       │  │ Dependencies:      │  │ Dependencies:      │    │
│  │                    │  │  - lobby-backend   │  │  - Cloud SQL       │    │
│  │ Dependencies:      │  │  - nakama          │  │  - Nakama          │    │
│  │  - Cloud SQL       │  │                    │  │  - AES, AIS, AFS   │    │
│  │  - lobby-backend   │  │                    │  │  - External APIs   │    │
│  └────────────────────┘  └────────────────────┘  └────────────────────┘    │
│                                                                              │
│  ┌────────────────────┐  ┌────────────────────┐  ┌────────────────────┐    │
│  │ AFS                │  │ AHSAT              │  │ AIS                │    │
│  │ Asset File Service │  │ Analytics          │  │ AI Image           │    │
│  ├────────────────────┤  ├────────────────────┤  ├────────────────────┤    │
│  │ Port: 9933         │  │ Port: 6969         │  │ Port: 5050         │    │
│  │ Tech: Go + Gin     │  │ Tech: Go + Gin     │  │ Tech: Python       │    │
│  │                    │  │                    │  │       FastAPI      │    │
│  │ Health: /ping      │  │ Health: /ping      │  │ Health: /health    │    │
│  │ Replicas: 1-10     │  │ Replicas: 1-10     │  │ Replicas: 1-5      │    │
│  │ Resources:         │  │ Resources:         │  │ Resources:         │    │
│  │  250m/1 CPU        │  │  250m/1 CPU        │  │  250m/1 CPU        │    │
│  │  512Mi/1Gi RAM     │  │  512Mi/1Gi RAM     │  │  512Mi/1Gi RAM     │    │
│  │                    │  │                    │  │                    │    │
│  │ Storage: GCS       │  │ Dependencies:      │  │ Storage: GCS       │    │
│  │ (Native client)    │  │  - Cloud SQL       │  │ (Native client)    │    │
│  │                    │  │  - Nakama          │  │                    │    │
│  │ Workload Identity  │  │                    │  │ External API:      │    │
│  │                    │  │                    │  │  - Piapi.ai        │    │
│  └────────────────────┘  └────────────────────┘  └────────────────────┘    │
│                                                                              │
│  ┌────────────────────┐  ┌────────────────────┐                             │
│  │ AES                │  │ APS                │                             │
│  │ Email Service      │  │ Payment Service    │                             │
│  ├────────────────────┤  ├────────────────────┤                             │
│  │ Port: 1988         │  │ Port: 4444         │                             │
│  │ Tech: Python       │  │ Tech: Go + Gin     │                             │
│  │       FastAPI      │  │                    │                             │
│  │ Health: /health    │  │ Health: /v0/aps/   │                             │
│  │                    │  │         ping       │                             │
│  │ Replicas: 1-5      │  │ Replicas: 1-5      │                             │
│  │ Resources:         │  │ Resources:         │                             │
│  │  100m/512m CPU     │  │  250m/1 CPU        │                             │
│  │  128Mi/512Mi RAM   │  │  256Mi/512Mi RAM   │                             │
│  │                    │  │                    │                             │
│  │ External:          │  │ External API:      │                             │
│  │  - AWS SES (SMTP)  │  │  - Yuno Payments   │                             │
│  │    587             │  │    (sandbox/prod)  │                             │
│  └────────────────────┘  └────────────────────┘                             │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 6. Database - Cloud SQL PostgreSQL

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    CLOUD SQL POSTGRESQL                                      │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  DEV/STG INSTANCES (us-east1):                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  Instance: project-dev-postgres / project-stg-postgres               │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │  Engine: PostgreSQL 15                                             │   │
│  │  Tier: db-custom-1-3840 (1 vCPU, 3.75GB RAM)                      │   │
│  │  HA: ZONAL (single zone, no failover)                             │   │
│  │  Storage: SSD 20GB (autoresize to 100GB)                          │   │
│  │  Connectivity: Private IP only                                     │   │
│  │  SSL: Required                                                     │   │
│  │                                                                     │   │
│  │  DATABASES:                                                        │   │
│  │    nakama    - Game server data                                    │   │
│  │    lobby     - Lobby backend data                                  │   │
│  │                                                                     │   │
│  │  USERS:                                                            │   │
│  │    nakama    - Application user (auto-generated password)         │   │
│  │    lobby     - Application user (auto-generated password)         │   │
│  │                                                                     │   │
│  │  FLAGS:                                                            │   │
│  │    max_connections: 20 (limited for dev/stg)                      │   │
│  │                                                                     │   │
│  │  BACKUPS:                                                          │   │
│  │    Daily at 03:00 UTC, 3 retained backups                         │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  PRODUCTION INSTANCE (southamerica-east1):                                  │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  Instance: project-prd-postgres                                     │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │  Engine: PostgreSQL 15                                             │   │
│  │  Tier: db-custom-4-16384 (4 vCPU, 16GB RAM)                       │   │
│  │  HA: REGIONAL (automatic failover to standby)                     │   │
│  │  Storage: SSD 100GB (autoresize to 500GB)                         │   │
│  │  Connectivity: Private IP only (10.39.0.5)                        │   │
│  │  SSL: Required                                                     │   │
│  │  Deletion Protection: ENABLED                                      │   │
│  │                                                                     │   │
│  │  DATABASES:                                                        │   │
│  │    nakama    - charset: UTF8, collation: en_US.UTF-8              │   │
│  │    lobby     - charset: UTF8, collation: en_US.UTF8               │   │
│  │                                                                     │   │
│  │  USERS:                                                            │   │
│  │    nakama    - BUILT_IN type                                       │   │
│  │    lobby     - BUILT_IN type                                       │   │
│  │                                                                     │   │
│  │  FLAGS:                                                            │   │
│  │    max_connections: 5000  (high traffic production)                │   │
│  │    log_checkpoints: on                                             │   │
│  │    log_connections: on                                             │   │
│  │    log_disconnections: on                                          │   │
│  │    log_lock_waits: on                                              │   │
│  │                                                                     │   │
│  │  BACKUPS:                                                          │   │
│  │    Daily at 03:00 UTC                                              │   │
│  │    PITR: Enabled (7 days transaction log retention)               │   │
│  │    Retained backups: 14                                            │   │
│  │                                                                     │   │
│  │  MAINTENANCE WINDOW:                                               │   │
│  │    Sunday 03:00 UTC, STABLE track                                  │   │
│  │                                                                     │   │
│  │  QUERY INSIGHTS: Enabled                                           │   │
│  │    query_string_length: 1024                                       │   │
│  │    record_application_tags: true                                   │   │
│  │    record_client_address: true                                     │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  SECRET MANAGER INTEGRATION:                                                │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  Per user, Terraform creates:                                      │   │
│  │    gameplatform-{env}-db-{user}-connection  (full connection string)    │   │
│  │    gameplatform-{env}-db-{user}-password    (password only)             │   │
│  │    gameplatform-{env}-db-host               (private IP)                │   │
│  │                                                                     │   │
│  │  ESO syncs to K8s Secrets for pod consumption                     │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 7. Storage - GCS Buckets

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    GCS BUCKETS                                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  ASSETS BUCKET                                                       │   │
│  │  {env}-gameplatform-server-software-{env}                                  │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │  Examples:                                                          │   │
│  │    dev-gameplatform-server-software-dev                                   │   │
│  │    stg-gameplatform-server-software-stg                                   │   │
│  │    prd-gameplatform-server-software-prd                                   │   │
│  │                                                                      │   │
│  │  Purpose: User assets, avatars, world files, AI generations         │   │
│  │  Location: Same region as workloads                                 │   │
│  │  Storage Class: STANDARD                                            │   │
│  │  Access: Workload Identity (no service account keys)                │   │
│  │                                                                      │   │
│  │  Used by:                                                           │   │
│  │    - AFS (upload/download via native GCS client)                   │   │
│  │    - AIS (store generated images via native GCS client)            │   │
│  │                                                                      │   │
│  │  Structure:                                                         │   │
│  │    /users/{user_id}/avatars/                                        │   │
│  │    /users/{user_id}/assets/                                         │   │
│  │    /worlds/{world_id}/                                              │   │
│  │    /generations/{job_id}/                                           │   │
│  │                                                                      │   │
│  │  Authentication:                                                    │   │
│  │    Native GCS client (cloud.google.com/go/storage for Go)          │   │
│  │    Native GCS client (google-cloud-storage for Python)             │   │
│  │    Workload Identity Federation (no HMAC keys needed)              │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  TERRAFORM STATE BUCKETS                                            │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │  gameplatform-nonprod-terraform-state (us-east1)                         │   │
│  │    - Stores dev/stg/nonprod stack states                           │   │
│  │    - Versioning: Enabled                                            │   │
│  │                                                                      │   │
│  │  gameplatform-terraform-state-prd (southamerica-east1)                   │   │
│  │    - Stores prd stack states                                        │   │
│  │    - Versioning: Enabled                                            │   │
│  │    - Separate bucket for production isolation                       │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 8. Service Communication - Data Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    SERVICE COMMUNICATION                                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  INTERNAL (K8s DNS - cluster.local)                                         │
│  ──────────────────────────────────                                         │
│                                                                              │
│  ┌────────────┐     HTTP 7350      ┌────────────┐                           │
│  │ Lobby      │ ─────────────────▶ │ Nakama     │                           │
│  │ Backend    │                    │            │                           │
│  └────────────┘                    └────────────┘                           │
│        │                                  │                                  │
│        │ HTTP 6969                        │ TCP 5432                        │
│        ▼                                  ▼                                  │
│  ┌────────────┐                    ┌────────────┐                           │
│  │ AHSAT      │                    │ Cloud SQL  │                           │
│  │            │                    │ PostgreSQL │                           │
│  └────────────┘                    └────────────┘                           │
│        │                                  ▲                                  │
│        │ HTTP 5050                        │ TCP 5432                        │
│        ▼                                  │                                  │
│  ┌────────────┐     HTTP 9933      ┌────────────┐                           │
│  │ AIS        │ ─────────────────▶ │ AFS        │                           │
│  │ (AI Image) │                    │ (Files)    │                           │
│  └────────────┘                    └────────────┘                           │
│        │                                  │                                  │
│        │                                  │                                  │
│        ▼                                  ▼                                  │
│  ┌────────────┐                    ┌────────────┐                           │
│  │ GCS Bucket │                    │ GCS Bucket │                           │
│  │ (native)   │                    │ (native)   │                           │
│  └────────────┘                    └────────────┘                           │
│                                                                              │
│  K8s SERVICE DNS NAMES:                                                     │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  game-platform-{env}-lobby.gameplatform-{env}.svc.cluster.local:3000   │   │
│  │  game-platform-{env}-lobby-backend.gameplatform-{env}.svc.cluster...:3001│  │
│  │  game-platform-{env}-nakama.gameplatform-{env}.svc.cluster.local:7350  │   │
│  │  game-platform-{env}-afs.gameplatform-{env}.svc.cluster.local:9933     │   │
│  │  game-platform-{env}-ahsat.gameplatform-{env}.svc.cluster.local:6969   │   │
│  │  game-platform-{env}-ais.gameplatform-{env}.svc.cluster.local:5050     │   │
│  │  game-platform-{env}-aes.gameplatform-{env}.svc.cluster.local:1988     │   │
│  │  game-platform-{env}-aps.gameplatform-{env}.svc.cluster.local:4444     │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│                                                                              │
│  EXTERNAL (Internet - via Cloud NAT Gateway)                                │
│  ───────────────────────────────────────────                                │
│                                                                              │
│  ┌────────────┐     SMTP 587       ┌────────────┐                           │
│  │ AES        │ ─────────────────▶ │ AWS SES    │                           │
│  │ (Email)    │                    │ us-east-1  │                           │
│  └────────────┘                    └────────────┘                           │
│                                                                              │
│  ┌────────────┐     HTTPS 443      ┌────────────┐                           │
│  │ AIS        │ ─────────────────▶ │ Piapi.ai   │                           │
│  │ (AI Image) │                    │ (3D Gen)   │                           │
│  └────────────┘                    └────────────┘                           │
│                                                                              │
│  ┌────────────┐     HTTPS 443      ┌────────────┐                           │
│  │ APS        │ ─────────────────▶ │ Yuno       │                           │
│  │ (Payments) │                    │ Payments   │                           │
│  └────────────┘                    └────────────┘                           │
│                                                                              │
│  ┌────────────┐     HTTPS 443      ┌────────────┐                           │
│  │ Lobby-     │ ─────────────────▶ │ Google     │                           │
│  │ Backend    │                    │ OAuth      │                           │
│  └────────────┘                    └────────────┘                           │
│                                                                              │
│  ┌────────────┐     HTTPS 443      ┌────────────┐                           │
│  │ Lobby-     │ ─────────────────▶ │ Ready      │                           │
│  │ Backend    │                    │ Player Me  │                           │
│  └────────────┘                    └────────────┘                           │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 9. IAM & Workload Identity

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    IAM & WORKLOAD IDENTITY                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  WORKLOAD IDENTITY (Pod → GCP API Authentication)                   │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │                                                                      │   │
│  │  HOW IT WORKS:                                                      │   │
│  │    1. K8s ServiceAccount annotated with GSA email                   │   │
│  │    2. GSA has IAM binding to K8s SA                                 │   │
│  │    3. Pod uses K8s SA token to authenticate to GCP APIs            │   │
│  │    4. No service account keys needed (secure by default)           │   │
│  │                                                                      │   │
│  │  FORMAT:                                                            │   │
│  │    GSA: {service}@{project}.iam.gserviceaccount.com                │   │
│  │    KSA: serviceAccount:{project}.svc.id.goog[{ns}/{ksa}]          │   │
│  │                                                                      │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  SERVICE ACCOUNTS PER WORKLOAD                                      │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │                                                                      │   │
│  │  NAKAMA:                                                            │   │
│  │    GSA: gameplatform-{env}-nakama@{project}.iam.gserviceaccount.com      │   │
│  │    Roles:                                                           │   │
│  │      - roles/cloudsql.client                                        │   │
│  │      - roles/secretmanager.secretAccessor                          │   │
│  │      - roles/monitoring.metricWriter                               │   │
│  │                                                                      │   │
│  │  LOBBY-BACKEND:                                                     │   │
│  │    GSA: gameplatform-{env}-lobby-backend@{project}.iam.gserviceaccount.. │   │
│  │    Roles:                                                           │   │
│  │      - roles/cloudsql.client                                        │   │
│  │      - roles/secretmanager.secretAccessor                          │   │
│  │      - roles/monitoring.metricWriter                               │   │
│  │                                                                      │   │
│  │  AFS / AIS:                                                         │   │
│  │    GSA: gameplatform-{env}-{service}@{project}.iam.gserviceaccount.com   │   │
│  │    Roles:                                                           │   │
│  │      - roles/storage.objectAdmin (GCS bucket access)               │   │
│  │      - roles/secretmanager.secretAccessor                          │   │
│  │                                                                      │   │
│  │  EXTERNAL-SECRETS:                                                  │   │
│  │    GSA: gameplatform-{env}-external-secrets@{project}.iam...             │   │
│  │    Roles:                                                           │   │
│  │      - roles/secretmanager.secretAccessor                          │   │
│  │      - roles/secretmanager.viewer                                   │   │
│  │                                                                      │   │
│  │  ARGOCD:                                                            │   │
│  │    GSA: gameplatform-{env}-argocd@{project}.iam.gserviceaccount.com      │   │
│  │    Roles:                                                           │   │
│  │      - roles/artifactregistry.reader                               │   │
│  │                                                                      │   │
│  │  ARC-RUNNER:                                                        │   │
│  │    GSA: gameplatform-{env}-arc-runner@{project}.iam.gserviceaccount.com  │   │
│  │    Roles:                                                           │   │
│  │      - roles/artifactregistry.writer                               │   │
│  │      - roles/artifactregistry.reader                               │   │
│  │      - roles/storage.objectViewer                                   │   │
│  │      - roles/secretmanager.secretAccessor                          │   │
│  │      - roles/container.developer                                    │   │
│  │                                                                      │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  GITHUB OIDC (CI/CD Pipeline Authentication)                        │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │                                                                      │   │
│  │  Workload Identity Pool: github                                     │   │
│  │  Provider: github (OIDC, attribute mapping)                         │   │
│  │                                                                      │   │
│  │  Service Account: gameplatform-github-actions@{project}.iam...           │   │
│  │                                                                      │   │
│  │  Roles:                                                             │   │
│  │    - roles/artifactregistry.writer                                  │   │
│  │    - roles/container.developer                                      │   │
│  │    - roles/storage.admin                                            │   │
│  │    - roles/secretmanager.secretAccessor                            │   │
│  │    - roles/iam.workloadIdentityUser                                 │   │
│  │    - roles/editor (for VPN/Bastion stack)                          │   │
│  │    - roles/iam.securityAdmin                                        │   │
│  │    - roles/iam.workloadIdentityPoolAdmin                           │   │
│  │    - roles/servicenetworking.networksAdmin                         │   │
│  │                                                                      │   │
│  │  Repository Bindings:                                               │   │
│  │    - gameplatform/gameplatform-monorepo                                        │   │
│  │    - gameplatform/platform-kubernetes-infrastructure                       │   │
│  │    - gameplatform/gameplatform-shared-infrastructure-gcp                       │   │
│  │    - gameplatform/gameplatform-shared-actions                                  │   │
│  │    - gameplatform/gameplatform-terraform                                        │   │
│  │                                                                      │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 10. CI/CD Pipeline

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    CI/CD PIPELINE                                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    ARTIFACT REGISTRY                                 │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │                                                                      │   │
│  │  REPOSITORIES:                                                      │   │
│  │    us-east1-docker.pkg.dev/project-nonprod-env/project-dev-images    │   │
│  │    us-east1-docker.pkg.dev/project-nonprod-env/project-stg-images    │   │
│  │    southamerica-east1-docker.pkg.dev/project-prd-env/project-prd-images│  │
│  │                                                                      │   │
│  │  IMAGES (per repo):                                                 │   │
│  │    - lobby                                                          │   │
│  │    - lobby-backend                                                  │   │
│  │    - nakama                                                         │   │
│  │    - afs                                                            │   │
│  │    - ahsat                                                          │   │
│  │    - ais                                                            │   │
│  │    - aes                                                            │   │
│  │    - aps                                                            │   │
│  │                                                                      │   │
│  │  TAGGING:                                                           │   │
│  │    Format: {service}:{version}.{build} or :latest                  │   │
│  │    Example: lobby:1.1.7.42                                          │   │
│  │                                                                      │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    ARC (Actions Runner Controller)                   │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │                                                                      │   │
│  │  CONTROLLER (arc-systems namespace):                                │   │
│  │    - gha-runner-scale-set-controller (deployment)                   │   │
│  │    - Webhook server (receives GitHub events)                        │   │
│  │    - Scales runners from 0 based on workflow demand                │   │
│  │                                                                      │   │
│  │  RUNNER POOLS (arc-runners namespace):                              │   │
│  │    - gameplatform-heavy (e2-standard-4, SSD, Docker builds)              │   │
│  │    - Scale: 0-10 pods                                               │   │
│  │    - Ephemeral (destroyed after each job)                          │   │
│  │                                                                      │   │
│  │  RUNNER IMAGE:                                                      │   │
│  │    Custom image with: docker, gcloud, kubectl, helm, terraform     │   │
│  │                                                                      │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    ARGOCD (GitOps)                                   │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │                                                                      │   │
│  │  LOCATION: Runners cluster (argocd namespace)                       │   │
│  │                                                                      │   │
│  │  MANAGES:                                                           │   │
│  │    - Dev workloads cluster (remote)                                │   │
│  │    - Stg workloads cluster (remote)                                │   │
│  │    - Prd workloads cluster (via prd-runners ArgoCD)                │   │
│  │                                                                      │   │
│  │  CONFIGURATION:                                                     │   │
│  │    Reconciliation interval: 30 seconds                              │   │
│  │    Auto-sync: Enabled                                               │   │
│  │    Self-heal: Enabled                                               │   │
│  │    Prune: Enabled                                                   │   │
│  │                                                                      │   │
│  │  IMAGE UPDATER:                                                     │   │
│  │    Watches: Artifact Registry for new tags                         │   │
│  │    Updates: Git repository with new image tags                     │   │
│  │    Strategy: semver (picks latest semantic version)                │   │
│  │                                                                      │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    DEPLOYMENT FLOW                                   │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │                                                                      │   │
│  │  1. Developer pushes code to GitHub                                 │   │
│  │            │                                                         │   │
│  │            ▼                                                         │   │
│  │  2. GitHub sends webhook to ARC controller                          │   │
│  │            │                                                         │   │
│  │            ▼                                                         │   │
│  │  3. ARC scales up runner pod (0 → 1)                                │   │
│  │            │                                                         │   │
│  │            ▼                                                         │   │
│  │  4. Runner builds Docker image                                      │   │
│  │            │                                                         │   │
│  │            ▼                                                         │   │
│  │  5. Image pushed to Artifact Registry                               │   │
│  │            │                                                         │   │
│  │            ▼                                                         │   │
│  │  6. ArgoCD Image Updater detects new tag                            │   │
│  │            │                                                         │   │
│  │            ▼                                                         │   │
│  │  7. ArgoCD syncs deployment with new image                          │   │
│  │            │                                                         │   │
│  │            ▼                                                         │   │
│  │  8. GKE performs rolling update                                     │   │
│  │            │                                                         │   │
│  │            ▼                                                         │   │
│  │  9. Health checks verify new pods                                   │   │
│  │            │                                                         │   │
│  │            ▼                                                         │   │
│  │  10. Old pods terminated                                            │   │
│  │                                                                      │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    CONFIGMAP SYNC                                    │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │                                                                      │   │
│  │  Workflow: sync-configmaps.yml                                      │   │
│  │  Trigger: Push to environment-variables/** OR manual dispatch       │   │
│  │                                                                      │   │
│  │  FLOW:                                                              │   │
│  │    1. .env file modified in gameplatform-monorepo                        │   │
│  │    2. Workflow runs kubectl create configmap ... --dry-run -o yaml │   │
│  │    3. Piped to kubectl apply -f -                                   │   │
│  │    4. ConfigMap updated in gameplatform-{env} namespace                   │   │
│  │    5. Pod envFrom references ConfigMap                              │   │
│  │    6. Pod restart (or wait for rollout) applies new config          │   │
│  │                                                                      │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 11. VPN & Bastion Access

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    VPN & BASTION ACCESS                                      │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  BASTION VM                                                          │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │                                                                      │   │
│  │  NON-PROD:                                                          │   │
│  │    Name: gameplatform-nonprod-bastion                                     │   │
│  │    Zone: us-east1-a                                                 │   │
│  │    Machine: e2-small (2 vCPU, 2GB RAM)                             │   │
│  │    Internal IP: 10.120.0.3 (runners subnet)                        │   │
│  │    External IP: Dynamic (NAT allocated)                             │   │
│  │                                                                      │   │
│  │  PRODUCTION:                                                        │   │
│  │    Name: project-prd-bastion                                         │   │
│  │    Zone: southamerica-east1-a                                       │   │
│  │    Machine: e2-small (2 vCPU, 2GB RAM)                             │   │
│  │    Internal IP: 10.112.0.3 (runners subnet)                        │   │
│  │    External IP: 198.51.100.29 (STATIC)                             │   │
│  │                                                                      │   │
│  │  INSTALLED TOOLS:                                                   │   │
│  │    - kubectl (cluster management)                                   │   │
│  │    - helm (chart deployment)                                        │   │
│  │    - argocd CLI (GitOps management)                                │   │
│  │    - psql (database client)                                         │   │
│  │    - gcloud (GCP CLI)                                               │   │
│  │    - WireGuard (VPN server)                                         │   │
│  │                                                                      │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  WIREGUARD VPN                                                       │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │                                                                      │   │
│  │  PORT: 51820/UDP                                                    │   │
│  │  INTERFACE: wg0                                                     │   │
│  │  NETWORK: 10.0.0.0/24 (VPN clients)                                │   │
│  │                                                                      │   │
│  │  SERVER CONFIG:                                                     │   │
│  │    /etc/wireguard/wg0.conf                                          │   │
│  │    ListenPort = 51820                                               │   │
│  │    Address = 10.0.0.1/24                                            │   │
│  │    PostUp = iptables -A FORWARD ... (NAT masquerade)               │   │
│  │    PostDown = iptables -D FORWARD ...                               │   │
│  │                                                                      │   │
│  │  CLIENT MANAGEMENT:                                                 │   │
│  │    /opt/wireguard/add-user.sh {username}                           │   │
│  │    /opt/wireguard/remove-user.sh {username}                        │   │
│  │    /opt/wireguard/list-users.sh                                     │   │
│  │                                                                      │   │
│  │  CLIENT CONFIGS STORED:                                             │   │
│  │    /etc/wireguard/clients/{username}.conf                          │   │
│  │                                                                      │   │
│  │  ACCESS GRANTED:                                                    │   │
│  │    - Private GKE cluster endpoints                                  │   │
│  │    - Cloud SQL private IP                                           │   │
│  │    - Internal services via K8s DNS                                  │   │
│  │                                                                      │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  ACCESS FLOW                                                         │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │                                                                      │   │
│  │  ┌──────────┐      WireGuard      ┌────────────┐                   │   │
│  │  │ Admin    │ ──────────────────▶ │ Bastion VM │                   │   │
│  │  │ Laptop   │     51820/UDP       │ 10.0.0.1   │                   │   │
│  │  │ 10.0.0.X │                     └──────┬─────┘                   │   │
│  │  └──────────┘                            │                          │   │
│  │                                          │ NAT Masquerade           │   │
│  │                                          ▼                          │   │
│  │  ┌─────────────────────────────────────────────────────────────┐   │   │
│  │  │                    PRIVATE VPC                               │   │   │
│  │  │                                                              │   │   │
│  │  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │   │   │
│  │  │  │ GKE API     │  │ Cloud SQL   │  │ K8s Services│          │   │   │
│  │  │  │ 172.16.x.x  │  │ 10.x.x.x    │  │ 10.x.x.x    │          │   │   │
│  │  │  └─────────────┘  └─────────────┘  └─────────────┘          │   │   │
│  │  │                                                              │   │   │
│  │  └─────────────────────────────────────────────────────────────┘   │   │
│  │                                                                      │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 12. Secret Management

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    SECRET MANAGEMENT                                         │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  GCP SECRET MANAGER                                                  │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │                                                                      │   │
│  │  DATABASE SECRETS (auto-created by Terraform):                      │   │
│  │    gameplatform-{env}-db-nakama-connection                               │   │
│  │    gameplatform-{env}-db-nakama-password                                  │   │
│  │    gameplatform-{env}-db-lobby-connection                                │   │
│  │    gameplatform-{env}-db-lobby-password                                   │   │
│  │    gameplatform-{env}-db-host                                             │   │
│  │                                                                      │   │
│  │  APPLICATION SECRETS (manually created):                            │   │
│  │    gameplatform-{env}-oauth-google-client-id                             │   │
│  │    gameplatform-{env}-oauth-google-client-secret                         │   │
│  │    gameplatform-{env}-nextauth-secret                                     │   │
│  │    gameplatform-{env}-nakama-server-key                                   │   │
│  │    gameplatform-{env}-smtp-password                                       │   │
│  │    gameplatform-{env}-yuno-api-key                                        │   │
│  │    gameplatform-{env}-piapi-api-key                                       │   │
│  │                                                                      │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  EXTERNAL SECRETS OPERATOR (ESO)                                    │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │                                                                      │   │
│  │  INSTALLATION:                                                      │   │
│  │    Namespace: external-secrets                                      │   │
│  │    Clusters: All workloads + runners clusters                       │   │
│  │                                                                      │   │
│  │  CLUSTER SECRET STORE:                                              │   │
│  │    Name: gcp-secret-manager                                         │   │
│  │    Provider: gcpsm (GCP Secret Manager)                             │   │
│  │    Auth: Workload Identity                                          │   │
│  │    Service Account: gameplatform-{env}-external-secrets                   │   │
│  │                                                                      │   │
│  │  EXTERNAL SECRET EXAMPLE:                                           │   │
│  │    apiVersion: external-secrets.io/v1beta1                          │   │
│  │    kind: ExternalSecret                                             │   │
│  │    metadata:                                                        │   │
│  │      name: db-credentials                                           │   │
│  │    spec:                                                            │   │
│  │      secretStoreRef:                                                │   │
│  │        name: gcp-secret-manager                                     │   │
│  │        kind: ClusterSecretStore                                     │   │
│  │      target:                                                        │   │
│  │        name: db-credentials                                         │   │
│  │      data:                                                          │   │
│  │        - secretKey: DB_PASSWORD                                     │   │
│  │          remoteRef:                                                 │   │
│  │            key: gameplatform-{env}-db-nakama-password                    │   │
│  │                                                                      │   │
│  │  REFRESH INTERVAL: 1 hour                                           │   │
│  │                                                                      │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  SECRET FLOW                                                         │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │                                                                      │   │
│  │  ┌──────────────┐      Workload     ┌──────────────┐               │   │
│  │  │ GCP Secret   │ ─────Identity────▶ │ ESO         │               │   │
│  │  │ Manager      │                    │ Controller   │               │   │
│  │  └──────────────┘                    └──────┬───────┘               │   │
│  │                                             │                        │   │
│  │                                             │ Creates/Updates        │   │
│  │                                             ▼                        │   │
│  │                                      ┌──────────────┐               │   │
│  │                                      │ K8s Secret   │               │   │
│  │                                      │ db-credentials│              │   │
│  │                                      └──────┬───────┘               │   │
│  │                                             │                        │   │
│  │                                             │ envFrom.secretRef     │   │
│  │                                             ▼                        │   │
│  │                                      ┌──────────────┐               │   │
│  │                                      │ Pod          │               │   │
│  │                                      │ (env vars)   │               │   │
│  │                                      └──────────────┘               │   │
│  │                                                                      │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 13. Terraform Stacks

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    TERRAFORM/TERRAGRUNT STACKS                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  REPOSITORY: gameplatform-shared-infrastructure-gcp                               │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  STACK STRUCTURE                                                     │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │                                                                      │   │
│  │  stacks/                                                            │   │
│  │  ├── 01-foundation/     (APIs, IAM, service accounts)               │   │
│  │  ├── 02-networking/     (VPC, subnets, NAT, firewall)              │   │
│  │  ├── 03-gke/            (GKE workloads cluster)                    │   │
│  │  ├── 04-database/       (Cloud SQL PostgreSQL)                     │   │
│  │  ├── 05-dns-lb/         (Cloud DNS, Load Balancer)                 │   │
│  │  ├── 06-workloads/      (Artifact Registry, GitHub OIDC, ESO SA)  │   │
│  │  ├── 07-vpn-bastion/    (WireGuard VPN, Bastion VM)               │   │
│  │  └── 08-gke-runners/    (GKE runners cluster)                      │   │
│  │                                                                      │   │
│  │  ENVIRONMENTS:                                                      │   │
│  │  ├── nonprod/           (shared: 02, 06, 07, 08)                   │   │
│  │  │   └── 02-networking/ (shared VPC for dev+stg)                   │   │
│  │  ├── dev/               (01, 03, 04, 05, 06)                       │   │
│  │  ├── stg/               (01, 03, 04, 05, 06)                       │   │
│  │  └── prd/               (01-08 all stacks)                         │   │
│  │                                                                      │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  STACK DEPENDENCIES                                                  │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │                                                                      │   │
│  │  01-foundation ──┐                                                   │   │
│  │                  │                                                   │   │
│  │  02-networking ──┼──▶ 03-gke ──▶ 04-database                        │   │
│  │                  │         │                                         │   │
│  │                  │         ├──▶ 05-dns-lb                            │   │
│  │                  │         │                                         │   │
│  │                  │         └──▶ 06-workloads                         │   │
│  │                  │                                                   │   │
│  │                  └──▶ 07-vpn-bastion                                │   │
│  │                  │                                                   │   │
│  │                  └──▶ 08-gke-runners                                │   │
│  │                                                                      │   │
│  │  DEPENDENCY OUTPUTS USED:                                           │   │
│  │    02→03: vpc_self_link, subnet_self_link                          │   │
│  │    02→04: vpc_self_link, private_service_connection_peering        │   │
│  │    03→05: cluster_name, cluster_endpoint                           │   │
│  │    02→07: vpc_self_link, subnet_name                               │   │
│  │    02→08: vpc_self_link, subnet_self_link                          │   │
│  │                                                                      │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  TERRAFORM STATE LOCATIONS                                           │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │                                                                      │   │
│  │  NON-PROD (us-east1):                                               │   │
│  │    Bucket: gameplatform-nonprod-terraform-state                           │   │
│  │    Paths:                                                           │   │
│  │      dev/01-foundation/terraform.tfstate                           │   │
│  │      dev/03-gke/terraform.tfstate                                  │   │
│  │      dev/04-database/terraform.tfstate                             │   │
│  │      dev/05-dns-lb/terraform.tfstate                               │   │
│  │      dev/06-workloads/terraform.tfstate                            │   │
│  │      stg/... (same structure)                                       │   │
│  │      nonprod/02-networking/terraform.tfstate                       │   │
│  │      nonprod/06-workloads/terraform.tfstate                        │   │
│  │      nonprod/07-vpn-bastion/terraform.tfstate                      │   │
│  │      nonprod/08-gke-runners/terraform.tfstate                      │   │
│  │                                                                      │   │
│  │  PRODUCTION (southamerica-east1):                                   │   │
│  │    Bucket: gameplatform-terraform-state-prd                               │   │
│  │    Paths:                                                           │   │
│  │      prd/01-foundation/terraform.tfstate                           │   │
│  │      prd/02-networking/terraform.tfstate                           │   │
│  │      prd/03-gke/terraform.tfstate                                  │   │
│  │      prd/04-database/terraform.tfstate                             │   │
│  │      prd/05-dns-lb/terraform.tfstate                               │   │
│  │      prd/06-workloads/terraform.tfstate                            │   │
│  │      prd/07-vpn-bastion/terraform.tfstate                          │   │
│  │      prd/08-gke-runners/terraform.tfstate                          │   │
│  │                                                                      │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 14. Summary - GCP Architecture

### Key Components

| Component | GCP Service | Purpose |
|-----------|-------------|---------|
| Compute | GKE (Kubernetes) | Container orchestration |
| Networking | VPC + Cloud NAT | Private networking with outbound NAT |
| Database | Cloud SQL PostgreSQL | Managed relational database |
| Storage | GCS | Object storage for assets |
| DNS | Cloud DNS | Domain management |
| SSL | Google-managed Certs | Automatic certificate renewal |
| Load Balancer | Global ALB | Layer 7 routing (single IP) |
| Secrets | Secret Manager + ESO | Centralized secret management |
| Registry | Artifact Registry | Container image registry |
| CI/CD | ARC + ArgoCD | GitOps deployment pipeline |
| VPN | WireGuard | Secure admin access |

### Architecture Characteristics

| Characteristic | Implementation |
|---------------|----------------|
| **High Availability** | GKE regional clusters, Cloud SQL HA (prd), 3 zones |
| **Security** | Private clusters, Workload Identity, no service account keys |
| **Scalability** | GKE autoscaling 0-10 runners, HPA on workloads |
| **Cost Optimization** | Runners scale to 0, e2 machine types, single VPC (nonprod) |
| **Observability** | Cloud Logging, Cloud Monitoring, Query Insights |
| **GitOps** | ArgoCD auto-sync, Image Updater, 30s reconciliation |
| **Zero Trust** | Workload Identity, private endpoints, VPN-only access |

### Improvements over AWS (Legacy)

| Aspect | AWS (Legacy) | GCP (Current) |
|--------|--------------|---------------|
| Orchestration | ECS Fargate | GKE (full Kubernetes) |
| GitOps | None | ArgoCD + Image Updater |
| CI/CD Runners | GitHub hosted | Self-hosted ARC (0-10 scale) |
| Secret Sync | Manual | ESO automatic sync |
| VPN Access | None (public) | WireGuard (private clusters) |
| Load Balancer | Multiple ALBs | Single Global IP |
| Service Discovery | Cloud Map | Native K8s DNS |

---

## 15. Appendix - Environment-Specific Details

### DEV Environment
- **Project:** project-nonprod-env
- **Region:** us-east1
- **Domain:** Internal only (VPN access)
- **VPC:** Shared (gameplatform-nonprod-vpc)
- **GKE Nodes:** e2-standard-2, 1-3 nodes
- **Cloud SQL:** db-custom-1-3840, Zonal
- **ArgoCD:** Managed from nonprod-runners

### STG Environment
- **Project:** project-nonprod-env
- **Region:** us-east1
- **Domain:** Internal only (VPN access)
- **VPC:** Shared (gameplatform-nonprod-vpc)
- **GKE Nodes:** e2-standard-2, 1-3 nodes
- **Cloud SQL:** db-custom-1-3840, Zonal
- **ArgoCD:** Managed from nonprod-runners

### PRD Environment
- **Project:** project-prd-env
- **Region:** southamerica-east1 (Sao Paulo)
- **Domain:** gameplatform.example.com (public)
- **VPC:** Dedicated (project-prd-vpc)
- **GKE Nodes:** e2-standard-4, 3-5 nodes (HA)
- **Cloud SQL:** db-custom-4-16384, Regional (HA)
- **Bastion IP:** 198.51.100.29
- **ArgoCD:** Managed from prd-runners (separate)

---

*End of GCP Architecture Documentation*
