# ======================================================================
# NAKAMA (Game Server) Infrastructure
# ======================================================================

# Nakama ECS Task Definition 
module "nakama_task_definition" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/ecs-task-definition?ref=main"

  family                   = "gameplatform-${var.environment}-nakama"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.nakama_cpu
  memory                   = var.nakama_memory
  execution_role_arn       = module.ecs_execution_role.arn
  task_role_arn            = module.ecs_task_role.arn

  container = {
    name      = "nakama"
    image     = var.container_images.nakama
    essential = true

    port_mappings = [
      {
        container_port = 7350
        host_port      = 7350
        protocol       = "tcp"
      },
      {
        container_port = 7351
        host_port      = 7351
        protocol       = "tcp"
      }
    ]

    log_group_name = module.server_log_group.name
    
    environment = {
      # Database - Full connection string for Nakama
      NAKAMA_DATABASE_ADDRESS    = "postgres://nakama:${DB_PASSWORD}@${data.aws_db_instance.shared_rds.endpoint}/nakama?sslmode=require"
    
      # Database - Individual components for AHSAT & AFS (and Nakama fallback)
      DB_HOST                    = "${data.aws_db_instance.shared_rds.address}"
      DB_PORT                    = "${data.aws_db_instance.shared_rds.port}"
      DB_USER                    = "nakama"
      DB_PASSWORD                = "${DB_PASSWORD}"
      DB_NAME                    = "nakama"
    
      # Nakama configuration
      NAKAMA_HTTP_KEY            = "${NAKAMA_HTTP_KEY}"
      NAKAMA_SERVER_KEY          = "${NAKAMA_SERVER_KEY}"
      DISABLE_EMAIL_VERIFICATION = "true"
    
      # Service URLs
      AHSAT_BASE_URL             = "https://ahsat.${var.domain_name}"
      
      # Encryption
      AES_KEY                    = "${AES_ENCRYPTION_KEY}"
    }


  }
}

# ALB Target Group for Server (Nakama)
module "server_target_group" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/alb-target-group?ref=main"

  name        = "gameplatform-eph-${var.environment}-nakama"
  port        = var.nakama_port
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.main.id
  target_type = "ip"

  health_check = {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 10
    timeout             = 30
    interval            = 60
    path                = var.health_check_path.server
    matcher             = "200"
    port                = "traffic-port"
    protocol            = "HTTP"
  }
}

# ALB Listener Rule for Server (Nakama)
module "server_listener_rule" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/alb-listener-rule?ref=main"

  listener_arn = data.aws_lb_listener.shared_https.arn
  priority     = 100 + tonumber(var.pr_number) # Ensure unique priority

  condition = {
    host_header = {
      values = ["nakama.${var.domain_name}"]
    }
  }

  action = {
    type             = "forward"
    target_group_arn = module.server_target_group.arn
  }
}

# Route53 Record for Nakama
module "server_dns_record" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/route53-record?ref=main"

  zone_id = data.aws_route53_zone.main.zone_id
  name    = "nakama"
  type    = "A"

  alias = {
    name                   = data.aws_lb.shared.dns_name
    zone_id                = data.aws_lb.shared.zone_id
    evaluate_target_health = true
  }
}

# ECS Service for Nakama (main server)
module "nakama_service" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/ecs-service?ref=main"

  name                   = "gameplatform-${var.environment}-nakama"
  cluster_arn            = module.ecs_cluster.arn
  task_definition        = module.nakama_task_definition.arn
  desired_count          = var.desired_count
  launch_type            = "FARGATE"
  enable_execute_command = true

  network_configuration = {
    subnets          = data.aws_subnets.private.ids
    security_groups  = [module.security_group.id]
    assign_public_ip = false
  }

  load_balancer = {
    target_group_arn = module.server_target_group.arn
    container_name   = "nakama"
    container_port   = var.nakama_port
  }

  service_registries = [
    {
      registry_arn = module.nakama_service_discovery.arn
    }
  ]

  depends_on = [module.server_listener_rule]
}

# ======================================================================
# NAKAMA SERVICE DISCOVERY
# ======================================================================

# Service Discovery Service for Nakama
module "nakama_service_discovery" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/service-discovery-service?ref=main"

  name         = "nakama"
  namespace_id = module.service_discovery_namespace.id
  description  = "Service discovery for Nakama game server"

  dns_ttl        = 10
  dns_type       = "A"
  routing_policy = "MULTIVALUE"

  health_check_custom_config = {
    failure_threshold = 1
  }

  tags = local.tags
}

# ======================================================================
# NAKAMA ADDITIONAL HTTPS LISTENERS (7349, 7350, 7351)
# ======================================================================

# HTTPS Listener for port 7349
module "nakama_https_listener_7349" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/alb-listener?ref=main"

  load_balancer_arn = data.aws_lb.shared.arn
  port              = 7349
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-Res-2021-06"
  certificate_arn   = data.aws_acm_certificate.wildcard.arn

  default_action = {
    type             = "forward"
    target_group_arn = module.server_target_group.arn
  }

  rules = [
    {
      priority         = 1
      host_headers     = ["nakama.${var.domain_name}"]
      path_patterns    = null
      target_group_arn = module.server_target_group.arn
    }
  ]

  tags = local.tags
}

# HTTPS Listener for port 7350
module "nakama_https_listener_7350" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/alb-listener?ref=main"

  load_balancer_arn = data.aws_lb.shared.arn
  port              = 7350
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-Res-2021-06"
  certificate_arn   = data.aws_acm_certificate.wildcard.arn

  default_action = {
    type             = "forward"
    target_group_arn = module.server_target_group.arn
  }

  rules = [
    {
      priority         = 1
      host_headers     = ["nakama.${var.domain_name}"]
      path_patterns    = null
      target_group_arn = module.server_target_group.arn
    }
  ]

  tags = local.tags
}

# HTTPS Listener for port 7351
module "nakama_https_listener_7351" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/alb-listener?ref=main"

  load_balancer_arn = data.aws_lb.shared.arn
  port              = 7351
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-Res-2021-06"
  certificate_arn   = data.aws_acm_certificate.wildcard.arn

  default_action = {
    type             = "forward"
    target_group_arn = module.server_target_group.arn
  }

  rules = [
    {
      priority         = 1
      host_headers     = ["nakama.${var.domain_name}"]
      path_patterns    = null
      target_group_arn = module.server_target_group.arn
    }
  ]

  tags = local.tags
}
