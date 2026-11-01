#!/bin/bash

# Install cert-manager for automatic SSL certificate management
# Usage: ./install-cert-manager.sh [dev|stg|prd]

set -euo pipefail

ENV="${1:-dev}"

echo "Installing cert-manager for $ENV environment..."

# Add Jetstack Helm repository
helm repo add jetstack https://charts.jetstack.io
helm repo update

# Install cert-manager with CRDs
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set installCRDs=true \
  --set global.leaderElection.namespace=cert-manager \
  --wait

# Wait for cert-manager to be ready
echo "Waiting for cert-manager to be ready..."
kubectl wait --for=condition=available --timeout=300s \
  deployment/cert-manager -n cert-manager
kubectl wait --for=condition=available --timeout=300s \
  deployment/cert-manager-webhook -n cert-manager
kubectl wait --for=condition=available --timeout=300s \
  deployment/cert-manager-cainjector -n cert-manager

# Create ClusterIssuers for Let's Encrypt
case "$ENV" in
  dev)
    DOMAIN="dev-gameplatform.example.com"
    EMAIL="devops@gameplatform.example.com"
    ;;
  stg)
    DOMAIN="stg-gameplatform.example.com"
    EMAIL="devops@gameplatform.example.com"
    ;;
  prd)
    DOMAIN="gameplatform.example.com"
    EMAIL="devops@gameplatform.example.com"
    ;;
esac

# Create staging ClusterIssuer (for testing)
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: $EMAIL
    privateKeySecretRef:
      name: letsencrypt-staging
    solvers:
    - http01:
        ingress:
          class: gce
EOF

# Create production ClusterIssuer
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: $EMAIL
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: gce
EOF

# Create ManagedCertificate for GCP Load Balancer
cat <<EOF | kubectl apply -f -
apiVersion: networking.gke.io/v1
kind: ManagedCertificate
metadata:
  name: gameplatform-${ENV}-cert
spec:
  domains:
    - nakama.$DOMAIN
    - lobby.$DOMAIN
    - lobby-backend.$DOMAIN
    - afs.$DOMAIN
    - ahsat.$DOMAIN
    - aes.$DOMAIN
    - ais.$DOMAIN
EOF

echo "cert-manager installed successfully!"
echo ""
echo "Verify installation:"
echo "  kubectl get pods -n cert-manager"
echo "  kubectl get clusterissuer"
echo "  kubectl get managedcertificate"
echo ""
echo "SSL certificates will be automatically provisioned for:"
echo "  - nakama.$DOMAIN"
echo "  - lobby.$DOMAIN"
echo "  - lobby-backend.$DOMAIN"
echo "  - afs.$DOMAIN"
echo "  - ahsat.$DOMAIN"
echo "  - aes.$DOMAIN"
echo "  - ais.$DOMAIN"
