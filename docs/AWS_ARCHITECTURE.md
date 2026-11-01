# GamePlatform Platform - AWS Architecture (Legacy)

> **Status:** Legacy - Migration to GCP completed
> **Last Updated:** January 2026
> **Purpose:** Reference documentation for AWS → GCP migration

---

## 1. Overview - Three Isolated AWS Accounts

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                              GAMEPLATFORM AWS ARCHITECTURE                                     │
│                          3 ISOLATED AWS ACCOUNTS (Legacy)                                │
└─────────────────────────────────────────────────────────────────────────────────────────┘

                                      INTERNET
                                         │
         ┌───────────────────────────────┼───────────────────────────────┐
         │                               │                               │
         ▼                               ▼                               ▼
┌─────────────────────┐     ┌─────────────────────┐     ┌─────────────────────┐
│    AWS ACCOUNT      │     │    AWS ACCOUNT      │     │    AWS ACCOUNT      │
│       DEV           │     │       STG           │     │       LIVE          │
│   777777777771      │     │   777777777775      │     │   777777777772      │
│                     │     │                     │     │                     │
│   Region: us-east-1 │     │   Region: us-east-1 │     │   Region: sa-east-1 │
│                     │     │                     │     │   (Sao Paulo)       │
├─────────────────────┤     ├─────────────────────┤     ├─────────────────────┤
│                     │     │                     │     │                     │
│  ┌───────────────┐  │     │  ┌───────────────┐  │     │  ┌───────────────┐  │
│  │   Route 53    │  │     │  │   Route 53    │  │     │  │   Route 53    │  │
│  │ dev.gameplatform.   │  │     │  │ stg-gameplatform.   │  │     │  │ gameplatform.example.com  │  │
│  │   click       │  │     │  │   space       │  │     │  │               │  │
│  └───────┬───────┘  │     │  └───────┬───────┘  │     │  └───────┬───────┘  │
│          │          │     │          │          │     │          │          │
│  ┌───────▼───────┐  │     │  ┌───────▼───────┐  │     │  ┌───────▼───────┐  │
│  │     ACM       │  │     │  │     ACM       │  │     │  │     ACM       │  │
│  │ *.dev.gameplatform. │  │     │  │ *.stg-gameplatform. │  │     │  │ *.gameplatform.     │  │
│  │   click       │  │     │  │   space       │  │     │  │   space       │  │
│  └───────┬───────┘  │     │  └───────┬───────┘  │     │  └───────┬───────┘  │
│          │          │     │          │          │     │          │          │
│  ┌───────▼───────┐  │     │  ┌───────▼───────┐  │     │  ┌───────▼───────┐  │
│  │     ALB       │  │     │  │     ALB       │  │     │  │     ALB       │  │
│  │  (Internet)   │  │     │  │  (Internet)   │  │     │  │  (Internet)   │  │
│  └───────┬───────┘  │     │  └───────┬───────┘  │     │  └───────┬───────┘  │
│          │          │     │          │          │     │          │          │
│  ┌───────▼───────┐  │     │  ┌───────▼───────┐  │     │  ┌───────▼───────┐  │
│  │     VPC       │  │     │  │     VPC       │  │     │  │     VPC       │  │
│  │ 10.0.0.0/16   │  │     │  │ 10.0.0.0/16   │  │     │  │ 10.0.0.0/16   │  │
│  │               │  │     │  │               │  │     │  │               │  │
│  │ ┌───────────┐ │  │     │  │ ┌───────────┐ │  │     │  │ ┌───────────┐ │  │
│  │ │ECS Fargate│ │  │     │  │ │ECS Fargate│ │  │     │  │ │ECS Fargate│ │  │
│  │ │ 8 Services│ │  │     │  │ │ 8 Services│ │  │     │  │ │ 8 Services│ │  │
│  │ │           │ │  │     │  │ │           │ │  │     │  │ │           │ │  │
│  │ │ 0.5 vCPU  │ │  │     │  │ │ 1 vCPU    │ │  │     │  │ │ 1 vCPU    │ │  │
│  │ │ 1GB RAM   │ │  │     │  │ │ 2GB RAM   │ │  │     │  │ │ 2GB RAM   │ │  │
│  │ └───────────┘ │  │     │  │ └───────────┘ │  │     │  │ └───────────┘ │  │
│  │               │  │     │  │               │  │     │  │               │  │
│  │ ┌───────────┐ │  │     │  │ ┌───────────┐ │  │     │  │ ┌───────────┐ │  │
│  │ │    RDS    │ │  │     │  │ │    RDS    │ │  │     │  │ │    RDS    │ │  │
│  │ │ t3.medium │ │  │     │  │ │ t3.large  │ │  │     │  │ │ t3.large  │ │  │
│  │ │ Single-AZ │ │  │     │  │ │ Single-AZ │ │  │     │  │ │ Multi-AZ  │ │  │
│  │ └───────────┘ │  │     │  │ └───────────┘ │  │     │  │ └───────────┘ │  │
│  │               │  │     │  │               │  │     │  │               │  │
│  │ ┌───────────┐ │  │     │  │ ┌───────────┐ │  │     │  │ ┌───────────┐ │  │
│  │ │    S3     │ │  │     │  │ │    S3     │ │  │     │  │ │    S3     │ │  │
│  │ │  Assets   │ │  │     │  │ │  Assets   │ │  │     │  │ │  Assets   │ │  │
│  │ └───────────┘ │  │     │  │ └───────────┘ │  │     │  │ └───────────┘ │  │
│  │               │  │     │  │               │  │     │  │               │  │
│  │ ┌───────────┐ │  │     │  │ ┌───────────┐ │  │     │  │ ┌───────────┐ │  │
│  │ │    ECR    │ │  │     │  │ │    ECR    │ │  │     │  │ │    ECR    │ │  │
│  │ │  Images   │ │  │     │  │ │  Images   │ │  │     │  │ │  Images   │ │  │
│  │ └───────────┘ │  │     │  │ └───────────┘ │  │     │  │ └───────────┘ │  │
│  │               │  │     │  │               │  │     │  │               │  │
│  └───────────────┘  │     │  └───────────────┘  │     │  └───────────────┘  │
│                     │     │                     │     │                     │
│  COST OPTIMIZATION: │     │  COST OPTIMIZATION: │     │  24/7 OPERATION:    │
│  - Scheduler ON     │     │  - Scheduler ON     │     │  - No scheduler     │
│  - Spot 20%         │     │  - Spot 20%         │     │  - No Spot          │
│  - Shutdown 20h BRT │     │  - Shutdown 20h BRT │     │  - Always ON        │
│                     │     │                     │     │                     │
└─────────────────────┘     └─────────────────────┘     └─────────────────────┘

         │                               │                               │
         │                               │                               │
         │     NO CROSS-ACCOUNT          │     COMPLETE                  │
         │     CONNECTIVITY              │     ISOLATION                 │
         │                               │                               │
         └───────────────────────────────┴───────────────────────────────┘
