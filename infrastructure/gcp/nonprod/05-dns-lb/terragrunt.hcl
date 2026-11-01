# =============================================================================
# 05-DNS-LB STACK - NONPROD (RUNNERS) ENVIRONMENT
# =============================================================================
# Private DNS zone for the nonprod-runners cluster (ArgoCD access via VPN)
#
# DNS Configuration:
# - Private zone: runners.gameplatform → nginx-ingress Internal LB on runners cluster
#
# IMPORTANT: Update the IP below after deploying ingress-nginx-runners via ArgoCD.
# To get the IP after nginx is deployed:
#   kubectl get svc -n ingress-nginx --context gke_project-nonprod-env_us-east1_project-nonprod-runners
# Then run: terragrunt apply

include "root" {
  path = find_in_parent_folders()
}

include "env" {
  path   = "${get_terragrunt_dir()}/../env.hcl"
  expose = true
}

terraform {
  source = "${get_repo_root()}/stacks/05-dns-lb"
}

dependency "networking" {
  config_path = "../02-networking"

  mock_outputs = {
    vpc_self_link = "projects/project-nonprod-env/global/networks/gameplatform-nonprod-vpc"
  }
}

inputs = {
  project_id  = include.env.locals.project_id
  environment = include.env.locals.environment
  region      = include.env.locals.region

  # =============================================================================
  # DNS ZONES
  # =============================================================================
  dns_zones = {
    gameplatform-runners-internal = {
      dns_name    = "runners.gameplatform."
      description = "GamePlatform runners internal DNS zone (VPN access only)"
      visibility  = "private"
      dnssec      = false
      private_visibility_config = {
        networks = [
          {
            network_url = dependency.networking.outputs.vpc_self_link
          }
        ]
      }
    }
  }

  # =============================================================================
  # DNS RECORDS
  # PRIVATE: Points to nginx-ingress Internal LB on runners cluster
  # =============================================================================
  # NOTE: Update the IP after ingress-nginx-runners is deployed via ArgoCD.
  # Check with: kubectl get svc -n ingress-nginx --context gke_project-nonprod-env_us-east1_project-nonprod-runners
  dns_records = {
    wildcard = {
      zone_name = "gameplatform-runners-internal"
      name      = "*.runners.gameplatform."
      type      = "A"
      ttl       = 300
      rrdatas   = ["10.120.15.199"]  # TODO: replace with actual IP after nginx deploys
    }
    argocd = {
      zone_name = "gameplatform-runners-internal"
      name      = "argocd.runners.gameplatform."
      type      = "A"
      ttl       = 300
      rrdatas   = ["10.120.15.199"]  # TODO: replace with actual IP after nginx deploys
    }
  }

  # =============================================================================
  # LOAD BALANCER - DISABLED (runners uses only private DNS + nginx internal LB)
  # =============================================================================
  enable_global_lb   = false
  ssl_domains        = []
  enable_cdn         = false
  enable_cloud_armor = false

  enable_gateway_ip = false
  gateway_ip_name   = ""

  enable_ssl_proxy = false

  enable_alb          = false
  alb_ssl_domains     = []
  alb_default_service = ""
  alb_services        = {}
  alb_tcp_services    = {}

  labels = {
    environment = "nonprod"
    project     = "gameplatform"
    managed_by  = "terragrunt"
    owner       = "infrastructure-team"
    cost_center = "nonprod"
    access      = "internal-vpn"
  }
}
