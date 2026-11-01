# Ephemeral Environments - Implementation Plan

**Document Version:** 2.0
**Created:** 2026-01-29
**Updated:** 2026-01-30
**Status:** DRAFT - Awaiting Review

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Requirements Analysis](#2-requirements-analysis)
3. [Architecture Overview](#3-architecture-overview)
4. [Resource Specifications](#4-resource-specifications)
5. [Database Strategy](#5-database-strategy)
6. [Network & Communication](#6-network--communication)
7. [CI/CD Pipeline Design](#7-cicd-pipeline-design)
8. [ArgoCD Integration](#8-argocd-integration)
9. [Lifecycle Management](#9-lifecycle-management)
10. [Implementation Phases](#10-implementation-phases)
11. [File Changes Summary](#11-file-changes-summary)
12. [Risk Assessment](#12-risk-assessment)
13. [References & Sources](#13-references--sources)

---

## 1. Executive Summary

This document outlines the complete implementation plan for ephemeral environments in the GamePlatform platform. Ephemeral environments are short-lived, isolated Kubernetes namespaces created automatically when a developer opens a Pull Request from an `eph-*` branch to `development`.

### Key Features
- **Automatic creation** on PR open (eph-* → development)
- **Automatic destruction** on PR merge/close
- **8-hour TTL** with reset on each commit
- **VPN-only access** via nonprod WireGuard (Internal LoadBalancer IPs)
- **Database restoration** from weekly DEV dump (`nakamatest` database)
- **PR comments** with environment details and access IPs
- **Recreatable** via `/deploy-eph` PR comment
- **Auto-update** on each commit to the PR branch

### Infrastructure Impact
- **Cluster:** project-dev-workloads (existing)
- **Resources:** ~700m CPU, ~1.75 GiB RAM per environment (reduced specs)
- **Storage:** New GCS bucket for database dumps
- **Isolation:** Complete - no shared resources with dev/stg/prd
- **Network:** Internal LoadBalancer services accessible via VPN

---

## 2. Requirements Analysis

### 2.1 Original Directives Mapping

| # | Directive | Solution |
|---|-----------|----------|
| 1 | Isolated pipelines | New workflow files: `ephemeral-deploy.yml`, `ephemeral-destroy.yml` |
| 2 | DEV configs as base | Copy DEV env files with namespace substitution |
| 3 | Minimum resources | Reduced CPU/memory limits (see Section 4) |
| 4 | Dynamic namespace | `gameplatform-eph-{pr-number}` created/deleted by workflow |
| 5 | Weekly DB dump | GitHub Actions scheduled workflow to GCS |
| 6 | IP-based communication | Internal LoadBalancer services (VPC IPs via VPN) |
| 7 | PostgreSQL pod | StatefulSet with init container for dump restore |
| 8 | PR trigger | `pull_request` event with branch filter |
| 9 | PR comment with info | Workflow step posts comment with IPs |
| 10 | Auto-update on commit | `synchronize` event triggers rebuild + TTL reset |
| 11 | VPN-only access | Internal LoadBalancer (no external ingress) |
| 12 | 8h TTL + reset | Hourly cleanup workflow; annotation updated on deploy |
| 13 | Destroy on merge/close | `closed` event triggers destroy workflow |
| 14 | Recreation via comment | `issue_comment` event with `/deploy-eph` trigger |
| 15 | Command TBD | Defined as `/deploy-eph` |

### 2.2 Out of Scope
- Public DNS/Ingress for ephemeral environments
- Production data (only DEV dump is used)
- Persistent storage beyond database
- Custom SSL certificates
- Concurrent environment limits (unlimited for now)

### 2.3 Technical Discoveries

During analysis, the following was verified:

1. **Single Database:** All services use ONE database: `nakamatest`
   - Services using DB: nakama, lobby-backend, afs, ahsat, ais
   - Services NOT using DB: aes, aps

2. **Lobby Runtime Config:** The `lobby` service uses server-side runtime config injection (`window.__RUNTIME_CONFIG__`), NOT build-time embedded variables. This means `NEXT_PUBLIC_*` variables work correctly with ConfigMaps at runtime.

3. **Service Types:** Current Helm charts use `ClusterIP` which is NOT accessible via VPN. Changed to `Internal LoadBalancer` for ephemeral environments.

---

## 3. Architecture Overview

### 3.1 High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           GitHub Repository                              │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────────────────────┐  │
│  │  eph-*      │───▶│ development │    │ Workflows:                  │  │
│  │  branch     │ PR │   branch    │    │ - ephemeral-deploy.yml      │  │
│  └─────────────┘    └─────────────┘    │ - ephemeral-destroy.yml     │  │
│                                        │ - ephemeral-db-dump.yml     │  │
│                                        │ - ephemeral-ttl-cleanup.yml │  │
│                                        └─────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                     GKE: project-dev-workloads                           │
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────────────────┐ │
│  │  gameplatform-dev    │  │ gameplatform-eph-123 │  │ gameplatform-eph-456             │ │
│  │  (permanent)   │  │ (PR #123)      │  │ (PR #456)                  │ │
│  │                │  │                │  │                            │ │
│  │  - 8 services  │  │  - 8 services  │  │  - 8 services              │ │
│  │  - Cloud SQL   │  │  - PG pod      │  │  - PG pod                  │ │
│  │  - ClusterIP   │  │  - Internal LB │  │  - Internal LB             │ │
│  └────────────────┘  └────────────────┘  └────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                    VPN Access (10.116.x.x IPs)
                                    │
┌─────────────────────────────────────────────────────────────────────────┐
│                          GCS Bucket                                      │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │  gs://gameplatform-ephemeral-db-dumps/                                │    │
│  │  ├── latest.sql.gz          (weekly dump of nakamatest)        │    │
│  │  ├── 2026-01-29.sql.gz      (archived dumps)                   │    │
│  │  └── ...                                                        │    │
│  └─────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────┘
```

### 3.2 Component Interaction

```
PR Opened/Commit Pushed (eph-* → development)
        │
        ▼
┌───────────────────┐
│ ephemeral-deploy  │
│    workflow       │
└───────┬───────────┘
        │
        ├──▶ 1. Create namespace: gameplatform-eph-{PR#}
        │
        ├──▶ 2. Deploy PostgreSQL StatefulSet
        │       └──▶ Init container downloads & restores nakamatest dump
        │
        ├──▶ 3. Wait for PostgreSQL ready
        │
        ├──▶ 4. Create ExternalSecrets (copy from DEV)
        │
        ├──▶ 5. Wait for ExternalSecrets to sync (loop check)
        │
        ├──▶ 6. Generate ConfigMaps (from DEV env files + substitution)
        │
        ├──▶ 7. Build & push images with tag: eph-{PR#}-{SHA}
        │
        ├──▶ 8. Deploy services via Helm (Internal LoadBalancer)
        │
        ├──▶ 9. Wait for all pods ready
        │
        ├──▶ 10. Wait for LoadBalancer IPs assigned
        │
        ├──▶ 11. Update ConfigMaps with actual IPs
        │
        ├──▶ 12. Restart pods to pick up new ConfigMaps
        │
        ├──▶ 13. Reset TTL annotation
        │
        └──▶ 14. Post PR comment with environment info
```

### 3.3 Auto-Update Flow (on commit)

When a new commit is pushed to the `eph-*` branch:

1. GitHub triggers `pull_request` event with action `synchronize`
2. Workflow `ephemeral-deploy.yml` runs again
3. New images built with tag `eph-{PR#}-{new-SHA}`
4. `helm upgrade` updates deployments with new image
5. TTL annotation is reset (extends lifetime by 8 hours)
6. New PR comment posted with update confirmation

---

## 4. Resource Specifications

### 4.1 DEV Environment Baseline (Current)

| Service | CPU Request | CPU Limit | Memory Request | Memory Limit |
|---------|-------------|-----------|----------------|--------------|
| aes | 100m | 500m | 256Mi | 512Mi |
| afs | 100m | 500m | 256Mi | 512Mi |
| ahsat | 100m | 500m | 256Mi | 512Mi |
| ais | 250m | 1000m | 512Mi | 1Gi |
| aps | 100m | 500m | 256Mi | 512Mi |
| lobby | 200m | 1000m | 512Mi | 1Gi |
| lobby-backend | 200m | 1000m | 512Mi | 1Gi |
| nakama | 200m | 1000m | 512Mi | 1Gi |
| **TOTAL** | **1.25 cores** | **6 cores** | **3 GiB** | **6.5 GiB** |

### 4.2 Ephemeral Environment Specs (Reduced)

| Service | CPU Request | CPU Limit | Memory Request | Memory Limit |
|---------|-------------|-----------|----------------|--------------|
| aes | 50m | 250m | 128Mi | 256Mi |
| afs | 50m | 250m | 128Mi | 256Mi |
| ahsat | 50m | 250m | 128Mi | 256Mi |
| ais | 100m | 500m | 256Mi | 512Mi |
| aps | 50m | 250m | 128Mi | 256Mi |
| lobby | 100m | 500m | 256Mi | 512Mi |
| lobby-backend | 100m | 500m | 256Mi | 512Mi |
| nakama | 100m | 500m | 256Mi | 512Mi |
| postgresql | 100m | 500m | 256Mi | 512Mi |
| **TOTAL** | **700m** | **3.5 cores** | **1.75 GiB** | **3.5 GiB** |

### 4.3 Cluster Capacity

With the current node pool configuration:
- Node type: e2-standard-4 (4 vCPU, 16 GiB)
- Node count: 3 nodes
- Available capacity: ~10 vCPU, ~40 GiB (after system overhead)

No concurrent environment limit is enforced. The cluster will autoscale if needed.

---

## 5. Database Strategy

### 5.1 Database Configuration

**Single Database:** All services share the `nakamatest` database.

| Service | Uses Database | Database Name |
|---------|---------------|---------------|
| nakama | Yes | nakamatest |
| lobby-backend | Yes | nakamatest |
| afs | Yes | nakamatest |
| ahsat | Yes | nakamatest |
| ais | Yes | nakamatest |
| aes | No | - |
| aps | No | - |

### 5.2 Weekly Dump Automation

```yaml
# .github/workflows/ephemeral-db-dump.yml
name: Weekly DEV Database Dump

on:
  schedule:
    - cron: '0 3 * * 0'  # Every Sunday at 3 AM UTC
  workflow_dispatch:      # Manual trigger

jobs:
  dump:
    runs-on: [self-hosted, linux, gcp, light]
    steps:
      - name: Authenticate to GCP
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ secrets.GCP_WORKLOAD_IDENTITY_PROVIDER }}
          service_account: ${{ secrets.GCP_SERVICE_ACCOUNT }}

      - name: Get Cloud SQL credentials
        id: creds
        run: |
          gcloud secrets versions access latest \
            --secret="project-dev-postgres-credentials" \
            --project="project-nonprod-env" > /tmp/db-creds.json

          echo "DB_HOST=$(jq -r '.host' /tmp/db-creds.json)" >> $GITHUB_OUTPUT
          echo "DB_USER=$(jq -r '.user' /tmp/db-creds.json)" >> $GITHUB_OUTPUT
          echo "DB_PASS=$(jq -r '.password' /tmp/db-creds.json)" >> $GITHUB_OUTPUT
          rm /tmp/db-creds.json

      - name: Dump nakamatest database
        env:
          PGPASSWORD: ${{ steps.creds.outputs.DB_PASS }}
        run: |
          DUMP_DATE=$(date +%Y-%m-%d)

          pg_dump \
            -h ${{ steps.creds.outputs.DB_HOST }} \
            -U ${{ steps.creds.outputs.DB_USER }} \
            -d nakamatest \
            --no-owner \
            --no-privileges \
            | gzip > /tmp/nakamatest.sql.gz

          echo "Dump size: $(du -h /tmp/nakamatest.sql.gz | cut -f1)"

      - name: Upload to GCS
        run: |
          DUMP_DATE=$(date +%Y-%m-%d)

          # Upload dated dump
          gsutil cp /tmp/nakamatest.sql.gz \
            gs://gameplatform-ephemeral-db-dumps/${DUMP_DATE}.sql.gz

          # Update latest
          gsutil cp /tmp/nakamatest.sql.gz \
            gs://gameplatform-ephemeral-db-dumps/latest.sql.gz

          echo "Uploaded to gs://gameplatform-ephemeral-db-dumps/${DUMP_DATE}.sql.gz"
          echo "Updated gs://gameplatform-ephemeral-db-dumps/latest.sql.gz"

      - name: Cleanup old dumps (keep 4 weeks)
        run: |
          # List all dumps, sort by date, keep only last 4
          gsutil ls gs://gameplatform-ephemeral-db-dumps/*.sql.gz 2>/dev/null | \
            grep -v latest.sql.gz | \
            sort -r | \
            tail -n +5 | \
            xargs -r gsutil rm || true
```

### 5.3 PostgreSQL Pod with Dump Restore

```yaml
# charts/ephemeral-postgres/templates/statefulset.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: {{ .Release.Name }}-postgres
  namespace: {{ .Release.Namespace }}
spec:
  serviceName: {{ .Release.Name }}-postgres
  replicas: 1
  selector:
    matchLabels:
      app: postgres
      instance: {{ .Release.Name }}
  template:
    metadata:
      labels:
        app: postgres
        instance: {{ .Release.Name }}
    spec:
      serviceAccountName: {{ .Release.Name }}-postgres
      initContainers:
        - name: download-and-restore
          image: google/cloud-sdk:slim
          command:
            - /bin/bash
            - -c
            - |
              set -e
              echo "Downloading dump from GCS..."
              gsutil cp gs://{{ .Values.dumpBucket }}/{{ .Values.dumpFile }} /dump/dump.sql.gz
              echo "Download complete: $(ls -lh /dump/dump.sql.gz)"

              echo "Extracting dump..."
              gunzip -c /dump/dump.sql.gz > /docker-entrypoint-initdb.d/01-restore.sql
              echo "Extraction complete: $(ls -lh /docker-entrypoint-initdb.d/01-restore.sql)"
          volumeMounts:
            - name: dump-volume
              mountPath: /dump
            - name: initdb
              mountPath: /docker-entrypoint-initdb.d
      containers:
        - name: postgres
          image: postgres:15
          ports:
            - containerPort: 5432
          env:
            - name: POSTGRES_USER
              value: "{{ .Values.postgresUser }}"
            - name: POSTGRES_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: {{ .Release.Name }}-postgres-credentials
                  key: password
            - name: POSTGRES_DB
              value: "nakamatest"
          volumeMounts:
            - name: initdb
              mountPath: /docker-entrypoint-initdb.d
            - name: data
              mountPath: /var/lib/postgresql/data
          resources:
            requests:
              cpu: {{ .Values.resources.requests.cpu }}
              memory: {{ .Values.resources.requests.memory }}
            limits:
              cpu: {{ .Values.resources.limits.cpu }}
              memory: {{ .Values.resources.limits.memory }}
          readinessProbe:
            exec:
              command:
                - pg_isready
                - -U
                - {{ .Values.postgresUser }}
                - -d
                - nakamatest
            initialDelaySeconds: 5
            periodSeconds: 5
          livenessProbe:
            exec:
              command:
                - pg_isready
                - -U
                - {{ .Values.postgresUser }}
                - -d
                - nakamatest
            initialDelaySeconds: 30
            periodSeconds: 10
      volumes:
        - name: dump-volume
          emptyDir: {}
        - name: initdb
          emptyDir: {}
  volumeClaimTemplates:
    - metadata:
        name: data
      spec:
        accessModes: ["ReadWriteOnce"]
        resources:
          requests:
            storage: {{ .Values.storage.size }}
```

### 5.4 GCS Bucket Configuration

**Terraform addition to `nonprod/06-workloads/ephemeral-bucket.tf`:**

```hcl
resource "google_storage_bucket" "ephemeral_db_dumps" {
  name          = "gameplatform-ephemeral-db-dumps"
  project       = var.project_id
  location      = "US-EAST1"
  force_destroy = true

  uniform_bucket_level_access = true

  lifecycle_rule {
    condition {
      age = 30  # Delete dumps older than 30 days
    }
    action {
      type = "Delete"
    }
  }

  labels = {
    environment = "nonprod"
    purpose     = "ephemeral-environments"
  }
}

resource "google_storage_bucket_iam_member" "ephemeral_db_dumps_writer" {
  bucket = google_storage_bucket.ephemeral_db_dumps.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${var.github_actions_service_account}"
}

# Allow ephemeral workloads to read dumps
resource "google_storage_bucket_iam_member" "ephemeral_db_dumps_reader" {
  bucket = google_storage_bucket.ephemeral_db_dumps.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:project-dev-ais@project-nonprod-env.iam.gserviceaccount.com"
}
```

---

## 6. Network & Communication

### 6.1 Service Discovery

Within Kubernetes, services communicate via DNS:
```
{service-name}.{namespace}.svc.cluster.local
```

For ephemeral environments:
```
game-platform-eph-{PR#}-lobby.gameplatform-eph-{PR#}.svc.cluster.local
```

### 6.2 VPN Access via Internal LoadBalancer

**Key Change:** Ephemeral environments use `LoadBalancer` type with Internal annotation instead of `ClusterIP`.

This allocates IPs from the VPC subnet (`10.116.0.0/20`) which are accessible via VPN.

```yaml
# Service configuration for ephemeral environments
apiVersion: v1
kind: Service
metadata:
  name: game-platform-eph-123-lobby
  annotations:
    networking.gke.io/load-balancer-type: "Internal"
spec:
  type: LoadBalancer
  ports:
    - port: 3000
  selector:
    app: lobby
```

**Result:** Each service gets a VPC IP like `10.116.1.15` that developers can access directly from VPN.

### 6.3 Environment Variables Transformation

**Original (DEV):**
```bash
LOBBY_BACKEND_HOST=game-platform-dev-lobby-backend.gameplatform-dev.svc.cluster.local
AFS_HOST=game-platform-dev-afs.gameplatform-dev.svc.cluster.local
DB_HOST=10.148.0.3  # Cloud SQL
```

**Transformed (Ephemeral):**
```bash
LOBBY_BACKEND_HOST=game-platform-eph-123-lobby-backend.gameplatform-eph-123.svc.cluster.local
AFS_HOST=game-platform-eph-123-afs.gameplatform-eph-123.svc.cluster.local
DB_HOST=game-platform-eph-123-postgres.gameplatform-eph-123.svc.cluster.local
```

### 6.4 Browser-Facing URLs

**For variables accessed by browser (NEXT_PUBLIC_*):**

After LoadBalancer IPs are assigned, ConfigMaps are updated with actual IPs:

```bash
NEXT_PUBLIC_LOBBY_BACKEND=http://10.116.1.20:3001
NEXT_PUBLIC_AFS_HOST=http://10.116.1.21:9933
```

The `lobby` service uses runtime config injection (`window.__RUNTIME_CONFIG__`), so these values are read from `process.env` at request time, NOT embedded at build time.

### 6.5 ConfigMap Generation Script

```bash
#!/bin/bash
# scripts/generate-ephemeral-configmaps.sh

set -e

PR_NUMBER=$1
NAMESPACE="gameplatform-eph-${PR_NUMBER}"
SOURCE_ENV="dev"

echo "Generating ConfigMaps for ephemeral environment PR #${PR_NUMBER}"

for SERVICE in aes afs ahsat ais aps lobby lobby-backend nakama; do
  SOURCE_FILE="environment-variables/${SOURCE_ENV}/${SERVICE}.env"

  if [ ! -f "$SOURCE_FILE" ]; then
    echo "Warning: $SOURCE_FILE not found, skipping"
    continue
  fi

  echo "Processing ${SERVICE}..."

  # Read and transform
  > "/tmp/${SERVICE}.env"
  while IFS= read -r line || [ -n "$line" ]; do
    # Skip empty lines and comments
    [[ -z "$line" || "$line" =~ ^# ]] && continue

    # Replace dev namespace references with ephemeral namespace
    transformed=$(echo "$line" | \
      sed "s/gameplatform-dev/gameplatform-eph-${PR_NUMBER}/g" | \
      sed "s/game-platform-dev/game-platform-eph-${PR_NUMBER}/g")

    echo "$transformed" >> "/tmp/${SERVICE}.env"
  done < "$SOURCE_FILE"

  # Special handling for DB_HOST - point to PostgreSQL pod
  if grep -q "^DB_HOST=" "/tmp/${SERVICE}.env"; then
    sed -i "s|^DB_HOST=.*|DB_HOST=game-platform-eph-${PR_NUMBER}-postgres.gameplatform-eph-${PR_NUMBER}.svc.cluster.local|" "/tmp/${SERVICE}.env"
  fi

  # Create ConfigMap
  kubectl create configmap ${SERVICE}-config \
    --namespace=${NAMESPACE} \
    --from-env-file=/tmp/${SERVICE}.env \
    --dry-run=client -o yaml | kubectl apply -f -

  echo "Created ConfigMap ${SERVICE}-config"
done

echo "ConfigMap generation complete"
```

### 6.6 Update ConfigMaps with LoadBalancer IPs

After services are deployed, a second pass updates browser-facing URLs:

```bash
#!/bin/bash
# scripts/update-ephemeral-ips.sh

set -e

PR_NUMBER=$1
NAMESPACE="gameplatform-eph-${PR_NUMBER}"

echo "Waiting for LoadBalancer IPs..."

# Wait and collect IPs
declare -A SERVICE_IPS

for SERVICE in lobby lobby-backend afs nakama; do
  SVC_NAME="game-platform-eph-${PR_NUMBER}-${SERVICE}"

  echo "Waiting for ${SVC_NAME} IP..."
  for i in {1..60}; do
    IP=$(kubectl get svc ${SVC_NAME} -n ${NAMESPACE} -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
    if [ -n "$IP" ] && [ "$IP" != "null" ]; then
      SERVICE_IPS[$SERVICE]=$IP
      echo "  ${SERVICE}: ${IP}"
      break
    fi
    sleep 5
  done

  if [ -z "${SERVICE_IPS[$SERVICE]}" ]; then
    echo "Error: Failed to get IP for ${SVC_NAME}"
    exit 1
  fi
done

# Update lobby ConfigMap with browser-facing URLs
echo "Updating lobby ConfigMap with LoadBalancer IPs..."

kubectl get configmap lobby-config -n ${NAMESPACE} -o yaml > /tmp/lobby-config.yaml

# Update NEXT_PUBLIC_* values
sed -i "s|NEXT_PUBLIC_LOBBY_BACKEND=.*|NEXT_PUBLIC_LOBBY_BACKEND=http://${SERVICE_IPS[lobby-backend]}:3001|" /tmp/lobby-config.yaml
sed -i "s|NEXT_PUBLIC_AFS_HOST=.*|NEXT_PUBLIC_AFS_HOST=http://${SERVICE_IPS[afs]}:9933|" /tmp/lobby-config.yaml

kubectl apply -f /tmp/lobby-config.yaml

echo "ConfigMaps updated with LoadBalancer IPs"

# Output IPs for PR comment
echo "LOBBY_IP=${SERVICE_IPS[lobby]}" >> $GITHUB_OUTPUT
echo "LOBBY_BACKEND_IP=${SERVICE_IPS[lobby-backend]}" >> $GITHUB_OUTPUT
echo "AFS_IP=${SERVICE_IPS[afs]}" >> $GITHUB_OUTPUT
echo "NAKAMA_IP=${SERVICE_IPS[nakama]}" >> $GITHUB_OUTPUT
```

---

## 7. CI/CD Pipeline Design

### 7.1 Workflow: ephemeral-deploy.yml

```yaml
# .github/workflows/ephemeral-deploy.yml
name: Deploy Ephemeral Environment

on:
  pull_request:
    types: [opened, synchronize, reopened]
    branches:
      - development
  issue_comment:
    types: [created]

concurrency:
  group: ephemeral-${{ github.event.pull_request.number || github.event.issue.number }}
  cancel-in-progress: false

jobs:
  check-trigger:
    runs-on: ubuntu-latest
    outputs:
      should_deploy: ${{ steps.check.outputs.should_deploy }}
      pr_number: ${{ steps.check.outputs.pr_number }}
      branch_name: ${{ steps.check.outputs.branch_name }}
      commit_sha: ${{ steps.check.outputs.commit_sha }}
    steps:
      - name: Check trigger conditions
        id: check
        uses: actions/github-script@v7
        with:
          script: |
            const isPR = context.eventName === 'pull_request';
            const isComment = context.eventName === 'issue_comment';

            let shouldDeploy = false;
            let prNumber = '';
            let branchName = '';
            let commitSha = '';

            if (isPR) {
              branchName = context.payload.pull_request.head.ref;
              prNumber = context.payload.pull_request.number.toString();
              commitSha = context.payload.pull_request.head.sha.substring(0, 7);

              if (branchName.startsWith('eph-')) {
                shouldDeploy = true;
              }
            } else if (isComment) {
              const comment = context.payload.comment.body.trim();

              if (comment === '/deploy-eph') {
                const issue = context.payload.issue;

                if (issue.pull_request) {
                  const { data: pr } = await github.rest.pulls.get({
                    owner: context.repo.owner,
                    repo: context.repo.repo,
                    pull_number: issue.number
                  });

                  branchName = pr.head.ref;
                  prNumber = issue.number.toString();
                  commitSha = pr.head.sha.substring(0, 7);

                  if (branchName.startsWith('eph-')) {
                    shouldDeploy = true;
                  }
                }
              }
            }

            core.setOutput('should_deploy', shouldDeploy.toString());
            core.setOutput('pr_number', prNumber);
            core.setOutput('branch_name', branchName);
            core.setOutput('commit_sha', commitSha);

  deploy:
    needs: check-trigger
    if: needs.check-trigger.outputs.should_deploy == 'true'
    runs-on: [self-hosted, linux, gcp, heavy]
    env:
      PR_NUMBER: ${{ needs.check-trigger.outputs.pr_number }}
      BRANCH_NAME: ${{ needs.check-trigger.outputs.branch_name }}
      COMMIT_SHA: ${{ needs.check-trigger.outputs.commit_sha }}
      NAMESPACE: gameplatform-eph-${{ needs.check-trigger.outputs.pr_number }}
      IMAGE_TAG: eph-${{ needs.check-trigger.outputs.pr_number }}-${{ needs.check-trigger.outputs.commit_sha }}

    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        with:
          ref: ${{ env.BRANCH_NAME }}

      - name: Authenticate to GCP
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ secrets.GCP_WORKLOAD_IDENTITY_PROVIDER }}
          service_account: ${{ secrets.GCP_SERVICE_ACCOUNT }}

      - name: Setup GKE credentials
        uses: google-github-actions/get-gke-credentials@v2
        with:
          cluster_name: project-dev-workloads
          location: us-east1

      - name: Create namespace
        run: |
          kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

          # Add labels and annotations
          kubectl label namespace $NAMESPACE \
            ephemeral.gameplatform.io/pr-number="${PR_NUMBER}" \
            ephemeral.gameplatform.io/managed-by="github-actions" \
            --overwrite

          kubectl annotate namespace $NAMESPACE \
            ephemeral.gameplatform.io/created-at="$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
            ephemeral.gameplatform.io/ttl="8h" \
            ephemeral.gameplatform.io/branch="${BRANCH_NAME}" \
            ephemeral.gameplatform.io/commit="${COMMIT_SHA}" \
            --overwrite

      - name: Create service account for Workload Identity
        run: |
          kubectl apply -f - <<EOF
          apiVersion: v1
          kind: ServiceAccount
          metadata:
            name: ephemeral-workload
            namespace: $NAMESPACE
            annotations:
              iam.gke.io/gcp-service-account: project-dev-ais@project-nonprod-env.iam.gserviceaccount.com
          ---
          apiVersion: v1
          kind: ServiceAccount
          metadata:
            name: game-platform-eph-${PR_NUMBER}-postgres
            namespace: $NAMESPACE
            annotations:
              iam.gke.io/gcp-service-account: project-dev-ais@project-nonprod-env.iam.gserviceaccount.com
          EOF

      - name: Create PostgreSQL credentials secret
        run: |
          # Generate random password
          DB_PASSWORD=$(openssl rand -base64 24 | tr -d '/+=' | head -c 24)

          kubectl create secret generic game-platform-eph-${PR_NUMBER}-postgres-credentials \
            --namespace=$NAMESPACE \
            --from-literal=password="${DB_PASSWORD}" \
            --from-literal=user="gameplatform" \
            --dry-run=client -o yaml | kubectl apply -f -

      - name: Deploy PostgreSQL with dump restore
        run: |
          helm upgrade --install game-platform-eph-${PR_NUMBER}-postgres \
            ./charts/ephemeral-postgres \
            --namespace $NAMESPACE \
            --set dumpBucket="gameplatform-ephemeral-db-dumps" \
            --set dumpFile="latest.sql.gz" \
            --set postgresUser="gameplatform" \
            --set storage.size="5Gi" \
            --set resources.requests.cpu="100m" \
            --set resources.requests.memory="256Mi" \
            --set resources.limits.cpu="500m" \
            --set resources.limits.memory="512Mi" \
            --wait --timeout=10m

      - name: Wait for PostgreSQL ready
        run: |
          echo "Waiting for PostgreSQL to be ready..."
          kubectl wait --for=condition=ready pod \
            -l app=postgres,instance=game-platform-eph-${PR_NUMBER}-postgres \
            --namespace=$NAMESPACE \
            --timeout=300s
          echo "PostgreSQL is ready"

      - name: Create ExternalSecrets
        run: |
          # Copy ExternalSecret definitions from dev, adjusting namespace
          for SECRET in piapi-key gemini-api-key; do
            if kubectl get externalsecret project-dev-${SECRET} -n gameplatform-dev &>/dev/null; then
              kubectl get externalsecret project-dev-${SECRET} -n gameplatform-dev -o yaml | \
                sed "s/namespace: gameplatform-dev/namespace: ${NAMESPACE}/g" | \
                sed "s/name: project-dev-/name: gameplatform-eph-${PR_NUMBER}-/g" | \
                kubectl apply -f -
              echo "Created ExternalSecret gameplatform-eph-${PR_NUMBER}-${SECRET}"
            fi
          done

      - name: Wait for ExternalSecrets to sync
        run: |
          echo "Waiting for ExternalSecrets to sync..."

          MAX_ATTEMPTS=30
          ATTEMPT=0

          while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
            ALL_READY=true

            for SECRET in piapi-key gemini-api-key; do
              ES_NAME="gameplatform-eph-${PR_NUMBER}-${SECRET}"

              if kubectl get externalsecret ${ES_NAME} -n ${NAMESPACE} &>/dev/null; then
                STATUS=$(kubectl get externalsecret ${ES_NAME} -n ${NAMESPACE} -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "Unknown")

                if [ "$STATUS" != "True" ]; then
                  ALL_READY=false
                  echo "  ${ES_NAME}: Not ready (status: ${STATUS})"
                else
                  echo "  ${ES_NAME}: Ready"
                fi
              fi
            done

            if [ "$ALL_READY" = true ]; then
              echo "All ExternalSecrets are ready"
              break
            fi

            ATTEMPT=$((ATTEMPT + 1))
            echo "Attempt ${ATTEMPT}/${MAX_ATTEMPTS} - waiting 10s..."
            sleep 10
          done

          if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
            echo "Warning: Some ExternalSecrets may not be ready, continuing anyway"
          fi

      - name: Generate ConfigMaps
        run: |
          chmod +x ./scripts/generate-ephemeral-configmaps.sh
          ./scripts/generate-ephemeral-configmaps.sh $PR_NUMBER

      - name: Build and push images
        run: |
          for SERVICE in aes afs ahsat ais aps lobby lobby-backend nakama; do
            echo "Building ${SERVICE}..."

            docker build \
              -t us-east1-docker.pkg.dev/project-nonprod-env/project-dev-images/${SERVICE}:${IMAGE_TAG} \
              -f applications/${SERVICE}/Dockerfile \
              applications/${SERVICE}/

            docker push us-east1-docker.pkg.dev/project-nonprod-env/project-dev-images/${SERVICE}:${IMAGE_TAG}

            echo "Pushed ${SERVICE}:${IMAGE_TAG}"
          done

      - name: Deploy services via Helm
        run: |
          helm upgrade --install game-platform-eph-${PR_NUMBER} ./charts/game-platform \
            --namespace $NAMESPACE \
            --set global.environment=eph \
            --set global.imageTag=${IMAGE_TAG} \
            --set global.imagePullPolicy=Always \
            --set global.releasePrefix="game-platform-eph-${PR_NUMBER}" \
            \
            --set aes.enabled=true \
            --set aes.service.type=LoadBalancer \
            --set 'aes.service.annotations.networking\.gke\.io/load-balancer-type=Internal' \
            --set aes.resources.requests.cpu=50m \
            --set aes.resources.requests.memory=128Mi \
            --set aes.resources.limits.cpu=250m \
            --set aes.resources.limits.memory=256Mi \
            \
            --set afs.enabled=true \
            --set afs.service.type=LoadBalancer \
            --set 'afs.service.annotations.networking\.gke\.io/load-balancer-type=Internal' \
            --set afs.resources.requests.cpu=50m \
            --set afs.resources.requests.memory=128Mi \
            --set afs.resources.limits.cpu=250m \
            --set afs.resources.limits.memory=256Mi \
            \
            --set ahsat.enabled=true \
            --set ahsat.service.type=LoadBalancer \
            --set 'ahsat.service.annotations.networking\.gke\.io/load-balancer-type=Internal' \
            --set ahsat.resources.requests.cpu=50m \
            --set ahsat.resources.requests.memory=128Mi \
            --set ahsat.resources.limits.cpu=250m \
            --set ahsat.resources.limits.memory=256Mi \
            \
            --set ais.enabled=true \
            --set ais.service.type=LoadBalancer \
            --set 'ais.service.annotations.networking\.gke\.io/load-balancer-type=Internal' \
            --set ais.resources.requests.cpu=100m \
            --set ais.resources.requests.memory=256Mi \
            --set ais.resources.limits.cpu=500m \
            --set ais.resources.limits.memory=512Mi \
            \
            --set aps.enabled=true \
            --set aps.service.type=LoadBalancer \
            --set 'aps.service.annotations.networking\.gke\.io/load-balancer-type=Internal' \
            --set aps.resources.requests.cpu=50m \
            --set aps.resources.requests.memory=128Mi \
            --set aps.resources.limits.cpu=250m \
            --set aps.resources.limits.memory=256Mi \
            \
            --set lobby.enabled=true \
            --set lobby.service.type=LoadBalancer \
            --set 'lobby.service.annotations.networking\.gke\.io/load-balancer-type=Internal' \
            --set lobby.resources.requests.cpu=100m \
            --set lobby.resources.requests.memory=256Mi \
            --set lobby.resources.limits.cpu=500m \
            --set lobby.resources.limits.memory=512Mi \
            \
            --set lobby-backend.enabled=true \
            --set lobby-backend.service.type=LoadBalancer \
            --set 'lobby-backend.service.annotations.networking\.gke\.io/load-balancer-type=Internal' \
            --set lobby-backend.resources.requests.cpu=100m \
            --set lobby-backend.resources.requests.memory=256Mi \
            --set lobby-backend.resources.limits.cpu=500m \
            --set lobby-backend.resources.limits.memory=512Mi \
            \
            --set nakama.enabled=true \
            --set nakama.service.type=LoadBalancer \
            --set 'nakama.service.annotations.networking\.gke\.io/load-balancer-type=Internal' \
            --set nakama.resources.requests.cpu=100m \
            --set nakama.resources.requests.memory=256Mi \
            --set nakama.resources.limits.cpu=500m \
            --set nakama.resources.limits.memory=512Mi \
            \
            --wait --timeout=15m

      - name: Wait for pods ready
        run: |
          echo "Waiting for all pods to be ready..."
          kubectl wait --for=condition=ready pod \
            --selector=app.kubernetes.io/instance=game-platform-eph-${PR_NUMBER} \
            --namespace=$NAMESPACE \
            --timeout=300s
          echo "All pods are ready"

      - name: Wait for LoadBalancer IPs and update ConfigMaps
        id: collect-ips
        run: |
          chmod +x ./scripts/update-ephemeral-ips.sh
          ./scripts/update-ephemeral-ips.sh $PR_NUMBER

      - name: Restart lobby to pick up new ConfigMap
        run: |
          kubectl rollout restart deployment/game-platform-eph-${PR_NUMBER}-lobby -n $NAMESPACE
          kubectl rollout status deployment/game-platform-eph-${PR_NUMBER}-lobby -n $NAMESPACE --timeout=120s

      - name: Collect all service info
        id: service-info
        run: |
          echo "## Service Information" > /tmp/env-info.md
          echo "" >> /tmp/env-info.md
          echo "| Service | IP | Port |" >> /tmp/env-info.md
          echo "|---------|-----|------|" >> /tmp/env-info.md

          for SERVICE in aes afs ahsat ais aps lobby lobby-backend nakama postgres; do
            SVC_NAME="game-platform-eph-${PR_NUMBER}-${SERVICE}"

            if [ "$SERVICE" = "postgres" ]; then
              IP=$(kubectl get svc ${SVC_NAME} -n $NAMESPACE -o jsonpath='{.spec.clusterIP}' 2>/dev/null || echo "N/A")
            else
              IP=$(kubectl get svc ${SVC_NAME} -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "N/A")
            fi

            PORT=$(kubectl get svc ${SVC_NAME} -n $NAMESPACE -o jsonpath='{.spec.ports[0].port}' 2>/dev/null || echo "N/A")
            echo "| ${SERVICE} | ${IP} | ${PORT} |" >> /tmp/env-info.md
          done

          # Store lobby IP for comment
          LOBBY_IP=$(kubectl get svc game-platform-eph-${PR_NUMBER}-lobby -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
          echo "lobby_ip=${LOBBY_IP}" >> $GITHUB_OUTPUT

      - name: Post PR comment
        uses: actions/github-script@v7
        env:
          LOBBY_IP: ${{ steps.service-info.outputs.lobby_ip }}
        with:
          script: |
            const fs = require('fs');
            const envInfo = fs.readFileSync('/tmp/env-info.md', 'utf8');
            const isUpdate = context.eventName === 'pull_request' && context.payload.action === 'synchronize';

            const comment = `## ${isUpdate ? '🔄 Ephemeral Environment Updated' : '🚀 Ephemeral Environment Deployed'}

            **Namespace:** \`${process.env.NAMESPACE}\`
            **Branch:** \`${process.env.BRANCH_NAME}\`
            **Commit:** \`${process.env.COMMIT_SHA}\`
            **Image Tag:** \`${process.env.IMAGE_TAG}\`

            ### 🌐 Access

            **Lobby URL:** http://${process.env.LOBBY_IP}:3000

            > ⚠️ Connect to **nonprod VPN** first!

            ${envInfo}

            ### 📋 Useful Commands

            \`\`\`bash
            # Get all pods
            kubectl get pods -n ${process.env.NAMESPACE}

            # View logs
            kubectl logs -n ${process.env.NAMESPACE} -l app.kubernetes.io/name=lobby -f

            # Get all services
            kubectl get svc -n ${process.env.NAMESPACE}
            \`\`\`

            ### ⏰ TTL

            This environment will be automatically destroyed in **8 hours**.
            Each commit resets the TTL.

            **Commands:**
            - \`/deploy-eph\` - Recreate environment
            - \`/destroy-eph\` - Destroy environment
            `;

            await github.rest.issues.createComment({
              owner: context.repo.owner,
              repo: context.repo.repo,
              issue_number: parseInt(process.env.PR_NUMBER),
              body: comment
            });
```

### 7.2 Workflow: ephemeral-destroy.yml

```yaml
# .github/workflows/ephemeral-destroy.yml
name: Destroy Ephemeral Environment

on:
  pull_request:
    types: [closed]
    branches:
      - development
  issue_comment:
    types: [created]

jobs:
  check-trigger:
    runs-on: ubuntu-latest
    outputs:
      should_destroy: ${{ steps.check.outputs.should_destroy }}
      pr_number: ${{ steps.check.outputs.pr_number }}
    steps:
      - name: Check trigger conditions
        id: check
        uses: actions/github-script@v7
        with:
          script: |
            const isPR = context.eventName === 'pull_request';
            const isComment = context.eventName === 'issue_comment';

            let shouldDestroy = false;
            let prNumber = '';

            if (isPR && context.payload.action === 'closed') {
              const branchName = context.payload.pull_request.head.ref;
              prNumber = context.payload.pull_request.number.toString();

              if (branchName.startsWith('eph-')) {
                shouldDestroy = true;
              }
            } else if (isComment) {
              const comment = context.payload.comment.body.trim();

              if (comment === '/destroy-eph') {
                const issue = context.payload.issue;

                if (issue.pull_request) {
                  const { data: pr } = await github.rest.pulls.get({
                    owner: context.repo.owner,
                    repo: context.repo.repo,
                    pull_number: issue.number
                  });

                  if (pr.head.ref.startsWith('eph-')) {
                    shouldDestroy = true;
                    prNumber = issue.number.toString();
                  }
                }
              }
            }

            core.setOutput('should_destroy', shouldDestroy.toString());
            core.setOutput('pr_number', prNumber);

  destroy:
    needs: check-trigger
    if: needs.check-trigger.outputs.should_destroy == 'true'
    runs-on: [self-hosted, linux, gcp, light]
    env:
      PR_NUMBER: ${{ needs.check-trigger.outputs.pr_number }}
      NAMESPACE: gameplatform-eph-${{ needs.check-trigger.outputs.pr_number }}

    steps:
      - name: Authenticate to GCP
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ secrets.GCP_WORKLOAD_IDENTITY_PROVIDER }}
          service_account: ${{ secrets.GCP_SERVICE_ACCOUNT }}

      - name: Setup GKE credentials
        uses: google-github-actions/get-gke-credentials@v2
        with:
          cluster_name: project-dev-workloads
          location: us-east1

      - name: Delete namespace
        run: |
          if kubectl get namespace $NAMESPACE &>/dev/null; then
            echo "Deleting namespace $NAMESPACE..."
            kubectl delete namespace $NAMESPACE --wait=true --timeout=5m
            echo "Namespace $NAMESPACE deleted"
          else
            echo "Namespace $NAMESPACE does not exist"
          fi

      - name: Post PR comment
        uses: actions/github-script@v7
        with:
          script: |
            const comment = `## 🗑️ Ephemeral Environment Destroyed

            **Namespace:** \`${process.env.NAMESPACE}\`
            **Reason:** ${context.eventName === 'pull_request' ? 'PR closed/merged' : 'Manual (/destroy-eph)'}

            Use \`/deploy-eph\` to recreate the environment.
            `;

            await github.rest.issues.createComment({
              owner: context.repo.owner,
              repo: context.repo.repo,
              issue_number: parseInt(process.env.PR_NUMBER),
              body: comment
            });
```

### 7.3 Workflow: ephemeral-ttl-cleanup.yml

```yaml
# .github/workflows/ephemeral-ttl-cleanup.yml
name: Cleanup Expired Ephemeral Environments

on:
  schedule:
    - cron: '0 * * * *'  # Every hour
  workflow_dispatch:

jobs:
  cleanup:
    runs-on: [self-hosted, linux, gcp, light]
    steps:
      - name: Checkout (for gh CLI)
        uses: actions/checkout@v4

      - name: Authenticate to GCP
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ secrets.GCP_WORKLOAD_IDENTITY_PROVIDER }}
          service_account: ${{ secrets.GCP_SERVICE_ACCOUNT }}

      - name: Setup GKE credentials
        uses: google-github-actions/get-gke-credentials@v2
        with:
          cluster_name: project-dev-workloads
          location: us-east1

      - name: Cleanup expired environments
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          TTL_SECONDS=$((8 * 3600))  # 8 hours in seconds
          NOW=$(date +%s)

          echo "Checking for expired ephemeral environments..."
          echo "Current time: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
          echo "TTL: 8 hours"
          echo ""

          # Get all ephemeral namespaces by label
          NAMESPACES=$(kubectl get namespaces -l ephemeral.gameplatform.io/managed-by=github-actions -o name 2>/dev/null || true)

          if [ -z "$NAMESPACES" ]; then
            echo "No ephemeral environments found"
            exit 0
          fi

          for NS in $NAMESPACES; do
            NAMESPACE=$(echo $NS | cut -d'/' -f2)
            echo "Checking ${NAMESPACE}..."

            CREATED_AT=$(kubectl get namespace $NAMESPACE -o jsonpath='{.metadata.annotations.ephemeral\.gameplatform\.io/created-at}' 2>/dev/null || true)
            PR_NUMBER=$(kubectl get namespace $NAMESPACE -o jsonpath='{.metadata.labels.ephemeral\.gameplatform\.io/pr-number}' 2>/dev/null || true)

            if [ -z "$CREATED_AT" ]; then
              echo "  Warning: No created-at annotation, skipping"
              continue
            fi

            # Parse ISO 8601 date
            CREATED_TS=$(date -d "$CREATED_AT" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%SZ" "$CREATED_AT" +%s 2>/dev/null || echo "0")

            if [ "$CREATED_TS" = "0" ]; then
              echo "  Warning: Could not parse date, skipping"
              continue
            fi

            AGE_SECONDS=$((NOW - CREATED_TS))
            AGE_HOURS=$((AGE_SECONDS / 3600))
            AGE_MINUTES=$(((AGE_SECONDS % 3600) / 60))

            echo "  Created: ${CREATED_AT}"
            echo "  Age: ${AGE_HOURS}h ${AGE_MINUTES}m"
            echo "  PR: #${PR_NUMBER}"

            if [ $AGE_SECONDS -ge $TTL_SECONDS ]; then
              echo "  Status: EXPIRED - Deleting..."

              kubectl delete namespace $NAMESPACE --wait=false

              if [ -n "$PR_NUMBER" ]; then
                gh pr comment $PR_NUMBER --body "## ⏰ Ephemeral Environment Expired

**Namespace:** \`$NAMESPACE\`
**Age:** ${AGE_HOURS}h ${AGE_MINUTES}m (TTL: 8h)

The environment was automatically destroyed due to TTL expiration.

Use \`/deploy-eph\` to recreate the environment." || true
              fi

              echo "  Deleted!"
            else
              REMAINING=$((TTL_SECONDS - AGE_SECONDS))
              REMAINING_HOURS=$((REMAINING / 3600))
              REMAINING_MINUTES=$(((REMAINING % 3600) / 60))
              echo "  Status: Active - ${REMAINING_HOURS}h ${REMAINING_MINUTES}m remaining"
            fi

            echo ""
          done

          echo "Cleanup complete"
```

---

## 8. ArgoCD Integration

### 8.1 Current Architecture (App-of-Apps)

The current setup uses App-of-Apps pattern:
```
argocd/
├── bootstrap/
│   └── app-of-apps-dev.yaml      # Bootstrap app
├── dev/
│   └── application-dev.yaml      # Main platform app
```

### 8.2 Ephemeral Environment Strategy

**Decision: Do NOT use ArgoCD for ephemeral environments**

Reasons:
1. Ephemeral environments are short-lived (8h TTL)
2. ArgoCD sync introduces delay and complexity
3. Direct `helm upgrade` is faster for PR workflows
4. No need for GitOps reconciliation for temporary resources
5. Environment must update on EVERY commit, not just config changes

### 8.3 How Auto-Updates Work Without ArgoCD

When a developer pushes a new commit to the `eph-*` branch:

1. **GitHub Event:** `pull_request` with action `synchronize`
2. **Workflow Trigger:** `ephemeral-deploy.yml` runs
3. **Image Build:** New images built with unique tag `eph-{PR#}-{new-SHA}`
4. **Helm Upgrade:** Updates deployments with new image tag
5. **Rolling Update:** Kubernetes performs rolling update of pods
6. **TTL Reset:** Annotation `created-at` is updated to current time
7. **PR Comment:** New comment posted with update confirmation

This provides the same "push-to-update" experience as ArgoCD but with:
- Faster feedback (no sync delay)
- TTL reset on every commit
- Explicit image tagging per commit

### 8.4 Future Consideration: ApplicationSet

If ephemeral environments need ArgoCD in the future, use ApplicationSet with Pull Request Generator:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: ephemeral-environments
  namespace: argocd
spec:
  generators:
    - pullRequest:
        github:
          owner: gameplatformlabs
          repo: gameplatform-monorepo
          tokenRef:
            secretName: github-token
            key: token
        filters:
          - branchMatch: "^eph-.*"
  template:
    metadata:
      name: 'eph-{{number}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/gameplatformlabs/platform-kubernetes-infrastructure.git
        targetRevision: development
        path: charts/game-platform
        helm:
          values: |
            global:
              environment: eph
              imageTag: eph-{{number}}-{{head_sha}}
      destination:
        server: https://kubernetes.default.svc
        namespace: 'gameplatform-eph-{{number}}'
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
```

---

## 9. Lifecycle Management

### 9.1 State Diagram

```
                    PR Opened (eph-* → development)
                              │
                              ▼
                    ┌─────────────────┐
                    │    DEPLOYING    │
                    └────────┬────────┘
                             │
              Deploy Success │
                             ▼
    ┌──────────────────────────────────────────┐
    │                 RUNNING                   │
    │                                          │
    │  TTL: 8h (resets on each commit)         │
    │                                          │
    │  Events:                                 │
    │  - synchronize (commit) → UPDATING       │
    │  - /destroy-eph → DESTROYING             │
    │  - TTL expired → DESTROYING              │
    │  - PR closed/merged → DESTROYING         │
    └─────────────────────┬────────────────────┘
                          │
          ┌───────────────┼───────────────┐
          │               │               │
          ▼               ▼               ▼
    ┌───────────┐   ┌───────────┐   ┌───────────┐
    │  UPDATING │   │DESTROYING │   │  EXPIRED  │
    └─────┬─────┘   └─────┬─────┘   └─────┬─────┘
          │               │               │
          │               └───────┬───────┘
          │                       │
          ▼                       ▼
    ┌───────────┐           ┌───────────┐
    │  RUNNING  │           │ DESTROYED │
    │(TTL reset)│           │           │
    └───────────┘           │/deploy-eph│──▶ DEPLOYING
                            │ recreates │
                            └───────────┘
```

### 9.2 TTL Reset Logic

In `ephemeral-deploy.yml`, the TTL annotation is updated on every deployment (initial or update):

```yaml
kubectl annotate namespace $NAMESPACE \
  ephemeral.gameplatform.io/created-at="$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --overwrite
```

This means:
- Initial deploy: TTL = 8 hours from creation
- Each commit: TTL resets to 8 hours from that commit
- No activity for 8 hours: Environment is destroyed

### 9.3 Namespace Labels and Annotations

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: gameplatform-eph-123
  labels:
    ephemeral.gameplatform.io/pr-number: "123"           # For filtering
    ephemeral.gameplatform.io/managed-by: "github-actions"
  annotations:
    ephemeral.gameplatform.io/created-at: "2026-01-29T10:00:00Z"  # TTL reference
    ephemeral.gameplatform.io/ttl: "8h"
    ephemeral.gameplatform.io/branch: "eph-feature-xyz"
    ephemeral.gameplatform.io/commit: "abc1234"
```

---

## 10. Implementation Phases

### Phase 1: Infrastructure Setup
- [ ] Create GCS bucket `gameplatform-ephemeral-db-dumps` (Terraform)
- [ ] Create Helm chart `ephemeral-postgres`
- [ ] Create `scripts/generate-ephemeral-configmaps.sh`
- [ ] Create `scripts/update-ephemeral-ips.sh`

### Phase 2: Database Dump Automation
- [ ] Create `ephemeral-db-dump.yml` workflow
- [ ] Run manual trigger to create first dump
- [ ] Verify dump file in GCS bucket

### Phase 3: Deploy Pipeline
- [ ] Create `ephemeral-deploy.yml` workflow
- [ ] Create `ephemeral-destroy.yml` workflow
- [ ] Test with sample `eph-test` branch and PR

### Phase 4: Lifecycle Management
- [ ] Create `ephemeral-ttl-cleanup.yml` workflow
- [ ] Test TTL reset on commit
- [ ] Test `/deploy-eph` and `/destroy-eph` commands
- [ ] Test PR close/merge triggers destroy

### Phase 5: Documentation & Rollout
- [ ] Update developer documentation
- [ ] Create branch naming guidelines (`eph-*` convention)
- [ ] Announce to team
- [ ] Monitor first real usage

---

## 11. File Changes Summary

### 11.1 New Files to Create

| Repository | File | Purpose |
|------------|------|---------|
| gameplatform-monorepo | `.github/workflows/ephemeral-deploy.yml` | Deploy workflow |
| gameplatform-monorepo | `.github/workflows/ephemeral-destroy.yml` | Destroy workflow |
| gameplatform-monorepo | `.github/workflows/ephemeral-db-dump.yml` | Weekly DB dump |
| gameplatform-monorepo | `.github/workflows/ephemeral-ttl-cleanup.yml` | TTL cleanup |
| gameplatform-monorepo | `scripts/generate-ephemeral-configmaps.sh` | ConfigMap generator |
| gameplatform-monorepo | `scripts/update-ephemeral-ips.sh` | IP collector & ConfigMap updater |
| platform-kubernetes-infrastructure | `charts/ephemeral-postgres/Chart.yaml` | Helm chart metadata |
| platform-kubernetes-infrastructure | `charts/ephemeral-postgres/values.yaml` | Default values |
| platform-kubernetes-infrastructure | `charts/ephemeral-postgres/templates/statefulset.yaml` | PG StatefulSet |
| platform-kubernetes-infrastructure | `charts/ephemeral-postgres/templates/service.yaml` | PG Service |
| platform-kubernetes-infrastructure | `charts/ephemeral-postgres/templates/serviceaccount.yaml` | Workload Identity SA |
| gameplatform-shared-infrastructure-gcp | `nonprod/06-workloads/ephemeral-bucket.tf` | GCS bucket |

### 11.2 Files to Modify

| Repository | File | Change |
|------------|------|--------|
| None | - | No modifications to existing files required |

---

## 12. Risk Assessment

### 12.1 Risks and Mitigations

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| Database dump fails | Medium | Low | Add alerting; manual fallback |
| TTL cleanup fails | Medium | Low | Manual cleanup command available |
| LoadBalancer IP allocation slow | Medium | Medium | 5-minute timeout with retry |
| ConfigMap update race condition | Low | Low | Restart pods after update |
| Workload Identity issues | Medium | Medium | Reuse DEV service account |
| Image build fails | High | Low | Clear error in PR comment |

### 12.2 Rollback Plan

If ephemeral environments cause issues:

1. **Disable workflows:**
   ```bash
   # Rename to disable
   mv ephemeral-deploy.yml ephemeral-deploy.yml.disabled
   mv ephemeral-destroy.yml ephemeral-destroy.yml.disabled
   ```

2. **Manual cleanup:**
   ```bash
   kubectl delete ns -l ephemeral.gameplatform.io/managed-by=github-actions
   ```

3. **Investigate and fix issues**

4. **Re-enable workflows**

---

## 13. References & Sources

### Official Documentation

1. **GitHub Actions - Pull Request Events**
   - https://docs.github.com/en/actions/using-workflows/events-that-trigger-workflows#pull_request

2. **GitHub Actions - Issue Comment Events**
   - https://docs.github.com/en/actions/using-workflows/events-that-trigger-workflows#issue_comment

3. **Kubernetes - Init Containers**
   - https://kubernetes.io/docs/concepts/workloads/pods/init-containers/

4. **PostgreSQL - pg_dump**
   - https://www.postgresql.org/docs/current/app-pgdump.html

5. **Google Cloud Storage - Lifecycle Rules**
   - https://cloud.google.com/storage/docs/lifecycle

6. **GKE - Workload Identity**
   - https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity

7. **GKE - Internal LoadBalancer**
   - https://cloud.google.com/kubernetes-engine/docs/how-to/internal-load-balancing

8. **Helm - Upgrade Command**
   - https://helm.sh/docs/helm/helm_upgrade/

### Internal Documentation

1. **CLAUDE.md** - Architecture and patterns
2. **EXECUTION-PATH.md** - Infrastructure setup guide
3. **sync-configmaps.yml** - Reference for ConfigMap creation pattern

---

## Appendix A: PR Comment Commands

| Command | Description |
|---------|-------------|
| `/deploy-eph` | Deploy or redeploy ephemeral environment |
| `/destroy-eph` | Manually destroy ephemeral environment |

---

## Appendix B: Troubleshooting

### Environment not deploying

1. Check branch name starts with `eph-`
2. Check PR target is `development`
3. Check workflow logs in GitHub Actions
4. Verify GCP authentication is working

### Database not restoring

1. Check GCS bucket has `latest.sql.gz`:
   ```bash
   gsutil ls gs://gameplatform-ephemeral-db-dumps/
   ```
2. Check init container logs:
   ```bash
   kubectl logs -n NAMESPACE POD -c download-and-restore
   ```
3. Check PostgreSQL logs:
   ```bash
   kubectl logs -n NAMESPACE POD -c postgres
   ```

### Services not getting IPs

1. Check LoadBalancer status:
   ```bash
   kubectl get svc -n NAMESPACE
   ```
2. Check GKE events:
   ```bash
   kubectl get events -n NAMESPACE --sort-by='.lastTimestamp'
   ```
3. Verify Internal LB annotation is set

### ExternalSecrets not syncing

1. Check ExternalSecret status:
   ```bash
   kubectl get externalsecrets -n NAMESPACE
   ```
2. Check ESO operator logs:
   ```bash
   kubectl logs -n external-secrets -l app.kubernetes.io/name=external-secrets
   ```

### Pods not starting

1. Check ConfigMaps created:
   ```bash
   kubectl get cm -n NAMESPACE
   ```
2. Check pod events:
   ```bash
   kubectl describe pod -n NAMESPACE POD
   ```
3. Check pod logs:
   ```bash
   kubectl logs -n NAMESPACE POD
   ```

---

**End of Document**
