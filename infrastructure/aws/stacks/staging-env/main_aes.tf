# ======================================================================
# AES (GamePlatform Email Service) Infrastructure
# ======================================================================

# Data source for existing ECR repository
data "aws_ecr_repository" "aes" {
  name = "gameplatform-aes"
}

# SES Configuration for AES
module "ses_configuration" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/ses-configuration?ref=main"

  domain_name            = var.domain_name
  from_email             = "noreply@${var.domain_name}"
  configuration_set_name = "gameplatform-${var.environment}-ses"
  smtp_user_name         = "gameplatform-${var.environment}-ses-smtp"
  region                 = var.aws_region
  create_smtp_user       = false # Using hardcoded credentials for dev

  tags = local.tags
}

# # Secrets Manager for AES API Key
# module "aes_api_key_secret" {
#   source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/secretsmanager-secret?ref=main"

#   name        = "gameplatform-${var.environment}-aes-api-key"
#   description = "API key for AES email service"

#   secret_string = jsonencode({
#     api_key = random_password.aes_api_key.result
#   })

#   tags = local.tags
# }

# # Generate random API key for AES
# resource "random_password" "aes_api_key" {
#   length  = 32
#   special = true
# }

# AES Task Definition
module "aes_task_definition" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/ecs-task-definition?ref=main"

  family                   = "gameplatform-${var.environment}-aes"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = module.ecs_execution_role.arn
  task_role_arn            = module.ecs_task_role.arn

  container = {
    name      = "aes"
    image     = var.container_images.aes != "" ? var.container_images.aes : "${data.aws_ecr_repository.aes.repository_url}:latest"
    essential = true

    port_mappings = [
      {
        container_port = var.aes_port
        host_port      = var.aes_port
        protocol       = "tcp"
      }
    ]

    log_group_name = module.aes_log_group.name

    environment = {
      # Service config
      AES_PORT      = "1988"
      AES-API-KEY   = "${AES_API_KEY}"
      
      # SMTP/Email config
      SMTP_SERVER   = "email-smtp.us-east-1.amazonaws.com"
      SMTP_PORT     = "587"
      SMTP_USER     = "${AWS_SES_ACCESS_KEY}"
      SMTP_PASSWORD = "${AWS_SES_SMTP_PASSWORD}"
      FROM_EMAIL    = "no-reply@gameplatform.example.com"
    }

  }
}

# AES ALB Target Group
module "aes_target_group" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/alb-target-group?ref=main"

  name     = "gameplatform-${var.environment}-aes"
  port     = var.aes_port
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.main.id

  health_check = {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = var.health_check_path.aes
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 3
  }

  target_type = "ip"

  tags = local.tags
}

# AES ALB Listener Rule
module "aes_listener_rule" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/alb-listener-rule?ref=main"

  listener_arn = data.aws_lb_listener.shared_https.arn
  priority     = 500 + tonumber(var.pr_number)

  condition = {
    host_header = {
      values = ["aes.${var.domain_name}"]
    }
  }

  action = {
    type             = "forward"
    target_group_arn = module.aes_target_group.arn
  }
}

# AES Route53 Record
module "aes_dns_record" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/route53-record?ref=main"

  zone_id = data.aws_route53_zone.main.zone_id
  name    = "aes"
  type    = "A"

  alias = {
    name                   = data.aws_lb.shared.dns_name
    zone_id                = data.aws_lb.shared.zone_id
    evaluate_target_health = true
  }
}

# AES ECS Service
module "aes_service" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/ecs-service?ref=main"

  name                   = "gameplatform-${var.environment}-aes"
  cluster_arn            = module.ecs_cluster.arn
  task_definition        = module.aes_task_definition.arn
  desired_count          = var.desired_count
  launch_type            = "FARGATE"
  enable_execute_command = true

  network_configuration = {
    subnets          = data.aws_subnets.private.ids
    security_groups  = [module.security_group.id]
    assign_public_ip = false
  }

  load_balancer = {
    target_group_arn = module.aes_target_group.arn
    container_name   = "aes"
    container_port   = var.aes_port
  }

  service_registries = [
    {
      registry_arn = module.aes_service_discovery.arn
    }
  ]

  depends_on = [module.aes_listener_rule]
}

# ======================================================================
# AES SERVICE DISCOVERY
# ======================================================================

# Service Discovery Service for AES
module "aes_service_discovery" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/service-discovery-service?ref=main"

  name         = "aes"
  namespace_id = module.service_discovery_namespace.id
  description  = "Service discovery for AES email service"

  dns_ttl        = 10
  dns_type       = "A"
  routing_policy = "MULTIVALUE"

  health_check_custom_config = {
    failure_threshold = 1
  }

  tags = local.tags
}

# ======================================================================
# AES ADDITIONAL HTTPS LISTENER (1988)
# ======================================================================

# HTTPS Listener for port 1988
module "aes_https_listener_1988" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/alb-listener?ref=main"

  load_balancer_arn = data.aws_lb.shared.arn
  port              = 1988
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-Res-2021-06"
  certificate_arn   = data.aws_acm_certificate.wildcard.arn

  default_action = {
    type             = "forward"
    target_group_arn = module.aes_target_group.arn
  }

  rules = [
    {
      priority         = 1
      host_headers     = ["aes.${var.domain_name}"]
      path_patterns    = null
      target_group_arn = module.aes_target_group.arn
    }
  ]

  tags = local.tags
}
