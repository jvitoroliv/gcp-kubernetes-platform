#!/bin/bash

# Manual deployment script using Helm
# Usage: ./deploy.sh [dev|stg|prd] [tag]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

ENV="${1:-dev}"
TAG="${2:-latest}"

case "$ENV" in
  dev)
    PROJECT_ID="project-nonprod-env"
    CLUSTER_NAME="project-dev-workloads"
    NAMESPACE="gameplatform-dev"
    VALUES_FILE="values.yaml"
    DOMAIN="dev-gameplatform.example.com"
    REGION="us-east1"
    REGISTRY="us-east1-docker.pkg.dev/project-nonprod-env/project-dev-images"
    ;;
  stg)
    PROJECT_ID="project-nonprod-env"
    CLUSTER_NAME="project-stg-workloads"
    NAMESPACE="gameplatform-stg"
    VALUES_FILE="values-stg.yaml"
    DOMAIN="stg-gameplatform.example.com"
    REGION="us-east1"
    REGISTRY="us-east1-docker.pkg.dev/project-nonprod-env/project-stg-images"
    ;;
  prd)
    PROJECT_ID="project-prd-env"
    CLUSTER_NAME="project-prd-workloads"
    NAMESPACE="gameplatform-prd"
    VALUES_FILE="values-prd.yaml"
    DOMAIN="gameplatform.example.com"
    REGION="southamerica-east1"
    REGISTRY="southamerica-east1-docker.pkg.dev/project-prd-env/project-prd-images"
    ;;
  *)
    echo "Usage: $0 [dev|stg|prd] [tag]"
    exit 1
    ;;
esac

echo "Deploying GamePlatform Platform"
echo "Environment: $ENV"
echo "Tag: $TAG"
echo "Namespace: $NAMESPACE"
echo "Domain: $DOMAIN"
echo ""

# Confirm production deployment
if [ "$ENV" == "prd" ]; then
  read -p "Are you sure you want to deploy to PRODUCTION? Type 'yes' to confirm: " confirm
  if [ "$confirm" != "yes" ]; then
    echo "Deployment cancelled"
    exit 1
  fi
fi

# Get cluster credentials
echo "Getting cluster credentials..."
gcloud container clusters get-credentials "$CLUSTER_NAME" \
  --region="$REGION" \
  --project="$PROJECT_ID"

# Update Helm dependencies
echo "Updating Helm dependencies..."
cd "$REPO_ROOT/charts/game-platform"
helm dependency update

# Deploy with Helm
echo "Deploying with Helm..."
helm upgrade --install game-platform . \
  --namespace "$NAMESPACE" \
  --create-namespace \
  --values values.yaml \
  $([ "$ENV" != "dev" ] && echo "--values $VALUES_FILE") \
  --set global.imageRegistry="$REGISTRY" \
  --set nakama.image.tag="$TAG" \
  --set lobby.image.tag="$TAG" \
  --set lobby-backend.image.tag="$TAG" \
  --set afs.image.tag="$TAG" \
  --set ahsat.image.tag="$TAG" \
  --set aes.image.tag="$TAG" \
  --set ais.image.tag="$TAG" \
  --wait \
  --timeout=15m

# Verify deployment
echo ""
echo "Verifying deployment..."
kubectl get pods -n "$NAMESPACE"
kubectl get services -n "$NAMESPACE"
kubectl get ingress -n "$NAMESPACE"

# Run smoke tests
echo ""
echo "Running smoke tests..."
services=("nakama" "lobby" "afs" "ahsat" "aes" "ais")

for service in "${services[@]}"; do
  echo "Testing ${service}.$DOMAIN..."
  status=$(curl -f -s -o /dev/null -w "%{http_code}" "https://${service}.$DOMAIN/" 2>/dev/null || echo "0")
  if [ "$status" == "200" ] || [ "$status" == "301" ] || [ "$status" == "302" ]; then
    echo "  $service is healthy"
  else
    echo "  $service returned $status (may still be starting up)"
  fi
done

echo ""
echo "Deployment completed!"
echo ""
echo "Access your services:"
echo "  - Lobby: https://lobby.$DOMAIN"
echo "  - Nakama: https://nakama.$DOMAIN"
echo "  - Backend: https://lobby-backend.$DOMAIN"
echo ""
echo "Monitor deployment:"
echo "  kubectl get pods -n $NAMESPACE -w"
echo "  kubectl logs -f deployment/lobby -n $NAMESPACE"
