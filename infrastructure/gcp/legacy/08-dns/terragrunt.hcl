# =============================================================================
# 08-DNS STACK - LEGACY ENVIRONMENT
# =============================================================================
# Creates Cloud DNS zones and records for Rogues (migrated from Route 53)

include "root" {
  path = find_in_parent_folders()
}

include "env" {
  path   = "${get_terragrunt_dir()}/../env.hcl"
  expose = true
}

terraform {
  source = "${get_repo_root()}/stacks-legacy/08-dns"
}

dependency "load_balancer" {
  config_path = "../07-load-balancer"

  mock_outputs = {
    lb_ip_address = "34.120.0.1"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

dependency "middleware_lb" {
  config_path = "../11-middleware-lb"

  mock_outputs = {
    lb_ip_address = "34.120.0.4"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

dependency "compute" {
  config_path = "../05-compute"

  mock_outputs = {
    instance_external_ip = "34.120.0.2"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

dependency "vm_services_lb" {
  config_path = "../09-vm-services-lb"

  mock_outputs = {
    lb_ip_address = "34.120.0.3"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

inputs = {
  project_id  = include.env.locals.project_id
  environment = include.env.locals.environment
  region      = include.env.locals.region

  # DNS Zones (migrated from Route 53)
  dns_zones = {
    rogues-wtf = {
      dns_name    = "example-game.wtf."
      description = "Rogues production domain"
      visibility  = "public"
    }
    temprogues-click = {
      dns_name    = "example-game.click."
      description = "Rogues temporary/test domain"
      visibility  = "public"
    }
  }

  # DNS Records (replicated from AWS Route53)
  dns_records = {
    # example-game.wtf records - middleware (VM via dedicated LB)
    rogues-wtf-root = {
      zone    = "rogues-wtf"
      name    = "example-game.wtf."
      type    = "A"
      ttl     = 300
      rrdatas = [dependency.middleware_lb.outputs.lb_ip_address]
    }

    # example-game.wtf records - backend services (via VM Services LB with TLS termination)
    rogues-wtf-acrypt = {
      zone    = "rogues-wtf"
      name    = "acrypt.example-game.wtf."
      type    = "A"
      ttl     = 300
      rrdatas = [dependency.vm_services_lb.outputs.lb_ip_address]
    }
    rogues-wtf-afs = {
      zone    = "rogues-wtf"
      name    = "afs.example-game.wtf."
      type    = "A"
      ttl     = 300
      rrdatas = [dependency.vm_services_lb.outputs.lb_ip_address]
    }
    rogues-wtf-ahsat = {
      zone    = "rogues-wtf"
      name    = "ahsat.example-game.wtf."
      type    = "A"
      ttl     = 300
      rrdatas = [dependency.vm_services_lb.outputs.lb_ip_address]
    }
    rogues-wtf-nakama = {
      zone    = "rogues-wtf"
      name    = "nakama.example-game.wtf."
      type    = "A"
      ttl     = 300
      rrdatas = [dependency.vm_services_lb.outputs.lb_ip_address]
    }
    rogues-wtf-nlb = {
      zone    = "rogues-wtf"
      name    = "nlb.example-game.wtf."
      type    = "A"
      ttl     = 300
      rrdatas = [dependency.load_balancer.outputs.lb_ip_address]
    }

    # example-game.click records
    temprogues-click-root = {
      zone    = "temprogues-click"
      name    = "example-game.click."
      type    = "A"
      ttl     = 300
      rrdatas = [dependency.load_balancer.outputs.lb_ip_address]
    }
    temprogues-click-afs = {
      zone    = "temprogues-click"
      name    = "afs.example-game.click."
      type    = "A"
      ttl     = 300
      rrdatas = [dependency.load_balancer.outputs.lb_ip_address]
    }
    temprogues-click-ahsat = {
      zone    = "temprogues-click"
      name    = "ahsat.example-game.click."
      type    = "A"
      ttl     = 300
      rrdatas = [dependency.load_balancer.outputs.lb_ip_address]
    }
    temprogues-click-nakama = {
      zone    = "temprogues-click"
      name    = "nakama.example-game.click."
      type    = "A"
      ttl     = 300
      rrdatas = [dependency.load_balancer.outputs.lb_ip_address]
    }
  }

  labels = {
    environment = "legacy"
    project     = "gameplatform"
    service     = "rogues"
    component   = "dns"
    managed_by  = "terragrunt"
  }
}
