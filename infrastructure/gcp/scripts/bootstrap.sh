#!/bin/bash
# =============================================================================
# Bootstrap Script
# Creates the GCS bucket for Terraform state storage
# Run this ONCE before using Terraform
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
BUCKET_NAME="gameplatform-terraform-state"
BUCKET_LOCATION="southamerica-east1"
PROJECT_ID="${GCP_PROJECT_ID:-}"

# Usage function
usage() {
    echo "Usage: GCP_PROJECT_ID=<project-id> $0"
    echo ""
    echo "Environment variables:"
    echo "  GCP_PROJECT_ID  GCP project ID where the state bucket will be created"
    echo ""
    echo "Prerequisites:"
    echo "  - gcloud CLI installed and authenticated"
    echo "  - Appropriate IAM permissions to create GCS buckets"
    echo ""
    echo "Example:"
    echo "  GCP_PROJECT_ID=gameplatform-dev $0"
    exit 1
}

# Validate project ID
if [ -z "$PROJECT_ID" ]; then
    echo -e "${RED}Error: GCP_PROJECT_ID environment variable not set${NC}"
    usage
fi

echo -e "${GREEN}Bootstrapping Terraform state storage...${NC}"
echo "  Project:  $PROJECT_ID"
echo "  Bucket:   gs://$BUCKET_NAME"
echo "  Location: $BUCKET_LOCATION"
echo ""

# Set project
gcloud config set project "$PROJECT_ID"

# Check if bucket already exists
if gsutil ls -b "gs://$BUCKET_NAME" &>/dev/null; then
    echo -e "${YELLOW}Bucket gs://$BUCKET_NAME already exists${NC}"
else
    echo "Creating bucket..."
    gsutil mb -p "$PROJECT_ID" -l "$BUCKET_LOCATION" -b on "gs://$BUCKET_NAME"
    echo -e "${GREEN}Bucket created successfully${NC}"
fi

# Enable versioning
echo "Enabling versioning..."
gsutil versioning set on "gs://$BUCKET_NAME"

# Set lifecycle policy to delete old versions
echo "Setting lifecycle policy..."
cat > /tmp/lifecycle.json << EOF
{
  "lifecycle": {
    "rule": [
      {
        "action": {"type": "Delete"},
        "condition": {
          "numNewerVersions": 5,
          "isLive": false
        }
      }
    ]
  }
}
EOF
gsutil lifecycle set /tmp/lifecycle.json "gs://$BUCKET_NAME"
rm /tmp/lifecycle.json

# Enable uniform bucket-level access
echo "Enabling uniform bucket-level access..."
gsutil uniformbucketlevelaccess set on "gs://$BUCKET_NAME"

echo ""
echo -e "${GREEN}Bootstrap completed successfully!${NC}"
echo ""
echo "Next steps:"
echo "  1. Update backend.tf files if the bucket name is different"
echo "  2. Run ./scripts/tf-init.sh <stack-name> <environment>"
