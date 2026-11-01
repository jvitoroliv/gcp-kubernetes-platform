#!/bin/bash

# Install ArgoCD for GitOps continuous deployment
# Usage: ./install-argocd.sh [dev|stg|prd]

set -euo pipefail

ENV="${1:-dev}"

echo "Installing ArgoCD for $ENV environment..."

# Create namespace
kubectl create namespace argocd || true

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready
echo "Waiting for ArgoCD to be ready..."
kubectl wait --for=condition=available --timeout=600s \
  deployment/argocd-server -n argocd

# Patch ArgoCD service to LoadBalancer (or use port-forward)
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

# Get initial admin password
echo ""
echo "Waiting for ArgoCD admin password secret..."
kubectl wait --for=jsonpath='{.data.password}' --timeout=120s \
  secret/argocd-initial-admin-secret -n argocd

ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

# Get ArgoCD server address
echo "Waiting for LoadBalancer IP..."
sleep 30
ARGOCD_SERVER=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

if [ -z "$ARGOCD_SERVER" ]; then
  echo "LoadBalancer IP not yet assigned. Using port-forward instead:"
  echo "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
  ARGOCD_SERVER="localhost:8080"
fi

echo "ArgoCD installed successfully!"
echo ""
echo "Access ArgoCD UI:"
echo "  URL: https://$ARGOCD_SERVER"
echo "  Username: admin"
echo "  Password: $ARGOCD_PASSWORD"
echo ""
echo "Login with CLI:"
echo "  argocd login $ARGOCD_SERVER --username admin --password $ARGOCD_PASSWORD --insecure"
echo ""
echo "Change admin password:"
echo "  argocd account update-password"
echo ""
echo "Deploy GamePlatform Platform:"
echo "  kubectl apply -f ../argocd/$ENV/application-$ENV.yaml"
