#!/bin/bash
# =============================================================================
# ARC (Actions Runner Controller) Installation Script
# =============================================================================
# This script installs the ARC controller and runner scale sets on the
# GKE runners cluster.
#
# Prerequisites:
# - kubectl configured to point to gameplatform-nonprod-runners cluster
# - helm v3+ installed
# - External Secrets Operator installed (charts/external-secrets)
# - GitHub PAT stored in GCP Secret Manager (gameplatform-nonprod-github-arc-pat)
#
# Usage:
#   ./install.sh              # Install ARC with ExternalSecret
#   ./install.sh --manual     # Install ARC with manual secret (legacy)
#   ./install.sh --uninstall  # Uninstall ARC
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE_CONTROLLER="arc-systems"
NAMESPACE_RUNNERS="arc-runners"
SECRET_NAME="arc-github-secret"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_prerequisites() {
    log_info "Checking prerequisites..."

    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl not found. Please install kubectl."
        exit 1
    fi

    if ! command -v helm &> /dev/null; then
        log_error "helm not found. Please install helm v3+."
        exit 1
    fi

    # Check kubectl context
    CURRENT_CONTEXT=$(kubectl config current-context)
    if [[ ! "$CURRENT_CONTEXT" =~ "runners" ]]; then
        log_warn "Current context: $CURRENT_CONTEXT"
        log_warn "Expected context to contain 'runners'. Make sure you're connected to the right cluster."
        read -p "Continue anyway? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi

    log_info "Prerequisites check passed."
}

check_eso_installed() {
    log_info "Checking if External Secrets Operator is installed..."

    if ! kubectl get deployment external-secrets -n external-secrets &> /dev/null; then
        log_error "External Secrets Operator not found!"
        log_error "Please install ESO first: cd ../external-secrets && ./install.sh runners"
        exit 1
    fi

    if ! kubectl get clustersecretstore gcp-secret-manager &> /dev/null; then
        log_error "ClusterSecretStore 'gcp-secret-manager' not found!"
        log_error "Please check ESO installation."
        exit 1
    fi

    log_info "ESO is installed and ready."
}

create_namespaces() {
    log_info "Creating namespaces..."

    kubectl create namespace "$NAMESPACE_CONTROLLER" --dry-run=client -o yaml | kubectl apply -f -
    kubectl create namespace "$NAMESPACE_RUNNERS" --dry-run=client -o yaml | kubectl apply -f -

    log_info "Namespaces created."
}

create_external_secret() {
    log_info "Creating ExternalSecret for GitHub PAT..."

    kubectl apply -f "$SCRIPT_DIR/external-secret.yaml"

    log_info "Waiting for secret to sync..."
    for i in {1..30}; do
        if kubectl get secret "$SECRET_NAME" -n "$NAMESPACE_RUNNERS" &> /dev/null; then
            log_info "Secret synced successfully!"
            return 0
        fi
        sleep 2
    done

    log_error "Timeout waiting for secret to sync."
    log_error "Check ExternalSecret status: kubectl describe externalsecret arc-github-secret -n arc-runners"
    exit 1
}

create_manual_secret() {
    local github_pat="$1"

    log_info "Creating GitHub secret manually..."

    kubectl create secret generic "$SECRET_NAME" \
        --namespace "$NAMESPACE_RUNNERS" \
        --from-literal=github_token="$github_pat" \
        --dry-run=client -o yaml | kubectl apply -f -

    log_info "GitHub secret created."
}

install_controller() {
    log_info "Installing ARC controller..."

    helm upgrade --install arc \
        --namespace "$NAMESPACE_CONTROLLER" \
        --values "$SCRIPT_DIR/controller/values.yaml" \
        --wait \
        oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller

    log_info "ARC controller installed."
}

install_runner_light() {
    log_info "Installing light runner scale set..."

    helm upgrade --install arc-runner-light \
        --namespace "$NAMESPACE_RUNNERS" \
        --values "$SCRIPT_DIR/runner-light/values.yaml" \
        --wait \
        oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set

    log_info "Light runner scale set installed."
}

