# -----------------------------------------------------------------------------
# GKE RUNNERS STACK
# This stack sets up a dedicated GKE cluster for GitHub Actions runners:
# - Separate cluster for CI/CD workloads
# - Optimized node pools for different build types
# - Spot VMs for cost efficiency
# - Scale to zero when idle
# -----------------------------------------------------------------------------

locals {
  common_labels = merge({
    project     = "gameplatform"
    environment = var.environment
    component   = "gke-runners"
    managed_by  = "terragrunt"
  }, var.labels)

  # Naming convention
  name_prefix  = "gameplatform-${var.environment}"
  cluster_name = "${local.name_prefix}-runners"
}

# -----------------------------------------------------------------------------
# GKE CLUSTER FOR RUNNERS
# -----------------------------------------------------------------------------

module "gke_cluster" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/gcp/gke-cluster"

  name        = local.cluster_name
  location    = var.region
  project     = var.project_id
  description = "GamePlatform ${var.environment} GitHub Actions Runners cluster"

  network    = var.vpc_self_link
  subnetwork = var.subnet_self_link

  # Release channel - RAPID for latest features, REGULAR for stability
  release_channel = var.release_channel

  # VPC-native cluster with IP allocation
  ip_allocation_policy = {
    cluster_secondary_range_name  = var.pods_range_name
    services_secondary_range_name = var.services_range_name
  }

  # Private cluster configuration
  # Endpoint is private - ARC runners connect outbound to GitHub via Cloud NAT
  # ArgoCD can access dev/stg clusters via internal VPC networking
  private_cluster_config = {
    enable_private_nodes    = true
    enable_private_endpoint = true   # PRIVATE - VPN access only
    master_ipv4_cidr_block  = var.master_ipv4_cidr
    master_global_access    = true
  }

  # Master authorized networks
  master_authorized_networks = var.master_authorized_networks

  # Workload Identity for ARC
  enable_workload_identity = true

  # Maintenance window - early morning UTC
  maintenance_window = {
    start_time = var.maintenance_start_time
  }

  # Monitoring and logging - minimal for runners
  monitoring_components     = ["SYSTEM_COMPONENTS"]
  logging_components        = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  enable_managed_prometheus = false  # Not needed for CI runners

  # Dataplane V2 (eBPF-based networking)
  datapath_provider = "ADVANCED_DATAPATH"

  # Addons
  addons_config = {
    http_load_balancing            = false  # Runners don't need ingress
    horizontal_pod_autoscaling     = true   # Required for ARC scaling
    gce_persistent_disk_csi_driver = true   # For build caches if needed
  }

  # Remove default node pool - we create custom ones
  remove_default_node_pool = true
  initial_node_count       = 1

  # Protection - can be deleted for CI cluster
  deletion_protection = var.deletion_protection

  labels = local.common_labels
}

# -----------------------------------------------------------------------------
# NODE POOL: HEAVY RUNNERS
# For heavy jobs: Docker builds, multi-service builds
# -----------------------------------------------------------------------------

module "runners_heavy_pool" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/gcp/gke-node-pool"

  name     = "${local.name_prefix}-runners-heavy"
  location = var.region
  cluster  = module.gke_cluster.name
  project  = var.project_id

  autoscaling = {
    min_node_count = var.heavy_pool_min_nodes
    max_node_count = var.heavy_pool_max_nodes
  }

  auto_upgrade = var.node_auto_upgrade
  auto_repair  = var.node_auto_repair

  node_config = {
    preemptible     = false
    spot            = false  # Disabled for HA - spot VMs can be preempted
    machine_type    = var.heavy_pool_machine_type
    disk_size_gb    = var.heavy_pool_disk_size
    disk_type       = "pd-ssd"  # SSD for faster Docker layer caching
    service_account = var.gke_node_service_account
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]
    labels = merge(local.common_labels, {
      node_pool   = "runners-heavy"
      runner_type = "heavy"
    })
    tags = ["gke-node", "${local.cluster_name}-node", "runner-heavy"]
    taints = [
      {
        key    = "runner-type"
        value  = "heavy"
        effect = "NO_SCHEDULE"
      }
    ]
  }

  enable_workload_identity = true

  depends_on = [module.gke_cluster]
}

