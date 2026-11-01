#!/bin/bash
# =============================================================================
# Configure ArgoCD for PRD
# =============================================================================
# This script configures ArgoCD on the PRD runners cluster to:
#   1. Register the PRD workloads cluster
#   2. Add GitHub repository credentials
#   3. Apply the app-of-apps for PRD
#
# Prerequisites:
# - kubectl configured to point to project-prd-runners
# - Access to project-prd-workloads cluster
# - GitHub PAT stored in GCP Secret Manager (project-prd-github-arc-pat)
#
# Usage:
#   ./04-configure-argocd-prd.sh
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Configuration
PROJECT="project-prd-env"
REGION="southamerica-east1"
RUNNERS_CLUSTER="project-prd-runners"
WORKLOADS_CLUSTER="project-prd-workloads"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_section() { echo -e "\n${BLUE}=== $1 ===${NC}\n"; }

check_prerequisites() {
    log_section "Checking Prerequisites"

    # Check kubectl
    if ! command -v kubectl &>/dev/null; then
        log_error "kubectl not found. Please install kubectl."
        exit 1
    fi

    # Check gcloud
    if ! command -v gcloud &>/dev/null; then
        log_error "gcloud not found. Please install Google Cloud SDK."
        exit 1
    fi

    log_info "All prerequisites met!"
}

setup_workloads_cluster_access() {
    log_section "Setting up Workloads Cluster Access"

    # Get workloads cluster credentials
    log_info "Getting credentials for workloads cluster..."
    gcloud container clusters get-credentials "$WORKLOADS_CLUSTER" \
        --region "$REGION" --project "$PROJECT" 2>/dev/null

    # Check if ServiceAccount already exists
    if kubectl get serviceaccount argocd-manager -n kube-system &>/dev/null; then
        log_info "ServiceAccount argocd-manager already exists"
    else
        log_info "Creating ServiceAccount argocd-manager..."
        kubectl create serviceaccount argocd-manager -n kube-system
    fi

    # Check if ClusterRole already exists
    if kubectl get clusterrole argocd-manager-role &>/dev/null; then
        log_info "ClusterRole argocd-manager-role already exists"
    else
        log_info "Creating ClusterRole argocd-manager-role..."
        kubectl create clusterrole argocd-manager-role --verb="*" --resource="*"
    fi

    # Check if ClusterRoleBinding already exists
    if kubectl get clusterrolebinding argocd-manager-role-binding &>/dev/null; then
        log_info "ClusterRoleBinding argocd-manager-role-binding already exists"
    else
        log_info "Creating ClusterRoleBinding argocd-manager-role-binding..."
        kubectl create clusterrolebinding argocd-manager-role-binding \
            --clusterrole=argocd-manager-role \
            --serviceaccount=kube-system:argocd-manager
    fi

    # Create long-lived token secret if not exists
    if kubectl get secret argocd-manager-long-lived-token -n kube-system &>/dev/null; then
        log_info "Token secret already exists"
    else
        log_info "Creating long-lived token secret..."
        kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: argocd-manager-long-lived-token
  namespace: kube-system
  annotations:
    kubernetes.io/service-account.name: argocd-manager
type: kubernetes.io/service-account-token
EOF
    fi

    # Wait for token to be populated
    log_info "Waiting for token to be populated..."
    for i in {1..30}; do
        TOKEN=$(kubectl get secret argocd-manager-long-lived-token -n kube-system \
            -o jsonpath='{.data.token}' 2>/dev/null || echo "")
        if [[ -n "$TOKEN" ]]; then
            log_info "Token is ready!"
            break
        fi
        if [[ $i -eq 30 ]]; then
            log_error "Timeout waiting for token"
            exit 1
        fi
        sleep 2
    done

    # Get cluster info
    CLUSTER_SERVER=$(kubectl config view -o jsonpath="{.clusters[?(@.name==\"gke_${PROJECT}_${REGION}_${WORKLOADS_CLUSTER}\")].cluster.server}")
    CLUSTER_CA=$(kubectl config view --raw -o jsonpath="{.clusters[?(@.name==\"gke_${PROJECT}_${REGION}_${WORKLOADS_CLUSTER}\")].cluster.certificate-authority-data}")
    SA_TOKEN=$(kubectl get secret argocd-manager-long-lived-token -n kube-system -o jsonpath='{.data.token}' | base64 -d)

    log_info "Cluster server: $CLUSTER_SERVER"
    log_info "CA data length: ${#CLUSTER_CA}"
    log_info "Token length: ${#SA_TOKEN}"

    # Export for use in next function
    export CLUSTER_SERVER CLUSTER_CA SA_TOKEN
}