install_runner_heavy() {
    log_info "Installing heavy runner scale set..."

    helm upgrade --install arc-runner-heavy \
        --namespace "$NAMESPACE_RUNNERS" \
        --values "$SCRIPT_DIR/runner-heavy/values.yaml" \
        --wait \
        oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set

    log_info "Heavy runner scale set installed."
}

uninstall() {
    log_warn "Uninstalling ARC components..."

    helm uninstall arc-runner-heavy --namespace "$NAMESPACE_RUNNERS" 2>/dev/null || true
    helm uninstall arc-runner-light --namespace "$NAMESPACE_RUNNERS" 2>/dev/null || true
    helm uninstall arc --namespace "$NAMESPACE_CONTROLLER" 2>/dev/null || true

    kubectl delete -f "$SCRIPT_DIR/external-secret.yaml" 2>/dev/null || true
    kubectl delete secret "$SECRET_NAME" --namespace "$NAMESPACE_RUNNERS" 2>/dev/null || true

    log_info "ARC components uninstalled."
    log_info "Namespaces preserved. Delete manually if needed:"
    log_info "  kubectl delete namespace $NAMESPACE_CONTROLLER $NAMESPACE_RUNNERS"
}

verify_installation() {
    log_info "Verifying installation..."

    echo ""
    echo "=== Controller Pods ==="
    kubectl get pods -n "$NAMESPACE_CONTROLLER"

    echo ""
    echo "=== Runner Pods ==="
    kubectl get pods -n "$NAMESPACE_RUNNERS"

    echo ""
    echo "=== Secrets ==="
    kubectl get secrets -n "$NAMESPACE_RUNNERS"

    echo ""
    echo "=== ExternalSecrets ==="
    kubectl get externalsecrets -n "$NAMESPACE_RUNNERS"

    echo ""
    echo "=== Helm Releases ==="
    helm list -n "$NAMESPACE_CONTROLLER"
    helm list -n "$NAMESPACE_RUNNERS"

    echo ""
    log_info "Installation complete!"
    log_info ""
    log_info "To use in GitHub Actions workflows:"
    log_info "  jobs:"
    log_info "    lint:"
    log_info "      runs-on: gameplatform-light"
    log_info "    build:"
    log_info "      runs-on: gameplatform-heavy"
}

show_usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  (no args)        Install ARC using ExternalSecret (recommended)"
    echo "  --manual <pat>   Install ARC with manual secret (legacy)"
    echo "  --uninstall      Remove all ARC components"
    echo "  --help           Show this help"
    echo ""
    echo "Examples:"
    echo "  # Recommended: Use ExternalSecret (requires ESO installed)"
    echo "  $0"
    echo ""
    echo "  # Legacy: Manual secret"
    echo "  $0 --manual ghp_xxxxxxxxxxxxxxxxxxxx"
    echo ""
    echo "  # Uninstall"
    echo "  $0 --uninstall"
}

# =============================================================================
# Main
# =============================================================================

# Default: install with ExternalSecret
if [[ $# -eq 0 ]]; then
    check_prerequisites
    check_eso_installed
    create_namespaces
    create_external_secret
    install_controller
    install_runner_light
    install_runner_heavy
    verify_installation
    exit 0
fi

case "$1" in
    --manual)
        if [[ $# -lt 2 ]]; then
            log_error "Missing GitHub PAT argument"
            show_usage
            exit 1
        fi
        GITHUB_PAT="$2"
        if [[ ! "$GITHUB_PAT" =~ ^ghp_|^github_pat_ ]]; then
            log_error "Invalid GitHub PAT format. Expected 'ghp_...' or 'github_pat_...'"
            exit 1
        fi
        check_prerequisites
        create_namespaces
        create_manual_secret "$GITHUB_PAT"
        install_controller
        install_runner_light
        install_runner_heavy
        verify_installation
        ;;
    --uninstall)
        check_prerequisites
        uninstall
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
