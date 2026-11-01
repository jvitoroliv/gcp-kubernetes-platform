# =============================================================================
# 05-DNS-LB STACK - STG ENVIRONMENT
# =============================================================================
# Architecture: AWS ALB Equivalent using GCP Application Load Balancer
# - Single IP for ALL services (both port 443 and custom ports)
# - Hostname-based routing on port 443 (like AWS ALB)
# - TCP Proxy for custom ports (7350, 6969, 9933, etc.) on same IP
# - All services accessible with or without specifying port
#
# DNS Configuration:
# - Public zone: stg-gameplatform.example.com → Single ALB IP (all services)
# - Private zone: stg.gameplatform → nginx-ingress Internal LB (10.48.0.13)

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
  config_path = "../../nonprod/02-networking"

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
    project-stg-internal = {
      dns_name    = "stg.gameplatform."
      description = "GamePlatform stg internal DNS zone (VPN access only)"
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
  # PUBLIC: Points to ALB IP (34.160.45.214)
  # PRIVATE: Points to nginx-ingress Internal LB (10.48.0.13)
  # =============================================================================
  dns_records = {
    # -------------------------------------------------------------------------
    # PUBLIC ZONE RECORDS (stg-gameplatform.example.com)
    # All records point to single ALB IP (34.160.45.214)
    # -------------------------------------------------------------------------
    wildcard-public = {
      zone_name = "stg-gameplatform-dns"
      name      = "*.stg-gameplatform.example.com."
      type      = "A"
      ttl       = 300
      rrdatas   = ["34.160.45.214"]  # ALB IP
    }
    nakama-public = {
      zone_name = "stg-gameplatform-dns"
      name      = "nakama.stg-gameplatform.example.com."
      type      = "A"
      ttl       = 300
      rrdatas   = ["34.160.45.214"]  # ALB IP
    }
    lobby-public = {
      zone_name = "stg-gameplatform-dns"
      name      = "lobby.stg-gameplatform.example.com."
      type      = "A"
      ttl       = 300
      rrdatas   = ["34.160.45.214"]  # ALB IP
    }
    lobby-backend-public = {
      zone_name = "stg-gameplatform-dns"
      name      = "lobby-backend.stg-gameplatform.example.com."
      type      = "A"
      ttl       = 300
      rrdatas   = ["34.160.45.214"]  # ALB IP
    }
    afs-public = {
      zone_name = "stg-gameplatform-dns"
      name      = "afs.stg-gameplatform.example.com."
      type      = "A"
      ttl       = 300
      rrdatas   = ["34.160.45.214"]  # ALB IP
    }
    ahsat-public = {
      zone_name = "stg-gameplatform-dns"
      name      = "ahsat.stg-gameplatform.example.com."
      type      = "A"
      ttl       = 300
      rrdatas   = ["34.160.45.214"]  # ALB IP
    }
    aes-public = {
      zone_name = "stg-gameplatform-dns"
      name      = "aes.stg-gameplatform.example.com."
      type      = "A"
      ttl       = 300
      rrdatas   = ["34.160.45.214"]  # ALB IP
    }
    ais-public = {
      zone_name = "stg-gameplatform-dns"
      name      = "ais.stg-gameplatform.example.com."
      type      = "A"
      ttl       = 300
      rrdatas   = ["34.160.45.214"]  # ALB IP
    }
    aps-public = {
      zone_name = "stg-gameplatform-dns"
      name      = "aps.stg-gameplatform.example.com."
      type      = "A"
      ttl       = 300
      rrdatas   = ["34.160.45.214"]  # ALB IP
    }
    # -------------------------------------------------------------------------
    # PRIVATE ZONE RECORDS (stg.gameplatform) - For internal VPC resolution
    # -------------------------------------------------------------------------
    wildcard = {
      zone_name = "project-stg-internal"
      name      = "*.stg.gameplatform."
      type      = "A"
      ttl       = 300
      rrdatas   = ["10.48.0.13"]
    }
    nakama = {
      zone_name = "project-stg-internal"
      name      = "nakama.stg.gameplatform."
      type      = "A"
      ttl       = 300
      rrdatas   = ["10.48.0.13"]
    }
    lobby = {
      zone_name = "project-stg-internal"
      name      = "lobby.stg.gameplatform."
      type      = "A"
      ttl       = 300
      rrdatas   = ["10.48.0.13"]
    }
    lobby-backend = {
      zone_name = "project-stg-internal"
      name      = "lobby-backend.stg.gameplatform."
      type      = "A"
      ttl       = 300
      rrdatas   = ["10.48.0.13"]
    }
    afs = {
      zone_name = "project-stg-internal"
      name      = "afs.stg.gameplatform."
      type      = "A"
      ttl       = 300
      rrdatas   = ["10.48.0.13"]
    }
    ahsat = {
      zone_name = "project-stg-internal"
      name      = "ahsat.stg.gameplatform."
      type      = "A"
      ttl       = 300
      rrdatas   = ["10.48.0.13"]
    }
    aes = {
      zone_name = "project-stg-internal"
      name      = "aes.stg.gameplatform."
      type      = "A"
      ttl       = 300
      rrdatas   = ["10.48.0.13"]
    }
    ais = {
      zone_name = "project-stg-internal"
      name      = "ais.stg.gameplatform."
      type      = "A"
      ttl       = 300
      rrdatas   = ["10.48.0.13"]
    }
    aps = {
      zone_name = "project-stg-internal"
      name      = "aps.stg.gameplatform."
      type      = "A"
      ttl       = 300
      rrdatas   = ["10.48.0.13"]
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
  # NOTE: NEGs and certificate will be configured after services are deployed
  # =============================================================================
  enable_ssl_proxy = true

  # SSL Proxy uses GKE ManagedCertificate (shared with Ingress) because
  # Terraform-managed cert can't validate via HTTP-01 (no port 80 on SSL Proxy).
  # The GKE ManagedCertificate is created by the alb-ingress Helm chart and
  # covers all 8 service domains.
  ssl_proxy_certificate_domains = []
  ssl_proxy_external_certificate = "https://www.googleapis.com/compute/v1/projects/project-nonprod-env/global/sslCertificates/mcrt-00000000-0000-0000-0000-000000000000"

  ssl_proxy_services = {
    lobby-3000 = {
      port              = 3000
      backend_port      = 3000
      timeout_sec       = 30
      health_check_path = "/"
      description       = "Lobby frontend HTTPS on custom port"
      neg_self_links    = [
        "https://www.googleapis.com/compute/v1/projects/project-nonprod-env/zones/us-east1-b/networkEndpointGroups/k8s1-00000000-namespace-service-80-00000000",
        "https://www.googleapis.com/compute/v1/projects/project-nonprod-env/zones/us-east1-c/networkEndpointGroups/k8s1-00000000-namespace-service-80-00000000",
        "https://www.googleapis.com/compute/v1/projects/project-nonprod-env/zones/us-east1-d/networkEndpointGroups/k8s1-00000000-namespace-service-80-00000000"
      ]
    }
    lobby-backend-3001 = {
      port              = 3001
      backend_port      = 3001
      timeout_sec       = 30
      health_check_path = "/health"
      description       = "Lobby backend API HTTPS on custom port"
      neg_self_links    = [
        "https://www.googleapis.com/compute/v1/projects/project-nonprod-env/zones/us-east1-b/networkEndpointGroups/k8s1-00000000-namespace-service-80-00000000",
        "https://www.googleapis.com/compute/v1/projects/project-nonprod-env/zones/us-east1-c/networkEndpointGroups/k8s1-00000000-namespace-service-80-00000000",
        "https://www.googleapis.com/compute/v1/projects/project-nonprod-env/zones/us-east1-d/networkEndpointGroups/k8s1-00000000-namespace-service-80-00000000"
      ]
    }
    nakama-7350 = {
      port              = 7350
      backend_port      = 7350
      timeout_sec       = 86400
      health_check_path = "/"
      description       = "Nakama game server HTTPS"
      neg_self_links    = [
        "https://www.googleapis.com/compute/v1/projects/project-nonprod-env/zones/us-east1-b/networkEndpointGroups/k8s1-00000000-namespace-service-80-00000000",
        "https://www.googleapis.com/compute/v1/projects/project-nonprod-env/zones/us-east1-c/networkEndpointGroups/k8s1-00000000-namespace-service-80-00000000",
        "https://www.googleapis.com/compute/v1/projects/project-nonprod-env/zones/us-east1-d/networkEndpointGroups/k8s1-00000000-namespace-service-80-00000000"
      ]
    }
    afs-9933 = {
      port              = 9933
      backend_port      = 9933
      timeout_sec       = 300
      health_check_path = "/ping"
      description       = "Asset File Service HTTPS"
      neg_self_links    = [
        "https://www.googleapis.com/compute/v1/projects/project-nonprod-env/zones/us-east1-b/networkEndpointGroups/k8s1-00000000-namespace-service-80-00000000",
        "https://www.googleapis.com/compute/v1/projects/project-nonprod-env/zones/us-east1-c/networkEndpointGroups/k8s1-00000000-namespace-service-80-00000000",
        "https://www.googleapis.com/compute/v1/projects/project-nonprod-env/zones/us-east1-d/networkEndpointGroups/k8s1-00000000-namespace-service-80-00000000"
      ]
    }
    ahsat-6969 = {
      port              = 6969
      backend_port      = 6969
      timeout_sec       = 30
      health_check_path = "/ping"
      description       = "AHSAT Analytics Service HTTPS"
      neg_self_links    = [
        "https://www.googleapis.com/compute/v1/projects/project-nonprod-env/zones/us-east1-b/networkEndpointGroups/k8s1-00000000-namespace-service-80-00000000",
        "https://www.googleapis.com/compute/v1/projects/project-nonprod-env/zones/us-east1-c/networkEndpointGroups/k8s1-00000000-namespace-service-80-00000000",
        "https://www.googleapis.com/compute/v1/projects/project-nonprod-env/zones/us-east1-d/networkEndpointGroups/k8s1-00000000-namespace-service-80-00000000"
      ]
    }
    ais-5050 = {
      port              = 5050
      backend_port      = 5050
      timeout_sec       = 300
      health_check_path = "/health"
      description       = "AI Image Service HTTPS"
      neg_self_links    = [
        "https://www.googleapis.com/compute/v1/projects/project-nonprod-env/zones/us-east1-b/networkEndpointGroups/k8s1-00000000-namespace-service-80-00000000",
        "https://www.googleapis.com/compute/v1/projects/project-nonprod-env/zones/us-east1-c/networkEndpointGroups/k8s1-00000000-namespace-service-80-00000000",
        "https://www.googleapis.com/compute/v1/projects/project-nonprod-env/zones/us-east1-d/networkEndpointGroups/k8s1-00000000-namespace-service-80-00000000"
      ]
    }
    aes-1988 = {
      port              = 1988
      backend_port      = 1988
      timeout_sec       = 30
      health_check_path = "/health"
      description       = "Email Service HTTPS"
      neg_self_links    = [
        "https://www.googleapis.com/compute/v1/projects/project-nonprod-env/zones/us-east1-b/networkEndpointGroups/k8s1-00000000-namespace-service-80-00000000",
        "https://www.googleapis.com/compute/v1/projects/project-nonprod-env/zones/us-east1-c/networkEndpointGroups/k8s1-00000000-namespace-service-80-00000000",
        "https://www.googleapis.com/compute/v1/projects/project-nonprod-env/zones/us-east1-d/networkEndpointGroups/k8s1-00000000-namespace-service-80-00000000"
      ]
    }
    aps-4444 = {
      port              = 4444
      backend_port      = 4444
      timeout_sec       = 30
      health_check_path = "/v0/aps/ping"
      description       = "Payment Service HTTPS"
      neg_self_links    = [
        "https://www.googleapis.com/compute/v1/projects/project-nonprod-env/zones/us-east1-b/networkEndpointGroups/k8s1-00000000-namespace-service-80-00000000",
        "https://www.googleapis.com/compute/v1/projects/project-nonprod-env/zones/us-east1-c/networkEndpointGroups/k8s1-00000000-namespace-service-80-00000000",
        "https://www.googleapis.com/compute/v1/projects/project-nonprod-env/zones/us-east1-d/networkEndpointGroups/k8s1-00000000-namespace-service-80-00000000"
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
    environment = "stg"
    project     = "gameplatform"
    managed_by  = "terragrunt"
    owner       = "infrastructure-team"
    cost_center = "staging"
    access      = "external-alb"
  }
}
