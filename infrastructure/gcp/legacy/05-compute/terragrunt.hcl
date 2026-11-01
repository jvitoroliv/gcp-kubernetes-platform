# =============================================================================
# 05-COMPUTE STACK - LEGACY ENVIRONMENT
# =============================================================================
# Creates GCE instance for Rogues game server (equivalent to EC2 Rogues-SERVER)

include "root" {
  path = find_in_parent_folders()
}

include "env" {
  path   = "${get_terragrunt_dir()}/../env.hcl"
  expose = true
}

terraform {
  source = "${get_repo_root()}/stacks-legacy/05-compute"
}

dependency "foundation" {
  config_path = "../01-foundation"

  mock_outputs = {
    service_account_emails = {
      rogues-server = "rogues-server@project-legacy-env.iam.gserviceaccount.com"
    }
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

dependency "networking" {
  config_path = "../02-networking"

  mock_outputs = {
    vpc_self_link    = "projects/project-legacy-env/global/networks/gameplatform-legacy-vpc"
    subnet_self_link = "projects/project-legacy-env/regions/southamerica-east1/subnetworks/gameplatform-legacy-subnet"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

inputs = {
  project_id  = include.env.locals.project_id
  environment = include.env.locals.environment
  region      = include.env.locals.region

  # Instance configuration (equivalent to t3.medium: 2 vCPU, 4GB RAM)
  instance_name = "rogues-server"
  machine_type  = "e2-medium"
  zone          = "${include.env.locals.region}-a"

  # Boot disk - Ubuntu 22.04 LTS (similar to EC2 AMI)
  boot_disk = {
    image = "ubuntu-os-cloud/ubuntu-2204-lts"
    size  = 80
    type  = "pd-balanced"
  }

  # Network configuration
  network    = dependency.networking.outputs.vpc_self_link
  subnetwork = dependency.networking.outputs.subnet_self_link
  tags       = ["rogues-server"]

  # Assign public IP (like EC2 with Elastic IP)
  assign_public_ip = true

  # Service account
  service_account = {
    email  = dependency.foundation.outputs.service_account_emails["rogues-server"]
    scopes = ["cloud-platform"]
  }

  # Startup script to configure the server
  startup_script = <<-STARTUP
#!/bin/bash
set -ex

# Log all output
exec > >(tee /var/log/startup-script.log) 2>&1
echo "=== Starting Rogues server setup at $(date) ==="

# ============================================================================
# SYSTEM SETUP
# ============================================================================
apt-get update
apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release git jq

# ============================================================================
# INSTALL DOCKER
# ============================================================================
echo "Installing Docker..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Enable Docker service
systemctl enable docker
systemctl start docker

# Add ubuntu user to docker group
usermod -aG docker ubuntu

# Install docker-compose standalone (for compatibility with docker-compose.yml v3)
curl -L "https://github.com/docker/compose/releases/download/v2.24.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# ============================================================================
# DOWNLOAD SECRETS FROM SECRET MANAGER
# ============================================================================
echo "Fetching secrets from Secret Manager..."

# Function to get secret or use default
get_secret() {
    local secret_name=$1
    local default_value=$2
    local value=$(gcloud secrets versions access latest --secret="$secret_name" --project="project-legacy-env" 2>/dev/null || echo "$default_value")
    echo "$value"
}

# Fetch GitHub PAT first (needed for cloning)
GITHUB_PAT=$(get_secret "rogues-github-pat" "")

# Fetch other secrets
HUBSPOT_ACCESS_TOKEN=$(get_secret "rogues-hubspot-token" "")
YUNO_PRIVATE_KEY=$(get_secret "rogues-yuno-private-key" "")
YUNO_PUBLIC_KEY=$(get_secret "rogues-yuno-public-key" "")
SMTP_USER=$(get_secret "rogues-smtp-user" "")
SMTP_PASSWORD=$(get_secret "rogues-smtp-password" "")
AES_API_KEY=$(get_secret "rogues-aes-api-key" "")
MATRICA_API_KEY=$(get_secret "rogues-matrica-api-key" "")

# ============================================================================
# CLONE REPOSITORY
# ============================================================================
echo "Cloning repository..."
cd /opt
git clone --branch rogues-server https://$${GITHUB_PAT}@github.com/example-gamedev-org/gameplatform-server.git rogues
cd /opt/rogues
chown -R ubuntu:ubuntu /opt/rogues

# ============================================================================
# CREATE .ENV FILE
# ============================================================================
echo "Creating .env file..."
cat > /opt/rogues/.env <<ENVFILE
# Environment
ENV=rogues

# Database (local Docker container)
DB_USER=postgres
DB_PORT=5432
DB_NAME=nakama
DB_PASSWORD=localdb
DB_URL=postgres

# Service ports
AFS_PORT=9933
AHSAT_PORT=6969
APS_PORT=8989
AES_PORT=1988
ACRYPT_PORT=14333
ACRYPT_DEV_PORT=14334

# GCS Configuration (uses Workload Identity - no credentials needed)
# Bucket: rogues-gameplatform-server-software-rogues

# HubSpot
HUBSPOT_ACCESS_TOKEN=PLACEHOLDER_HUBSPOT_TOKEN

# Yuno Payment
YUNO_ACCOUNT_ID=ACCOUNT-DUMMY
YUNO_PRIVATE_KEY=PLACEHOLDER_YUNO_PRIVATE_KEY
YUNO_PUBLIC_KEY=PLACEHOLDER_YUNO_PUBLIC_KEY

# Email Service (AES)
SMTP_USER=PLACEHOLDER_SMTP_USER
SMTP_PASSWORD=PLACEHOLDER_SMTP_PASSWORD
SMTP_SERVER=smtp.sendgrid.net
SMTP_PORT=587
FROM_EMAIL=no-reply@gameplatform.example.com
AES_API_KEY=PLACEHOLDER_AES_API_KEY
DISABLE_EMAIL_VERIFICATION=0

# APS Configuration
APS_CHECK_PRICE=1
APS_TOLERANCE=0.01

# Nakama
NK_HTTP_KEY=${NAKAMA_HTTP_KEY}
CLOUDGAMECO_WORLD_BUILDER_TICK_RATE=10

# Matrica
MATRICA_CLIENT_ID=6b108fe8e095e9e
MATRICA_CLIENT_SECRET=lLvcWXlKSESI1JHbFtO3JtFyvBI6h2
MATRICA_API_KEY=PLACEHOLDER_MATRICA_API_KEY

# ACrypt
APP_URL=https://acrypt.example-game.wtf/
REDIRECT_URI=https://acrypt.example-game.wtf/callback
NODE_ENV=production
ENVFILE

# Replace placeholders with actual secrets
sed -i "s|PLACEHOLDER_HUBSPOT_TOKEN|$${HUBSPOT_ACCESS_TOKEN}|g" /opt/rogues/.env
sed -i "s|PLACEHOLDER_YUNO_PRIVATE_KEY|$${YUNO_PRIVATE_KEY}|g" /opt/rogues/.env
sed -i "s|PLACEHOLDER_YUNO_PUBLIC_KEY|$${YUNO_PUBLIC_KEY}|g" /opt/rogues/.env
sed -i "s|PLACEHOLDER_SMTP_USER|$${SMTP_USER}|g" /opt/rogues/.env
sed -i "s|PLACEHOLDER_SMTP_PASSWORD|$${SMTP_PASSWORD}|g" /opt/rogues/.env
sed -i "s|PLACEHOLDER_AES_API_KEY|$${AES_API_KEY}|g" /opt/rogues/.env
sed -i "s|PLACEHOLDER_MATRICA_API_KEY|$${MATRICA_API_KEY}|g" /opt/rogues/.env

# Set proper permissions
chmod 600 /opt/rogues/.env
chown ubuntu:ubuntu /opt/rogues/.env

# ============================================================================
# BUILD AND START CONTAINERS
# ============================================================================
echo "Building and starting Docker containers..."
cd /opt/rogues

# Build all images
docker-compose build

# Start postgres first and wait for it to be ready
docker-compose up -d postgres
echo "Waiting for PostgreSQL to be ready..."
sleep 30

# ============================================================================
# DOWNLOAD AND RESTORE DATABASE DUMP
# ============================================================================
echo "Downloading database dump from GCS..."
gcloud storage cp gs://gameplatform-terraform-state-legacy/backups/nakama_backup_20260121.dump /tmp/nakama_backup.dump

echo "Restoring database..."
# Copy dump into container
docker cp /tmp/nakama_backup.dump backend_postgres:/tmp/nakama_backup.dump

# Restore the dump
docker exec backend_postgres pg_restore -U postgres -d nakama --clean --if-exists /tmp/nakama_backup.dump || true

# Clean up
rm /tmp/nakama_backup.dump
docker exec backend_postgres rm /tmp/nakama_backup.dump

echo "Database restore completed"

# ============================================================================
# START ALL REMAINING SERVICES
# ============================================================================
echo "Starting all services..."
docker-compose up -d

# Wait for services to start
sleep 30

# ============================================================================
# VERIFY SERVICES
# ============================================================================
echo "Verifying services..."
docker-compose ps

echo "=== Rogues server setup completed at $(date) ==="
echo "Services running:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
STARTUP

  labels = {
    environment = "legacy"
    project     = "gameplatform"
    service     = "rogues"
    component   = "game-server"
    managed_by  = "terragrunt"
  }
}
