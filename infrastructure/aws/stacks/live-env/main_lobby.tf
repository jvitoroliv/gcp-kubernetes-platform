# ======================================================================
# LOBBY (Next.js Frontend) Infrastructure  
# ======================================================================

# Lobby ECS Task Definition
module "lobby_task_definition" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/ecs-task-definition?ref=main"

  family                   = "gameplatform-${var.environment}-lobby"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = module.ecs_execution_role.arn
  task_role_arn            = module.ecs_task_role.arn

  container = {
    name      = "lobby"
    image     = var.container_images.lobby
    essential = true

    port_mappings = [
      {
        container_port = 3000
        host_port      = 3000
        protocol       = "tcp"
      }
    ]

    log_group_name = module.lobby_log_group.name

    environment = {
      # Next.js standard
      NODE_ENV                  = "production"
      
      # NextAuth configuration
      NEXTAUTH_URL              = "https://app.${var.domain_name}/"
      NEXTAUTH_SECRET           = "${NEXTAUTH_SECRET}"
      
      # Google OAuth
      GOOGLE_CLIENT_ID          = "${GOOGLE_CLIENT_ID}"
      GOOGLE_CLIENT_SECRET      = "${GOOGLE_CLIENT_SECRET}"
      
      # Public client-side variables (NEXT_PUBLIC_ prefix required)
      NEXT_PUBLIC_LOBBY_BACKEND = "https://lobby-backend.${var.domain_name}"
      NEXT_PUBLIC_AFS_HOST      = "https://afs.${var.domain_name}"

      # Hubspot variables
      NEXT_PUBLIC_HUBSPOT_PORTAL_ID = "44821273"
    }
  }
}

# ALB Target Group for Lobby
module "lobby_target_group" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/alb-target-group?ref=main"

  name        = "gameplatform-eph-${var.environment}-lby"
  port        = var.lobby_port
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.main.id
  target_type = "ip"

  health_check = {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = var.health_check_path.lobby
    matcher             = "200"
    port                = "traffic-port"
    protocol            = "HTTP"
  }
}

# ALB Listener Rule for Lobby
module "lobby_listener_rule" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/alb-listener-rule?ref=main"

  listener_arn = data.aws_lb_listener.shared_https.arn
  priority     = 200 + tonumber(var.pr_number) # Ensure unique priority

  condition = {
    host_header = {
      values = ["app.${var.domain_name}"]
    }
  }

  action = {
    type             = "forward"
    target_group_arn = module.lobby_target_group.arn
  }
}

# Route53 Record for Lobby (ALB direct - only when CloudFront is disabled)
# NOTE: This module is commented out to prevent DNS deletion during CloudFront deployment
# The DNS record will be managed by cloudfront_error_pages.tf when CloudFront is enabled
# module "lobby_dns_record" {
#   source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/route53-record?ref=main"
#
#   # Only create when CloudFront error pages are DISABLED
#   count = var.enable_cloudfront_error_pages ? 0 : 1
#
#   zone_id = data.aws_route53_zone.main.zone_id
#   name    = "app"
#   type    = "A"
#
#   alias = {
#     name                   = data.aws_lb.shared.dns_name
#     zone_id                = data.aws_lb.shared.zone_id
#     evaluate_target_health = true
#   }
# }

# ECS Service for Lobby
module "lobby_service" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/ecs-service?ref=main"

  name                   = "gameplatform-${var.environment}-lobby"
  cluster_arn            = module.ecs_cluster.arn
  task_definition        = module.lobby_task_definition.arn
  desired_count          = var.desired_count
  launch_type            = "FARGATE"
  enable_execute_command = true

  network_configuration = {
    subnets          = data.aws_subnets.private.ids
    security_groups  = [module.security_group.id]
    assign_public_ip = false
  }

  load_balancer = {
    target_group_arn = module.lobby_target_group.arn
    container_name   = "lobby"
    container_port   = var.lobby_port
  }

  service_registries = [
    {
      registry_arn = module.lobby_service_discovery.arn
    }
  ]

  depends_on = [module.lobby_listener_rule]
}

# ======================================================================
# LOBBY SERVICE DISCOVERY
# ======================================================================

# Service Discovery Service for Lobby
module "lobby_service_discovery" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/service-discovery-service?ref=main"

  name         = "lobby"
  namespace_id = module.service_discovery_namespace.id
  description  = "Service discovery for Lobby frontend"

  dns_ttl        = 10
  dns_type       = "A"
  routing_policy = "MULTIVALUE"

  health_check_custom_config = {
    failure_threshold = 1
  }

  tags = local.tags
}
