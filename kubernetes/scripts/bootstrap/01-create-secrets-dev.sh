#!/bin/bash
# =============================================================================
# Create GCP Secret Manager Secrets for DEV
# =============================================================================
# Values extracted from gameplatform-shared-infrastructure/stacks/persistent-env/
# =============================================================================

set -euo pipefail

PROJECT="project-nonprod-env"
PREFIX="gameplatform-dev"

echo "=== Creating secrets for DEV environment ==="
echo "Project: $PROJECT"
echo ""

create_secret() {
    local name="$1"
    local value="$2"

    if gcloud secrets describe "$name" --project="$PROJECT" &>/dev/null; then
        echo "[UPDATE] $name"
        printf '%s' "$value" | gcloud secrets versions add "$name" --data-file=- --project="$PROJECT"
    else
        echo "[CREATE] $name"
        printf '%s' "$value" | gcloud secrets create "$name" --data-file=- --project="$PROJECT" --replication-policy="automatic"
    fi
}

# =============================================================================
# NAKAMA secrets (from main_nakama.tf)
# =============================================================================
echo ""
echo "=== Nakama ==="
create_secret "${PREFIX}-nakama-http-key" "${NAKAMA_HTTP_KEY}"
create_secret "${PREFIX}-nakama-server-key" "${NAKAMA_SERVER_KEY}"
create_secret "${PREFIX}-aes-encryption-key" "${AES_ENCRYPTION_KEY}"

# =============================================================================
# LOBBY secrets (from main_lobby.tf)
# =============================================================================
echo ""
echo "=== Lobby (OAuth) ==="
create_secret "${PREFIX}-nextauth-secret" "${NEXTAUTH_SECRET}"
create_secret "${PREFIX}-google-client-id" "${GOOGLE_CLIENT_ID}"
create_secret "${PREFIX}-google-client-secret" "${GOOGLE_CLIENT_SECRET}"

# =============================================================================
# AES (Email Service) secrets (from main_aes.tf)
# =============================================================================
echo ""
echo "=== AES (Email Service) ==="
create_secret "${PREFIX}-aes-api-key" "${AES_API_KEY}"
create_secret "${PREFIX}-smtp-user" "${AWS_SES_ACCESS_KEY}"
create_secret "${PREFIX}-smtp-password" "${AWS_SES_SMTP_PASSWORD}"

# =============================================================================
# AIS (AI Image Service) secrets (from main_ais.tf)
# =============================================================================
echo ""
echo "=== AIS (AI Image Service) ==="
create_secret "${PREFIX}-piapi-key" "${PIAPI_KEY}"
create_secret "${PREFIX}-gemini-api-key" "${GEMINI_API_KEY}"

# =============================================================================
# AHSAT secrets (from main_ahsat.tf)
# =============================================================================
echo ""
echo "=== AHSAT ==="
create_secret "${PREFIX}-ai-api-key" "${AI_API_KEY}"

# =============================================================================
# AIS_APP_SECRET (shared between AHSAT and AIS)
# Using same pattern for GCP
# =============================================================================
echo ""
echo "=== AIS App Secret ==="
create_secret "${PREFIX}-ais-app-secret" "${AIS_APP_SECRET}"

# =============================================================================
# APS (Payment Service / Yuno) secrets (from main_aps.tf)
# =============================================================================
echo ""
echo "=== APS (Yuno Payment) ==="
create_secret "${PREFIX}-yuno-public-key" "${YUNO_PUBLIC_KEY}"
create_secret "${PREFIX}-yuno-private-key" "${YUNO_PRIVATE_KEY}"
create_secret "${PREFIX}-yuno-account-id" "${YUNO_ACCOUNT_ID}"

echo ""
echo "=== Done! ==="
echo ""
echo "NOTE: Database secrets (project-dev-db-*) are created by Terraform 04-database stack."
