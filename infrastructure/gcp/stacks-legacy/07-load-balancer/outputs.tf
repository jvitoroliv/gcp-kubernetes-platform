output "lb_ip_address" {
  description = "IP address of the load balancer"
  value       = google_compute_global_address.lb_ip.address
}

output "lb_ip_name" {
  description = "Name of the IP address resource"
  value       = google_compute_global_address.lb_ip.name
}

output "ssl_certificate_name" {
  description = "Name of the SSL certificate"
  value       = module.ssl_certificate.name
}

output "ssl_certificate_domains" {
  description = "Domains on the SSL certificate"
  value       = var.ssl_domains
}

output "backend_service_id" {
  description = "ID of the backend service"
  value       = google_compute_backend_service.cloud_run_backend.id
}

output "url_map_id" {
  description = "ID of the URL map"
  value       = google_compute_url_map.url_map.id
}
