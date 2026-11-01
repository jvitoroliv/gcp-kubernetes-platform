bucket         = "gameplatform-terraform-state-live"
key            = "postgres/terraform.tfstate"
region         = "sa-east-1"
encrypt        = true
dynamodb_table = "gameplatform-terraform-state-lock-live"