```

---

## 2. Account Details Summary

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                            THREE AWS ACCOUNTS - DETAILS                                  │
├─────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                          │
│  ┌─────────────────────────────────────────────────────────────────────────────────┐   │
│  │                              DEV ACCOUNT                                         │   │
│  ├─────────────────────────────────────────────────────────────────────────────────┤   │
│  │                                                                                  │   │
│  │  Account ID:     777777777771                                                    │   │
│  │  Region:         us-east-1 (N. Virginia)                                        │   │
│  │  Domain:         dev.gameplatform-dev.example.com                                               │   │
│  │                                                                                  │   │
│  │  RESOURCES:                                                                      │   │
│  │  ├── VPC:        project-dev-vpc (10.0.0.0/16)                                   │   │
│  │  ├── ALB:        project-dev-shared-alb                                          │   │
│  │  ├── ECS:        project-dev-shared-cluster                                      │   │
│  │  ├── RDS:        dev-postgres-postgres (db.t3.medium, Single-AZ)               │   │
│  │  ├── S3:         dev-gameplatform-server-software-dev                                 │   │
│  │  ├── ECR:        777777777771.dkr.ecr.us-east-1.amazonaws.com                  │   │
│  │  └── CloudWatch: /ecs/project-dev-*                                             │   │
│  │                                                                                  │   │
│  │  COMPUTE:                                                                        │   │
│  │    CPU:          512 units (0.5 vCPU) per task                                  │   │
│  │    Memory:       1024 MB per task                                               │   │
│  │    Spot:         20% (FARGATE_SPOT)                                             │   │
│  │                                                                                  │   │
│  │  COST CONTROLS:                                                                  │   │
│  │    Scheduler:    ON (shutdown 20:00 BRT, startup 06:00 BRT)                     │   │
│  │    Log retention: 3 days                                                        │   │
│  │                                                                                  │   │
│  └─────────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                          │
│  ┌─────────────────────────────────────────────────────────────────────────────────┐   │
│  │                              STG ACCOUNT                                         │   │
│  ├─────────────────────────────────────────────────────────────────────────────────┤   │
│  │                                                                                  │   │
│  │  Account ID:     777777777775                                                    │   │
│  │  Region:         us-east-1 (N. Virginia)                                        │   │
│  │  Domain:         stg-gameplatform.example.com                                               │   │
│  │                                                                                  │   │
│  │  RESOURCES:                                                                      │   │
│  │  ├── VPC:        project-stg-vpc (10.0.0.0/16)                                   │   │
│  │  ├── ALB:        project-stg-shared-alb                                          │   │
│  │  ├── ECS:        project-stg-shared-cluster                                      │   │
│  │  ├── RDS:        stg-postgres-postgres (db.t3.large, Single-AZ)                │   │
│  │  ├── S3:         stg-gameplatform-server-software-stg                                 │   │
│  │  ├── ECR:        777777777775.dkr.ecr.us-east-1.amazonaws.com                  │   │
│  │  └── CloudWatch: /ecs/project-stg-*                                             │   │
│  │                                                                                  │   │
│  │  COMPUTE:                                                                        │   │
│  │    CPU:          1024 units (1 vCPU) per task                                   │   │
│  │    Memory:       2048 MB per task                                               │   │
│  │    Spot:         20% (FARGATE_SPOT)                                             │   │
│  │                                                                                  │   │
│  │  COST CONTROLS:                                                                  │   │
│  │    Scheduler:    ON (shutdown 20:00 BRT, startup 06:00 BRT)                     │   │
│  │    Log retention: 14 days                                                       │   │
│  │                                                                                  │   │
│  └─────────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                          │
│  ┌─────────────────────────────────────────────────────────────────────────────────┐   │
│  │                              LIVE ACCOUNT (Production)                           │   │
│  ├─────────────────────────────────────────────────────────────────────────────────┤   │
│  │                                                                                  │   │
│  │  Account ID:     777777777772                                                    │   │
│  │  Region:         sa-east-1 (Sao Paulo, Brazil)                                  │   │
│  │  Domain:         gameplatform.example.com                                                   │   │
│  │                                                                                  │   │
│  │  RESOURCES:                                                                      │   │
│  │  ├── VPC:        project-live-vpc (10.0.0.0/16)                                  │   │
│  │  ├── ALB:        project-live-shared-alb                                         │   │
│  │  ├── ECS:        project-live-shared-cluster                                     │   │
│  │  ├── RDS:        live-postgres-postgres (db.t3.large, MULTI-AZ)                │   │
│  │  ├── S3:         live-gameplatform-server-software-live                               │   │
│  │  ├── ECR:        777777777772.dkr.ecr.sa-east-1.amazonaws.com                  │   │
│  │  └── CloudWatch: /ecs/project-live-*                                            │   │
│  │                                                                                  │   │
│  │  COMPUTE:                                                                        │   │
│  │    CPU:          1024 units (1 vCPU) per task                                   │   │
│  │    Memory:       2048 MB per task                                               │   │
│  │    Spot:         0% (reliability - FARGATE only)                                │   │
│  │                                                                                  │   │
│  │  PRODUCTION SETTINGS:                                                            │   │
│  │    Scheduler:    OFF (24/7 operation)                                           │   │
│  │    RDS Multi-AZ: YES (automatic failover)                                       │   │
│  │    Log retention: 30 days                                                       │   │
│  │                                                                                  │   │
│  └─────────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                          │
└─────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Single Account Architecture (Repeated per Account)

Each AWS account has an identical architecture structure. The diagram below represents
what exists in EACH of the 3 accounts (DEV, STG, LIVE):

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    ACCOUNT: {ACCOUNT_ID}                                     │
│                    REGION:  {REGION}                                         │
│                    DOMAIN:  {DOMAIN}                                         │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│                              INTERNET                                        │
│                                 │                                            │
│                    ┌────────────┴────────────┐                              │
│                    │                          │                              │
│           ┌────────▼────────┐       ┌────────▼────────┐                     │
│           │   Route 53      │       │   ACM           │                     │
│           │   DNS Service   │       │   Certificates  │                     │
│           │   {domain}      │       │   *.{domain}    │                     │
│           └────────┬────────┘       └────────┬────────┘                     │
│                    │                          │                              │
│                    └────────────┬─────────────┘                              │
│                                 │                                            │
│                    ┌────────────▼────────────┐                              │
│                    │   Application Load      │                              │
│                    │   Balancer (ALB)        │                              │
│                    │   Internet-facing       │                              │
│                    │   Ports: 80, 443,       │                              │
│                    │   7349, 7350, 7351      │                              │
│                    └────────────┬────────────┘                              │
│                                 │                                            │
│  ┌──────────────────────────────┴──────────────────────────────────┐       │
│  │                         VPC: 10.0.0.0/16                         │       │
│  ├──────────────────────────────────────────────────────────────────┤       │
│  │                                                                   │       │
│  │  ┌─────────────────────────────────────────────────────────┐    │       │
│  │  │                    PUBLIC SUBNETS                        │    │       │
│  │  │                    Route: 0.0.0.0/0 → IGW               │    │       │
│  │  ├───────────────────┬───────────────────┬─────────────────┤    │       │
│  │  │ PUBLIC SUBNET 1   │ PUBLIC SUBNET 2   │ PUBLIC SUBNET 3 │    │       │
│  │  │ 10.0.1.0/24       │ 10.0.2.0/24       │ 10.0.3.0/24     │    │       │
│  │  │ AZ: {region}a     │ AZ: {region}b     │ AZ: {region}c   │    │       │
│  │  │                   │                   │                  │    │       │
│  │  │ ┌─────────────┐   │ ┌─────────────┐   │ ┌─────────────┐  │    │       │
│  │  │ │ NAT Gateway │   │ │ NAT Gateway │   │ │ NAT Gateway │  │    │       │
│  │  │ │ + EIP       │   │ │ + EIP       │   │ │ + EIP       │  │    │       │
│  │  │ └─────────────┘   │ └─────────────┘   │ └─────────────┘  │    │       │
│  │  │                   │                   │                  │    │       │
│  │  │ ALB endpoints     │ ALB endpoints     │ ALB endpoints    │    │       │
│  │  └───────────────────┴───────────────────┴─────────────────┘    │       │
│  │                             │                                    │       │
│  │                             ▼                                    │       │
│  │  ┌─────────────────────────────────────────────────────────┐    │       │
│  │  │                    PRIVATE SUBNETS                       │    │       │
│  │  │                    Route: 0.0.0.0/0 → NAT GW            │    │       │
│  │  ├───────────────────┬───────────────────┬─────────────────┤    │       │
│  │  │ PRIVATE SUBNET 1  │ PRIVATE SUBNET 2  │ PRIVATE SUBNET 3│    │       │
│  │  │ 10.0.11.0/24      │ 10.0.12.0/24      │ 10.0.13.0/24    │    │       │
│  │  │ AZ: {region}a     │ AZ: {region}b     │ AZ: {region}c   │    │       │
│  │  │                   │                   │                  │    │       │
│  │  │ ┌───────────────┐ │ ┌───────────────┐ │ ┌──────────────┐ │    │       │
│  │  │ │ ECS Fargate   │ │ │ ECS Fargate   │ │ │ ECS Fargate  │ │    │       │
│  │  │ │ Tasks         │ │ │ Tasks         │ │ │ Tasks        │ │    │       │
│  │  │ │               │ │ │               │ │ │              │ │    │       │
│  │  │ │ - Nakama      │ │ │ - Nakama      │ │ │ - Nakama     │ │    │       │
│  │  │ │ - Lobby       │ │ │ - Lobby       │ │ │ - Lobby      │ │    │       │
│  │  │ │ - Backend     │ │ │ - Backend     │ │ │ - Backend    │ │    │       │
│  │  │ │ - AFS         │ │ │ - AFS         │ │ │ - AFS        │ │    │       │
│  │  │ │ - AIS         │ │ │ - AIS         │ │ │ - AIS        │ │    │       │
│  │  │ │ - AES         │ │ │ - AES         │ │ │ - AES        │ │    │       │
│  │  │ │ - APS         │ │ │ - APS         │ │ │ - APS        │ │    │       │
│  │  │ │ - AHSAT       │ │ │ - AHSAT       │ │ │ - AHSAT      │ │    │       │
│  │  │ └───────────────┘ │ └───────────────┘ │ └──────────────┘ │    │       │
│  │  │                   │                   │                  │    │       │
│  │  │ RDS Primary       │ RDS Standby       │                  │    │       │
│  │  │ (LIVE only)       │ (Multi-AZ)        │                  │    │       │
│  │  └───────────────────┴───────────────────┴─────────────────┘    │       │
│  │                                                                   │       │
│  └───────────────────────────────────────────────────────────────────┘       │
│                                 │                                            │
│                    ┌────────────┴────────────┐                              │
│                    │                          │                              │
│           ┌────────▼────────┐       ┌────────▼────────┐                     │
│           │  RDS PostgreSQL │       │   S3 Buckets    │                     │
│           │  Private Access │       │   Assets        │                     │
│           └─────────────────┘       └─────────────────┘                     │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 4. Security Groups (Per Account)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        SECURITY GROUPS (Per Account)                         │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  SG: gameplatform-{env}-alb-sg (ALB Security Group)                       │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │  INBOUND:                                                           │   │
│  │    80/tcp   ← 0.0.0.0/0    (HTTP - redirect to HTTPS)              │   │
│  │    443/tcp  ← 0.0.0.0/0    (HTTPS - main traffic)                  │   │
│  │    7349/tcp ← 0.0.0.0/0    (Nakama gRPC)                           │   │
│  │    7350/tcp ← 0.0.0.0/0    (Nakama HTTP API)                       │   │
│  │    7351/tcp ← 0.0.0.0/0    (Nakama Admin Console)                  │   │
│  │    1988/tcp ← 0.0.0.0/0    (AES - Email Service)                   │   │
│  │    6969/tcp ← 0.0.0.0/0    (AHSAT - Analytics)                     │   │
│  │    5050/tcp ← 0.0.0.0/0    (AIS - AI Service)                      │   │
│  │    4444/tcp ← 0.0.0.0/0    (APS - Payments)                        │   │
│  │    9933/tcp ← 0.0.0.0/0    (AFS - File Service)                    │   │
│  │  OUTBOUND:                                                          │   │
│  │    All      → VPC CIDR     (to ECS tasks)                          │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  SG: gameplatform-{env}-ecs-sg (ECS Tasks Security Group)                 │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │  INBOUND:                                                           │   │
│  │    All      ← ALB SG       (traffic from ALB)                      │   │
│  │    All      ← Self         (inter-task communication)              │   │
│  │  OUTBOUND:                                                          │   │
│  │    443/tcp  → 0.0.0.0/0    (HTTPS to internet via NAT)             │   │
│  │    5432/tcp → RDS SG       (PostgreSQL)                            │   │
│  │    587/tcp  → 0.0.0.0/0    (SMTP - AWS SES)                        │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  SG: gameplatform-{env}-rds-sg (RDS Security Group)                       │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │  INBOUND:                                                           │   │
│  │    5432/tcp ← ECS SG       (from ECS tasks only)                   │   │
│  │  OUTBOUND:                                                          │   │
│  │    None                    (database doesn't initiate)             │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 5. Load Balancing - ALB Configuration (Per Account)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│              APPLICATION LOAD BALANCER (Per Account)                         │
│              gameplatform-{env}-shared-alb                                         │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  TYPE: Application (Layer 7)                                                 │
│  SCHEME: Internet-facing                                                     │
│  SUBNETS: 3 Public subnets (HA across AZs)                                  │
│  SECURITY GROUP: gameplatform-{env}-alb-sg                                        │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                         LISTENERS                                    │   │
│  ├───────────┬────────────────────────────────────────────────────────┤   │
│  │ Port 80   │ HTTP  → Redirect to HTTPS (301)                        │   │
│  │ Port 443  │ HTTPS → Host-based routing to Target Groups           │   │
│  │ Port 7349 │ HTTPS → nakama target group (gRPC)                    │   │
│  │ Port 7350 │ HTTPS → nakama target group (HTTP API)                │   │
│  │ Port 7351 │ HTTPS → nakama target group (Console)                 │   │
│  └───────────┴────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    LISTENER RULES (Port 443)                         │   │
│  ├───────────┬────────────────────────────────────────────────────────┤   │
│  │ Priority  │ Host Header → Target Group                             │   │
│  ├───────────┼────────────────────────────────────────────────────────┤   │
│  │ 100       │ nakama.{domain} → gameplatform-{env}-nakama                 │   │
│  │ 200       │ lobby.{domain}  → gameplatform-{env}-lobby                  │   │
│  │           │ OR {domain} (apex)                                     │   │
│  │ 300       │ afs.{domain}    → gameplatform-{env}-afs                    │   │
│  │ 400       │ ahsat.{domain}  → gameplatform-{env}-ahsat                  │   │
│  │ 500       │ api.{domain}    → gameplatform-{env}-lobby-backend          │   │
│  │ 600       │ aes.{domain}    → gameplatform-{env}-aes                    │   │
│  │ 700       │ ais.{domain}    → gameplatform-{env}-ais                    │   │
│  │ 800       │ aps.{domain}    → gameplatform-{env}-aps                    │   │
│  │ Default   │ * → 404 (no match)                                     │   │
│  └───────────┴────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    DOMAINS BY ACCOUNT                                │   │
│  ├───────────────┬─────────────────────────────────────────────────────┤   │
│  │ DEV           │ nakama.dev.gameplatform-dev.example.com, lobby.dev.gameplatform-dev.example.com,   │   │
│  │ 777777777771  │ api.dev.gameplatform-dev.example.com, afs.dev.gameplatform-dev.example.com, etc.  │   │
│  ├───────────────┼─────────────────────────────────────────────────────┤   │
│  │ STG           │ nakama.stg-gameplatform.example.com, lobby.stg-gameplatform.example.com,   │   │
│  │ 777777777775  │ api.stg-gameplatform.example.com, afs.stg-gameplatform.example.com, etc.  │   │
│  ├───────────────┼─────────────────────────────────────────────────────┤   │
│  │ LIVE          │ nakama.gameplatform.example.com, app.gameplatform.example.com (lobby),    │   │
│  │ 777777777772  │ lobby-backend.gameplatform.example.com, afs.gameplatform.example.com, etc.│   │
│  └───────────────┴─────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    SSL/TLS CONFIGURATION                             │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │ Certificate: ACM Wildcard *.{domain_name}                           │   │
│  │ Policy (443): ELBSecurityPolicy-TLS-1-2-2017-01                    │   │
│  │ Policy (7349-51): ELBSecurityPolicy-TLS13-1-2-Res-2021-06         │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 6. ECS Infrastructure (Per Account)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    ECS CLUSTER (Per Account)                                 │
│                    gameplatform-{env}-shared-cluster                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  TYPE: Fargate (Serverless containers)                                       │
│  CONTAINER INSIGHTS: Enabled                                                 │
│  LOGGING: CloudWatch Logs                                                    │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    CAPACITY PROVIDERS BY ACCOUNT                     │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │                                                                      │   │
│  │  DEV (777777777771):              STG (777777777775):               │   │
│  │    FARGATE:       80% weight       FARGATE:       80% weight        │   │
│  │    FARGATE_SPOT:  20% weight       FARGATE_SPOT:  20% weight        │   │
│  │    Base: 1 task on FARGATE         Base: 1 task on FARGATE          │   │
│  │                                                                      │   │
│  │  LIVE (777777777772):                                               │   │
│  │    FARGATE:       100% weight (reliability)                         │   │
│  │    FARGATE_SPOT:  0% (disabled for production)                     │   │
│  │                                                                      │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    SERVICE DISCOVERY (AWS Cloud Map)                 │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │  Namespace: gameplatform-{env}.local (Private DNS)                        │   │
│  │  VPC: gameplatform-{env}-vpc                                              │   │
│  │  DNS TTL: 10 seconds                                                │   │
│  │  Routing: MULTIVALUE                                                │   │
│  │                                                                      │   │
│  │  Services registered:                                               │   │
│  │    nakama.gameplatform-{env}.local:7350                                  │   │
│  │    lobby.gameplatform-{env}.local:3000                                   │   │
│  │    lobby-backend.gameplatform-{env}.local:3001                           │   │
│  │    afs.gameplatform-{env}.local:9933                                     │   │
│  │    ahsat.gameplatform-{env}.local:6969                                   │   │
│  │    ais.gameplatform-{env}.local:5050                                     │   │
│  │    aes.gameplatform-{env}.local:1988                                     │   │
│  │    aps.gameplatform-{env}.local:4444                                     │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 7. 8 Microservices (Identical in All Accounts)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    8 MICROSERVICES (Per Account)                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌────────────────────┐  ┌────────────────────┐  ┌────────────────────┐    │
│  │ NAKAMA             │  │ LOBBY              │  │ LOBBY-BACKEND      │    │
│  │ Game Server        │  │ Frontend           │  │ API                │    │
│  ├────────────────────┤  ├────────────────────┤  ├────────────────────┤    │
│  │ Port: 7350 (HTTP)  │  │ Port: 3000         │  │ Port: 3001         │    │
│  │ Port: 7349 (gRPC)  │  │ Tech: Next.js 15   │  │ Tech: NestJS 11    │    │
│  │ Port: 7351 (Admin) │  │ Health: /          │  │ Health: /health    │    │
│  │ Tech: Go + Lua     │  │                    │  │                    │    │
│  │ Health: /healthchk │  │ Dependencies:      │  │ Dependencies:      │    │
│  │                    │  │  - lobby-backend   │  │  - RDS (nakama db) │    │
│  │ Dependencies:      │  │  - nakama          │  │  - Nakama          │    │
│  │  - RDS (nakama db) │  │                    │  │  - AES, AIS, AFS   │    │
│  └────────────────────┘  └────────────────────┘  └────────────────────┘    │
│                                                                              │
│  ┌────────────────────┐  ┌────────────────────┐  ┌────────────────────┐    │
│  │ AFS                │  │ AHSAT              │  │ AIS                │    │
│  │ Asset File Service │  │ Analytics          │  │ AI Image           │    │
│  ├────────────────────┤  ├────────────────────┤  ├────────────────────┤    │
│  │ Port: 9933         │  │ Port: 6969         │  │ Port: 5050         │    │
│  │ Tech: Go + Gin     │  │ Tech: Go + Gin     │  │ Tech: Python       │    │
│  │ Health: /ping      │  │ Health: /ping      │  │       FastAPI      │    │
│  │                    │  │                    │  │ Health: /health    │    │
│  │ Storage: S3        │  │ Dependencies:      │  │                    │    │
│  │ (AWS SDK)          │  │  - RDS (nakamatest)│  │ Storage: S3        │    │
│  │                    │  │  - Nakama          │  │ External: Piapi.ai │    │
│  └────────────────────┘  └────────────────────┘  └────────────────────┘    │
│                                                                              │
│  ┌────────────────────┐  ┌────────────────────┐                             │
│  │ AES                │  │ APS                │                             │
│  │ Email Service      │  │ Payment Service    │                             │
│  ├────────────────────┤  ├────────────────────┤                             │
│  │ Port: 1988         │  │ Port: 4444         │                             │
│  │ Tech: Python       │  │ Tech: Go + Gin     │                             │
│  │       FastAPI      │  │ Health: /v0/aps/   │                             │
│  │ Health: /health    │  │         ping       │                             │
│  │                    │  │                    │                             │
│  │ External:          │  │ External:          │                             │
│  │  - AWS SES (SMTP)  │  │  - Yuno Payments   │                             │
│  └────────────────────┘  └────────────────────┘                             │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    RESOURCE ALLOCATION BY ACCOUNT                    │   │
│  ├─────────────┬───────────────┬───────────────┬───────────────────────┤   │
│  │ Account     │ CPU (units)   │ Memory (MB)   │ Replicas              │   │
│  ├─────────────┼───────────────┼───────────────┼───────────────────────┤   │
│  │ DEV         │ 512 (0.5vCPU) │ 1024          │ 1 per service         │   │
│  │ STG         │ 1024 (1vCPU)  │ 2048          │ 1 per service         │   │
│  │ LIVE        │ 1024 (1vCPU)  │ 2048          │ 1 per service         │   │
│  │ (Nakama)    │ 2048 (2vCPU)  │ 4096          │ 1 (all envs)          │   │
│  └─────────────┴───────────────┴───────────────┴───────────────────────┘   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 8. Database - RDS PostgreSQL (Per Account)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    RDS POSTGRESQL (Per Account)                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  DEV ACCOUNT (777777777771)                                         │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │  Instance:        dev-postgres-postgres                             │   │
│  │  Instance Class:  db.t3.medium (2 vCPU, 4GB RAM)                   │   │
│  │  Multi-AZ:        NO (cost optimization)                           │   │
│  │  Storage:         gp3 SSD, 20GB                                    │   │
│  │  Region:          us-east-1                                         │   │
│  │  Endpoint:        dev-postgres-postgres.xxx.us-east-1.rds.amazon.. │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  STG ACCOUNT (777777777775)                                         │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │  Instance:        stg-postgres-postgres                             │   │
│  │  Instance Class:  db.t3.large (2 vCPU, 8GB RAM)                    │   │
│  │  Multi-AZ:        NO (cost optimization)                           │   │
│  │  Storage:         gp3 SSD, 50GB                                    │   │
│  │  Region:          us-east-1                                         │   │
│  │  Endpoint:        stg-postgres-postgres.xxx.us-east-1.rds.amazon.. │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  LIVE ACCOUNT (777777777772)                                        │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │  Instance:        live-postgres-postgres                            │   │
│  │  Instance Class:  db.t3.large (2 vCPU, 8GB RAM)                    │   │
│  │  Multi-AZ:        YES (automatic failover for HA)                  │   │
│  │  Storage:         gp3 SSD, 100GB                                   │   │
│  │  Region:          sa-east-1 (Sao Paulo)                            │   │
│  │  Endpoint:        live-postgres-postgres.xxx.sa-east-1.rds.amazon..│   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  COMMON CONFIGURATION (All Accounts)                                │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │  Engine:          PostgreSQL 13+                                   │   │
│  │  Encryption:      Yes (AWS managed KMS)                            │   │
│  │  Public Access:   No (Private VPC only)                            │   │
│  │                                                                      │   │
│  │  DATABASES:                                                        │   │
│  │    nakama       - Main Nakama database (users, sessions)          │   │
│  │    nakamatest   - Services database (lobby-backend, ahsat)        │   │
│  │    postgres     - System database                                  │   │
│  │                                                                      │   │
│  │  USERS:                                                            │   │
│  │    postgres     - Admin user (AWS managed)                         │   │
│  │    nakama       - Application user (all services)                  │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 9. Storage - S3 Buckets (Per Account)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    S3 BUCKETS (Per Account)                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  DEV ACCOUNT (777777777771)                                         │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │  Assets:         dev-gameplatform-server-software-dev                     │   │
│  │  ALB Logs:       project-dev-alb-access-logs-{random}               │   │
│  │  Region:         us-east-1                                          │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  STG ACCOUNT (777777777775)                                         │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │  Assets:         stg-gameplatform-server-software-stg                     │   │
│  │  ALB Logs:       project-stg-alb-access-logs-{random}               │   │
│  │  Region:         us-east-1                                          │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  LIVE ACCOUNT (777777777772)                                        │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │  Assets:         live-gameplatform-server-software-live                   │   │
│  │  ALB Logs:       project-live-alb-access-logs-{random}              │   │
│  │  Region:         sa-east-1                                          │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  COMMON CONFIGURATION                                               │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │  Access:         ECS Task Role (IAM)                                │   │
│  │  Versioning:     Disabled (cost optimization)                       │   │
│  │  Encryption:     AES-256 (server-side)                             │   │
│  │                                                                      │   │
│  │  Used by:                                                           │   │
│  │    - AFS (upload/download assets via AWS SDK)                      │   │
│  │    - AIS (store generated images via AWS SDK)                      │   │
│  │                                                                      │   │
│  │  Structure:                                                         │   │
│  │    /users/{user_id}/avatars/                                        │   │
│  │    /users/{user_id}/assets/                                         │   │
│  │    /worlds/{world_id}/                                              │   │
│  │    /generations/{job_id}/                                           │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 10. Container Registry - ECR (Per Account)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    ECR CONTAINER REGISTRY (Per Account)                      │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  REGISTRY URLS                                                       │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │                                                                      │   │
│  │  DEV:   777777777771.dkr.ecr.us-east-1.amazonaws.com               │   │
│  │  STG:   777777777775.dkr.ecr.us-east-1.amazonaws.com               │   │
│  │  LIVE:  777777777772.dkr.ecr.sa-east-1.amazonaws.com               │   │
│  │                                                                      │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  REPOSITORIES (Same in each account)                                │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │                                                                      │   │
│  │  - gameplatform-nakama                                                    │   │
│  │  - gameplatform-lobby                                                     │   │
│  │  - gameplatform-lobby-backend                                             │   │
│  │  - gameplatform-afs                                                       │   │
│  │  - gameplatform-ahsat                                                     │   │
│  │  - gameplatform-ais                                                       │   │
│  │  - gameplatform-aes                                                       │   │
│  │  - gameplatform-aps                                                       │   │
│  │                                                                      │   │
│  │  IMAGE TAGGING:                                                     │   │
│  │    Format: {service}:{environment}-{version}.{build}               │   │
│  │    Example: gameplatform-nakama:dev-1.1.5.6                              │   │
│  │    Example: gameplatform-lobby:live-1.1.7.42                             │   │
│  │                                                                      │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 11. Service Communication

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    SERVICE COMMUNICATION (Per Account)                       │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  INTERNAL (VPC - via AWS Cloud Map Service Discovery)                       │
│  ─────────────────────────────────────────────────────                      │
│                                                                              │
│  ┌────────────┐     HTTP 7350      ┌────────────┐                           │
│  │ Lobby      │ ─────────────────▶ │ Nakama     │                           │
│  │ Backend    │                    │            │                           │
│  └────────────┘                    └────────────┘                           │
│        │                                  │                                  │
│        │ HTTP 6969                        │ TCP 5432                        │
│        ▼                                  ▼                                  │
│  ┌────────────┐                    ┌────────────┐                           │
│  │ AHSAT      │                    │ RDS        │                           │
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
│        ▼                                  ▼                                  │
│  ┌────────────┐                    ┌────────────┐                           │
│  │ S3 Bucket  │                    │ S3 Bucket  │                           │
│  │ (Assets)   │                    │ (Assets)   │                           │
│  └────────────┘                    └────────────┘                           │
│                                                                              │
│                                                                              │
│  EXTERNAL (Internet - via NAT Gateway)                                       │
│  ─────────────────────────────────────                                      │
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
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 12. Cost Optimization - Scheduler (DEV & STG Only)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    COST OPTIMIZATION - SCHEDULER                             │
│                    (DEV & STG ACCOUNTS ONLY)                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    EVENTBRIDGE + LAMBDA                              │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │                                                                      │   │
│  │  SCHEDULE (BRT timezone):                                           │   │
│  │    Shutdown: 20:00 BRT (23:00 UTC) Mon-Fri                         │   │
│  │    Startup:  06:00 BRT (09:00 UTC) Mon-Fri                         │   │
│  │                                                                      │   │
│  │  COMPONENTS CONTROLLED:                                             │   │
│  │    - ECS services (desired_count → 0 on shutdown)                   │   │
│  │    - RDS instances (optional stop)                                  │   │
│  │                                                                      │   │
│  │  FLOW:                                                              │   │
│  │    EventBridge Rule → Lambda Function → ECS UpdateService          │   │
│  │                                                                      │   │
│  │  SAVINGS:                                                           │   │
│  │    ~50% cost reduction on dev/stg (workday shutdown)               │   │
│  │                                                                      │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    FARGATE SPOT USAGE                                │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │                                                                      │   │
│  │  DEV (777777777771):                                                │   │
│  │    FARGATE:       80% weight                                        │   │
│  │    FARGATE_SPOT:  20% weight (~70% cheaper)                        │   │
│  │                                                                      │   │
│  │  STG (777777777775):                                                │   │
│  │    FARGATE:       80% weight                                        │   │
│  │    FARGATE_SPOT:  20% weight (~70% cheaper)                        │   │
│  │                                                                      │   │
│  │  LIVE (777777777772):                                               │   │
│  │    FARGATE:       100% weight (NO SPOT - reliability)              │   │
│  │    FARGATE_SPOT:  0%                                                │   │
│  │                                                                      │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 13. CI/CD Pipeline

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    CI/CD PIPELINE                                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    DEPLOYMENT FLOW                                   │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │                                                                      │   │
│  │  1. Developer pushes code to GitHub                                 │   │
│  │            │                                                         │   │
│  │            ▼                                                         │   │
│  │  2. GitHub Actions builds Docker image                              │   │
│  │            │                                                         │   │
│  │            ▼                                                         │   │
│  │  3. Image pushed to ECR (account-specific)                          │   │
│  │       DEV  → 777777777771.dkr.ecr.us-east-1.amazonaws.com          │   │
│  │       STG  → 777777777775.dkr.ecr.us-east-1.amazonaws.com          │   │
│  │       LIVE → 777777777772.dkr.ecr.sa-east-1.amazonaws.com          │   │
│  │            │                                                         │   │
│  │            ▼                                                         │   │
│  │  4. Terraform updates ECS task definition                           │   │
│  │            │                                                         │   │
│  │            ▼                                                         │   │
│  │  5. ECS service performs rolling deployment                         │   │
│  │            │                                                         │   │
│  │            ▼                                                         │   │
│  │  6. Health checks verify new tasks                                  │   │
│  │            │                                                         │   │
│  │            ▼                                                         │   │
│  │  7. Old tasks drained and terminated                                │   │
│  │                                                                      │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    NO CROSS-ACCOUNT DEPLOYMENT                       │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │                                                                      │   │
│  │  Each environment has:                                              │   │
│  │    - Its own AWS account                                            │   │
│  │    - Its own ECR registry                                           │   │
│  │    - Its own ECS cluster                                            │   │
│  │    - Its own GitHub Actions workflow credentials                    │   │
│  │                                                                      │   │
│  │  NO image promotion between accounts                                │   │
│  │  Each build targets a specific account                              │   │
│  │                                                                      │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 14. IAM Roles (Per Account)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    IAM ROLES (Per Account)                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  ECS TASK EXECUTION ROLE                                             │   │
│  │  gameplatform-{env}-execution-role                                         │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │  Trust: ecs-tasks.amazonaws.com                                     │   │
│  │                                                                      │   │
│  │  Policies:                                                          │   │
│  │    - AmazonECSTaskExecutionRolePolicy (AWS Managed)                 │   │
│  │      - ecr:GetAuthorizationToken                                    │   │
│  │      - ecr:BatchGetImage                                            │   │
│  │      - ecr:GetDownloadUrlForLayer                                   │   │
│  │      - logs:CreateLogStream                                         │   │
│  │      - logs:PutLogEvents                                            │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  ECS TASK ROLE                                                       │   │
│  │  gameplatform-{env}-task-role                                              │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │  Trust: ecs-tasks.amazonaws.com                                     │   │
│  │                                                                      │   │
│  │  Policies:                                                          │   │
│  │    - S3 Full Access:                                                │   │
│  │      - s3:*                                                         │   │
│  │      - s3:ListAllMyBuckets                                          │   │
│  │      - s3:GetBucketLocation                                         │   │
│  │      - s3:CreateBucket                                              │   │
│  │                                                                      │   │
│  │    - ECS Exec (for debugging):                                      │   │
│  │      - ssmmessages:CreateControlChannel                             │   │
│  │      - ssmmessages:CreateDataChannel                                │   │
│  │      - ssmmessages:OpenControlChannel                               │   │
│  │      - ssmmessages:OpenDataChannel                                  │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  GITHUB ACTIONS ROLE (OIDC)                                          │   │
│  │  GitHubActionsRole                                                   │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │  Trust: token.actions.githubusercontent.com (OIDC)                  │   │
│  │                                                                      │   │
│  │  Policies:                                                          │   │
│  │    - ECR push/pull                                                  │   │
│  │    - ECS task definition update                                     │   │
│  │    - ECS service update                                             │   │
│  │    - S3 access (for deployments)                                    │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 15. Summary - Key Points

### Account Isolation
- **3 completely separate AWS accounts** - NO cross-account access
- Each account has its own VPC, ALB, ECS, RDS, S3, ECR
- Different regions: DEV/STG in us-east-1, LIVE in sa-east-1

### Key Differences by Account

| Aspect | DEV | STG | LIVE |
|--------|-----|-----|------|
| Account ID | 777777777771 | 777777777775 | 777777777772 |
| Region | us-east-1 | us-east-1 | sa-east-1 |
| Domain | dev.gameplatform-dev.example.com | stg-gameplatform.example.com | gameplatform.example.com |
| CPU | 0.5 vCPU | 1 vCPU | 1 vCPU |
| Memory | 1GB | 2GB | 2GB |
| RDS | t3.medium, Single-AZ | t3.large, Single-AZ | t3.large, Multi-AZ |
| Spot | 20% | 20% | 0% |
| Scheduler | ON | ON | OFF |
| Log retention | 3 days | 14 days | 30 days |

### Components (Same in Each Account)
- 1 VPC (10.0.0.0/16)
- 3 Public subnets + 3 Private subnets
- 3 NAT Gateways (one per AZ)
- 1 ALB (Internet-facing)
- 1 ECS Fargate Cluster
- 8 ECS Services (microservices)
- 1 RDS PostgreSQL instance
- S3 buckets (assets + logs)
- ECR repositories (8 images)
- CloudWatch log groups

### Limitations (Why Migrated to GCP)
- No shared infrastructure (cost inefficiency)
- No GitOps (manual deployments)
- No Kubernetes features (limited scheduling)
- Region lock (LIVE in sa-east-1 only)
- Cost at scale (Fargate pricing)

---

*End of AWS Architecture Documentation*