# -----------------------------------------------------------------------------
# NODE POOL: INFRA (ArgoCD, ESO, ARC Controller)
# Dedicated pool for infrastructure workloads - always running (min=1)
# NO TAINTS - allows any workload to schedule
# Small and stable - no spot VMs
# -----------------------------------------------------------------------------

module "infra_pool" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/gcp/gke-node-pool"

  name     = "${local.name_prefix}-infra"
  location = var.region
  cluster  = module.gke_cluster.name
  project  = var.project_id

  autoscaling = {
    min_node_count = var.infra_pool_min_nodes
    max_node_count = var.infra_pool_max_nodes
  }

  auto_upgrade = var.node_auto_upgrade
  auto_repair  = var.node_auto_repair

  node_config = {
    preemptible     = false
    spot            = false  # Infra must be stable - no spot
    machine_type    = var.infra_pool_machine_type
    disk_size_gb    = var.infra_pool_disk_size
    disk_type       = "pd-standard"  # Standard disk is fine for infra
    service_account = var.gke_node_service_account
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]
    labels = merge(local.common_labels, {
      node_pool = "infra"
      purpose   = "infrastructure"
    })
    tags = ["gke-node", "${local.cluster_name}-node", "infra"]
    # NO TAINTS - allows ArgoCD, ESO, ARC controller to schedule
  }

  enable_workload_identity = true

  depends_on = [module.gke_cluster]
}

# -----------------------------------------------------------------------------
# WORKLOAD IDENTITY: ARC CONTROLLER
# Service account for Actions Runner Controller
# -----------------------------------------------------------------------------

module "arc_controller_workload_identity" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/gcp/gke-workload-identity"

  project_id         = var.project_id
  project            = var.project_id
  service_account_id = "${local.name_prefix}-arc-controller"
  display_name       = "ARC Controller Workload Identity"
  description        = "Service account for GitHub Actions Runner Controller"
  namespace          = "arc-systems"
  ksa_name           = "arc-gha-rs-controller"
  roles = [
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
  ]

  depends_on = [module.gke_cluster]
}

# -----------------------------------------------------------------------------
# WORKLOAD IDENTITY: ARC RUNNERS
# Service account for the runner pods themselves
# -----------------------------------------------------------------------------

module "arc_runner_workload_identity" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/gcp/gke-workload-identity"

  project_id         = var.project_id
  project            = var.project_id
  service_account_id = "${local.name_prefix}-arc-runner"
  display_name       = "ARC Runner Workload Identity"
  description        = "Service account for GitHub Actions Runner pods"
  namespace          = "arc-runners"
  ksa_name           = "arc-runner"
  roles = [
    "roles/artifactregistry.writer",      # Push images
    "roles/artifactregistry.reader",      # Pull base images
    "roles/storage.objectViewer",         # Read from GCS if needed
    "roles/secretmanager.secretAccessor", # Access secrets
    "roles/container.developer",          # Deploy to GKE (workloads cluster)
  ]

  depends_on = [module.gke_cluster]
}

# -----------------------------------------------------------------------------
# FIREWALL RULE: ALLOW GITHUB WEBHOOKS
# Allow GitHub to send webhooks to the ARC controller
# -----------------------------------------------------------------------------

resource "google_compute_firewall" "allow_github_webhooks" {
  name    = "${local.name_prefix}-allow-github-webhooks"
  project = var.project_id
  network = var.vpc_name

  direction = "INGRESS"
  priority  = 1000

  # GitHub webhook IPs (meta API: https://api.github.com/meta)
  source_ranges = [
    "192.30.252.0/22",
    "185.199.108.0/22",
    "140.82.112.0/20",
    "143.55.64.0/20",
  ]

  target_tags = ["${local.cluster_name}-node"]

  allow {
    protocol = "tcp"
    ports    = ["443", "80"]
  }

  description = "Allow GitHub webhooks to reach ARC controller"
}
