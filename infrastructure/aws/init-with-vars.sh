#!/bin/bash
set -euo pipefail

# Script to initialize Terraform with the correct variables for Atlantis
# This script must be used by Atlantis during the init process

# Detect which stack we are on
STACK_NAME=$(basename "$PWD")
ENVIRONMENT=${ENVIRONMENT:-dev}

echo "🔧 Initializing Terraform for stack: $STACK_NAME, environment: $ENVIRONMENT"

# Check if we are in a valid stack directory
if [ ! -f "backend.tf" ]; then
    echo "❌ Error: Not in a valid Terraform stack directory (missing backend.tf)"
    exit 1
fi

# Find variables file
TFVARS_FILE="../../environments/$ENVIRONMENT/$STACK_NAME.tfvars"

echo "📁 Looking for tfvars file: $TFVARS_FILE"

if [ -f "$TFVARS_FILE" ]; then
    echo "✅ Found tfvars file: $TFVARS_FILE"
    
    # Run terraform plan with variables file
    echo "🚀 Running terraform plan with variables..."
    terraform plan -var-file="$TFVARS_FILE" -out=terraform.tfplan
else
    echo "⚠️  No tfvars file found, running plan without additional variables"
    terraform plan -out=terraform.tfplan
fi

echo "✅ Terraform plan completed successfully!"
echo "💾 Plan file saved as: terraform.tfplan"