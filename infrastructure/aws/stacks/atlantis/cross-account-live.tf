# module "atlantis_assume_dev_policy" {
#   source = "github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/iam-policy"

#   name = "gameplatform-${var.environment}-atlantis-assume-dev"
#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect = "Allow"
#         Action = ["sts:AssumeRole"]
#         Resource = ["arn:aws:iam::777777777771:role/project-dev-atlantis-cross-account-role"]
#       }
#     ]
#   })
# }

# module "atlantis_cross-account_policy_attachment_live" {
#   source = "github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/iam-role-policy-attachment"

#   role       = module.atlantis_task_role.name
#   policy_arn = module.atlantis_assume_dev_policy.arn
# }