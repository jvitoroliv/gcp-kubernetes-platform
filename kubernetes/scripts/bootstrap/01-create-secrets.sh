#!/bin/bash
# =============================================================================
# Create GCP Secret Manager Secrets
# =============================================================================
# This script creates all required secrets in GCP Secret Manager for an environment.
# Run this AFTER Terraform stacks 01-06 are applied.
#
# Prerequisites:
# - gcloud CLI authenticated with appropriate permissions
# - Project ID set correctly
#
# Usage:
#   ./01-create-secrets.sh dev    # Create dev secrets
#   ./01-create-secrets.sh stg    # Create stg secrets
#   ./01-create-secrets.sh prd    # Create prd secrets
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_section() { echo -e "\n${BLUE}=== $1 ===${NC}\n"; }

show_usage() {
    echo "Usage: $0 <environment>"
    echo ""
    echo "Arguments:"
    echo "  dev    Create secrets for development environment"
    echo "  stg    Create secrets for staging environment"
    echo "  prd    Create secrets for production environment"
    echo ""
    echo "Examples:"
    echo "  $0 dev"
    echo ""
    echo "NOTE: Database secrets (gameplatform-{env}-db-*) are created by Terraform 04-database."
    echo "      This script creates application-level secrets only."
}

create_secret() {
    local secret_name="$1"
    local secret_value="$2"
    local project="$3"

    if gcloud secrets describe "$secret_name" --project="$project" &>/dev/null; then
        log_warn "Secret $secret_name already exists, adding new version..."
        printf '%s' "$secret_value" | gcloud secrets versions add "$secret_name" \
            --data-file=- --project="$project"
    else
        log_info "Creating secret: $secret_name"
        printf '%s' "$secret_value" | gcloud secrets create "$secret_name" \
            --data-file=- --project="$project" --replication-policy="automatic"
    fi
}

create_secret_placeholder() {
    local secret_name="$1"
    local project="$2"

    if gcloud secrets describe "$secret_name" --project="$project" &>/dev/null; then
        log_warn "Secret $secret_name already exists, skipping..."
        return 0
    fi

    log_info "Creating placeholder secret: $secret_name (update with real value later)"
    printf '%s' "PLACEHOLDER_UPDATE_ME" | gcloud secrets create "$secret_name" \
        --data-file=- --project="$project" --replication-policy="automatic"
}

prompt_secret() {
    local prompt_text="$1"
    local secret_var="$2"

    echo -n "$prompt_text: "
    read -s value
    echo ""
    eval "$secret_var=\"\$value\""
}

# =============================================================================
# Main
# =============================================================================

if [[ $# -lt 1 ]]; then
    show_usage
    exit 1
fi

ENV="$1"

# Validate environment
case "$ENV" in
    dev|stg)
        PROJECT="project-nonprod-env"
        ;;
    prd)
        PROJECT="project-prd-env"
        ;;
    *)
        log_error "Invalid environment: $ENV"
        show_usage
        exit 1
        ;;
esac

SECRET_PREFIX="gameplatform-${ENV}"

log_section "Creating Secrets for $ENV Environment"
log_info "Project: $PROJECT"
log_info "Secret Prefix: $SECRET_PREFIX"
echo ""

# Verify project access
log_info "Verifying project access..."
if ! gcloud projects describe "$PROJECT" &>/dev/null; then
    log_error "Cannot access project $PROJECT. Check your gcloud authentication."
    exit 1
fi

# =============================================================================
# NAKAMA Secrets
# =============================================================================
log_section "Nakama Secrets"

echo "Generate random keys for Nakama? (y/N): "
read -r generate_nakama
if [[ "$generate_nakama" =~ ^[Yy]$ ]]; then
    NAKAMA_HTTP_KEY=$(openssl rand -hex 32)
    NAKAMA_SERVER_KEY=$(openssl rand -hex 32)
    log_info "Generated random keys for Nakama"
else
    prompt_secret "Enter Nakama HTTP Key" NAKAMA_HTTP_KEY
    prompt_secret "Enter Nakama Server Key" NAKAMA_SERVER_KEY
fi

create_secret "${SECRET_PREFIX}-nakama-http-key" "$NAKAMA_HTTP_KEY" "$PROJECT"
create_secret "${SECRET_PREFIX}-nakama-server-key" "$NAKAMA_SERVER_KEY" "$PROJECT"

# =============================================================================
# AES (Encryption) Secrets
# =============================================================================
log_section "Encryption Secrets"

echo "Generate random AES encryption key? (y/N): "
read -r generate_aes
if [[ "$generate_aes" =~ ^[Yy]$ ]]; then
    AES_ENCRYPTION_KEY=$(openssl rand -base64 32)
    log_info "Generated random AES encryption key"
else
    prompt_secret "Enter AES Encryption Key" AES_ENCRYPTION_KEY
fi

create_secret "${SECRET_PREFIX}-aes-encryption-key" "$AES_ENCRYPTION_KEY" "$PROJECT"

# =============================================================================
# OAuth Secrets
# =============================================================================
log_section "OAuth Secrets"

prompt_secret "Enter Google OAuth Client ID" GOOGLE_CLIENT_ID
prompt_secret "Enter Google OAuth Client Secret" GOOGLE_CLIENT_SECRET

echo "Generate random NextAuth secret? (y/N): "
read -r generate_nextauth
if [[ "$generate_nextauth" =~ ^[Yy]$ ]]; then
    NEXTAUTH_SECRET=$(openssl rand -base64 32)
    log_info "Generated random NextAuth secret"
