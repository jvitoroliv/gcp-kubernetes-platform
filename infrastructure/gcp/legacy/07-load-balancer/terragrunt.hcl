# =============================================================================
# 07-LOAD-BALANCER STACK - LEGACY ENVIRONMENT
# =============================================================================
# Creates SSL/TLS Load Balancer for Rogues middleware (equivalent to AWS NLB)

include "root" {
  path = find_in_parent_folders()
}

include "env" {
  path   = "${get_terragrunt_dir()}/../env.hcl"
  expose = true
}

terraform {
  source = "${get_repo_root()}/stacks-legacy/07-load-balancer"
}

dependency "cloud_run" {
  config_path = "../06-cloud-run"

  mock_outputs = {
    service_uri = "https://rogues-middleware-xxx.a.run.app"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

inputs = {
  project_id  = include.env.locals.project_id
  environment = include.env.locals.environment
  region      = include.env.locals.region

  # Load balancer name
  lb_name = "rogues-middleware-lb"

  # SSL certificate domains (managed by Google)
  ssl_domains = [
    "example-game.wtf",
    "example-game.click",
    "afs.example-game.click",
    "ahsat.example-game.click",
    "nakama.example-game.click"
  ]

  # Backend: Cloud Run service
  cloud_run_service_name = "rogues-middleware"

  # HTTPS on port 443 (like NLB with TLS)
  port = 443

  labels = {
    environment = "legacy"
    project     = "gameplatform"
    service     = "rogues"
    component   = "load-balancer"
    managed_by  = "terragrunt"
  }
}
