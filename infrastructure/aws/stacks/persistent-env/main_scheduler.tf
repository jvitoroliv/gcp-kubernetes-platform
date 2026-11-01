# ======================================================================
# ENVIRONMENT SCHEDULER - AUTOMATED SHUTDOWN/STARTUP
# ======================================================================
# Automatically shuts down non-production resources during off-hours
# to optimize costs and starts them back up during business hours

locals {
  scheduler_enabled = var.enable_scheduler

  # Lambda configuration
  lambda_runtime     = "python3.12"
  lambda_timeout     = 300 # 5 minutes
  lambda_memory_size = 256 # MB

  # Schedule configuration (UTC times)
  # Shutdown: 23:00 UTC = 20:00 BRT (Brazil - 8 PM)
  # Startup:  09:00 UTC = 06:00 BRT (Brazil - 6 AM)
  shutdown_schedule = var.scheduler_shutdown_cron
  startup_schedule  = var.scheduler_startup_cron
}

# ======================================================================
# DYNAMODB TABLE FOR STATE TRACKING
# ======================================================================

module "scheduler_state_table" {
  count  = local.scheduler_enabled ? 1 : 0
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/dynamodb-table?ref=main"

  name         = "gameplatform-${var.environment}-scheduler-state"
  billing_mode = "PAY_PER_REQUEST" # On-demand pricing

  hash_key  = "resource_id"
  range_key = "environment"

  attributes = [
    {
      name = "resource_id"
      type = "S"
    },
    {
      name = "environment"
      type = "S"
    }
  ]

  ttl = {
    enabled        = true
    attribute_name = "ttl"
  }

  tags = merge(local.tags, {
    Name        = "gameplatform-${var.environment}-scheduler-state"
    Purpose     = "scheduler-state-tracking"
    CostCenter  = "infrastructure-optimization"
    Description = "Stores ECS service and RDS state for scheduler restoration"
  })
}

# ======================================================================
# SNS TOPIC FOR NOTIFICATIONS
# ======================================================================

resource "aws_sns_topic" "scheduler_notifications" {
  count = local.scheduler_enabled ? 1 : 0

  name              = "gameplatform-${var.environment}-scheduler-notifications"
  display_name      = "GamePlatform ${var.environment} Scheduler Notifications"
  kms_master_key_id = "alias/aws/sns"

  tags = merge(local.tags, {
    Name        = "gameplatform-${var.environment}-scheduler-notifications"
    Purpose     = "scheduler-alerts"
    Environment = var.environment
  })
}

# SNS Topic Policy (allow Lambda to publish)
resource "aws_sns_topic_policy" "scheduler_notifications" {
  count = local.scheduler_enabled ? 1 : 0

  arn = aws_sns_topic.scheduler_notifications[0].arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowLambdaPublish"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = [
          "SNS:Publish"
        ]
        Resource = aws_sns_topic.scheduler_notifications[0].arn
      }
    ]
  })
}

# Optional: SNS Email Subscription (configure in tfvars)
resource "aws_sns_topic_subscription" "scheduler_email" {
  count = local.scheduler_enabled && var.scheduler_notification_email != "" ? 1 : 0

  topic_arn = aws_sns_topic.scheduler_notifications[0].arn
  protocol  = "email"
  endpoint  = var.scheduler_notification_email
}

# ======================================================================
# IAM ROLE FOR LAMBDA FUNCTIONS
# ======================================================================

module "scheduler_lambda_role" {
  count  = local.scheduler_enabled ? 1 : 0
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/iam-role?ref=main"

  name        = "gameplatform-${var.environment}-scheduler-lambda-role"
  description = "IAM role for environment scheduler Lambda functions"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = local.tags
}

# Lambda Basic Execution Policy
module "scheduler_lambda_basic_policy_attachment" {
  count  = local.scheduler_enabled ? 1 : 0
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/iam-role-policy-attachment?ref=main"

  role       = module.scheduler_lambda_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Custom Policy for Scheduler Operations
module "scheduler_operations_policy" {
  count  = local.scheduler_enabled ? 1 : 0
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/iam-policy?ref=main"

