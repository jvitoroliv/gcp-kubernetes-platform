# ======================================================================
# APS (GamePlatform Payment Service) Infrastructure
# ======================================================================

# Data source for existing ECR repository
data "aws_ecr_repository" "aps" {
  name = "gameplatform-aps"
}

# CloudWatch Log Group for APS
module "aps_log_group" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/cloudwatch-log-group?ref=main"

  name              = "/aws/ecs/gameplatform-${var.environment}-aps"
  retention_in_days = var.log_retention_days

  tags = local.tags
}

# APS Task Definition
module "aps_task_definition" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/ecs-task-definition?ref=main"

  family                   = "gameplatform-${var.environment}-aps"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = module.ecs_execution_role.arn
  task_role_arn            = module.ecs_task_role.arn

  container = {
    name      = "aps"
    image     = var.container_images.aps != "" ? var.container_images.aps : "${data.aws_ecr_repository.aps.repository_url}:latest"
    essential = true

    port_mappings = [
      {
        container_port = var.aps_port
        host_port      = var.aps_port
        protocol       = "tcp"
      }
    ]

    log_group_name = module.aps_log_group.name

    environment = {
      # APS Configuration
      APS_PORT         = tostring(var.aps_port)
      YUNO_PUBLIC_KEY  = "${YUNO_PUBLIC_KEY}"
      YUNO_PRIVATE_KEY = "${YUNO_PRIVATE_KEY}"
      YUNO_ACCOUNT_ID  = "${YUNO_ACCOUNT_ID}"
      YUNO_URL_API     = "https://api-sandbox.y.uno/v1"
    }
  }
}

# APS ALB Target Group
module "aps_target_group" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/alb-target-group?ref=main"

  name     = "gameplatform-${var.environment}-aps"
  port     = var.aps_port
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.main.id

  health_check = {
    enabled             = true
    healthy_threshold   = 2
    interval            = 60
    matcher             = "200"
    path                = var.health_check_path.aps
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 30
    unhealthy_threshold = 5
  }

  target_type = "ip"

  tags = local.tags
}

# APS ALB Listener Rule
module "aps_listener_rule" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/alb-listener-rule?ref=main"

  listener_arn = data.aws_lb_listener.shared_https.arn
  priority     = 800 + tonumber(var.pr_number)

  condition = {
    host_header = {
      values = ["aps.${var.domain_name}"]
    }
  }

  action = {
    type             = "forward"
    target_group_arn = module.aps_target_group.arn
  }
}

# APS Route53 Record
module "aps_dns_record" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/route53-record?ref=main"

  zone_id = data.aws_route53_zone.main.zone_id
  name    = "aps"
  type    = "A"

  alias = {
    name                   = data.aws_lb.shared.dns_name
    zone_id                = data.aws_lb.shared.zone_id
    evaluate_target_health = true
  }
}

# APS ECS Service
module "aps_service" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/ecs-service?ref=main"

  name                   = "gameplatform-${var.environment}-aps"
  cluster_arn            = module.ecs_cluster.arn
  task_definition        = module.aps_task_definition.arn
  desired_count          = var.desired_count
  launch_type            = "FARGATE"
  enable_execute_command = true

  network_configuration = {
    subnets          = data.aws_subnets.private.ids
    security_groups  = [module.security_group.id]
    assign_public_ip = false
  }

  load_balancer = {
    target_group_arn = module.aps_target_group.arn
    container_name   = "aps"
    container_port   = var.aps_port
  }

  service_registries = [
    {
      registry_arn = module.aps_service_discovery.arn
    }
  ]

  depends_on = [module.aps_listener_rule]
}

# ======================================================================
# APS SERVICE DISCOVERY
# ======================================================================

# Service Discovery Service for APS
module "aps_service_discovery" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/service-discovery-service?ref=main"

  name         = "aps"
  namespace_id = module.service_discovery_namespace.id
  description  = "Service discovery for APS payment service"

  dns_ttl        = 10
  dns_type       = "A"
  routing_policy = "MULTIVALUE"

  health_check_custom_config = {
    failure_threshold = 1
  }

  tags = local.tags
}

# ======================================================================
# APS ADDITIONAL HTTPS LISTENER (4444)
# ======================================================================

# HTTPS Listener for port 4444
module "aps_https_listener_4444" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/alb-listener?ref=main"

  load_balancer_arn = data.aws_lb.shared.arn
  port              = 4444
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-Res-2021-06"
  certificate_arn   = data.aws_acm_certificate.wildcard.arn

  default_action = {
    type             = "forward"
    target_group_arn = module.aps_target_group.arn
  }

  rules = [
    {
      priority         = 1
      host_headers     = ["aps.${var.domain_name}"]
      path_patterns    = null
      target_group_arn = module.aps_target_group.arn
    }
  ]

  tags = local.tags
}
