#!/bin/bash
# =============================================================================
# Bootstrap Runners Cluster (gameplatform-nonprod-runners)
# =============================================================================
# This script bootstraps the runners cluster with:
#   1. External Secrets Operator (ESO)
#   2. Actions Runner Controller (ARC)
#   3. ArgoCD (manages dev and stg clusters remotely)
#
# Prerequisites:
# - VPN connected (cluster is private)
# - kubectl configured to point to gameplatform-nonprod-runners
# - Secrets created in GCP Secret Manager (01-create-secrets.sh)
#
# IMPORTANT: This script must be run MANUALLY via VPN because:
# - The cluster is private (no public endpoint)
# - GitHub Actions cannot access private clusters without runners
# - This is a one-time bootstrap (chicken-egg problem)
#
# Usage:
#   # First, connect to cluster via VPN
#   gcloud container clusters get-credentials gameplatform-nonprod-runners \
#     --region us-east1 --project project-nonprod-env --internal-ip
#
#   # Then run this script
#   ./02-bootstrap-runners.sh
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Configuration
PROJECT="project-nonprod-env"
REGION="us-east1"
CLUSTER_NAME="gameplatform-nonprod-runners"

# Namespaces
NS_ESO="external-secrets"
NS_ARC_SYSTEMS="arc-systems"
NS_ARC_RUNNERS="arc-runners"
NS_ARGOCD="argocd"

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

    # Check helm
    if ! command -v helm &>/dev/null; then
        log_error "helm not found. Please install helm v3+."
        exit 1
    fi

    # Check gcloud
    if ! command -v gcloud &>/dev/null; then
        log_error "gcloud not found. Please install Google Cloud SDK."
        exit 1
    fi

    # Verify kubectl context
    CURRENT_CONTEXT=$(kubectl config current-context 2>/dev/null || echo "")
    if [[ -z "$CURRENT_CONTEXT" ]]; then
        log_error "No kubectl context set. Connect to the cluster first:"
        echo "  gcloud container clusters get-credentials $CLUSTER_NAME \\"
        echo "    --region $REGION --project $PROJECT --internal-ip"
        exit 1
    fi

    if [[ ! "$CURRENT_CONTEXT" =~ "runners" ]]; then
        log_warn "Current context: $CURRENT_CONTEXT"
        log_warn "Expected context to contain 'runners'."
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

    # Create namespace
    kubectl create namespace "$NS_ESO" --dry-run=client -o yaml | kubectl apply -f -

    # Install ESO using OCI chart
    log_info "Installing ESO via Helm..."
    helm upgrade --install external-secrets \
        --namespace "$NS_ESO" \
        --values "$REPO_ROOT/charts/external-secrets/values.yaml" \
        --values "$REPO_ROOT/charts/external-secrets/values-runners.yaml" \
        --wait \
        --timeout 5m \
        oci://ghcr.io/external-secrets/charts/external-secrets

    # Wait for deployments
    log_info "Waiting for ESO deployments..."
    kubectl rollout status deployment/external-secrets -n "$NS_ESO" --timeout=120s
    kubectl rollout status deployment/external-secrets-webhook -n "$NS_ESO" --timeout=120s
    kubectl rollout status deployment/external-secrets-cert-controller -n "$NS_ESO" --timeout=120s

    # Apply ClusterSecretStore (runners-specific with workloadIdentity config)
    log_info "Applying ClusterSecretStore..."
    kubectl apply -f "$REPO_ROOT/charts/external-secrets/cluster-secret-store-runners.yaml"

    # Wait for ClusterSecretStore to be ready
    log_info "Waiting for ClusterSecretStore to be ready..."
    for i in {1..30}; do
        STATUS=$(kubectl get clustersecretstore gcp-secret-manager -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "Unknown")
        if [[ "$STATUS" == "True" ]]; then
            log_info "ClusterSecretStore is ready!"
            break
        fi
        if [[ $i -eq 30 ]]; then
            log_error "ClusterSecretStore not ready after 60s. Status: $STATUS"
            log_error "Check: kubectl describe clustersecretstore gcp-secret-manager"
            exit 1
        fi
        sleep 2
    done

    log_info "ESO installed successfully!"
    kubectl get clustersecretstore
}

