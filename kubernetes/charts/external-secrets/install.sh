#!/bin/bash
# =============================================================================
# External Secrets Operator Installation Script
# =============================================================================
# Installs ESO on a GKE cluster with Workload Identity
#
# Usage:
#   ./install.sh workloads    # Install on workloads cluster
#   ./install.sh runners      # Install on runners cluster
#   ./install.sh --uninstall  # Uninstall ESO
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="external-secrets"
RELEASE_NAME="external-secrets"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

check_prerequisites() {
    log_info "Checking prerequisites..."

    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl not found"
        exit 1
    fi

    if ! command -v helm &> /dev/null; then
        log_error "helm not found"
        exit 1
    fi

    log_info "Prerequisites OK"
}

install_eso() {
    local cluster_type="$1"
    local values_file="values-${cluster_type}.yaml"

    if [[ ! -f "$SCRIPT_DIR/$values_file" ]]; then
        log_error "Values file not found: $values_file"
        exit 1
    fi

    log_info "Installing External Secrets Operator for $cluster_type cluster..."

    # Create namespace
    kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

    # Install ESO
    helm upgrade --install "$RELEASE_NAME" \
        --namespace "$NAMESPACE" \
        --values "$SCRIPT_DIR/values.yaml" \
        --values "$SCRIPT_DIR/$values_file" \
        --wait \
        oci://ghcr.io/external-secrets/charts/external-secrets

    log_info "Waiting for ESO to be ready..."
    kubectl rollout status deployment/external-secrets -n "$NAMESPACE" --timeout=120s
    kubectl rollout status deployment/external-secrets-webhook -n "$NAMESPACE" --timeout=120s
    kubectl rollout status deployment/external-secrets-cert-controller -n "$NAMESPACE" --timeout=120s

    log_info "Applying ClusterSecretStore..."
    kubectl apply -f "$SCRIPT_DIR/cluster-secret-store.yaml"

    log_info "ESO installed successfully!"
    echo ""
    log_info "Verify with: kubectl get clustersecretstore"
}

uninstall_eso() {
    log_warn "Uninstalling External Secrets Operator..."

    kubectl delete -f "$SCRIPT_DIR/cluster-secret-store.yaml" 2>/dev/null || true
    helm uninstall "$RELEASE_NAME" -n "$NAMESPACE" 2>/dev/null || true

    log_info "ESO uninstalled. Namespace preserved."
    log_info "Delete namespace manually: kubectl delete namespace $NAMESPACE"
}

show_usage() {
    echo "Usage: $0 <cluster-type>"
    echo ""
    echo "Arguments:"
    echo "  workloads    Install on workloads cluster (project-dev-workloads)"
    echo "  runners      Install on runners cluster (gameplatform-nonprod-runners)"
    echo "  --uninstall  Uninstall ESO"
    echo ""
    echo "Examples:"
    echo "  # Connect to workloads cluster and install"
    echo "  gcloud container clusters get-credentials project-dev-workloads --region us-east1 --project project-nonprod-env"
    echo "  $0 workloads"
    echo ""
    echo "  # Connect to runners cluster and install"
    echo "  gcloud container clusters get-credentials gameplatform-nonprod-runners --region us-east1 --project project-nonprod-env"
    echo "  $0 runners"
}

# =============================================================================
# Main
# =============================================================================

if [[ $# -lt 1 ]]; then
    show_usage
    exit 1
fi

case "$1" in
    workloads|runners)
        check_prerequisites
        install_eso "$1"
        ;;
    --uninstall)
        check_prerequisites
        uninstall_eso
        ;;
    --help|-h)
        show_usage
        ;;
    *)
        log_error "Invalid argument: $1"
        show_usage
        exit 1
        ;;
esac
