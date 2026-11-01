bucket         = "gameplatform-terraform-state-live"
key            = "dns-and-alb/terraform.tfstate"
region         = "sa-east-1"
encrypt        = true
dynamodb_table = "gameplatform-terraform-state-lock-live"