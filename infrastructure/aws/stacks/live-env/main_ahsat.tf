# ======================================================================
# AHSAT (Analytics and Session Tracking) Infrastructure
# ======================================================================

# AHSAT ECS Task Definition
module "ahsat_task_definition" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/ecs-task-definition?ref=main"

  family                   = "gameplatform-${var.environment}-ahsat"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = module.ecs_execution_role.arn
  task_role_arn            = module.ecs_task_role.arn

  container = {
    name      = "ahsat"
    image     = var.container_images.ahsat
    essential = true

    port_mappings = [
      {
        container_port = 6969
        host_port      = 6969
        protocol       = "tcp"
      }
    ]

    log_group_name = module.server_log_group.name


    environment = {
      # Database connection
      DB_HOST                   = "${data.aws_db_instance.shared_rds.address}"
      DB_PORT                   = "${data.aws_db_instance.shared_rds.port}"
      DB_USER                   = "nakama"
      DB_PASSWORD               = "${DB_PASSWORD}"
      DB_NAME                   = "nakama"
      
      # Service URLs
      AFS_BASE_URL              = "https://afs.${var.domain_name}"
      NAKAMA_BASE_URL           = "https://nakama.${var.domain_name}"
      AIS_BASE_URL              = "https://ais.${var.domain_name}"
      AES_URL                   = "https://aes.${var.domain_name}"
      
      # Service config
      AHSAT_PORT                = tostring(var.ahsat_port)
      NK_HTTP_KEY               = "${NAKAMA_HTTP_KEY}"
      AI_API_KEY                = "${AI_API_KEY}"
      
      # Email service optional
      AES_PORT                  = "1988"
      AES_API_KEY               = "${AES_API_KEY}"
      AES-API-KEY               = "${AES_API_KEY}"


      # gameplatform inteligence service
      AIS_APP_SECRET = var.ais_app_secret

    }


  }
}

# ALB Target Group for AHSAT
module "ahsat_target_group" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/alb-target-group?ref=main"

  name        = "gameplatform-eph-${var.environment}-ahsat"
  port        = var.ahsat_port
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.main.id
  target_type = "ip"

  health_check = {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 5
    timeout             = 30
    interval            = 60
    path                = var.health_check_path.ahsat
    matcher             = "200"
    port                = "traffic-port"
    protocol            = "HTTP"
  }
}

# ALB Listener Rule for AHSAT
module "ahsat_listener_rule" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/alb-listener-rule?ref=main"

  listener_arn = data.aws_lb_listener.shared_https.arn
  priority     = 400 + tonumber(var.pr_number) # Ensure unique priority

  condition = {
    host_header = {
      values = ["ahsat.${var.domain_name}"]
    }
  }

  action = {
    type             = "forward"
    target_group_arn = module.ahsat_target_group.arn
  }
}

# Route53 Record for AHSAT
module "ahsat_dns_record" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/route53-record?ref=main"

  zone_id = data.aws_route53_zone.main.zone_id
  name    = "ahsat"
  type    = "A"

  alias = {
    name                   = data.aws_lb.shared.dns_name
    zone_id                = data.aws_lb.shared.zone_id
    evaluate_target_health = true
  }
}

# ECS Service for AHSAT  
module "ahsat_service" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/ecs-service?ref=main"

  name                   = "gameplatform-${var.environment}-ahsat"
  cluster_arn            = module.ecs_cluster.arn
  task_definition        = module.ahsat_task_definition.arn
  desired_count          = var.desired_count
  launch_type            = "FARGATE"
  enable_execute_command = true

  network_configuration = {
    subnets          = data.aws_subnets.private.ids
    security_groups  = [module.security_group.id]
    assign_public_ip = false
  }

  load_balancer = {
    target_group_arn = module.ahsat_target_group.arn
    container_name   = "ahsat"
    container_port   = var.ahsat_port
  }

  service_registries = [
    {
      registry_arn = module.ahsat_service_discovery.arn
    }
  ]

  depends_on = [module.ahsat_listener_rule]
}

# ======================================================================
# AHSAT SERVICE DISCOVERY
# ======================================================================

# Service Discovery Service for AHSAT
module "ahsat_service_discovery" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/service-discovery-service?ref=main"

  name         = "ahsat"
  namespace_id = module.service_discovery_namespace.id
  description  = "Service discovery for AHSAT analytics service"

  dns_ttl        = 10
  dns_type       = "A"
  routing_policy = "MULTIVALUE"

  health_check_custom_config = {
    failure_threshold = 1
  }

  tags = local.tags
}

# ======================================================================
# AHSAT ADDITIONAL HTTPS LISTENER (6969)
# ======================================================================

# HTTPS Listener for port 6969
module "ahsat_https_listener_6969" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/alb-listener?ref=main"

  load_balancer_arn = data.aws_lb.shared.arn
  port              = 6969
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-Res-2021-06"
  certificate_arn   = data.aws_acm_certificate.wildcard.arn

  default_action = {
    type             = "forward"
    target_group_arn = module.ahsat_target_group.arn
  }

  rules = [
    {
      priority         = 1
      host_headers     = ["ahsat.${var.domain_name}"]
      path_patterns    = null
      target_group_arn = module.ahsat_target_group.arn
    }
  ]

  tags = local.tags
}
