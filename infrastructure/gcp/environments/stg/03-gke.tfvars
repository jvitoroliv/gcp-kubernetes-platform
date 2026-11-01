# =============================================================================
# STG ENVIRONMENT - GKE STACK
# NOTE: Stg has SAME configuration as Prd for parity testing
# =============================================================================

project_id  = "project-nonprod-env"
environment = "stg"
region      = "us-east1"

# Network references (from 02-networking outputs)
# vpc_self_link    = "projects/project-nonprod-env/global/networks/project-stg-vpc"
# subnet_self_link = "projects/project-nonprod-env/regions/us-east1/subnetworks/project-stg-subnet"

# GKE Cluster Configuration
release_channel         = "REGULAR"
enable_private_nodes    = true
enable_private_endpoint = false
master_global_access    = true

# Master authorized networks - SAME AS PRD
master_authorized_networks = [
  {
    cidr_block   = "0.0.0.0/0"
    display_name = "all"
  }
]

enable_workload_identity = true
deletion_protection      = true # Enabled like production

# Node Pools - SAME AS PRD
node_pools = {
  general = {
    machine_type   = "e2-standard-4" # 4 vCPUs, 16GB RAM - SAME AS PRD
    min_node_count = 2
    max_node_count = 10
    disk_size_gb   = 100
    disk_type      = "pd-ssd" # SSD like production
    preemptible    = false    # No preemptible for staging parity
    spot           = false
    labels = {
      pool = "general"
    }
  }
  game-servers = {
    machine_type   = "e2-standard-8" # 8 vCPUs, 32GB RAM - SAME AS PRD
    min_node_count = 1
    max_node_count = 5
    disk_size_gb   = 100
    disk_type      = "pd-ssd"
    preemptible    = false
    spot           = false
    labels = {
      pool       = "game-servers"
      workload   = "nakama"
    }
    taints = [
      {
        key    = "workload"
        value  = "game-server"
        effect = "NO_SCHEDULE"
      }
    ]
  }
}

# Maintenance Window - 3 AM UTC on Sunday
maintenance_start_time = "03:00"

# Monitoring and Logging - SAME AS PRD
monitoring_components     = ["SYSTEM_COMPONENTS", "WORKLOADS"]
logging_components        = ["SYSTEM_COMPONENTS", "WORKLOADS"]
enable_managed_prometheus = true

# Addons
enable_http_load_balancing            = true
enable_horizontal_pod_autoscaling     = true
enable_network_policy                 = true
enable_gce_persistent_disk_csi_driver = true

labels = {
  owner       = "infrastructure-team"
  cost_center = "stg"
}
