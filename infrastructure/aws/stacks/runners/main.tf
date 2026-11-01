locals {
  common_tags = {
    Project         = "GamePlatform"
    Environment     = var.environment
    Component       = "Runners"
    ManagedBy       = "terraform"
    TerraformModule = "gameplatform-shared-infrastructure/runners"
  }

  tags = merge(local.common_tags, var.additional_tags)
}

module "ecs_cluster" {
  source = "github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/ecs-cluster"

  name                               = "gameplatform-${var.environment}-shared-cluster"
  enable_container_insights          = var.enable_container_insights
  default_capacity_providers         = var.capacity_providers
  default_capacity_provider_strategy = var.capacity_provider_strategy

  tags = local.tags
}

