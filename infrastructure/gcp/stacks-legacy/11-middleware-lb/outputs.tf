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

output "backend_service_id" {
  description = "ID of the backend service"
  value       = google_compute_backend_service.middleware_backend.id
}
