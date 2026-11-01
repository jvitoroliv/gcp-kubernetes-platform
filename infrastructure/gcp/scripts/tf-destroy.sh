#!/bin/bash
# =============================================================================
# Terraform Destroy Script
# Destroys Terraform resources for a specific stack and environment
# USE WITH EXTREME CAUTION!
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# Usage function
usage() {
    echo "Usage: $0 <stack-name> <environment> [--auto-approve]"
    echo ""
    echo "Arguments:"
    echo "  stack-name   Stack to destroy (e.g., 01-foundation, 02-networking)"
    echo "  environment  Environment to use (dev, stg, prd)"
    echo ""
    echo "Options:"
    echo "  --auto-approve  Skip interactive approval (DANGEROUS!)"
    echo ""
    echo "Examples:"
    echo "  $0 01-foundation dev"
    echo "  $0 03-gke stg"
    exit 1
}

# Validate arguments
if [ $# -lt 2 ]; then
    echo -e "${RED}Error: Invalid number of arguments${NC}"
    usage
fi

STACK_NAME="$1"
ENVIRONMENT="$2"
AUTO_APPROVE=""

# Parse optional arguments
shift 2
while [[ $# -gt 0 ]]; do
    case $1 in
        --auto-approve)
            AUTO_APPROVE="-auto-approve"
            shift
            ;;
        *)
            echo -e "${RED}Error: Unknown option $1${NC}"
            usage
            ;;
    esac
done

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(dev|stg|prd)$ ]]; then
    echo -e "${RED}Error: Invalid environment '$ENVIRONMENT'. Must be dev, stg, or prd${NC}"
    exit 1
fi

# Block destroy on prd unless explicitly confirmed
if [ "$ENVIRONMENT" = "prd" ]; then
    echo -e "${RED}============================================================${NC}"
    echo -e "${RED}DANGER: YOU ARE ABOUT TO DESTROY PRODUCTION RESOURCES!${NC}"
    echo -e "${RED}============================================================${NC}"
    echo ""
    echo "This action will destroy all resources in the $STACK_NAME stack"
    echo "for the PRD (production) environment."
    echo ""
    echo "This action is IRREVERSIBLE and may cause data loss!"
    echo ""
    read -p "Type 'destroy-prd-$STACK_NAME' to confirm: " confirm
    if [ "$confirm" != "destroy-prd-$STACK_NAME" ]; then
        echo "Aborted."
        exit 0
    fi
fi

# Extra confirmation for stg
if [ "$ENVIRONMENT" = "stg" ] && [ -z "$AUTO_APPROVE" ]; then
    echo -e "${YELLOW}WARNING: You are about to destroy resources in STG environment!${NC}"
    read -p "Are you sure you want to continue? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        echo "Aborted."
        exit 0
    fi
fi

# Validate stack exists
STACK_DIR="$ROOT_DIR/stacks/$STACK_NAME"
if [ ! -d "$STACK_DIR" ]; then
    echo -e "${RED}Error: Stack '$STACK_NAME' not found at $STACK_DIR${NC}"
    exit 1
fi

# Validate tfvars exists
TFVARS_FILE="$ROOT_DIR/environments/$ENVIRONMENT/$STACK_NAME.tfvars"
if [ ! -f "$TFVARS_FILE" ]; then
    echo -e "${RED}Error: tfvars file not found at $TFVARS_FILE${NC}"
    exit 1
fi

echo -e "${RED}Destroying Terraform resources...${NC}"
echo "  Stack:       $STACK_NAME"
echo "  Environment: $ENVIRONMENT"
echo ""

cd "$STACK_DIR"

# Run destroy
terraform destroy -var-file="$TFVARS_FILE" $AUTO_APPROVE

echo ""
echo -e "${GREEN}Destroy completed.${NC}"
