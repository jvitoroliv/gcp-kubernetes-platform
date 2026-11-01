# =============================================================================
# 03-GKE STACK - PRD ENVIRONMENT
# =============================================================================

include "root" {
  path = find_in_parent_folders()
}

include "env" {
  path   = "${get_terragrunt_dir()}/../env.hcl"
  expose = true
}

terraform {
  source = "${get_repo_root()}/stacks/03-gke"
}

dependency "networking" {
  config_path = "../02-networking"

  mock_outputs = {
    vpc_self_link              = "projects/project-prd-env/global/networks/project-prd-vpc"
    workloads_subnet_self_link = "projects/project-prd-env/regions/southamerica-east1/subnetworks/project-prd-workloads-subnet"
    workloads_master_cidr      = "172.16.0.0/28"
    runners_pods_cidr          = "10.116.0.0/14"
  }
}

dependency "foundation" {
  config_path = "../01-foundation"

  mock_outputs = {
    gke_node_service_account_email = "project-prd-gke-nodes@project-prd-env.iam.gserviceaccount.com"
  }
}

inputs = {
  project_id  = include.env.locals.project_id
  environment = include.env.locals.environment
  region      = include.env.locals.region

  cluster_name = "project-prd-workloads"

  # Network references (from prd 02-networking - workloads subnet)
  vpc_self_link            = dependency.networking.outputs.vpc_self_link
  subnet_self_link         = dependency.networking.outputs.workloads_subnet_self_link
  master_ipv4_cidr         = dependency.networking.outputs.workloads_master_cidr
  gke_node_service_account = dependency.foundation.outputs.gke_node_service_account_email

  # GKE Cluster Configuration
  release_channel = "UNSPECIFIED"  # Disable automatic version upgrades

  # Node Management - disable auto-upgrades to prevent disruption
  node_auto_upgrade = false
  node_auto_repair  = true

  # =============================================================================
  # PRIVATE CLUSTER - PRIVATE ENDPOINT (VPN access only, like dev/stg)
  # Public services exposed via Gateway/Ingress (like AWS ALB)
  # =============================================================================
  enable_private_nodes    = true
  enable_private_endpoint = true   # PRIVATE - VPN access only
  master_global_access    = true   # Access from any GCP region

  # Master authorized networks - who can access the API server
  master_authorized_networks = [
    {
      cidr_block   = "10.0.0.0/24"     # On-premises network (via VPN)
      display_name = "on-premises-vpn"
    },
    {
      cidr_block   = "10.100.0.0/20"   # PRD workloads subnet (internal)
      display_name = "prd-workloads-subnet"
    },
    {
      cidr_block   = "10.112.0.0/20"   # PRD runners subnet (internal)
      display_name = "prd-runners-subnet"
    },
    {
      cidr_block   = "10.116.0.0/14"   # PRD runners pod CIDR (ArgoCD pods)
      display_name = "prd-runners-pods"
    }
  ]

  enable_workload_identity = true
  deletion_protection      = true  # ENABLED for prd

  # Node Pools - Production sizes
  node_pools = {
    general = {
      machine_type   = "e2-standard-4"  # 4 vCPUs, 16GB RAM
      min_node_count = 3
      max_node_count = 20
      disk_size_gb   = 100
      disk_type      = "pd-ssd"
      preemptible    = false  # NO preemptible for production
      spot           = false
      labels = {
        pool = "general"
      }
      taints = []
    }
  }

  # Maintenance Window - 3 AM UTC on Sunday
  maintenance_start_time = "03:00"

  # Monitoring and Logging
  monitoring_components     = ["SYSTEM_COMPONENTS"]
  logging_components        = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  enable_managed_prometheus = false

  # Addons
  enable_http_load_balancing            = true
  enable_horizontal_pod_autoscaling     = true
  enable_gce_persistent_disk_csi_driver = true

  # Gateway API
  gateway_api_channel = "CHANNEL_STANDARD"

  labels = {
    environment = "prd"
    project     = "gameplatform"
    managed_by  = "terragrunt"
    owner       = "infrastructure-team"
    cost_center = "production"
  }
}
