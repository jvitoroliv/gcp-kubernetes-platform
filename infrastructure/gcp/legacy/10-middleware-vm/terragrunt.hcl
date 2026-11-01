# =============================================================================
# 10-MIDDLEWARE-VM STACK - LEGACY ENVIRONMENT
# =============================================================================
# Creates dedicated GCE instance for Rogues middleware
# Runs the middleware container that serves game assets

include "root" {
  path = find_in_parent_folders()
}

include "env" {
  path   = "${get_terragrunt_dir()}/../env.hcl"
  expose = true
}

terraform {
  source = "${get_repo_root()}/stacks-legacy/10-middleware-vm"
}

dependency "foundation" {
  config_path = "../01-foundation"

  mock_outputs = {
    service_account_emails = {
      rogues-middleware = "rogues-middleware@project-legacy-env.iam.gserviceaccount.com"
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

  # Instance configuration (small instance - middleware is lightweight)
  instance_name = "rogues-middleware"
  machine_type  = "e2-small"
  zone          = "${include.env.locals.region}-a"

  # Boot disk - Ubuntu 22.04 LTS
  boot_disk = {
    image = "ubuntu-os-cloud/ubuntu-2204-lts"
    size  = 30
    type  = "pd-balanced"
  }

  # Network configuration
  network    = dependency.networking.outputs.vpc_self_link
  subnetwork = dependency.networking.outputs.subnet_self_link
  tags       = ["rogues-middleware", "http-server", "https-server"]

  # Assign public IP for health checks and direct access if needed
  assign_public_ip = true

  # Service account
  service_account = {
    email  = dependency.foundation.outputs.service_account_emails["rogues-middleware"]
    scopes = ["cloud-platform"]
  }

  # Startup script to configure the middleware server
  startup_script = <<-STARTUP
#!/bin/bash
set -ex

# Log all output
exec > >(tee /var/log/startup-script.log) 2>&1
echo "=== Starting Rogues middleware setup at $(date) ==="

# ============================================================================
# SYSTEM SETUP
# ============================================================================
apt-get update
apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release git

# ============================================================================
# INSTALL DOCKER
# ============================================================================
echo "Installing Docker..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io

# Enable Docker service
systemctl enable docker
systemctl start docker

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

# Fetch GitHub PAT (needed for cloning private repo)
GITHUB_PAT=$(get_secret "rogues-github-pat" "")

# ============================================================================
# CLONE REPOSITORY
# ============================================================================
echo "Cloning middleware repository..."
cd /opt
git clone --branch rogue-dev https://$${GITHUB_PAT}@github.com/example-gamedev-org/gameplatform-middleware-komodo.git middleware
cd /opt/middleware
chown -R ubuntu:ubuntu /opt/middleware

# ============================================================================
# BUILD AND START CONTAINER
# ============================================================================
echo "Building Docker image..."
docker build -t rogues-middleware:latest .

echo "Starting middleware container..."
docker run -d \
  --name rogues-middleware \
  --restart unless-stopped \
  -p 3333:3333 \
  -e GCS_BUCKET=galapagos-exports-gcs \
  -e S3_URL=https://storage.googleapis.com/galapagos-exports-gcs/rogue/index.7z \
  rogues-middleware:latest

# Wait for container to start
sleep 10

# ============================================================================
# VERIFY SERVICE
# ============================================================================
echo "Verifying middleware service..."
docker ps
curl -s http://localhost:3333/ | head -c 200 || echo "Service starting..."

echo "=== Rogues middleware setup completed at $(date) ==="
STARTUP

  labels = {
    environment = "legacy"
    project     = "gameplatform"
    service     = "rogues"
    component   = "middleware"
    managed_by  = "terragrunt"
  }
}
