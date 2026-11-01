# -----------------------------------------------------------------------------
# REQUIRED VARIABLES
# -----------------------------------------------------------------------------

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, stg, prd, nonprod)"
  type        = string

  validation {
    condition     = contains(["dev", "stg", "prd", "nonprod"], var.environment)
    error_message = "Environment must be one of: dev, stg, prd, nonprod"
  }
}

variable "region" {
  description = "GCP region"
  type        = string
}

# -----------------------------------------------------------------------------
# NETWORK REFERENCES
# -----------------------------------------------------------------------------

variable "vpc_self_link" {
  description = "Self link of the VPC network"
  type        = string
}

variable "vpc_name" {
  description = "Name of the VPC network"
  type        = string
}

variable "subnet_self_link" {
  description = "Self link of the subnet for bastion host"
  type        = string
}

# -----------------------------------------------------------------------------
# VPN CONFIGURATION
# -----------------------------------------------------------------------------

variable "cloud_router_asn" {
  description = "ASN for Cloud Router (BGP)"
  type        = number
  default     = 64512
}

variable "peer_asn" {
  description = "ASN for peer router (your side)"
  type        = number
  default     = 65001
}

variable "peer_vpn_gateway_ip" {
  description = "Public IP address of the peer VPN gateway. Leave empty to create VPN gateway without tunnels."
  type        = string
  default     = ""
}

variable "vpn_shared_secret" {
  description = "Shared secret for VPN tunnel authentication"
  type        = string
  default     = ""
  sensitive   = true
}

variable "on_premises_cidr" {
  description = "CIDR block of your on-premises/local network"
  type        = string
  default     = "10.0.0.0/24"
}

variable "enable_bgp" {
  description = "Enable BGP for dynamic routing. If false, static routes will be used."
  type        = bool
  default     = false
}

variable "advertised_ip_ranges" {
  description = "Additional IP ranges to advertise via BGP"
  type = list(object({
    range       = string
    description = string
  }))
  default = []
}

# -----------------------------------------------------------------------------
# BASTION HOST CONFIGURATION
# -----------------------------------------------------------------------------

variable "enable_bastion" {
  description = "Enable bastion host creation"
  type        = bool
  default     = true
}

variable "bastion_zone" {
  description = "Zone for bastion host"
  type        = string
  default     = ""
}

variable "bastion_machine_type" {
  description = "Machine type for bastion host"
  type        = string
  default     = "e2-micro"
}

variable "bastion_image" {
  description = "Image for bastion host boot disk"
  type        = string
  default     = "debian-cloud/debian-12"
}

variable "bastion_disk_size" {
  description = "Boot disk size in GB"
  type        = number
  default     = 20
}

variable "iap_members" {
  description = "List of IAM members who can access bastion via IAP (e.g., user:email@example.com)"
  type        = list(string)
  default     = []
}

variable "bastion_enable_external_ip" {
  description = "Enable external IP for bastion (required for WireGuard VPN)"
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------
# WIREGUARD VPN CONFIGURATION
# -----------------------------------------------------------------------------

variable "enable_wireguard" {
  description = "Enable WireGuard VPN on bastion host"
  type        = bool
  default     = false
}

variable "wireguard_vpc_networks" {
  description = "Comma-separated list of VPC network CIDRs to route through WireGuard VPN (e.g., subnets, pods, services, Cloud SQL)"
  type        = string
  default     = ""
}

variable "wireguard_dns_servers" {
  description = "Comma-separated list of DNS servers for WireGuard clients (e.g., kube-dns IP)"
  type        = string
  default     = "8.8.8.8"
}

variable "enable_ssh_external" {
  description = "Enable SSH access from external IPs (0.0.0.0/0) to bastion. Use with caution."
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------
# LABELS
# -----------------------------------------------------------------------------

variable "labels" {
  description = "Labels to apply to all resources"
  type        = map(string)
  default     = {}
}