  name        = "gameplatform-${var.environment}-scheduler-operations"
  description = "Policy for scheduler Lambda to manage ECS services and RDS instances"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECSOperations"
        Effect = "Allow"
        Action = [
          "ecs:ListServices",
          "ecs:DescribeServices",
          "ecs:UpdateService"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "ecs:cluster" = data.aws_ecs_cluster.shared.arn
          }
        }
      },
      {
        Sid    = "RDSOperations"
        Effect = "Allow"
        Action = [
          "rds:DescribeDBInstances",
          "rds:StopDBInstance",
          "rds:StartDBInstance"
        ]
        Resource = "arn:aws:rds:${var.aws_region}:${data.aws_caller_identity.current.account_id}:db:${var.environment}-postgres-postgres"
      },
      {
        Sid    = "DynamoDBOperations"
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:Scan",
          "dynamodb:Query"
        ]
        Resource = local.scheduler_enabled ? module.scheduler_state_table[0].table_arn : "*"
      },
      {
        Sid    = "SNSPublish"
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = local.scheduler_enabled ? aws_sns_topic.scheduler_notifications[0].arn : "*"
      },
      {
        Sid    = "CloudWatchMetrics"
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
      }
    ]
  })

  tags = local.tags
}

module "scheduler_operations_policy_attachment" {
  count  = local.scheduler_enabled ? 1 : 0
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/iam-role-policy-attachment?ref=main"

  role       = module.scheduler_lambda_role[0].name
  policy_arn = module.scheduler_operations_policy[0].arn
}

# ======================================================================
# CLOUDWATCH LOG GROUPS
# ======================================================================

module "scheduler_shutdown_log_group" {
  count  = local.scheduler_enabled ? 1 : 0
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/cloudwatch-log-group?ref=main"

  name              = "/aws/lambda/gameplatform-${var.environment}-scheduler-shutdown"
  retention_in_days = var.log_retention_days
}

module "scheduler_startup_log_group" {
  count  = local.scheduler_enabled ? 1 : 0
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/cloudwatch-log-group?ref=main"

  name              = "/aws/lambda/gameplatform-${var.environment}-scheduler-startup"
  retention_in_days = var.log_retention_days
}

# ======================================================================
# LAMBDA FUNCTIONS
# ======================================================================

# Package Lambda code
data "archive_file" "scheduler_lambda" {
  count = local.scheduler_enabled ? 1 : 0

  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/.terraform/scheduler_lambda.zip"
}

# Shutdown Lambda Function
resource "aws_lambda_function" "scheduler_shutdown" {
  count = local.scheduler_enabled ? 1 : 0

  filename         = data.archive_file.scheduler_lambda[0].output_path
  function_name    = "gameplatform-${var.environment}-scheduler-shutdown"
  role             = module.scheduler_lambda_role[0].arn
  handler          = "scheduler_shutdown.lambda_handler"
  source_code_hash = data.archive_file.scheduler_lambda[0].output_base64sha256
  runtime          = local.lambda_runtime
  timeout          = local.lambda_timeout
  memory_size      = local.lambda_memory_size

  environment {
    variables = {
      ENVIRONMENT      = var.environment
      CLUSTER_NAME     = data.aws_ecs_cluster.shared.cluster_name
      DB_INSTANCE_ID   = "${var.environment}-postgres-postgres"
      STATE_TABLE_NAME = module.scheduler_state_table[0].table_name
      SNS_TOPIC_ARN    = aws_sns_topic.scheduler_notifications[0].arn
    }
  }

  depends_on = [
    module.scheduler_shutdown_log_group,
    module.scheduler_lambda_basic_policy_attachment,
    module.scheduler_operations_policy_attachment
  ]

  tags = merge(local.tags, {
    Name        = "gameplatform-${var.environment}-scheduler-shutdown"
    Purpose     = "cost-optimization-shutdown"
    Environment = var.environment
  })
}

