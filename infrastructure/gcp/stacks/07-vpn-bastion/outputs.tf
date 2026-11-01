# -----------------------------------------------------------------------------
# VPN OUTPUTS
# -----------------------------------------------------------------------------

output "vpn_gateway_id" {
  description = "ID of the HA VPN gateway"
  value       = google_compute_ha_vpn_gateway.gateway.id
}

output "vpn_gateway_self_link" {
  description = "Self link of the HA VPN gateway"
  value       = google_compute_ha_vpn_gateway.gateway.self_link
}

output "vpn_gateway_ip_addresses" {
  description = "External IP addresses of the VPN gateway interfaces"
  value = [
    google_compute_ha_vpn_gateway.gateway.vpn_interfaces[0].ip_address,
    google_compute_ha_vpn_gateway.gateway.vpn_interfaces[1].ip_address,
  ]
}

output "cloud_router_name" {
  description = "Name of the Cloud Router"
  value       = google_compute_router.vpn_router.name
}

output "vpn_tunnel_names" {
  description = "Names of the VPN tunnels"
  value = var.peer_vpn_gateway_ip != "" ? [
    google_compute_vpn_tunnel.tunnel_0[0].name,
    google_compute_vpn_tunnel.tunnel_1[0].name,
  ] : []
}

# -----------------------------------------------------------------------------
# BASTION OUTPUTS
# -----------------------------------------------------------------------------

output "bastion_name" {
  description = "Name of the bastion host"
  value       = var.enable_bastion ? google_compute_instance.bastion[0].name : null
}

output "bastion_zone" {
  description = "Zone of the bastion host"
  value       = var.enable_bastion ? google_compute_instance.bastion[0].zone : null
}

output "bastion_internal_ip" {
  description = "Internal IP of the bastion host"
  value       = var.enable_bastion ? google_compute_instance.bastion[0].network_interface[0].network_ip : null
}

output "bastion_service_account" {
  description = "Service account email of the bastion host"
  value       = var.enable_bastion ? google_service_account.bastion[0].email : null
}

output "bastion_external_ip" {
  description = "External IP of the bastion host (for WireGuard)"
  value       = var.enable_bastion && var.bastion_enable_external_ip ? google_compute_instance.bastion[0].network_interface[0].access_config[0].nat_ip : null
}

# -----------------------------------------------------------------------------
# CONNECTION INSTRUCTIONS
# -----------------------------------------------------------------------------

output "vpn_setup_instructions" {
  description = "Instructions for setting up the VPN on your side"
  value       = <<-EOT
    ============================================================
    VPN SETUP INSTRUCTIONS
    ============================================================

    GCP VPN Gateway IPs:
      - Interface 0: ${google_compute_ha_vpn_gateway.gateway.vpn_interfaces[0].ip_address}
      - Interface 1: ${google_compute_ha_vpn_gateway.gateway.vpn_interfaces[1].ip_address}

    Cloud Router ASN: ${var.cloud_router_asn}

    To complete VPN setup:
    1. Configure your VPN device with the GCP gateway IPs above
    2. Set the shared secret (stored in Secret Manager or provided via variable)
    3. Update the Terraform variables:
       - peer_vpn_gateway_ip = "YOUR_PUBLIC_IP"
       - vpn_shared_secret   = "YOUR_SECRET"
    4. Re-run terraform apply

    BGP Configuration (if enabled):
      - Peer 0 IP: 169.254.0.2
      - Peer 1 IP: 169.254.0.6
      - Your ASN: ${var.peer_asn}

    ============================================================
  EOT
}

output "bastion_ssh_command" {
  description = "Command to SSH into bastion via IAP"
  value       = var.enable_bastion ? "gcloud compute ssh ${google_compute_instance.bastion[0].name} --zone=${var.bastion_zone} --tunnel-through-iap --project=${var.project_id}" : null
}

output "kubectl_via_bastion" {
  description = "Instructions to use kubectl via bastion"
  value = var.enable_bastion ? join("\n", [
    "============================================================",
    "KUBECTL VIA BASTION (IAP Tunnel)",
    "============================================================",
    "",
    "Option 1: SSH into bastion and run kubectl there",
    "$ gcloud compute ssh ${google_compute_instance.bastion[0].name} --zone=${var.bastion_zone} --tunnel-through-iap --project=${var.project_id}",
    "",
    "Option 2: Port forward through bastion (run on your local machine)",
    "$ gcloud compute start-iap-tunnel ${google_compute_instance.bastion[0].name} 22 --local-host-port=localhost:2222 --zone=${var.bastion_zone} --project=${var.project_id}",
    "",
    "Then in another terminal:",
    "$ ssh -p 2222 localhost -L 6443:GKE_MASTER_IP:443 -N",
    "$ kubectl --server=https://localhost:6443 get nodes",
    "",
    "============================================================"
  ]) : null
}

output "wireguard_instructions" {
  description = "Instructions for WireGuard VPN setup"
  value = var.enable_bastion && var.enable_wireguard ? join("\n", [
    "============================================================",
    "WIREGUARD VPN SETUP",
    "============================================================",
    "",
    "WireGuard server is running on: ${google_compute_instance.bastion[0].network_interface[0].access_config[0].nat_ip}:51820",
    "",
    "To get the client config, run:",
    "$ gcloud compute instances describe ${google_compute_instance.bastion[0].name} \\",
    "    --zone=${var.bastion_zone} \\",
    "    --project=${var.project_id} \\",
    "    --format='get(metadata.items[wg-client-config])'",
    "",
    "NOTE: The startup script takes ~2-3 minutes to complete.",
    "If the config is empty, wait and try again.",
    "",
    "To check startup script progress:",
    "$ gcloud compute ssh ${google_compute_instance.bastion[0].name} --zone=${var.bastion_zone} --tunnel-through-iap --project=${var.project_id} -- tail -f /var/log/startup-script.log",
    "",
    "Save the config to a file and import into WireGuard client:",
    "$ gcloud compute instances describe ${google_compute_instance.bastion[0].name} \\",
    "    --zone=${var.bastion_zone} \\",
    "    --project=${var.project_id} \\",
    "    --format='get(metadata.items[wg-client-config])' > ~/wireguard-gameplatform.conf",
    "",
    "============================================================"
  ]) : null
}
