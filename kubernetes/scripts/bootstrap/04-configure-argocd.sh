#!/bin/bash
# =============================================================================
# Configure ArgoCD
# =============================================================================
# This script configures ArgoCD on the runners cluster to manage dev and stg:
#   1. Add repository credentials
#   2. Register remote clusters (dev-workloads, stg-workloads)
#   3. Apply ArgoCD Applications
#
# Prerequisites:
# - VPN connected
# - kubectl configured to point to gameplatform-nonprod-runners
# - ArgoCD installed (02-bootstrap-runners.sh)
# - Workloads clusters bootstrapped (03-bootstrap-workloads.sh)
# - argocd CLI installed
#
# Usage:
#   ./04-configure-argocd.sh
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Configuration
PROJECT="project-nonprod-env"
REGION="us-east1"
RUNNERS_CLUSTER="gameplatform-nonprod-runners"
DEV_CLUSTER="project-dev-workloads"
STG_CLUSTER="project-stg-workloads"

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
        log_error "kubectl not found."
        exit 1
    fi

    # Check argocd CLI
    if ! command -v argocd &>/dev/null; then
        log_warn "argocd CLI not found. Install it:"
        echo "  brew install argocd"
        echo "  OR"
        echo "  curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64"
        exit 1
    fi

    # Verify kubectl context (should be runners cluster)
    CURRENT_CONTEXT=$(kubectl config current-context 2>/dev/null || echo "")
    if [[ ! "$CURRENT_CONTEXT" =~ "runners" ]]; then
        log_warn "Current context: $CURRENT_CONTEXT"
        log_warn "Expected context to point to runners cluster."
        echo ""
        echo "Connect to runners cluster:"
        echo "  gcloud container clusters get-credentials $RUNNERS_CLUSTER \\"
        echo "    --region $REGION --project $PROJECT --internal-ip"
        echo ""
        read -p "Continue anyway? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi

    # Check ArgoCD is running
    if ! kubectl get deployment argocd-server -n argocd &>/dev/null; then
        log_error "ArgoCD not found in cluster. Run 02-bootstrap-runners.sh first."
        exit 1
    fi

    log_info "Prerequisites met!"
}

get_argocd_password() {
    log_info "Getting ArgoCD admin password..."
    ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret \
        -o jsonpath="{.data.password}" | base64 -d)

    if [[ -z "$ARGOCD_PASSWORD" ]]; then
        log_error "Could not get ArgoCD password."
        exit 1
    fi
}

setup_port_forward() {
    log_info "Setting up port-forward to ArgoCD server..."

    # Kill any existing port-forward
    pkill -f "kubectl.*port-forward.*argocd-server" 2>/dev/null || true
    sleep 1

    # Start port-forward in background
    kubectl port-forward svc/argocd-server -n argocd 8080:443 &>/dev/null &
    PF_PID=$!

    # Wait for port-forward to be ready
    sleep 3

    if ! kill -0 $PF_PID 2>/dev/null; then
        log_error "Port-forward failed to start."
        exit 1
    fi

    log_info "Port-forward running on localhost:8080 (PID: $PF_PID)"
}

login_argocd() {
    log_section "Logging into ArgoCD"

    log_info "Logging in as admin..."
    if ! argocd login localhost:8080 \
        --username admin \
        --password "$ARGOCD_PASSWORD" \
        --insecure; then
        log_error "Failed to login to ArgoCD."
        exit 1
    fi

    log_info "Logged in successfully!"
}

add_repository() {
    log_section "Adding Repository Credentials"

    echo ""
    log_info "ArgoCD needs credentials to access the private GitHub repository."
    echo ""

    # Check if repo already exists
    if argocd repo list | grep -q "platform-kubernetes-infrastructure"; then
        log_warn "Repository already configured."
        return 0
    fi

    echo "Enter GitHub username (e.g., jvitoroliv-gameplatform): "
    read -r GITHUB_USER

    echo "Enter GitHub PAT (with repo read access): "
    read -s GITHUB_PAT
    echo ""

    log_info "Adding repository..."
    argocd repo add https://github.com/example-gamedev-org/platform-kubernetes-infrastructure.git \
        --username "$GITHUB_USER" \
        --password "$GITHUB_PAT"

    log_info "Repository added successfully!"
}

