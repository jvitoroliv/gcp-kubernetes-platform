# ======================================================================
# LOBBY-BACKEND (NestJS API) Infrastructure
# ======================================================================

# Data source for existing ECR repository
data "aws_ecr_repository" "lobby_backend" {
  name = "gameplatform-lobby-backend"
}

# CloudWatch Log Group for Lobby Backend
module "lobby_backend_log_group" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/cloudwatch-log-group?ref=main"

  name              = "/aws/ecs/gameplatform-${var.environment}-lobby-backend"
  retention_in_days = var.log_retention_days

  tags = local.tags
}

# Lobby Backend Task Definition
module "lobby_backend_task_definition" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/ecs-task-definition?ref=main"

  family                   = "gameplatform-${var.environment}-lobby-backend"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = module.ecs_execution_role.arn
  task_role_arn            = module.ecs_task_role.arn

  container = {
    name      = "lobby-backend"
    image     = var.container_images.lobby_backend != "" ? var.container_images.lobby_backend : "${data.aws_ecr_repository.lobby_backend.repository_url}:latest"
    essential = true

    port_mappings = [
      {
        container_port = var.lobby_backend_port
        host_port      = var.lobby_backend_port
        protocol       = "tcp"
      }
    ]

    log_group_name = module.lobby_backend_log_group.name
    environment = {
      # Database connection
      DB_HOST                = "${data.aws_db_instance.shared_rds.address}"
      DB_PORT                = "${data.aws_db_instance.shared_rds.port}"
      DB_USER                = "nakama"
      DB_PASSWORD            = "${DB_PASSWORD}"
      DB_NAME                = "nakamatest"
      
      # Nakama connection (use public HTTPS endpoint)
      NAKAMA_HOST            = "nakama.${var.domain_name}"
      NAKAMA_PORT            = "7350"
      NAKAMA_SERVER_KEY      = "${NAKAMA_SERVER_KEY}"
      NAKAMA_USE_SSL         = "true"
      
      # Service URLs (use public HTTPS URLs)
      AHSAT_HOST             = "https://ahsat.${var.domain_name}"
      AFS_HOST               = "https://afs.${var.domain_name}"
      AES_URL                = "https://aes.${var.domain_name}"
      
      # OAuth configuration
      OAUTH_CLIENT_ID        = "${GOOGLE_CLIENT_ID}"
      
      # Email/AES configuration
      AES_API_KEY            = "${AES_API_KEY}"
      SMTP_SERVER            = "email-smtp.us-east-1.amazonaws.com"
      SMTP_PORT              = "587"
      SMTP_USER              = "${AWS_SES_ACCESS_KEY}"
      SMTP_PASSWORD          = "${AWS_SES_SMTP_PASSWORD}"
      
      # Optional configurations
      PORT                   = tostring(var.lobby_backend_port)
      MAX_DISPLAY_NAME_LENGTH = "15"

      APS_HOST = "https://aps.dev.gameplatform.click/"

      HUBSPOT_PRIVATE_APP_TOKEN = "${HUBSPOT_TOKEN}"
    }


  }
}

# Lobby Backend ALB Target Group
module "lobby_backend_target_group" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/alb-target-group?ref=main"

  name     = "gameplatform-${var.environment}-lobby-be" # Shortened due to AWS name limits
  port     = var.lobby_backend_port
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.main.id

  health_check = {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = var.health_check_path.lobby_backend
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 3
  }

  target_type = "ip"

  tags = local.tags
}

# Lobby Backend ALB Listener Rule
module "lobby_backend_listener_rule" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/alb-listener-rule?ref=main"

  listener_arn = data.aws_lb_listener.shared_https.arn
  priority     = 600 + tonumber(var.pr_number)

  condition = {
    host_header = {
      values = ["lobby-backend.${var.domain_name}"]
    }
  }

  action = {
    type             = "forward"
    target_group_arn = module.lobby_backend_target_group.arn
  }
}

# Lobby Backend Route53 Record
module "lobby_backend_dns_record" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/route53-record?ref=main"

  zone_id = data.aws_route53_zone.main.zone_id
  name    = "lobby-backend"
  type    = "A"

  alias = {
    name                   = data.aws_lb.shared.dns_name
    zone_id                = data.aws_lb.shared.zone_id
    evaluate_target_health = true
  }
}

# Lobby Backend ECS Service
module "lobby_backend_service" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/ecs-service?ref=main"

  name                   = "gameplatform-${var.environment}-lobby-backend"
  cluster_arn            = data.aws_ecs_cluster.shared.arn
  task_definition        = module.lobby_backend_task_definition.arn
  desired_count          = var.desired_count
  launch_type            = "FARGATE"
  enable_execute_command = true

  network_configuration = {
    subnets          = data.aws_subnets.private.ids
    security_groups  = [module.security_group.id]
    assign_public_ip = false
  }

  load_balancer = {
    target_group_arn = module.lobby_backend_target_group.arn
    container_name   = "lobby-backend"
    container_port   = var.lobby_backend_port
  }

  service_registries = [
    {
      registry_arn = module.lobby_backend_service_discovery.arn
    }
  ]

  depends_on = [module.lobby_backend_listener_rule]
}

# ======================================================================
# LOBBY-BACKEND SERVICE DISCOVERY
# ======================================================================

# Service Discovery Service for Lobby Backend
module "lobby_backend_service_discovery" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/service-discovery-service?ref=main"

  name         = "lobby-backend"
  namespace_id = module.service_discovery_namespace.id
  description  = "Service discovery for Lobby Backend API"

  dns_ttl        = 10
  dns_type       = "A"
  routing_policy = "MULTIVALUE"

  health_check_custom_config = {
    failure_threshold = 1
  }

  tags = local.tags
}
