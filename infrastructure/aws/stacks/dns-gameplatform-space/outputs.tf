output "hosted_zone_id" {
  description = "Route53 hosted zone ID"
  value       = local.hosted_zone_id
}

output "hosted_zone_name" {
  description = "Route53 hosted zone name"
  value       = local.hosted_zone_name
}

output "hosted_zone_name_servers" {
  description = "Route53 hosted zone name servers (USE THESE TO UPDATE NAMECHEAP DNS SETTINGS)"
  value       = var.create_hosted_zone ? module.hosted_zone[0].name_servers : null
}

output "domain_migration_instructions" {
  description = "Instructions for completing domain migration from Namecheap to Route53"
  value = var.create_hosted_zone ? {
    step_1 = "Deploy this Terraform configuration to create Route53 hosted zone"
    step_2 = "Copy the Name Servers from hosted_zone_name_servers output"
    step_3 = "Login to Namecheap control panel for gameplatform.example.com domain"
    step_4 = "Change DNS settings from Namecheap BasicDNS to Custom DNS"
    step_5 = "Replace Namecheap nameservers with Route53 nameservers"
    step_6 = "Wait 24-48 hours for DNS propagation worldwide"
    step_7 = "Test domain resolution using dig gameplatform.example.com NS"
    note   = "After migration, all DNS records will be managed in AWS Route53"
  } : null
}

output "wildcard_certificate_arn" {
  description = "ACM wildcard certificate ARN"
  value       = var.create_wildcard_certificate ? module.wildcard_certificate[0].certificate_arn : null
}

output "wildcard_certificate_domain_name" {
  description = "ACM wildcard certificate domain name"
  value       = var.create_wildcard_certificate ? "*.${var.domain_name}" : null
}

output "wildcard_certificate_status" {
  description = "ACM wildcard certificate validation status"
  value       = null
}

output "shared_alb_arn" {
  description = "Shared ALB ARN"
  value       = var.create_shared_alb ? module.shared_alb[0].arn : null
}

output "shared_alb_dns_name" {
  description = "Shared ALB DNS name"
  value       = var.create_shared_alb ? module.shared_alb[0].dns_name : null
}

output "shared_alb_zone_id" {
  description = "Shared ALB Route53 zone ID"
  value       = var.create_shared_alb ? module.shared_alb[0].zone_id : null
}

output "shared_alb_name" {
  description = "Shared ALB name"
  value       = var.create_shared_alb ? "gameplatform-${var.environment}-shared-alb" : null
}

output "alb_security_group_id" {
  description = "ALB security group ID"
  value       = var.create_shared_alb ? module.alb_security_group[0].id : null
}

output "http_listener_arn" {
  description = "HTTP listener ARN"
  value       = var.create_shared_alb ? module.http_listener[0].listener_arn : null
}

output "https_listener_arn" {
  description = "HTTPS listener ARN"
  value       = var.create_shared_alb && var.create_wildcard_certificate ? module.https_listener[0].listener_arn : null
}

output "default_target_group_arn" {
  description = "Default target group ARN"
  value       = var.create_shared_alb ? module.default_target_group[0].arn : null
}

output "access_logs_bucket_name" {
  description = "ALB access logs S3 bucket name"
  value       = var.create_shared_alb && var.enable_access_logs ? module.alb_access_logs_bucket[0].id : null
}

output "access_logs_bucket_arn" {
  description = "ALB access logs S3 bucket ARN"
  value       = var.create_shared_alb && var.enable_access_logs ? module.alb_access_logs_bucket[0].arn : null
}

output "apex_domain_fqdn" {
  description = "Apex domain FQDN"
  value       = var.create_shared_alb ? module.apex_domain_record[0].fqdn : null
}

output "wildcard_domain_fqdn" {
  description = "Wildcard domain FQDN"
  value       = var.create_shared_alb ? module.wildcard_domain_record[0].fqdn : null
}

output "dns_alb_summary" {
  description = "Summary of DNS and ALB configuration"
  value = {
    environment = var.environment
    domain_name = var.domain_name

    dns = {
      hosted_zone_id   = local.hosted_zone_id
      hosted_zone_name = local.hosted_zone_name
      name_servers     = var.create_hosted_zone ? module.hosted_zone[0].name_servers : null
      apex_domain      = var.create_shared_alb ? module.apex_domain_record[0].fqdn : null
      wildcard_domain  = var.create_shared_alb ? module.wildcard_domain_record[0].fqdn : null
    }

    certificate = {
      enabled     = var.create_wildcard_certificate
      arn         = var.create_wildcard_certificate ? module.wildcard_certificate[0].certificate_arn : null
      domain_name = var.create_wildcard_certificate ? "*.${var.domain_name}" : null
      status      = null
    }

    alb = {
      enabled        = var.create_shared_alb
      name           = var.create_shared_alb ? "gameplatform-${var.environment}-space-alb" : null
      arn            = var.create_shared_alb ? module.shared_alb[0].arn : null
      dns_name       = var.create_shared_alb ? module.shared_alb[0].dns_name : null
      zone_id        = var.create_shared_alb ? module.shared_alb[0].zone_id : null
      scheme         = var.alb_scheme
      type           = var.alb_type
      security_group = var.create_shared_alb ? module.alb_security_group[0].id : null
    }

    listeners = {
      http_arn  = (var.create_shared_alb && length(module.http_listener) > 0) ? module.http_listener[0].listener_arn : null
      https_arn = (var.create_shared_alb && var.create_wildcard_certificate && length(module.https_listener) > 0) ? module.https_listener[0].listener_arn : null
    }

    access_logs = {
      enabled     = var.create_shared_alb && var.enable_access_logs
      bucket_name = var.create_shared_alb && var.enable_access_logs ? module.alb_access_logs_bucket[0].id : null
      bucket_arn  = var.create_shared_alb && var.enable_access_logs ? module.alb_access_logs_bucket[0].arn : null
      retention   = var.access_logs_retention_days
    }
  }
}
