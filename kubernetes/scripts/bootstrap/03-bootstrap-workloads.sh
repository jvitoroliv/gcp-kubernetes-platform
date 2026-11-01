#!/bin/bash
# =============================================================================
# Bootstrap Workloads Cluster
# =============================================================================
# This script bootstraps a workloads cluster (dev or stg) with:
#   1. External Secrets Operator (ESO)
#   2. Application namespace
#   3. ServiceAccount for ArgoCD remote access
#
# Prerequisites:
# - VPN connected (cluster is private)
# - kubectl configured to point to the target cluster
# - Secrets created in GCP Secret Manager (01-create-secrets.sh)
#
# This script can be run:
#   - MANUALLY via VPN (for initial setup before runners exist)
#   - VIA WORKFLOW after runners cluster is bootstrapped
#
# Usage:
#   ./03-bootstrap-workloads.sh dev    # Bootstrap dev-workloads
#   ./03-bootstrap-workloads.sh stg    # Bootstrap stg-workloads
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Configuration
PROJECT="project-nonprod-env"
REGION="us-east1"

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

show_usage() {
    echo "Usage: $0 <environment>"
    echo ""
    echo "Arguments:"
    echo "  dev    Bootstrap project-dev-workloads cluster"
    echo "  stg    Bootstrap project-stg-workloads cluster"
    echo ""
    echo "Prerequisites:"
    echo "  1. VPN connected (cluster is private)"
    echo "  2. kubectl configured to target cluster:"
    echo "     gcloud container clusters get-credentials project-dev-workloads \\"
    echo "       --region us-east1 --project project-nonprod-env --internal-ip"
}

check_prerequisites() {
    local cluster_name="$1"

    log_section "Checking Prerequisites"

    # Check kubectl
    if ! command -v kubectl &>/dev/null; then
        log_error "kubectl not found. Please install kubectl."
        exit 1
    fi

    # Check helm
    if ! command -v helm &>/dev/null; then
        log_error "helm not found. Please install helm v3+."
        exit 1
    fi

    # Verify kubectl context
    CURRENT_CONTEXT=$(kubectl config current-context 2>/dev/null || echo "")
    if [[ -z "$CURRENT_CONTEXT" ]]; then
        log_error "No kubectl context set. Connect to the cluster first:"
        echo "  gcloud container clusters get-credentials $cluster_name \\"
        echo "    --region $REGION --project $PROJECT --internal-ip"
        exit 1
    fi

    if [[ ! "$CURRENT_CONTEXT" =~ "$cluster_name" ]]; then
        log_warn "Current context: $CURRENT_CONTEXT"
        log_warn "Expected context to contain '$cluster_name'."
        echo ""
        read -p "Continue anyway? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi

    # Test cluster connectivity
    log_info "Testing cluster connectivity..."
    if ! kubectl get nodes &>/dev/null; then
        log_error "Cannot connect to cluster. Make sure VPN is connected."
        exit 1
    fi

    log_info "All prerequisites met!"
}

install_eso() {
    log_section "Installing External Secrets Operator"

    local namespace="external-secrets"

    # Create namespace
    kubectl create namespace "$namespace" --dry-run=client -o yaml | kubectl apply -f -

    # Install ESO using OCI chart
    log_info "Installing ESO via Helm..."
    helm upgrade --install external-secrets \
        --namespace "$namespace" \
        --values "$REPO_ROOT/charts/external-secrets/values.yaml" \
        --values "$REPO_ROOT/charts/external-secrets/values-workloads.yaml" \
        --wait \
        --timeout 5m \
        oci://ghcr.io/external-secrets/charts/external-secrets

    # Wait for deployments
    log_info "Waiting for ESO deployments..."
    kubectl rollout status deployment/external-secrets -n "$namespace" --timeout=120s
    kubectl rollout status deployment/external-secrets-webhook -n "$namespace" --timeout=120s
    kubectl rollout status deployment/external-secrets-cert-controller -n "$namespace" --timeout=120s

    # Apply ClusterSecretStore
    log_info "Applying ClusterSecretStore..."
    kubectl apply -f "$REPO_ROOT/charts/external-secrets/cluster-secret-store.yaml"

    log_info "ESO installed successfully!"
    kubectl get clustersecretstore
}

create_namespace() {
    local env="$1"
    local namespace="gameplatform-${env}"

    log_section "Creating Application Namespace"

    kubectl create namespace "$namespace" --dry-run=client -o yaml | kubectl apply -f -

    log_info "Namespace $namespace created."
}

create_argocd_sa() {
    local env="$1"
    local namespace="gameplatform-${env}"

    log_section "Creating ArgoCD Manager ServiceAccount"

    # Create ServiceAccount for ArgoCD to manage this cluster remotely
    log_info "Creating argocd-manager ServiceAccount..."
    kubectl create serviceaccount argocd-manager -n "$namespace" --dry-run=client -o yaml | kubectl apply -f -

    # Create ClusterRoleBinding for ArgoCD
    log_info "Creating ClusterRoleBinding..."
    cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: argocd-manager-${env}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: argocd-manager
  namespace: ${namespace}
EOF

    log_info "ArgoCD ServiceAccount created."
}

show_summary() {
    local env="$1"
    local cluster_name="$2"
    local namespace="gameplatform-${env}"

    log_section "Bootstrap Summary"

    echo "Workloads cluster bootstrapped successfully!"
    echo ""
    echo "Environment: $env"
    echo "Cluster: $cluster_name"
    echo "Namespace: $namespace"
    echo ""
    echo "Installed Components:"
    echo "  - External Secrets Operator (namespace: external-secrets)"
    echo "  - ClusterSecretStore: gcp-secret-manager"
    echo "  - Application namespace: $namespace"
    echo "  - ArgoCD ServiceAccount: argocd-manager"
    echo ""
    echo "Next Steps:"
    if [[ "$env" == "dev" ]]; then
        echo "  1. Run: ./03-bootstrap-workloads.sh stg (if needed)"
        echo "  2. Run: ./04-configure-argocd.sh"
    else
        echo "  1. Run: ./04-configure-argocd.sh"
    fi
    echo ""
    echo "To verify ESO:"
    echo "  kubectl get clustersecretstore"
    echo "  kubectl get externalsecrets -n $namespace"
}

# =============================================================================
# Main
# =============================================================================

if [[ $# -lt 1 ]]; then
    show_usage
    exit 1
fi

ENV="$1"

# Validate and set configuration
case "$ENV" in
    dev)
        CLUSTER_NAME="project-dev-workloads"
        ;;
    stg)
        CLUSTER_NAME="project-stg-workloads"
        ;;
    *)
        log_error "Invalid environment: $ENV"
        show_usage
        exit 1
        ;;
esac

log_section "Bootstrap Workloads Cluster"
log_info "Environment: $ENV"
log_info "Cluster: $CLUSTER_NAME"
log_info "Project: $PROJECT"
log_info "Region: $REGION"

check_prerequisites "$CLUSTER_NAME"

echo ""
log_warn "This will install ESO and create the application namespace."
read -p "Continue? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 0
fi

install_eso
create_namespace "$ENV"
create_argocd_sa "$ENV"
show_summary "$ENV" "$CLUSTER_NAME"
