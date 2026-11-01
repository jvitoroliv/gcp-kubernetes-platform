#!/bin/bash

# Install External Secrets Operator for GCP Secret Manager
# Usage: ./install-external-secrets.sh [dev|stg|prd]

set -euo pipefail

ENV="${1:-dev}"

case "$ENV" in
  dev)
    PROJECT_ID="project-nonprod-env"
    REGION="us-east1"
    ;;
  stg)
    PROJECT_ID="project-nonprod-env"
    REGION="us-east1"
    ;;
  prd)
    PROJECT_ID="project-prd-env"
    REGION="southamerica-east1"
    ;;
  *)
    echo "Usage: $0 [dev|stg|prd]"
    exit 1
    ;;
esac

echo "Installing External Secrets Operator for $ENV..."

# Add Helm repository
helm repo add external-secrets https://charts.external-secrets.io
helm repo update

# Install External Secrets Operator
helm upgrade --install external-secrets \
  external-secrets/external-secrets \
  --namespace external-secrets-system \
  --create-namespace \
  --set installCRDs=true \
  --set webhook.port=9443 \
  --wait

# Wait for operator to be ready
echo "Waiting for External Secrets Operator to be ready..."
kubectl wait --for=condition=available --timeout=300s \
  deployment/external-secrets -n external-secrets-system

# Create GCP service account for Workload Identity
SA_NAME="external-secrets-sa"
K8S_SA_NAME="external-secrets-sa"
NAMESPACE="external-secrets-system"

echo "Creating GCP service account..."
gcloud iam service-accounts create "$SA_NAME" \
  --display-name="External Secrets Operator" \
  --project="$PROJECT_ID" || true

# Grant Secret Manager access
echo "Granting Secret Manager permissions..."
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:$SA_NAME@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"

# Bind Kubernetes SA to GCP SA (Workload Identity)
echo "Configuring Workload Identity..."
gcloud iam service-accounts add-iam-policy-binding \
  "$SA_NAME@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/iam.workloadIdentityUser" \
  --member="serviceAccount:$PROJECT_ID.svc.id.goog[$NAMESPACE/$K8S_SA_NAME]"

# Create Kubernetes service account
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: $K8S_SA_NAME
  namespace: $NAMESPACE
  annotations:
    iam.gke.io/gcp-service-account: $SA_NAME@$PROJECT_ID.iam.gserviceaccount.com
EOF

# Apply ClusterSecretStore
echo "Creating ClusterSecretStore..."
cat <<EOF | kubectl apply -f -
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: gcp-secret-manager
spec:
  provider:
    gcpsm:
      projectID: "$PROJECT_ID"
      auth:
        workloadIdentity:
          clusterLocation: $REGION
          clusterName: gameplatform-$ENV-workloads
          serviceAccountRef:
            name: $K8S_SA_NAME
            namespace: $NAMESPACE
EOF

echo "External Secrets Operator installed successfully!"
echo ""
echo "Verify installation:"
echo "  kubectl get pods -n external-secrets-system"
echo "  kubectl get clustersecretstore"
echo ""
echo "Next: Create ExternalSecret resources to sync secrets from GCP Secret Manager"
