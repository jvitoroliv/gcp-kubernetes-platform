# =============================================================================
# 09-VM-SERVICES-LB STACK - LEGACY ENVIRONMENT
# =============================================================================
# Creates HTTPS Load Balancer for VM-based services with TLS termination
# Services: afs, nakama, ahsat, acrypt (run on rogues-server VM)

include "root" {
  path = find_in_parent_folders()
}

include "env" {
  path   = "${get_terragrunt_dir()}/../env.hcl"
  expose = true
}

terraform {
  source = "${get_repo_root()}/stacks-legacy/09-vm-services-lb"
}

dependency "compute" {
  config_path = "../05-compute"

  mock_outputs = {
    instance_self_link   = "projects/project-legacy-env/zones/southamerica-east1-a/instances/rogues-server"
    instance_external_ip = "35.199.116.123"
    instance_zone        = "southamerica-east1-a"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

inputs = {
  project_id  = include.env.locals.project_id
  environment = include.env.locals.environment
  region      = include.env.locals.region

  # Load balancer name
  lb_name = "rogues-vm-services-lb"

  # SSL certificate domains
  ssl_domains = [
    "afs.example-game.wtf",
    "nakama.example-game.wtf",
    "ahsat.example-game.wtf",
    "acrypt.example-game.wtf"
  ]

  # VM configuration
  vm_zone      = dependency.compute.outputs.instance_zone
  vm_self_link = dependency.compute.outputs.instance_self_link

  # Backend services configuration (host-based routing)
  backend_services = {
    afs = {
      port  = 9933
      hosts = ["afs.example-game.wtf"]
    }
    nakama = {
      port  = 7350
      hosts = ["nakama.example-game.wtf"]
    }
    ahsat = {
      port  = 6969
      hosts = ["ahsat.example-game.wtf"]
    }
    acrypt = {
      port  = 14333
      hosts = ["acrypt.example-game.wtf"]
    }
  }

  # Default service (fallback)
  default_service = "nakama"

  labels = {
    environment = "legacy"
    project     = "gameplatform"
    service     = "rogues"
    component   = "vm-services-lb"
    managed_by  = "terragrunt"
  }
}
