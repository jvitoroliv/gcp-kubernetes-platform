# =============================================================================
# 11-MIDDLEWARE-LB STACK - LEGACY ENVIRONMENT
# =============================================================================
# Creates HTTPS Load Balancer for the middleware VM
# Handles example-game.wtf domain with TLS termination

include "root" {
  path = find_in_parent_folders()
}

include "env" {
  path   = "${get_terragrunt_dir()}/../env.hcl"
  expose = true
}

terraform {
  source = "${get_repo_root()}/stacks-legacy/11-middleware-lb"
}

dependency "middleware_vm" {
  config_path = "../10-middleware-vm"

  mock_outputs = {
    instance_self_link = "projects/project-legacy-env/zones/southamerica-east1-a/instances/rogues-middleware"
    instance_zone      = "southamerica-east1-a"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

inputs = {
  project_id  = include.env.locals.project_id
  environment = include.env.locals.environment
  region      = include.env.locals.region

  # Load balancer name (different from 07-load-balancer to avoid conflict)
  lb_name = "rogues-middleware-vm-lb"

  # SSL certificate domain
  ssl_domains = ["example-game.wtf"]

  # VM configuration
  vm_zone      = dependency.middleware_vm.outputs.instance_zone
  vm_self_link = dependency.middleware_vm.outputs.instance_self_link

  # Service port
  service_port = 3333

  labels = {
    environment = "legacy"
    project     = "gameplatform"
    service     = "rogues"
    component   = "middleware-lb"
    managed_by  = "terragrunt"
  }
}
