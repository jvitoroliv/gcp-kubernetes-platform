# Gaming Platform — GCP Infrastructure (AWS-to-GCP Migration)

I built the cloud platform for a gaming company migrating from AWS to GCP. Five private GKE clusters, nine microservices, full GitOps with ArgoCD, observability from scratch, and CI/CD that deploys to three environments without anyone touching kubectl.

This repo is the infrastructure backbone. Everything that isn't application code lives here.

## What this project is

The company runs a real-time multiplayer gaming platform. The backend is a mix of custom services (lobby, matchmaking, game session management) sitting on top of Nakama, an open-source game server. I came in when the whole thing was running on AWS ECS with manual deployments and no IaC to speak of.

My job: move everything to GCP, set up Kubernetes properly, and make deployments boring. The kind of boring where a developer merges to `develop` and their code's running in dev five minutes later without them thinking about it.

## Architecture

### Cluster topology

Five GKE clusters, all private (no public endpoints, you need WireGuard VPN to even run kubectl):

| Cluster | Purpose | Region |
|---|---|---|
| `project-dev-workloads` | Dev environment services | us-east1 |
| `project-stg-workloads` | Staging environment services | us-east1 |
| `project-prd-workloads` | Production services | southamerica-east1 |
| `project-dev-runners` | GitHub Actions self-hosted runners (nonprod) | us-east1 |
| `project-prd-runners` | GitHub Actions self-hosted runners (prod) | southamerica-east1 |

Production runs in `southamerica-east1` because most of the player base is in Brazil. Nonprod stays in `us-east1` for cost reasons.

The runners clusters exist because CI/CD needs to talk to the private workload clusters. GitHub-hosted runners can't reach them since the clusters have no public endpoint. So the runners sit inside the same VPC and connect via internal IPs.

### Services

Nine microservices, each packaged as a Helm chart with its own:
- Deployment with resource requests/limits
- Service (ClusterIP)
- Ingress rules
- HorizontalPodAutoscaler
- PodDisruptionBudget
- ServiceMonitor for Prometheus scraping
- ExternalSecret pulling from GCP Secret Manager
- ServiceAccount with workload identity binding

| Service | What it does |
|---|---|
| `nakama` | Open-source game server, matchmaking, real-time multiplayer, leaderboards |
| `lobby` | Player-facing lobby UI |
| `lobby-backend` | API backing the lobby frontend |
| `aes` | Account and entitlement service |
| `afs` | Friend service |
| `ahsat` | Anti-cheat and session tracking |
| `ais` | Inventory service |
| `aps` | Payment/store service |
| `metabase` | Analytics dashboard (production only) |

### GitOps with ArgoCD

ArgoCD manages everything after the initial cluster bootstrap. The `argocd/` directory has ~40 Application manifests organized by environment:

```
argocd/
├── bootstrap/          # ArgoCD itself + initial app-of-apps
├── dev/                # Dev environment apps
│   ├── alb-ingress.yaml
│   ├── cert-manager.yaml
│   ├── gateway.yaml
│   ├── ingress-nginx.yaml
│   ├── kube-dns-config.yaml
│   ├── monitoring/
│   │   ├── loki.yaml
│   │   ├── otel-collector.yaml
│   │   ├── prometheus.yaml
│   │   ├── promtail.yaml
│   │   └── tempo.yaml
│   └── reloader.yaml
├── stg/                # Same structure as dev
├── prd/                # Production + metabase
├── runners/            # Nonprod runner configs
└── prd-runners/        # Prod runner configs
```

Each Application manifest points to a Helm chart in this repo (or a remote chart for third-party tools). ArgoCD watches the repo, diffs against what's running, and syncs. No manual `helm upgrade` hitting production. Ever.

### Observability stack

Full observability across all environments. Each cluster gets:

- **Prometheus** (via kube-prometheus-stack) for metrics collection, alerting rules, ServiceMonitor CRDs
- **Grafana** for dashboards, data source configuration per environment
- **Loki** for log aggregation, connected to Grafana
- **Tempo** for distributed tracing
- **OpenTelemetry Collector** as the telemetry pipeline, receives traces/metrics from services and routes them
- **Promtail** as a DaemonSet shipping container logs to Loki

The Helm values are split per environment. Dev gets smaller resource allocations and shorter retention. Production gets proper sizing and longer retention windows.

### Secrets management

Zero hardcoded secrets. The flow:

1. Secrets live in GCP Secret Manager
2. External Secrets Operator (ESO) runs in each cluster
3. A `ClusterSecretStore` connects ESO to GCP Secret Manager using workload identity
4. Each service has an `ExternalSecret` resource that pulls its secrets and creates a Kubernetes Secret
5. Reloader watches those Secrets and restarts pods when they change

The bootstrap scripts create the initial secrets in GCP Secret Manager. After that, ESO handles synchronization.

### Authentication, no static keys anywhere

GitHub Actions authenticate to GCP using OIDC workload identity federation. The workflow:

```yaml
- name: Authenticate to Google Cloud
  uses: google-github-actions/auth@v2
  with:
    workload_identity_provider: projects/${{ vars.GCP_PROJECT_NUMBER }}/locations/global/workloadIdentityPools/gameplatform-nonprod-github-pool/providers/github-oidc
    service_account: gameplatform-nonprod-github-actions@project-nonprod-env.iam.gserviceaccount.com
```

No service account keys. No JSON key files. GitHub proves its identity via OIDC token, GCP validates it against the workload identity pool, and grants short-lived credentials scoped to the specific service account. If someone compromises the CI, there's no long-lived key to steal.

## Tech stack

| Layer | Tools |
|---|---|
| Cloud | GCP (GKE, Secret Manager, Artifact Registry, IAM, VPC) |
| Orchestration | Kubernetes (GKE private clusters) |
| GitOps | ArgoCD |
| Charts | Helm 3 |
| Config management | Kustomize (base + overlays per env) |
| CI/CD | GitHub Actions (11 workflows) |
| Monitoring | Prometheus, Grafana, Loki, Tempo, OTel Collector |
| Secrets | External Secrets Operator + GCP Secret Manager |
| Ingress | NGINX Ingress Controller, cert-manager (Let's Encrypt) |
| Networking | WireGuard VPN, private GKE endpoints |
| Container registry | GCP Artifact Registry (regional) |
| Auth | OIDC workload identity federation |

## Repository structure

```
.
├── .github/workflows/       # 11 CI/CD workflows
│   ├── bootstrap-cluster.yml
│   ├── build-and-push.yaml
│   ├── build-runner-image.yml
│   ├── deploy-dev.yaml
│   ├── deploy-stg.yaml
│   └── deploy-prd.yaml
├── argocd/                  # ~40 ArgoCD Application manifests
│   ├── bootstrap/
│   ├── dev/
│   ├── stg/
│   ├── prd/
│   ├── runners/
│   └── prd-runners/
├── charts/                  # Helm chart values for platform components
│   ├── alb-ingress/
│   ├── cert-manager/
│   ├── ephemeral-postgres/
│   ├── external-secrets/
│   ├── gateway/
│   ├── ingress-nginx/
│   ├── kube-dns-config/
│   ├── kube-prometheus-stack/
│   ├── loki/
│   ├── otel-collector/
│   ├── promtail/
│   ├── reloader/
│   ├── runners/
│   └── tempo/
├── kustomize/               # Environment overlays
│   ├── base/
│   └── overlays/
│       ├── dev/
│       ├── stg/
│       └── prd/
├── scripts/                 # Bootstrap and deployment
│   ├── bootstrap/
│   │   ├── 01-create-secrets.sh
│   │   ├── 01-create-secrets-dev.sh
│   │   ├── 01-create-secrets-stg.sh
│   │   ├── 01-create-secrets-prd.sh
│   │   ├── 02-bootstrap-runners.sh
│   │   ├── 02-bootstrap-prd-runners.sh
│   │   ├── 03-bootstrap-workloads.sh
│   │   ├── 04-configure-argocd.sh
│   │   └── 04-configure-argocd-prd.sh
│   ├── deploy.sh
│   ├── generate-service-charts.sh
│   ├── generate-service-charts-fixed.sh
│   ├── install-argocd.sh
│   ├── install-cert-manager.sh
│   ├── install-external-secrets.sh
│   └── setup-cluster.sh
├── svc-charts/              # Application Helm charts (9 services)
│   ├── aes/
│   ├── afs/
│   ├── ahsat/
│   ├── ais/
│   ├── aps/
│   ├── lobby/
│   ├── lobby-backend/
│   ├── metabase/
│   └── nakama/
├── docs/
└── images/
```

## What I built

### The bootstrap sequence

Standing up a new cluster from scratch follows a numbered script sequence. I designed it this way because the order matters and I didn't want anyone guessing:

1. **`01-create-secrets-{env}.sh`** — Populates GCP Secret Manager with the initial secrets (database URLs, API keys, service account tokens). Each environment has its own script because the secret values differ.

2. **`02-bootstrap-runners.sh`** — Sets up the GitHub Actions runner cluster. Installs cert-manager, creates the runner namespace, deploys the self-hosted runner controller. Without this, no CI/CD can reach the private workload clusters.

3. **`03-bootstrap-workloads.sh`** — The main one. Installs External Secrets Operator, creates the application namespace, sets up the ArgoCD ServiceAccount with cluster-admin binding. The script checks prerequisites (VPN connected, right kubectl context, helm installed) before doing anything. It validates your kubectl context matches the target cluster name and warns you if it doesn't.

4. **`04-configure-argocd.sh`** — Registers the workload clusters with ArgoCD running in the runners cluster. After this, ArgoCD can deploy to the workload cluster remotely.

Each script has colored output, proper error handling (`set -euo pipefail`), and confirmation prompts before destructive operations.

### CI/CD workflows

The deploy workflows follow the same pattern across all three environments:

1. Checkout code
2. Authenticate to GCP via OIDC (no keys)
3. Get GKE credentials for the target cluster
4. Install Helm
5. Update Helm dependencies
6. `helm upgrade --install` with environment-specific values and image tags
7. Verify deployment (kubectl get pods/services/ingress)
8. Run smoke tests, curl each service endpoint, check for 200/301/302

The production deploy adds an extra safeguard:
```bash
if [ "$ENV" == "prd" ]; then
  read -p "Are you sure you want to deploy to PRODUCTION? Type 'yes' to confirm: " confirm
  if [ "$confirm" != "yes" ]; then
    echo "Deployment cancelled"
    exit 1
  fi
fi
```

### Kustomize overlays

Base configuration defines the common resources (configmaps, external-secrets, namespace definitions). Overlays per environment add or patch what's different:

- Dev: smaller resource limits, debug logging, relaxed rate limits
- Staging: production-like config but with staging endpoints
- Production: full resource allocation, production domains, strict settings

### Service chart template

Every service chart follows the same structure I templated out:

```
svc-charts/{service}/
├── Chart.yaml
├── values.yaml
└── templates/
    ├── deployment.yaml
    ├── service.yaml
    ├── ingress.yaml
    ├── hpa.yaml
    ├── pdb.yaml
    ├── servicemonitor.yaml
    ├── external-secret.yaml
    └── serviceaccount.yaml
```

The consistency matters. Nine services. When someone needs to debug why one isn't scaling, they know exactly where to look. Same file, same structure, every time.

I wrote a `generate-service-charts.sh` script that scaffolds new service charts from this template. Give it a service name and it creates the whole directory with sensible defaults.

## Deployment workflow

### Automated (normal path)

```
Developer merges PR to develop
    → GitHub Actions triggers deploy-dev.yaml
    → OIDC auth to GCP
    → Helm upgrade to dev cluster
    → Smoke tests pass
    → Dev deployment complete

Developer merges develop to staging
    → deploy-stg.yaml fires
    → Same flow, staging cluster

Release branch merged to main
    → deploy-prd.yaml fires
    → Production cluster (southamerica-east1)
    → Extended smoke tests
```

### Manual (emergency or first-time)

```bash
# Connect VPN first (clusters are private)
./scripts/deploy.sh prd v2.1.0
```

The manual script handles cluster credential fetching, Helm dependency updates, deployment, verification, and smoke tests. All in one command. Production requires typing "yes" to confirm.

### Day-zero bootstrap (new cluster)

```bash
# 1. Create secrets in GCP Secret Manager
./scripts/bootstrap/01-create-secrets-dev.sh

# 2. Bootstrap runners cluster (if not exists)
./scripts/bootstrap/02-bootstrap-runners.sh

# 3. Bootstrap workloads cluster
./scripts/bootstrap/03-bootstrap-workloads.sh dev

# 4. Register with ArgoCD
./scripts/bootstrap/04-configure-argocd.sh
```

After step 4, ArgoCD takes over. Push a manifest to the `argocd/` directory and it syncs automatically.

## Environment domains

| Environment | Domain | Region |
|---|---|---|
| Development | `*.dev-gameplatform.example.com` | us-east1 |
| Staging | `*.stg-gameplatform.example.com` | us-east1 |
| Production | `*.gameplatform.example.com` | southamerica-east1 |

Each service gets its own subdomain (e.g., `lobby.dev-gameplatform.example.com`, `nakama.prd-gameplatform.example.com`). Ingress handles routing, cert-manager handles TLS certificates via Let's Encrypt.

## Design decisions

**Why private clusters?** Security. No public Kubernetes API means nobody outside the VPC can even attempt to authenticate. The tradeoff is needing VPN for local development, but that's worth it for a gaming platform handling player data.

**Why separate runner clusters?** Isolation. CI/CD workloads are unpredictable. Building Docker images can spike CPU and memory. Keeping runners on their own cluster means a runaway build can't starve production pods of resources.

**Why ArgoCD instead of raw Helm in CI?** Drift detection. CI-only deployments work fine until someone does a manual `kubectl apply` in production at 2 AM and forgets about it. ArgoCD catches that. It shows you the diff between what's in git and what's running.

**Why External Secrets Operator over Sealed Secrets or SOPS?** GCP Secret Manager is the source of truth. ESO pulls from it automatically and creates native Kubernetes Secrets. No encryption keys to manage, no binary secrets in git, and rotating a secret is as simple as updating it in Secret Manager. ESO syncs the change and Reloader restarts the affected pods.

**Why Kustomize AND Helm?** Different jobs. Helm templates the application charts with their complex logic (HPAs, PDBs, conditional resources). Kustomize handles the simpler environment-specific patches (namespace names, configmap values, ingress hosts). Each tool does what it's good at.
