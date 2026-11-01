#!/bin/bash

# Setup GKE cluster for GamePlatform Platform
# Usage: ./setup-cluster.sh [dev|stg|prd]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV="${1:-dev}"

# Configuration based on environment
case "$ENV" in
  dev)
    PROJECT_ID="project-nonprod-env"
    CLUSTER_NAME="project-dev-workloads"
    NODE_COUNT=3
    MACHINE_TYPE="e2-standard-4"
    REGION="us-east1"
    ;;
  stg)
    PROJECT_ID="project-nonprod-env"
    CLUSTER_NAME="project-stg-workloads"
    NODE_COUNT=5
    MACHINE_TYPE="e2-standard-8"
    REGION="us-east1"
    ;;
  prd)
    PROJECT_ID="project-prd-env"
    CLUSTER_NAME="project-prd-workloads"
    NODE_COUNT=10
    MACHINE_TYPE="n2-standard-8"
    REGION="southamerica-east1"
    ;;
  *)
    echo "Usage: $0 [dev|stg|prd]"
    exit 1
    ;;
esac

echo "Setting up GKE cluster for $ENV environment"
echo "Project: $PROJECT_ID"
echo "Cluster: $CLUSTER_NAME"
echo "Region: $REGION"

# Set project
gcloud config set project "$PROJECT_ID"

# Enable required APIs
echo "Enabling required GCP APIs..."
gcloud services enable \
  container.googleapis.com \
  compute.googleapis.com \
  artifactregistry.googleapis.com \
  cloudresourcemanager.googleapis.com \
  secretmanager.googleapis.com \
  sqladmin.googleapis.com \
  servicenetworking.googleapis.com

# Create GKE cluster
echo "Creating GKE cluster..."
gcloud container clusters create "$CLUSTER_NAME" \
  --region="$REGION" \
  --num-nodes="$NODE_COUNT" \
  --machine-type="$MACHINE_TYPE" \
  --disk-size=100 \
  --disk-type=pd-standard \
  --enable-autoscaling \
  --min-nodes=2 \
  --max-nodes=20 \
  --enable-autorepair \
  --enable-autoupgrade \
  --enable-ip-alias \
  --network=default \
  --subnetwork=default \
  --enable-stackdriver-kubernetes \
  --enable-cloud-logging \
  --enable-cloud-monitoring \
  --addons=HorizontalPodAutoscaling,HttpLoadBalancing,GcePersistentDiskCsiDriver \
  --workload-pool="$PROJECT_ID.svc.id.goog" \
  --enable-shielded-nodes \
  --shielded-secure-boot \
  --shielded-integrity-monitoring \
  --release-channel=regular

# Get credentials
echo "Getting cluster credentials..."
gcloud container clusters get-credentials "$CLUSTER_NAME" --region="$REGION"

# Create namespaces
echo "Creating namespaces..."
kubectl create namespace "gameplatform-$ENV" || true
kubectl create namespace argocd || true
kubectl create namespace external-secrets-system || true
kubectl create namespace cert-manager || true

# Label namespaces
kubectl label namespace "gameplatform-$ENV" environment="$ENV" --overwrite
kubectl label namespace "gameplatform-$ENV" istio-injection=enabled --overwrite || true

echo "GKE cluster setup complete!"
echo ""
echo "Next steps:"
echo "  1. Run ./install-external-secrets.sh $ENV"
echo "  2. Run ./install-cert-manager.sh $ENV"
echo "  3. Run ./install-argocd.sh $ENV"
echo "  4. Configure DNS and SSL certificates"
echo "  5. Deploy applications with ArgoCD or Helm"
