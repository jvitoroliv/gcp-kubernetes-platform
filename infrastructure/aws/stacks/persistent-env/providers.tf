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

  default_tags {
    tags = local.common_tags
  }
}

# provider "aws" {
#   alias   = "ug-network-core-us"
#   region  = "us-east-1"
#   assume_role {
#     role_arn     = "arn:aws:iam::777777777773:role/cross_account_admin_role"
#     session_name = "terraform-session"
#   }
#   profile = "ug-management-core"
# }