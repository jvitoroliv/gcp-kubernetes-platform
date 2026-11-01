#!/bin/bash
# =============================================================================
# Terraform Plan Script
# Plans Terraform changes for a specific stack and environment
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
    echo "Usage: $0 <stack-name> <environment> [--out=<planfile>]"
    echo ""
    echo "Arguments:"
    echo "  stack-name   Stack to plan (e.g., 01-foundation, 02-networking)"
    echo "  environment  Environment to use (dev, stg, prd)"
    echo ""
    echo "Options:"
    echo "  --out=FILE   Save plan to file for later apply"
    echo ""
    echo "Examples:"
    echo "  $0 01-foundation dev"
    echo "  $0 03-gke stg --out=plan.tfplan"
    exit 1
}

# Validate arguments
if [ $# -lt 2 ]; then
    echo -e "${RED}Error: Invalid number of arguments${NC}"
    usage
fi

STACK_NAME="$1"
ENVIRONMENT="$2"
PLAN_FILE=""

# Parse optional arguments
shift 2
while [[ $# -gt 0 ]]; do
    case $1 in
        --out=*)
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

echo -e "${GREEN}Planning Terraform changes...${NC}"
echo "  Stack:       $STACK_NAME"
echo "  Environment: $ENVIRONMENT"
echo ""

cd "$STACK_DIR"

# Build plan command
PLAN_CMD="terraform plan -var-file=$TFVARS_FILE"
if [ -n "$PLAN_FILE" ]; then
    PLAN_CMD="$PLAN_CMD -out=$PLAN_FILE"
fi

# Run plan
eval "$PLAN_CMD"

echo ""
if [ -n "$PLAN_FILE" ]; then
    echo -e "${GREEN}Plan saved to: $PLAN_FILE${NC}"
    echo "Apply with: terraform apply $PLAN_FILE"
fi
