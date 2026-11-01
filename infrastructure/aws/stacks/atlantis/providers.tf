terraform {
  required_version = ">= 1.13"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region

  # Dynamic assume_role block for cross-account access
  # Will use assume_role_arn variable if set
  dynamic "assume_role" {
    for_each = length(try(var.assume_role_arn, "")) > 0 ? [1] : []
    content {
      role_arn = var.assume_role_arn
    }
  }

  # Avoid dynamic values (e.g., CreatedDate) in default_tags to prevent
  # provider plan/apply inconsistencies. Use a stable subset.
  default_tags {
    tags = {
      Project         = "GamePlatform"
      Environment     = var.environment
      Component       = "Atlantis"
      ManagedBy       = "terraform"
      TerraformModule = "gameplatform-shared-infrastructure/atlantis"
    }
  }
}
