#!/bin/bash
# =============================================================================
# Terraform Init Script
# Initializes Terraform for a specific stack and environment
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
    echo "Usage: $0 <stack-name> <environment>"
    echo ""
    echo "Arguments:"
    echo "  stack-name   Stack to initialize (e.g., 01-foundation, 02-networking)"
    echo "  environment  Environment to use (dev, stg, prd)"
    echo ""
    echo "Examples:"
    echo "  $0 01-foundation dev"
    echo "  $0 03-gke stg"
    echo "  $0 04-database prd"
    exit 1
}

# Validate arguments
if [ $# -ne 2 ]; then
    echo -e "${RED}Error: Invalid number of arguments${NC}"
    usage
fi

STACK_NAME="$1"
ENVIRONMENT="$2"

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(dev|stg|prd)$ ]]; then
    echo -e "${RED}Error: Invalid environment '$ENVIRONMENT'. Must be dev, stg, or prd${NC}"
    exit 1
fi

# Validate stack exists
STACK_DIR="$ROOT_DIR/stacks/$STACK_NAME"
if [ ! -d "$STACK_DIR" ]; then
    echo -e "${RED}Error: Stack '$STACK_NAME' not found at $STACK_DIR${NC}"
    echo ""
    echo "Available stacks:"
    ls -1 "$ROOT_DIR/stacks/"
    exit 1
fi

# Validate backend config exists
BACKEND_CONFIG="$ROOT_DIR/environments/$ENVIRONMENT/$STACK_NAME-backend.hcl"
if [ ! -f "$BACKEND_CONFIG" ]; then
    echo -e "${RED}Error: Backend config not found at $BACKEND_CONFIG${NC}"
    exit 1
fi

echo -e "${GREEN}Initializing Terraform...${NC}"
echo "  Stack:       $STACK_NAME"
echo "  Environment: $ENVIRONMENT"
echo "  Directory:   $STACK_DIR"
echo ""

cd "$STACK_DIR"

# Initialize Terraform with backend config
terraform init \
    -backend-config="$BACKEND_CONFIG" \
    -reconfigure

echo ""
echo -e "${GREEN}Terraform initialized successfully!${NC}"
echo ""
echo "Next steps:"
echo "  - Run 'terraform plan' to see changes"
echo "  - Run 'terraform apply' to apply changes"
