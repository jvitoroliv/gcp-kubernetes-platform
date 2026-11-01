# -----------------------------------------------------------------------------
# OUTPUTS
# -----------------------------------------------------------------------------

output "lb_ip_address" {
  description = "External IP address of the load balancer"
  value       = google_compute_global_address.lb_ip.address
}

output "lb_name" {
  description = "Name of the load balancer"
  value       = var.lb_name
}

output "ssl_certificate_id" {
  description = "ID of the managed SSL certificate"
  value       = google_compute_managed_ssl_certificate.ssl_cert.id
}

output "backend_services" {
  description = "Map of backend service names to their IDs"
  value = {
    for k, v in google_compute_backend_service.service_backend : k => v.id
  }
}
