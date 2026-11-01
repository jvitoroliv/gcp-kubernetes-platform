# =============================================================================
# DEV ENVIRONMENT - GKE STACK
# =============================================================================

project_id  = "project-nonprod-env"
environment = "dev"
region      = "us-east1"

# Network references (from 02-networking outputs)
vpc_self_link            = "projects/project-nonprod-env/global/networks/project-dev-vpc"
subnet_self_link         = "projects/project-nonprod-env/regions/us-east1/subnetworks/project-dev-subnet"
gke_node_service_account = "project-dev-gke-nodes@project-nonprod-env.iam.gserviceaccount.com"

# GKE Cluster Configuration
release_channel         = "REGULAR"
enable_private_nodes    = true
enable_private_endpoint = true  # Private endpoint - requires VPN/Bastion access
master_global_access    = true

# Master authorized networks - Restricted to VPN and internal networks
# Access to GKE master API requires VPN connection or Bastion Host
master_authorized_networks = [
  {
    cidr_block   = "10.0.0.0/24"    # On-premises network (via VPN)
    display_name = "on-premises-vpn"
  },
  {
    cidr_block   = "10.100.0.0/20"  # VPC subnet (internal access)
    display_name = "vpc-internal"
  }
]

enable_workload_identity = true
deletion_protection      = false # Disabled for dev

# Node Pools - Smaller sizes for dev
node_pools = {
  general = {
    machine_type   = "e2-standard-2" # 2 vCPUs, 8GB RAM
    min_node_count = 1
    max_node_count = 3
    disk_size_gb   = 50
    disk_type      = "pd-standard"
    preemptible    = true # Use preemptible for cost savings in dev
    spot           = false
    labels = {
      pool = "general"
    }
  }
}

# Maintenance Window - 3 AM UTC on Sunday
maintenance_start_time = "03:00"

# Monitoring and Logging
monitoring_components     = ["SYSTEM_COMPONENTS"]
logging_components        = ["SYSTEM_COMPONENTS", "WORKLOADS"]
enable_managed_prometheus = false # Disabled for dev to save costs

# Addons (network_policy provided by Dataplane V2)
enable_http_load_balancing            = true
enable_horizontal_pod_autoscaling     = true
enable_gce_persistent_disk_csi_driver = true

labels = {
  owner       = "infrastructure-team"
  cost_center = "development"
}