else
    prompt_secret "Enter NextAuth Secret" NEXTAUTH_SECRET
fi

create_secret "${SECRET_PREFIX}-google-client-id" "$GOOGLE_CLIENT_ID" "$PROJECT"
create_secret "${SECRET_PREFIX}-google-client-secret" "$GOOGLE_CLIENT_SECRET" "$PROJECT"
create_secret "${SECRET_PREFIX}-nextauth-secret" "$NEXTAUTH_SECRET" "$PROJECT"

# =============================================================================
# Email Service (AES) Secrets
# =============================================================================
log_section "Email Service Secrets"

echo "Generate random AES API key? (y/N): "
read -r generate_aes_api
if [[ "$generate_aes_api" =~ ^[Yy]$ ]]; then
    AES_API_KEY=$(openssl rand -hex 32)
    log_info "Generated random AES API key"
else
    prompt_secret "Enter AES API Key" AES_API_KEY
fi

prompt_secret "Enter SMTP Username" SMTP_USER
prompt_secret "Enter SMTP Password" SMTP_PASSWORD

create_secret "${SECRET_PREFIX}-aes-api-key" "$AES_API_KEY" "$PROJECT"
create_secret "${SECRET_PREFIX}-smtp-user" "$SMTP_USER" "$PROJECT"
create_secret "${SECRET_PREFIX}-smtp-password" "$SMTP_PASSWORD" "$PROJECT"

# =============================================================================
# AI Service Secrets
# =============================================================================
log_section "AI Service Secrets"

prompt_secret "Enter AI API Key (OpenAI/Anthropic)" AI_API_KEY

echo "Generate random AIS App Secret? (y/N): "
read -r generate_ais
if [[ "$generate_ais" =~ ^[Yy]$ ]]; then
    AIS_APP_SECRET=$(openssl rand -hex 32)
    log_info "Generated random AIS App secret"
else
    prompt_secret "Enter AIS App Secret" AIS_APP_SECRET
fi

prompt_secret "Enter PIAPI Key" PIAPI_KEY
prompt_secret "Enter Gemini API Key" GEMINI_API_KEY

create_secret "${SECRET_PREFIX}-ai-api-key" "$AI_API_KEY" "$PROJECT"
create_secret "${SECRET_PREFIX}-ais-app-secret" "$AIS_APP_SECRET" "$PROJECT"
create_secret "${SECRET_PREFIX}-piapi-key" "$PIAPI_KEY" "$PROJECT"
create_secret "${SECRET_PREFIX}-gemini-api-key" "$GEMINI_API_KEY" "$PROJECT"

# =============================================================================
# Payment Service (APS/Yuno) Secrets
# =============================================================================
log_section "Payment Service Secrets"

prompt_secret "Enter Yuno Public Key" YUNO_PUBLIC_KEY
prompt_secret "Enter Yuno Private Key" YUNO_PRIVATE_KEY
prompt_secret "Enter Yuno Account ID" YUNO_ACCOUNT_ID

create_secret "${SECRET_PREFIX}-yuno-public-key" "$YUNO_PUBLIC_KEY" "$PROJECT"
create_secret "${SECRET_PREFIX}-yuno-private-key" "$YUNO_PRIVATE_KEY" "$PROJECT"
create_secret "${SECRET_PREFIX}-yuno-account-id" "$YUNO_ACCOUNT_ID" "$PROJECT"

# =============================================================================
# GCS (S3-compatible) Secrets - Placeholders
# =============================================================================
log_section "GCS HMAC Keys (Placeholders)"

log_warn "GCS HMAC keys should be created via GCP Console or Terraform."
log_warn "Creating placeholder secrets - update with real values later."

create_secret_placeholder "${SECRET_PREFIX}-gcs-access-key" "$PROJECT"
create_secret_placeholder "${SECRET_PREFIX}-gcs-secret-key" "$PROJECT"

# =============================================================================
# GitHub ARC PAT (for nonprod only)
# =============================================================================
if [[ "$ENV" == "dev" ]]; then
    log_section "GitHub Actions Runner Controller (nonprod shared)"

    echo "Create GitHub PAT secret for ARC? (y/N): "
    read -r create_arc_pat
    if [[ "$create_arc_pat" =~ ^[Yy]$ ]]; then
        prompt_secret "Enter GitHub PAT (with repo and admin:org permissions)" GITHUB_ARC_PAT
        create_secret "gameplatform-nonprod-github-arc-pat" "$GITHUB_ARC_PAT" "$PROJECT"
    fi
fi

# =============================================================================
# Summary
# =============================================================================
log_section "Summary"

log_info "Secrets created for $ENV environment:"
echo ""
gcloud secrets list --project="$PROJECT" --filter="name:${SECRET_PREFIX}" \
    --format="table(name,createTime)" 2>/dev/null || \
    gcloud secrets list --project="$PROJECT" --format="table(name,createTime)"

echo ""
log_info "Next steps:"
echo "  1. Verify secrets: gcloud secrets list --project=$PROJECT"
echo "  2. Bootstrap clusters: ./02-bootstrap-runners.sh (for nonprod)"
echo "  3. Bootstrap workloads: ./03-bootstrap-workloads.sh $ENV"
echo ""
log_warn "Remember: Database secrets are created by Terraform 04-database stack."
log_warn "Remember: Update GCS HMAC placeholders with real values."
