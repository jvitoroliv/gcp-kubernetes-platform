# ======================================================================
# AIS (AI Image Service) Infrastructure
# ======================================================================

# Data source for existing ECR repository
data "aws_ecr_repository" "ais" {
  name = "gameplatform-ais"
}

# CloudWatch Log Group for AIS
module "ais_log_group" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/cloudwatch-log-group?ref=main"

  name              = "/aws/ecs/gameplatform-${var.environment}-ais"
  retention_in_days = var.log_retention_days

  tags = local.tags
}

# AIS Task Definition
module "ais_task_definition" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/ecs-task-definition?ref=main"

  family                   = "gameplatform-${var.environment}-ais"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = module.ecs_execution_role.arn
  task_role_arn            = module.ecs_task_role.arn

  container = {
    name      = "ais"
    image     = var.container_images.ais != "" ? var.container_images.ais : "${data.aws_ecr_repository.ais.repository_url}:latest"
    essential = true

    port_mappings = [
      {
        container_port = var.ais_port
        host_port      = var.ais_port
        protocol       = "tcp"
      }
    ]

    log_group_name = module.ais_log_group.name

    environment = {
      # AIS Configuration

      # Database connection
      DB_HOST                   = "${data.aws_db_instance.shared_rds.address}"
      DB_PORT                   = "${data.aws_db_instance.shared_rds.port}"
      DB_USER                   = "nakama"
      DB_PASSWORD               = "${DB_PASSWORD}"
      DB_NAME                   = "nakamatest"

      ahsat_base_url             = "https://ahsat.${var.domain_name}"

      ENV         = "${var.environment}-${data.aws_caller_identity.current.account_id}"

      AIS_PORT = "5050"
      AIS_BASE_URL = "https://ais.${var.domain_name}"
      AIS_LOCAL_STORAGE_PATH = "/data/ais"
      AIS_ENABLE_EMBEDDED_WORKER = "true"
      AIS_APP_SECRET = var.ais_app_secret
      ALLOWED_ORIGINS = "*"
      LOG_LEVEL = "INFO"
      LOG_JSON = "false"
      MAX_REQUEST_BODY_MB = "64"
      PIAPI_BASE_URL = "https://api.piapi.ai"
      USE_S3_ACCELERATE = "false"
      WORKER_CONCURRENCY = "5"
      PIAPI_KEY = "${API_KEY}"
      GEMINI_API_KEY = "${GEMINI_API_KEY}"
      MASTER_PROMPT = "A 3D model of a [text], shown in an isometric 45-degree view. Clean geometry, precise proportions, refined textures, and accurate details. Lighting: flat, neutral, uniform, shadowless, and diffuse—no shading gradients. Object floats freely, isolated, with no contact surfaces. Background: pure transparent alpha, no floor, no pedestal, no base, no ambient occlusion, no reflections, no highlights, no extra objects, no text, no logos. Render: ultra-clean, unshaded colors, pure diffuse light, Unreal Engine 5, Octane render, 4K, fully cutout isolated subject."
    }
  }
}

# AIS ALB Target Group
module "ais_target_group" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/alb-target-group?ref=main"

  name     = "gameplatform-${var.environment}-ais"
  port     = var.ais_port
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.main.id

  health_check = {
    enabled             = true
    healthy_threshold   = 2
    interval            = 60
    matcher             = "200"
    path                = var.health_check_path.ais
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 30
    unhealthy_threshold = 5
  }

  target_type = "ip"

  tags = local.tags
}

# AIS ALB Listener Rule
module "ais_listener_rule" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/alb-listener-rule?ref=main"

  listener_arn = data.aws_lb_listener.shared_https.arn
  priority     = 700 + tonumber(var.pr_number)

  condition = {
    host_header = {
      values = ["ais.${var.domain_name}"]
    }
  }

  action = {
    type             = "forward"
    target_group_arn = module.ais_target_group.arn
  }
}

# AIS Route53 Record
module "ais_dns_record" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/route53-record?ref=main"

  zone_id = data.aws_route53_zone.main.zone_id
  name    = "ais"
  type    = "A"

  alias = {
    name                   = data.aws_lb.shared.dns_name
    zone_id                = data.aws_lb.shared.zone_id
    evaluate_target_health = true
  }
}

# AIS ECS Service
module "ais_service" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/ecs-service?ref=main"

  name                   = "gameplatform-${var.environment}-ais"
  cluster_arn            = data.aws_ecs_cluster.shared.arn
  task_definition        = module.ais_task_definition.arn
  desired_count          = var.desired_count
  launch_type            = "FARGATE"
  enable_execute_command = true

  network_configuration = {
    subnets          = data.aws_subnets.private.ids
    security_groups  = [module.security_group.id]
    assign_public_ip = false
  }

  load_balancer = {
    target_group_arn = module.ais_target_group.arn
    container_name   = "ais"
    container_port   = var.ais_port
  }

  service_registries = [
    {
      registry_arn = module.ais_service_discovery.arn
    }
  ]

  depends_on = [module.ais_listener_rule]
}

# ======================================================================
# AIS SERVICE DISCOVERY
# ======================================================================

# Service Discovery Service for AIS
module "ais_service_discovery" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/service-discovery-service?ref=main"

  name         = "ais"
  namespace_id = module.service_discovery_namespace.id
  description  = "Service discovery for AIS AI image service"

  dns_ttl        = 10
  dns_type       = "A"
  routing_policy = "MULTIVALUE"

  health_check_custom_config = {
    failure_threshold = 1
  }

  tags = local.tags
}

# ======================================================================
# AIS ADDITIONAL HTTPS LISTENER (5050)
# ======================================================================

# HTTPS Listener for port 5050
module "ais_https_listener_5050" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/alb-listener?ref=main"

  load_balancer_arn = data.aws_lb.shared.arn
  port              = 5050
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-Res-2021-06"
  certificate_arn   = data.aws_acm_certificate.wildcard.arn

  default_action = {
    type             = "forward"
    target_group_arn = module.ais_target_group.arn
  }

  rules = [
    {
      priority         = 1
      host_headers     = ["ais.${var.domain_name}"]
      path_patterns    = null
      target_group_arn = module.ais_target_group.arn
    }
  ]

  tags = local.tags
}
