bucket         = "gameplatform-us-east-1-tfstate"
key            = "shared-infrastructure/persistent-env/dev/terraform.tfstate"
region         = "us-east-1"
encrypt        = true
dynamodb_table = "gameplatform-us-east-1-tf-locks"