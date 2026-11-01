# =============================================================================
# 10-DNS-RECORDS STACK - PRD ENVIRONMENT
# =============================================================================
# DNS records for gameplatform.example.com domain in Cloud DNS
# Migrating from AWS Route53 hosted zone Z058983535M8LMA6QEXJ6
#
# This stack creates all DNS records needed for the production environment.
# After applying this stack, update the domain nameservers at Namecheap
# to point to Cloud DNS nameservers.

include "root" {
  path = find_in_parent_folders()
}

include "env" {
  path   = "${get_terragrunt_dir()}/../env.hcl"
  expose = true
}

terraform {
  source = "${get_repo_root()}/stacks/10-dns-records"
}

dependency "dns_lb" {
  config_path = "../05-dns-lb"

  mock_outputs = {
    dns_zones = {
      "project-prd-zone" = {
        name         = "project-prd-zone"
        dns_name     = "gameplatform.example.com."
        name_servers = ["ns-cloud-c1.googledomains.com."]
      }
    }
    alb_ip_address = "34.128.188.24"
  }
}

inputs = {
  project_id  = include.env.locals.project_id
  environment = include.env.locals.environment

  # DNS Zone from 05-dns-lb
  dns_zone_name     = dependency.dns_lb.outputs.dns_zones["project-prd-zone"].name
  dns_zone_dns_name = dependency.dns_lb.outputs.dns_zones["project-prd-zone"].dns_name

  # Load Balancer IP (global ALB IP for SSL Proxy)
  alb_ip_address = dependency.dns_lb.outputs.alb_ip_address

  # Service subdomains that point to the ALB
  # These are the GamePlatform platform services
  service_subdomains = [
    "aes",
    "afs",
    "ahsat",
    "ais",
    "ani-metrics",
    "aps",
    "lobby-backend",
    "nakama"
  ]

  labels = {
    environment = "prd"
    project     = "gameplatform"
    component   = "dns-records"
    managed_by  = "terragrunt"
  }
}
