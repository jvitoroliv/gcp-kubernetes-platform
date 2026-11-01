# =============================================================================
# 02-NETWORKING STACK - LEGACY ENVIRONMENT
# =============================================================================
# Creates VPC, subnet, firewall rules, and NAT for Rogues

include "root" {
  path = find_in_parent_folders()
}

include "env" {
  path   = "${get_terragrunt_dir()}/../env.hcl"
  expose = true
}

terraform {
  source = "${get_repo_root()}/stacks-legacy/02-networking"
}

dependency "foundation" {
  config_path = "../01-foundation"

  mock_outputs = {
    project_id = "project-legacy-env"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

inputs = {
  project_id  = include.env.locals.project_id
  environment = include.env.locals.environment
  region      = include.env.locals.region

  # VPC Configuration
  vpc_name = "gameplatform-legacy-vpc"

  # Subnet Configuration
  subnet_name       = "gameplatform-legacy-subnet"
  subnet_cidr       = "10.200.0.0/20"
  subnet_region     = include.env.locals.region

  # Firewall rules
  firewall_rules = {
    allow-internal = {
      description   = "Allow internal traffic"
      direction     = "INGRESS"
      priority      = 1000
      source_ranges = ["10.200.0.0/20"]
      allow_rules = [
        { protocol = "tcp", ports = ["0-65535"] },
        { protocol = "udp", ports = ["0-65535"] },
        { protocol = "icmp" }
      ]
    }
    allow-ssh-iap = {
      description   = "Allow SSH via IAP"
      direction     = "INGRESS"
      priority      = 1000
      source_ranges = ["35.235.240.0/20"]
      allow_rules = [
        { protocol = "tcp", ports = ["22"] }
      ]
    }
    allow-health-checks = {
      description   = "Allow GCP health checks"
      direction     = "INGRESS"
      priority      = 1000
      source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
      allow_rules = [
        { protocol = "tcp" }
      ]
    }
    allow-rogues-server = {
      description   = "Allow Rogues game server ports"
      direction     = "INGRESS"
      priority      = 1000
      source_ranges = ["0.0.0.0/0"]
      target_tags   = ["rogues-server"]
      allow_rules = [
        # Nakama game server
        { protocol = "tcp", ports = ["7349", "7350", "7351"] },
        { protocol = "udp", ports = ["7350", "7351"] },
        # AFS - Asset file server
        { protocol = "tcp", ports = ["9933"] },
        # AHSAT - Analytics/telemetry
        { protocol = "tcp", ports = ["6969"] },
        # Dashboard
        { protocol = "tcp", ports = ["9999"] },
        # ACrypt - OAuth callbacks
        { protocol = "tcp", ports = ["14333"] },
        # APS - Payment service
        { protocol = "tcp", ports = ["8989"] },
      ]
    }
    allow-rogues-middleware = {
      description   = "Allow Rogues middleware port"
      direction     = "INGRESS"
      priority      = 1000
      source_ranges = ["0.0.0.0/0"]
      target_tags   = ["rogues-middleware"]
      allow_rules = [
        # Middleware web server
        { protocol = "tcp", ports = ["3333"] },
      ]
    }
  }

  # NAT Configuration
  create_nat = true

  labels = {
    environment = "legacy"
    project     = "gameplatform"
    service     = "rogues"
    managed_by  = "terragrunt"
  }
}