install_arc() {
    log_section "Installing Actions Runner Controller"

    # Create namespaces
    kubectl create namespace "$NS_ARC_SYSTEMS" --dry-run=client -o yaml | kubectl apply -f -
    kubectl create namespace "$NS_ARC_RUNNERS" --dry-run=client -o yaml | kubectl apply -f -

    # Apply ExternalSecret for GitHub PAT
    log_info "Creating ExternalSecret for GitHub PAT..."
    kubectl apply -f "$REPO_ROOT/charts/runners/external-secret.yaml"

    # Wait for secret to sync
    log_info "Waiting for GitHub PAT secret to sync..."
    for i in {1..60}; do
        if kubectl get secret arc-github-secret -n "$NS_ARC_RUNNERS" &>/dev/null; then
            log_info "Secret synced successfully!"
            break
        fi
        if [[ $i -eq 60 ]]; then
            log_error "Timeout waiting for secret to sync."
            log_error "Check ExternalSecret status: kubectl describe externalsecret arc-github-secret -n $NS_ARC_RUNNERS"
            exit 1
        fi
        sleep 2
    done

    # Install ARC Controller
    log_info "Installing ARC Controller..."
    helm upgrade --install arc \
        --namespace "$NS_ARC_SYSTEMS" \
        --values "$REPO_ROOT/charts/runners/controller/values.yaml" \
        --wait \
        --timeout 5m \
        oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller

    # Install Heavy Runner Scale Set (only heavy - no light needed)
    log_info "Installing Heavy Runner Scale Set..."
    log_info "Building Helm dependencies..."
    helm dependency build "$REPO_ROOT/charts/runners/runner-heavy"
    helm upgrade --install arc-runner-heavy \
        --namespace "$NS_ARC_RUNNERS" \
        --wait \
        --timeout 5m \
        "$REPO_ROOT/charts/runners/runner-heavy"

    # Wait for listener pod to be ready (listener name contains "gameplatform-heavy" and ends with "-listener")
    log_info "Waiting for ARC listener to be ready..."
    for i in {1..60}; do
        LISTENER_POD=$(kubectl get pods -n "$NS_ARC_SYSTEMS" --no-headers 2>/dev/null | grep "gameplatform-heavy.*listener" | head -1 | awk '{print $1}')
        if [[ -n "$LISTENER_POD" ]]; then
            LISTENER_STATUS=$(kubectl get pod "$LISTENER_POD" -n "$NS_ARC_SYSTEMS" -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
            if [[ "$LISTENER_STATUS" == "Running" ]]; then
                log_info "ARC listener ($LISTENER_POD) is running!"
                break
            fi
        fi
        if [[ $i -eq 60 ]]; then
            log_warn "Listener not ready yet. Check: kubectl get pods -n $NS_ARC_SYSTEMS"
        fi
        sleep 2
    done

    log_info "ARC installed successfully!"
    kubectl get pods -n "$NS_ARC_SYSTEMS"
    kubectl get autoscalingrunnerset -n "$NS_ARC_RUNNERS"
}

install_argocd() {
    log_section "Installing ArgoCD"

    # Create namespace
    kubectl create namespace "$NS_ARGOCD" --dry-run=client -o yaml | kubectl apply -f -

    # Install ArgoCD
    log_info "Installing ArgoCD..."
    kubectl apply -n "$NS_ARGOCD" -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

    # Wait for ArgoCD to be ready
    log_info "Waiting for ArgoCD to be ready..."
    kubectl wait --for=condition=available --timeout=600s \
        deployment/argocd-server -n "$NS_ARGOCD"

    # Configure ArgoCD polling interval (30 seconds)
    log_info "Configuring ArgoCD polling interval to 30 seconds..."
    kubectl patch configmap argocd-cm -n "$NS_ARGOCD" --type merge -p '{"data":{"timeout.reconciliation":"30s"}}'

    # Restart argocd-repo-server to apply changes
    kubectl rollout restart deployment argocd-repo-server -n "$NS_ARGOCD"
    kubectl rollout status deployment argocd-repo-server -n "$NS_ARGOCD" --timeout=120s

    # Get initial admin password
    log_info "Retrieving ArgoCD admin password..."
    kubectl wait --for=jsonpath='{.data.password}' --timeout=120s \
        secret/argocd-initial-admin-secret -n "$NS_ARGOCD"

    ARGOCD_PASSWORD=$(kubectl -n "$NS_ARGOCD" get secret argocd-initial-admin-secret \
        -o jsonpath="{.data.password}" | base64 -d)

    log_info "ArgoCD installed successfully!"
    echo ""
    log_info "ArgoCD Access:"
    echo "  Port-forward: kubectl port-forward svc/argocd-server -n $NS_ARGOCD 8080:443"
    echo "  Username: admin"
    echo "  Password: $ARGOCD_PASSWORD"
}

show_summary() {
    log_section "Bootstrap Summary"

    echo "Runners cluster bootstrapped successfully!"
    echo ""
    echo "Installed Components:"
    echo "  - External Secrets Operator (namespace: $NS_ESO)"
    echo "  - Actions Runner Controller (namespaces: $NS_ARC_SYSTEMS, $NS_ARC_RUNNERS)"
    echo "  - ArgoCD (namespace: $NS_ARGOCD)"
    echo ""
    echo "Runner Scale Sets:"
    echo "  - gameplatform-heavy (for all CI/CD jobs - Docker builds, tests, linting)"
    echo ""
    echo "Next Steps:"
    echo "  1. Access ArgoCD UI: kubectl port-forward svc/argocd-server -n $NS_ARGOCD 8080:443"
    echo "  2. Login with: admin / <password above>"
    echo "  3. Run: ./03-bootstrap-workloads.sh dev"
    echo "  4. Run: ./04-configure-argocd.sh"
    echo ""
    echo "To verify runners in GitHub:"
    echo "  https://github.com/organizations/example-gamedev-org/settings/actions/runners"
}

# =============================================================================
# Main
# =============================================================================

log_section "Bootstrap Runners Cluster"
log_info "Cluster: $CLUSTER_NAME"
log_info "Project: $PROJECT"
log_info "Region: $REGION"

check_prerequisites

echo ""
log_warn "This will install ESO, ARC, and ArgoCD on the runners cluster."
read -p "Continue? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 0
fi

install_eso
install_arc
install_argocd
show_summary