register_cluster() {
    local cluster_name="$1"
    local friendly_name="$2"

    log_info "Registering cluster: $cluster_name as $friendly_name"

    # Check if cluster already registered
    if argocd cluster list | grep -q "$friendly_name"; then
        log_warn "Cluster $friendly_name already registered."
        return 0
    fi

    # Get cluster credentials
    log_info "Getting credentials for $cluster_name..."
    gcloud container clusters get-credentials "$cluster_name" \
        --region "$REGION" \
        --project "$PROJECT" \
        --internal-ip

    # Add cluster to ArgoCD
    local context="gke_${PROJECT}_${REGION}_${cluster_name}"

    log_info "Adding cluster to ArgoCD..."
    argocd cluster add "$context" \
        --name "$friendly_name" \
        --yes

    log_info "Cluster $friendly_name registered!"
}

register_clusters() {
    log_section "Registering Remote Clusters"

    register_cluster "$DEV_CLUSTER" "$DEV_CLUSTER"
    register_cluster "$STG_CLUSTER" "$STG_CLUSTER"

    # Switch back to runners cluster
    log_info "Switching back to runners cluster..."
    gcloud container clusters get-credentials "$RUNNERS_CLUSTER" \
        --region "$REGION" \
        --project "$PROJECT" \
        --internal-ip

    log_info "All clusters registered!"
    argocd cluster list
}

apply_applications() {
    log_section "Applying ArgoCD Applications"

    # Apply dev application
    log_info "Applying dev application..."
    kubectl apply -f "$REPO_ROOT/argocd/dev/application-dev.yaml"

    # Apply stg application
    log_info "Applying stg application..."
    kubectl apply -f "$REPO_ROOT/argocd/stg/application-stg.yaml"

    log_info "Applications applied!"

    # Show status
    echo ""
    argocd app list
}

cleanup() {
    log_info "Cleaning up port-forward..."
    pkill -f "kubectl.*port-forward.*argocd-server" 2>/dev/null || true
}

show_summary() {
    log_section "Configuration Summary"

    echo "ArgoCD configured successfully!"
    echo ""
    echo "Registered Clusters:"
    echo "  - $DEV_CLUSTER (gameplatform-dev namespace)"
    echo "  - $STG_CLUSTER (gameplatform-stg namespace)"
    echo ""
    echo "Applications:"
    echo "  - game-platform-dev (auto-sync enabled)"
    echo "  - game-platform-stg (auto-sync enabled)"
    echo ""
    echo "Access ArgoCD UI:"
    echo "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
    echo "  https://localhost:8080"
    echo "  Username: admin"
    echo "  Password: $ARGOCD_PASSWORD"
    echo ""
    echo "ArgoCD CLI commands:"
    echo "  argocd app list"
    echo "  argocd app sync game-platform-dev"
    echo "  argocd app sync game-platform-stg"
    echo ""
    echo "Next Steps:"
    echo "  1. Trigger build workflow in gameplatform-monorepo to build images"
    echo "  2. Sync configmaps workflow to deploy environment variables"
    echo "  3. ArgoCD will automatically deploy applications"
}

# =============================================================================
# Main
# =============================================================================

trap cleanup EXIT

log_section "Configure ArgoCD"
log_info "Runners Cluster: $RUNNERS_CLUSTER"
log_info "Dev Cluster: $DEV_CLUSTER"
log_info "Stg Cluster: $STG_CLUSTER"

check_prerequisites
get_argocd_password
setup_port_forward
login_argocd
add_repository
register_clusters
apply_applications
show_summary
