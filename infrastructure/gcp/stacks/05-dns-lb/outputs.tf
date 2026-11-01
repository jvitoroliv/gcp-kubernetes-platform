# -----------------------------------------------------------------------------
# DNS OUTPUTS
# -----------------------------------------------------------------------------

output "dns_zones" {
  description = "Map of created DNS zones"
  value = {
    for key, zone in module.dns_zones : key => {
      name         = zone.name
      dns_name     = zone.dns_name
      name_servers = zone.name_servers
    }
  }
}

output "dns_records" {
  description = "Map of created DNS records"
  value = {
    for key, record in module.dns_records : key => {
      name = record.name
      type = record.type
    }
  }
}

# -----------------------------------------------------------------------------
# LOAD BALANCER OUTPUTS
# -----------------------------------------------------------------------------

output "lb_ip_address" {
  description = "Global load balancer IP address"
  value       = var.enable_global_lb ? google_compute_global_address.lb[0].address : null
}

output "lb_ip_name" {
  description = "Global load balancer IP resource name"
  value       = var.enable_global_lb ? google_compute_global_address.lb[0].name : null
}

output "ssl_certificates" {
  description = "Map of SSL certificate names to their domains"
  value = {
    for domain, cert in module.ssl_certificates : domain => {
      name   = cert.name
      domain = domain
    }
  }
}

output "backend_services" {
  description = "Map of backend service names to their IDs"
  value = {
    for key, backend in module.backend_services : key => {
      id   = backend.id
      name = backend.name
    }
  }
}

output "url_map_id" {
  description = "URL map ID"
  value       = var.enable_global_lb ? module.url_map[0].id : null
}

output "url_map_name" {
  description = "URL map name"
  value       = var.enable_global_lb ? module.url_map[0].name : null
}

# -----------------------------------------------------------------------------
# SECURITY OUTPUTS
# -----------------------------------------------------------------------------

output "security_policy_id" {
  description = "Cloud Armor security policy ID"
  value       = var.enable_cloud_armor ? google_compute_security_policy.main[0].id : null
}

output "security_policy_name" {
  description = "Cloud Armor security policy name"
  value       = var.enable_cloud_armor ? google_compute_security_policy.main[0].name : null
}

# -----------------------------------------------------------------------------
# GATEWAY API OUTPUTS
# -----------------------------------------------------------------------------

output "gateway_ip_address" {
  description = "Gateway API static IP address"
  value       = var.enable_gateway_ip ? google_compute_global_address.gateway[0].address : null
}

output "gateway_ip_name" {
  description = "Gateway API static IP resource name"
  value       = var.enable_gateway_ip ? google_compute_global_address.gateway[0].name : null
}

output "gateway_ip_self_link" {
  description = "Gateway API static IP self link (for Gateway annotation)"
  value       = var.enable_gateway_ip ? google_compute_global_address.gateway[0].self_link : null
}

# -----------------------------------------------------------------------------
# APPLICATION LOAD BALANCER OUTPUTS
# -----------------------------------------------------------------------------

output "alb_ip_address" {
  description = "Application Load Balancer IP address"
  value       = var.enable_alb ? google_compute_global_address.alb[0].address : null
}

output "alb_ip_name" {
  description = "Application Load Balancer IP resource name"
  value       = var.enable_alb ? google_compute_global_address.alb[0].name : null
}

output "alb_certificate_id" {
  description = "ALB SSL certificate ID"
  value       = var.enable_alb && length(var.alb_ssl_domains) > 0 ? google_compute_managed_ssl_certificate.alb[0].id : null
}

output "alb_backend_services" {
  description = "Map of ALB backend services"
  value = {
    for key, backend in google_compute_backend_service.alb : key => {
      id   = backend.id
      name = backend.name
    }
  }
}

output "alb_url_map_id" {
  description = "ALB URL map ID (only when Terraform-managed ALB)"
  value       = var.enable_alb && length(var.alb_services) > 0 ? google_compute_url_map.alb[0].id : null
}

output "tcp_proxy_backend_services" {
  description = "Map of TCP Proxy backend services for custom ports"
  value = {
    for key, backend in google_compute_backend_service.tcp_proxy : key => {
      id   = backend.id
      name = backend.name
    }
  }
}

output "tcp_proxy_forwarding_rules" {
  description = "Map of TCP Proxy forwarding rules with ports"
  value = {
    for key, fwd in google_compute_global_forwarding_rule.tcp_proxy : key => {
      name       = fwd.name
      ip_address = fwd.ip_address
      port_range = fwd.port_range
    }
  }
}

# -----------------------------------------------------------------------------
# SSL PROXY OUTPUTS (Uses same IP as ALB)
# -----------------------------------------------------------------------------

output "ssl_proxy_ip_address" {
  description = "SSL Proxy Load Balancer IP address (same as ALB)"
  value       = var.enable_ssl_proxy && var.enable_alb ? google_compute_global_address.alb[0].address : null
}

output "ssl_proxy_ip_name" {
  description = "SSL Proxy Load Balancer IP resource name (same as ALB)"
  value       = var.enable_ssl_proxy && var.enable_alb ? google_compute_global_address.alb[0].name : null
}

output "ssl_proxy_certificate_id" {
  description = "SSL Proxy certificate ID"
  value       = var.enable_ssl_proxy && length(var.ssl_proxy_certificate_domains) > 0 ? google_compute_managed_ssl_certificate.ssl_proxy[0].id : null
}

output "ssl_proxy_backend_services" {
  description = "Map of SSL Proxy backend services"
  value = {
    for key, backend in google_compute_backend_service.ssl_proxy : key => {
      id   = backend.id
      name = backend.name
    }
  }
}

output "ssl_proxy_forwarding_rules" {
  description = "Map of SSL Proxy forwarding rules with ports"
  value = {
    for key, fwd in google_compute_global_forwarding_rule.ssl_proxy : key => {
      name       = fwd.name
      ip_address = fwd.ip_address
      port_range = fwd.port_range
    }
  }
}

# -----------------------------------------------------------------------------
# REGIONAL INGRESS IP OUTPUTS (for GKE nginx-ingress LoadBalancer)
# -----------------------------------------------------------------------------

output "regional_ingress_ip_address" {
  description = "Regional static IP address for GKE nginx-ingress LoadBalancer"
  value       = var.enable_regional_ingress_ip ? google_compute_address.regional_ingress[0].address : null
}

output "regional_ingress_ip_name" {
  description = "Regional static IP resource name"
  value       = var.enable_regional_ingress_ip ? google_compute_address.regional_ingress[0].name : null
}

output "regional_ingress_ip_self_link" {
  description = "Regional static IP self link"
  value       = var.enable_regional_ingress_ip ? google_compute_address.regional_ingress[0].self_link : null
}
