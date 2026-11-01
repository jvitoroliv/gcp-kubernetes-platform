#!/bin/bash
# Bootstrap S3 Terraform State for Live Environment
# This script creates empty state files in S3 to fix the 403 errors

set -e

BUCKET="gameplatform-terraform-state-live"
REGION="sa-east-1"

# Array of state file paths from backend HCL files
STATE_KEYS=(
    "networking/terraform.tfstate"
    "dns-and-alb/terraform.tfstate"
    "atlantis/terraform.tfstate"
    "postgres/terraform.tfstate"
    "runners/terraform.tfstate"
    "live-env/terraform.tfstate"
)

echo "🚀 Bootstrapping S3 Terraform state for live environment"
echo "📦 Bucket: $BUCKET"
echo "🌎 Region: $REGION"
echo

# Check if bucket exists
if ! aws s3 ls "s3://$BUCKET" --region "$REGION" >/dev/null 2>&1; then
    echo "❌ Bucket $BUCKET does not exist!"
    echo "Creating bucket..."
    aws s3 mb "s3://$BUCKET" --region "$REGION"

    # Enable versioning
    echo "Enabling versioning..."
    aws s3api put-bucket-versioning \
        --bucket "$BUCKET" \
        --versioning-configuration Status=Enabled \
        --region "$REGION"

    # Enable encryption
    echo "Enabling encryption..."
    aws s3api put-bucket-encryption \
        --bucket "$BUCKET" \
        --server-side-encryption-configuration '{
            "Rules": [
                {
                    "ApplyServerSideEncryptionByDefault": {
                        "SSEAlgorithm": "AES256"
                    }
                }
            ]
        }' \
        --region "$REGION"

    echo "✅ Bucket created and configured"
else
    echo "✅ Bucket $BUCKET exists"
fi

echo
echo "🔍 Checking existing state files..."

# Create empty state files for each stack
for key in "${STATE_KEYS[@]}"; do
    echo -n "📁 $key ... "

    # Check if state file already exists
    if aws s3 ls "s3://$BUCKET/$key" --region "$REGION" >/dev/null 2>&1; then
        echo "EXISTS ✅"
    else
        echo "CREATING 🆕"

        # Create minimal empty Terraform state
        cat > /tmp/empty_state.json << 'EOF'
{
    "version": 4,
    "terraform_version": "1.6.0",
    "serial": 1,
    "lineage": "00000000-0000-0000-0000-000000000000",
    "outputs": {},
    "resources": []
}
EOF

        # Upload empty state to S3
        aws s3 cp /tmp/empty_state.json "s3://$BUCKET/$key" \
            --region "$REGION" \
            --server-side-encryption AES256

        echo "    ✅ Empty state created"
    fi
done

echo
echo "🎉 Bootstrap complete! All state files are now available."
echo
echo "📋 Summary:"
echo "   Bucket: $BUCKET"
echo "   Region: $REGION"
echo "   State files: ${#STATE_KEYS[@]}"
echo
echo "🚀 You can now run terraform init without 403 errors!"

# Cleanup temp file
rm -f /tmp/empty_state.json