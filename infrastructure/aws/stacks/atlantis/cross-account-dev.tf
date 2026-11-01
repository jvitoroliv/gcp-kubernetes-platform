module "atlantis_cross-account_role" {
  source = "github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/iam-role"

  name = "gameplatform-${var.environment}-atlantis-cross-account-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::777777777772:role/project-live-atlantis-task-role"
        }
      }
    ]
  })

  tags = local.tags
}


module "atlantis_cross-account_policy" {
  source = "github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/iam-policy"

  name = "gameplatform-${var.environment}-atlantis-cross-account"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["*"]
        Resource = ["*"]
      }
    ]
  })
}


module "atlantis_cross-account_policy_attachment" {
  source = "github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/iam-role-policy-attachment"

  role       = module.atlantis_cross-account_role.name
  policy_arn = module.atlantis_cross-account_policy.arn
}


resource "aws_s3_bucket_policy" "tfstate_cross_account" {
  # Only apply this policy in dev environment (where the bucket exists)
  count = var.environment == "dev" ? 1 : 0

  bucket = "gameplatform-us-east-1-tfstate"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCrossAccountAccess"
        Effect = "Allow"
        Principal = {
          AWS = module.atlantis_cross-account_role.arn
        }
        Action = [
          "s3:*"
        ]
        Resource = [
          "arn:aws:s3:::gameplatform-us-east-1-tfstate",
          "arn:aws:s3:::gameplatform-us-east-1-tfstate/*"
        ]
      }
    ]
  })
}