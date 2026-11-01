# ======================================================================
# AFS (Asset File Service) Infrastructure
# ======================================================================

# AFS ECS Task Definition
module "afs_task_definition" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/ecs-task-definition?ref=main"

  family                   = "gameplatform-${var.environment}-afs"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = module.ecs_execution_role.arn
  task_role_arn            = module.ecs_task_role.arn

  container = {
    name      = "afs"
    image     = var.container_images.afs
    essential = true

    port_mappings = [
      {
        container_port = 9933
        host_port      = 9933
        protocol       = "tcp"
      }
    ]

    log_group_name = module.server_log_group.name

    environment = {
      # Service config
      AFS_PORT    = tostring(var.afs_port)
      ENV         = "${var.environment}-${data.aws_caller_identity.current.account_id}"
      
      # AWS config
      AWS_REGION  = var.aws_region
      
      # Database connection
      DB_HOST     = "${data.aws_db_instance.shared_rds.address}"
      DB_PORT     = "${data.aws_db_instance.shared_rds.port}"
      DB_USER     = "nakama"
      DB_PASSWORD = "${DB_PASSWORD}"
      DB_NAME     = "nakama"
    }


  }
}

# ALB Target Group for AFS
module "afs_target_group" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/alb-target-group?ref=main"

  name        = "gameplatform-eph-${var.environment}-afs"
  port        = var.afs_port
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.main.id
  target_type = "ip"

  health_check = {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = var.health_check_path.afs
    matcher             = "200"
    port                = "traffic-port"
    protocol            = "HTTP"
  }
}

# ALB Listener Rule for AFS
module "afs_listener_rule" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/alb-listener-rule?ref=main"

  listener_arn = data.aws_lb_listener.shared_https.arn
  priority     = 300 + tonumber(var.pr_number) # Ensure unique priority

  condition = {
    host_header = {
      values = ["afs.${var.domain_name}"]
    }
  }

  action = {
    type             = "forward"
    target_group_arn = module.afs_target_group.arn
  }
}

# Route53 Record for AFS
module "afs_dns_record" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/route53-record?ref=main"

  zone_id = data.aws_route53_zone.main.zone_id
  name    = "afs"
  type    = "A"

  alias = {
    name                   = data.aws_lb.shared.dns_name
    zone_id                = data.aws_lb.shared.zone_id
    evaluate_target_health = true
  }
}

# ECS Service for AFS
module "afs_service" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/ecs-service?ref=main"

  name                   = "gameplatform-${var.environment}-afs"
  cluster_arn            = module.ecs_cluster.arn
  task_definition        = module.afs_task_definition.arn
  desired_count          = var.desired_count
  launch_type            = "FARGATE"
  enable_execute_command = true

  network_configuration = {
    subnets          = data.aws_subnets.private.ids
    security_groups  = [module.security_group.id]
    assign_public_ip = false
  }

  load_balancer = {
    target_group_arn = module.afs_target_group.arn
    container_name   = "afs"
    container_port   = var.afs_port
  }

  service_registries = [
    {
      registry_arn = module.afs_service_discovery.arn
    }
  ]

  depends_on = [module.afs_listener_rule]
}

# ======================================================================
# AFS SERVICE DISCOVERY
# ======================================================================

# Service Discovery Service for AFS
module "afs_service_discovery" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/service-discovery-service?ref=main"

  name         = "afs"
  namespace_id = module.service_discovery_namespace.id
  description  = "Service discovery for AFS file service"

  dns_ttl        = 10
  dns_type       = "A"
  routing_policy = "MULTIVALUE"

  health_check_custom_config = {
    failure_threshold = 1
  }

  tags = local.tags
}

# ======================================================================
# AFS ADDITIONAL HTTPS LISTENER (9933)
# ======================================================================

# HTTPS Listener for port 9933
module "afs_https_listener_9933" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/alb-listener?ref=main"

  load_balancer_arn = data.aws_lb.shared.arn
  port              = 9933
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-Res-2021-06"
  certificate_arn   = data.aws_acm_certificate.wildcard.arn

  default_action = {
    type             = "forward"
    target_group_arn = module.afs_target_group.arn
  }

  rules = [
    {
      priority         = 1
      host_headers     = ["afs.${var.domain_name}"]
      path_patterns    = null
      target_group_arn = module.afs_target_group.arn
    }
  ]

  tags = local.tags
}