# Startup Lambda Function
resource "aws_lambda_function" "scheduler_startup" {
  count = local.scheduler_enabled ? 1 : 0

  filename         = data.archive_file.scheduler_lambda[0].output_path
  function_name    = "gameplatform-${var.environment}-scheduler-startup"
  role             = module.scheduler_lambda_role[0].arn
  handler          = "scheduler_startup.lambda_handler"
  source_code_hash = data.archive_file.scheduler_lambda[0].output_base64sha256
  runtime          = local.lambda_runtime
  timeout          = local.lambda_timeout
  memory_size      = local.lambda_memory_size

  environment {
    variables = {
      ENVIRONMENT      = var.environment
      CLUSTER_NAME     = data.aws_ecs_cluster.shared.cluster_name
      DB_INSTANCE_ID   = "${var.environment}-postgres-postgres"
      STATE_TABLE_NAME = module.scheduler_state_table[0].table_name
      SNS_TOPIC_ARN    = aws_sns_topic.scheduler_notifications[0].arn
    }
  }

  depends_on = [
    module.scheduler_startup_log_group,
    module.scheduler_lambda_basic_policy_attachment,
    module.scheduler_operations_policy_attachment
  ]

  tags = merge(local.tags, {
    Name        = "gameplatform-${var.environment}-scheduler-startup"
    Purpose     = "cost-optimization-startup"
    Environment = var.environment
  })
}

# ======================================================================
# EVENTBRIDGE RULES FOR SCHEDULING
# ======================================================================

# Shutdown Rule
resource "aws_cloudwatch_event_rule" "scheduler_shutdown" {
  count = local.scheduler_enabled ? 1 : 0

  name                = "gameplatform-${var.environment}-scheduler-shutdown"
  description         = "Trigger environment shutdown during off-hours"
  schedule_expression = local.shutdown_schedule
  state               = var.scheduler_enabled ? "ENABLED" : "DISABLED"

  tags = merge(local.tags, {
    Name        = "gameplatform-${var.environment}-scheduler-shutdown"
    Purpose     = "automated-shutdown"
    Environment = var.environment
  })
}

resource "aws_cloudwatch_event_target" "scheduler_shutdown" {
  count = local.scheduler_enabled ? 1 : 0

  rule      = aws_cloudwatch_event_rule.scheduler_shutdown[0].name
  target_id = "SchedulerShutdownLambda"
  arn       = aws_lambda_function.scheduler_shutdown[0].arn
}

resource "aws_lambda_permission" "scheduler_shutdown_eventbridge" {
  count = local.scheduler_enabled ? 1 : 0

  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.scheduler_shutdown[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.scheduler_shutdown[0].arn
}

# Startup Rule
resource "aws_cloudwatch_event_rule" "scheduler_startup" {
  count = local.scheduler_enabled ? 1 : 0

  name                = "gameplatform-${var.environment}-scheduler-startup"
  description         = "Trigger environment startup during business hours"
  schedule_expression = local.startup_schedule
  state               = var.scheduler_enabled ? "ENABLED" : "DISABLED"

  tags = merge(local.tags, {
    Name        = "gameplatform-${var.environment}-scheduler-startup"
    Purpose     = "automated-startup"
    Environment = var.environment
  })
}

resource "aws_cloudwatch_event_target" "scheduler_startup" {
  count = local.scheduler_enabled ? 1 : 0

  rule      = aws_cloudwatch_event_rule.scheduler_startup[0].name
  target_id = "SchedulerStartupLambda"
  arn       = aws_lambda_function.scheduler_startup[0].arn
}

resource "aws_lambda_permission" "scheduler_startup_eventbridge" {
  count = local.scheduler_enabled ? 1 : 0

  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.scheduler_startup[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.scheduler_startup[0].arn
}

# ======================================================================
# CLOUDWATCH ALARMS FOR MONITORING
# ======================================================================

resource "aws_cloudwatch_metric_alarm" "scheduler_shutdown_errors" {
  count = local.scheduler_enabled ? 1 : 0

  alarm_name          = "gameplatform-${var.environment}-scheduler-shutdown-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Scheduler shutdown function errors"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.scheduler_shutdown[0].function_name
  }

  alarm_actions = [aws_sns_topic.scheduler_notifications[0].arn]

  tags = local.tags
}

resource "aws_cloudwatch_metric_alarm" "scheduler_startup_errors" {
  count = local.scheduler_enabled ? 1 : 0

  alarm_name          = "gameplatform-${var.environment}-scheduler-startup-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Scheduler startup function errors"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.scheduler_startup[0].function_name
  }

  alarm_actions = [aws_sns_topic.scheduler_notifications[0].arn]

  tags = local.tags
}