register_cluster_in_argocd() {
    log_section "Registering Workloads Cluster in ArgoCD"

    # Switch to runners cluster
    log_info "Switching to runners cluster..."
    gcloud container clusters get-credentials "$RUNNERS_CLUSTER" \
        --region "$REGION" --project "$PROJECT" 2>/dev/null

    # Check if cluster secret already exists
    if kubectl get secret cluster-project-prd-workloads -n argocd &>/dev/null; then
        log_warn "Cluster secret already exists, updating..."
        kubectl delete secret cluster-project-prd-workloads -n argocd
    fi

    # Create cluster secret
    log_info "Creating cluster secret..."
    kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: cluster-project-prd-workloads
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: cluster
type: Opaque
stringData:
  name: project-prd-workloads
  server: "${CLUSTER_SERVER}"
  config: |
    {
      "bearerToken": "${SA_TOKEN}",
      "tlsClientConfig": {
        "insecure": false,
        "caData": "${CLUSTER_CA}"
      }
    }
EOF

    log_info "Cluster registered successfully!"
    kubectl get secrets -n argocd -l argocd.argoproj.io/secret-type=cluster
}

setup_repo_credentials() {
    log_section "Setting up Repository Credentials"

    # Check if repo secret already exists
    if kubectl get secret repo-platform-kubernetes-infrastructure -n argocd &>/dev/null; then
        log_info "Repository secret already exists"
        return
    fi

    # Get GitHub PAT from Secret Manager
    log_info "Getting GitHub PAT from Secret Manager..."
    GH_PAT=$(gcloud secrets versions access latest \
        --secret=project-prd-github-arc-pat \
        --project="$PROJECT" 2>/dev/null || echo "")

    if [[ -z "$GH_PAT" ]]; then
        log_error "Failed to get GitHub PAT from Secret Manager"
        log_error "Make sure secret 'project-prd-github-arc-pat' exists with a valid version"
        exit 1
    fi

    # Create repo secret
    log_info "Creating repository secret..."
    kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: repo-platform-kubernetes-infrastructure
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
type: Opaque
stringData:
  type: git
  url: https://github.com/example-gamedev-org/platform-kubernetes-infrastructure.git
  username: git
  password: ${GH_PAT}
EOF

    log_info "Repository credentials configured!"
    kubectl get secrets -n argocd -l argocd.argoproj.io/secret-type=repository
}

apply_app_of_apps() {
    log_section "Applying App-of-Apps for PRD"

    # Check if app-of-apps already exists
    if kubectl get application app-of-apps-prd -n argocd &>/dev/null; then
        log_info "app-of-apps-prd already exists, refreshing..."
        kubectl patch application app-of-apps-prd -n argocd \
            --type merge \
            -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'
    else
        log_info "Creating app-of-apps-prd..."
        kubectl apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: app-of-apps-prd
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://github.com/example-gamedev-org/platform-kubernetes-infrastructure.git
    targetRevision: main
    path: argocd/prd
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    syncOptions:
      - CreateNamespace=false
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
EOF
    fi

    # Wait for sync
    log_info "Waiting for ArgoCD to sync..."
    sleep 10

    log_info "ArgoCD Applications:"
    kubectl get applications -n argocd
}

show_summary() {
    log_section "Configuration Summary"

    echo "ArgoCD PRD configuration complete!"
    echo ""
    echo "Configured:"
    echo "  - Workloads cluster registered: project-prd-workloads"
    echo "  - Repository credentials: platform-kubernetes-infrastructure"
    echo "  - App-of-apps: app-of-apps-prd"
    echo ""
    echo "ArgoCD Applications:"
    kubectl get applications -n argocd
    echo ""
    echo "To access ArgoCD UI:"
    echo "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
    echo "  Open: https://localhost:8080"
    echo "  Username: admin"
    echo "  Password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
}

# =============================================================================
# Main
# =============================================================================

log_section "Configure ArgoCD for PRD"
log_info "Project: $PROJECT"
log_info "Region: $REGION"

check_prerequisites

echo ""
log_warn "This will configure ArgoCD on the PRD runners cluster."
read -p "Continue? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 0
fi

setup_workloads_cluster_access
register_cluster_in_argocd
setup_repo_credentials
apply_app_of_apps
show_summary
