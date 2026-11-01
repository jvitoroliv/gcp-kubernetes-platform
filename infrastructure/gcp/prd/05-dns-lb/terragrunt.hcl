# =============================================================================
# 05-DNS-LB STACK - PRD ENVIRONMENT
# =============================================================================
# Architecture: AWS ALB Equivalent using GCP Application Load Balancer
# - Single IP for ALL services (both port 443 and custom ports)
# - Hostname-based routing on port 443 (like AWS ALB)
# - TCP Proxy for custom ports (7350, 6969, 9933, etc.) on same IP
# - All services accessible with or without specifying port
#
# DNS Configuration:
# - Public zone: gameplatform.example.com → Single ALB IP (all services)
# =============================================================================

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
    vpc_self_link = "projects/project-prd-env/global/networks/project-prd-vpc"
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
    project-prd-zone = {
      dns_name    = "gameplatform.example.com."
      description = "GamePlatform production public DNS zone"
      visibility  = "public"
      dnssec      = false
    }
    project-prd-internal = {
      dns_name    = "prd.gameplatform."
      description = "GamePlatform production internal DNS zone (VPN access only)"
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
  # =============================================================================
  dns_records = {
    # -------------------------------------------------------------------------
    # PRIVATE ZONE RECORDS (prd.gameplatform) - For internal VPC resolution (VPN only)
    # Monitoring stack accessible only via VPN
    # -------------------------------------------------------------------------
    wildcard-monitoring = {
      zone_name = "project-prd-internal"
      name      = "*.prd.gameplatform."
      type      = "A"
      ttl       = 300
      rrdatas   = ["10.100.0.35"]  # ingress-nginx Internal LB
    }
    grafana-monitoring = {
      zone_name = "project-prd-internal"
      name      = "grafana.prd.gameplatform."
      type      = "A"
      ttl       = 300
      rrdatas   = ["10.100.0.35"]
    }
    prometheus-monitoring = {
      zone_name = "project-prd-internal"
      name      = "prometheus.prd.gameplatform."
      type      = "A"
      ttl       = 300
      rrdatas   = ["10.100.0.35"]
    }
    alertmanager-monitoring = {
      zone_name = "project-prd-internal"
      name      = "alertmanager.prd.gameplatform."
      type      = "A"
      ttl       = 300
      rrdatas   = ["10.100.0.35"]
    }
    argocd-monitoring = {
      zone_name = "project-prd-internal"
      name      = "argocd.prd.gameplatform."
      type      = "A"
      ttl       = 300
      rrdatas   = ["10.112.0.31"]
    }
  }

  # =============================================================================
  # GLOBAL LOAD BALANCER (Legacy) - DISABLED
  # =============================================================================
  enable_global_lb   = false
  ssl_domains        = []
  enable_cdn         = false
  enable_cloud_armor = false

  # =============================================================================
  # GATEWAY API - DISABLED (Replaced by ALB)
  # =============================================================================
  enable_gateway_ip = false
  gateway_ip_name   = ""

  # =============================================================================
  # SSL PROXY - HTTPS on custom ports (same IP as ALB)
  # Replicates AWS ALB behavior: all services on HTTPS with custom ports
  # =============================================================================
  enable_ssl_proxy = true

  # SSL Proxy uses GKE ManagedCertificate (shared with Ingress) because
  # Terraform-managed cert can't validate via HTTP-01 (no port 80 on SSL Proxy).
  # The GKE ManagedCertificate is created by the alb-ingress Helm chart and
  # covers all 8 service domains.
  ssl_proxy_certificate_domains = []
  ssl_proxy_external_certificate = "https://www.googleapis.com/compute/v1/projects/project-prd-env/global/sslCertificates/mcrt-00000000-0000-0000-0000-000000000000"

  ssl_proxy_services = {
    lobby-3000 = {
      port              = 3000
      backend_port      = 3000
      timeout_sec       = 30
      health_check_path = "/"
      description       = "Lobby frontend HTTPS on custom port"
      neg_self_links    = [
        "https://www.googleapis.com/compute/v1/projects/project-prd-env/zones/southamerica-east1-a/networkEndpointGroups/k8s1-00000000-namespace-service-80-00000000",
        "https://www.googleapis.com/compute/v1/projects/project-prd-env/zones/southamerica-east1-b/networkEndpointGroups/k8s1-00000000-namespace-service-80-00000000",
        "https://www.googleapis.com/compute/v1/projects/project-prd-env/zones/southamerica-east1-c/networkEndpointGroups/k8s1-00000000-namespace-service-80-00000000"
      ]
    }
    lobby-backend-3001 = {
      port              = 3001
      backend_port      = 3001
      timeout_sec       = 30
      health_check_path = "/health"
      description       = "Lobby backend API HTTPS on custom port"
      neg_self_links    = [
        "https://www.googleapis.com/compute/v1/projects/project-prd-env/zones/southamerica-east1-a/networkEndpointGroups/k8s1-00000000-namespace-service-80-00000000",
        "https://www.googleapis.com/compute/v1/projects/project-prd-env/zones/southamerica-east1-b/networkEndpointGroups/k8s1-00000000-namespace-service-80-00000000",
        "https://www.googleapis.com/compute/v1/projects/project-prd-env/zones/southamerica-east1-c/networkEndpointGroups/k8s1-00000000-namespace-service-80-00000000"
      ]
    }
    nakama-7350 = {
      port              = 7350
      backend_port      = 7350
      timeout_sec       = 86400
      health_check_path = "/"
      description       = "Nakama game server HTTPS"
      neg_self_links    = [
        "https://www.googleapis.com/compute/v1/projects/project-prd-env/zones/southamerica-east1-a/networkEndpointGroups/k8s1-00000000-namespace-service-80-00000000",
        "https://www.googleapis.com/compute/v1/projects/project-prd-env/zones/southamerica-east1-b/networkEndpointGroups/k8s1-00000000-namespace-service-80-00000000",
        "https://www.googleapis.com/compute/v1/projects/project-prd-env/zones/southamerica-east1-c/networkEndpointGroups/k8s1-00000000-namespace-service-80-00000000"
      ]
    }
    afs-9933 = {
      port              = 9933
      backend_port      = 9933
      timeout_sec       = 300
      health_check_path = "/ping"
      description       = "Asset File Service HTTPS"
      neg_self_links    = [
        "https://www.googleapis.com/compute/v1/projects/project-prd-env/zones/southamerica-east1-a/networkEndpointGroups/k8s1-00000000-namespace-service-80-00000000",
        "https://www.googleapis.com/compute/v1/projects/project-prd-env/zones/southamerica-east1-b/networkEndpointGroups/k8s1-00000000-namespace-service-80-00000000",
        "https://www.googleapis.com/compute/v1/projects/project-prd-env/zones/southamerica-east1-c/networkEndpointGroups/k8s1-00000000-namespace-service-80-00000000"
      ]
    }
    ahsat-6969 = {
      port              = 6969
      backend_port      = 6969
      timeout_sec       = 30
      health_check_path = "/ping"
      description       = "AHSAT Analytics Service HTTPS"
      neg_self_links    = [
        "https://www.googleapis.com/compute/v1/projects/project-prd-env/zones/southamerica-east1-a/networkEndpointGroups/k8s1-00000000-namespace-service-80-00000000",
        "https://www.googleapis.com/compute/v1/projects/project-prd-env/zones/southamerica-east1-b/networkEndpointGroups/k8s1-00000000-namespace-service-80-00000000",
        "https://www.googleapis.com/compute/v1/projects/project-prd-env/zones/southamerica-east1-c/networkEndpointGroups/k8s1-00000000-namespace-service-80-00000000"
      ]
    }
    ais-5050 = {
      port              = 5050
      backend_port      = 5050
      timeout_sec       = 300
      health_check_path = "/health"
      description       = "AI Image Service HTTPS"
      neg_self_links    = [
        "https://www.googleapis.com/compute/v1/projects/project-prd-env/zones/southamerica-east1-a/networkEndpointGroups/k8s1-00000000-namespace-service-80-00000000",
        "https://www.googleapis.com/compute/v1/projects/project-prd-env/zones/southamerica-east1-b/networkEndpointGroups/k8s1-00000000-namespace-service-80-00000000",
        "https://www.googleapis.com/compute/v1/projects/project-prd-env/zones/southamerica-east1-c/networkEndpointGroups/k8s1-00000000-namespace-service-80-00000000"
      ]
    }
    aes-1988 = {
      port              = 1988
      backend_port      = 1988
      timeout_sec       = 30
      health_check_path = "/health"
      description       = "Email Service HTTPS"
      neg_self_links    = [
        "https://www.googleapis.com/compute/v1/projects/project-prd-env/zones/southamerica-east1-a/networkEndpointGroups/k8s1-00000000-namespace-service-80-00000000",
        "https://www.googleapis.com/compute/v1/projects/project-prd-env/zones/southamerica-east1-b/networkEndpointGroups/k8s1-00000000-namespace-service-80-00000000",
        "https://www.googleapis.com/compute/v1/projects/project-prd-env/zones/southamerica-east1-c/networkEndpointGroups/k8s1-00000000-namespace-service-80-00000000"
      ]
    }
    aps-4444 = {
      port              = 4444
      backend_port      = 4444
      timeout_sec       = 30
      health_check_path = "/v0/aps/ping"
      description       = "Payment Service HTTPS"
      neg_self_links    = [
        "https://www.googleapis.com/compute/v1/projects/project-prd-env/zones/southamerica-east1-a/networkEndpointGroups/k8s1-00000000-namespace-service-80-00000000",
        "https://www.googleapis.com/compute/v1/projects/project-prd-env/zones/southamerica-east1-b/networkEndpointGroups/k8s1-00000000-namespace-service-80-00000000",
        "https://www.googleapis.com/compute/v1/projects/project-prd-env/zones/southamerica-east1-c/networkEndpointGroups/k8s1-00000000-namespace-service-80-00000000"
      ]
    }
  }

  # =============================================================================
  # APPLICATION LOAD BALANCER (AWS ALB Equivalent) - ENABLED
  # Creates ONLY the static IP. All other resources (backend services, URL map,
  # proxies, etc.) are created automatically by the GKE Ingress Controller
  # when the alb-ingress Helm chart is deployed.
  # =============================================================================
  enable_alb = true

  # SSL certificate created by Kubernetes ManagedCertificate CRD (alb-ingress chart)
  # Leave empty to avoid duplicate certificate creation
  alb_ssl_domains = []

  # Empty services - GKE Ingress Controller creates backend services for port 443
  alb_default_service = "lobby"
  alb_services        = {}
  alb_tcp_services    = {}  # Using SSL Proxy instead for HTTPS on custom ports

  labels = {
    environment = "prd"
    project     = "gameplatform"
    managed_by  = "terragrunt"
  }
}
