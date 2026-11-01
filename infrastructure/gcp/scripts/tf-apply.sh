#!/bin/bash
# =============================================================================
# Terraform Apply Script
# Applies Terraform changes for a specific stack and environment
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
    echo "Usage: $0 <stack-name> <environment> [--auto-approve] [--plan=<planfile>]"
    echo ""
    echo "Arguments:"
    echo "  stack-name   Stack to apply (e.g., 01-foundation, 02-networking)"
    echo "  environment  Environment to use (dev, stg, prd)"
    echo ""
    echo "Options:"
    echo "  --auto-approve  Skip interactive approval"
    echo "  --plan=FILE     Apply from a saved plan file"
    echo ""
    echo "Examples:"
    echo "  $0 01-foundation dev"
    echo "  $0 03-gke stg --auto-approve"
    echo "  $0 04-database prd --plan=plan.tfplan"
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
PLAN_FILE=""

# Parse optional arguments
shift 2
while [[ $# -gt 0 ]]; do
    case $1 in
        --auto-approve)
            AUTO_APPROVE="-auto-approve"
            shift
            ;;
        --plan=*)
            PLAN_FILE="${1#*=}"
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

# Extra confirmation for prd environment
if [ "$ENVIRONMENT" = "prd" ] && [ -z "$AUTO_APPROVE" ]; then
    echo -e "${YELLOW}WARNING: You are about to apply changes to PRD (production) environment!${NC}"
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

echo -e "${GREEN}Applying Terraform changes...${NC}"
echo "  Stack:       $STACK_NAME"
echo "  Environment: $ENVIRONMENT"
echo ""

cd "$STACK_DIR"

# Build apply command
if [ -n "$PLAN_FILE" ]; then
    APPLY_CMD="terraform apply $AUTO_APPROVE $PLAN_FILE"
else
    APPLY_CMD="terraform apply -var-file=$TFVARS_FILE $AUTO_APPROVE"
fi

# Run apply
eval "$APPLY_CMD"

echo ""
echo -e "${GREEN}Apply completed successfully!${NC}"
