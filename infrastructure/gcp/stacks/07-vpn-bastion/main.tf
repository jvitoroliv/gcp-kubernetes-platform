# -----------------------------------------------------------------------------
# VPN AND BASTION STACK
# This stack sets up secure administrative access:
# - Cloud VPN Gateway for site-to-site VPN
# - VPN Tunnel configuration
# - Bastion Host with IAP for emergency access
# - Firewall rules for VPN and Bastion
# -----------------------------------------------------------------------------

locals {
  common_labels = merge({
    project     = "gameplatform"
    environment = var.environment
    component   = "vpn-bastion"
    managed_by  = "terraform"
  }, var.labels)

  # Naming convention
  name_prefix = "gameplatform-${var.environment}"

  # Startup script for bastion WITH WireGuard
  wireguard_startup_script = <<-EOF
    #!/bin/bash
    set -e
    exec > >(tee /var/log/startup-script.log) 2>&1

    echo "=== Starting bastion setup with WireGuard ==="
    echo "Timestamp: $(date)"

    # Update system
    apt-get update
    apt-get upgrade -y

    # Install essential tools
    apt-get install -y \
      curl \
      wget \
      git \
      vim \
      htop \
      jq \
      unzip \
      apt-transport-https \
      ca-certificates \
      gnupg \
      lsb-release \
      iptables

    # Install kubectl
    echo "=== Installing kubectl ==="
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list
    apt-get update
    apt-get install -y kubectl

    # Install Helm
    echo "=== Installing Helm ==="
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

    # Install ArgoCD CLI
    echo "=== Installing ArgoCD CLI ==="
    curl -sSL -o /tmp/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
    install -m 555 /tmp/argocd /usr/local/bin/argocd
    rm /tmp/argocd

    # Install PostgreSQL client
    apt-get install -y postgresql-client

    # Configure gcloud auth plugin for kubectl
    echo 'export USE_GKE_GCLOUD_AUTH_PLUGIN=True' >> /etc/profile.d/gke.sh

    # Extract and run WireGuard install script from metadata
    echo "=== Installing WireGuard ==="
    curl -s -H "Metadata-Flavor: Google" \
      "http://metadata.google.internal/computeMetadata/v1/instance/attributes/wg-install-script" \
      > /tmp/install-wireguard-server.sh
    chmod +x /tmp/install-wireguard-server.sh
    /tmp/install-wireguard-server.sh

    # Copy management scripts to /etc/wireguard/
    echo "=== Installing WireGuard management scripts ==="
    curl -s -H "Metadata-Flavor: Google" \
      "http://metadata.google.internal/computeMetadata/v1/instance/attributes/wg-add-user" \
      > /etc/wireguard/add-user.sh
    curl -s -H "Metadata-Flavor: Google" \
      "http://metadata.google.internal/computeMetadata/v1/instance/attributes/wg-list-users" \
      > /etc/wireguard/list-users.sh
    curl -s -H "Metadata-Flavor: Google" \
      "http://metadata.google.internal/computeMetadata/v1/instance/attributes/wg-remove-user" \
      > /etc/wireguard/remove-user.sh
    chmod +x /etc/wireguard/*.sh

    # Create first user (admin) automatically
    echo "=== Creating admin user ==="
    /etc/wireguard/add-user.sh admin || echo "Admin user may already exist"

    # Save admin config to metadata for easy retrieval
    echo "=== Saving admin config to metadata ==="
    if [ -f /etc/wireguard/clients/admin.conf ]; then
      ZONE=$(curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/zone | cut -d'/' -f4)
      gcloud compute instances add-metadata $(hostname) \
        --zone=$ZONE \
        --metadata=wg-client-config="$(cat /etc/wireguard/clients/admin.conf)"
      echo "Admin config saved to metadata (wg-client-config)"
    fi

    EXTERNAL_IP=$(curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip)

    echo ""
    echo "=== Bastion setup complete with WireGuard VPN ==="
    echo "Server listening on $EXTERNAL_IP:51820"
    echo ""
    echo "To add more users (SSH into bastion and run):"
    echo "  sudo /etc/wireguard/add-user.sh <username>"
    echo ""
  EOF

  # Startup script for bastion WITHOUT WireGuard
  bastion_startup_script = <<-EOF
    #!/bin/bash
    set -e

    # Update system
    apt-get update
    apt-get upgrade -y

    # Install essential tools
    apt-get install -y \
      curl \
      wget \
      git \
      vim \
      htop \
      jq \
      unzip \
      apt-transport-https \
      ca-certificates \
      gnupg \
      lsb-release

    # Install kubectl
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list
    apt-get update
    apt-get install -y kubectl

    # Install gcloud CLI (usually pre-installed on GCP images)
    if ! command -v gcloud &> /dev/null; then
      curl https://sdk.cloud.google.com | bash
    fi

    # Install Helm
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

    # Install PostgreSQL client
    apt-get install -y postgresql-client

    # Configure gcloud auth plugin for kubectl
    echo 'export USE_GKE_GCLOUD_AUTH_PLUGIN=True' >> /etc/profile.d/gke.sh

    echo "Bastion setup complete!"
  EOF

  # WireGuard install script - only escape ${} not $() or $VAR
  wg_install_script = <<-EOF
#!/bin/bash
# WireGuard Server Installation Script for Bastion
set -e

# Configuration
WG_INTERFACE="wg0"
WG_PORT="51820"
WG_NETWORK="10.200.0.0/24"
SERVER_IP="10.200.0.1"
VPC_NETWORKS="${var.wireguard_vpc_networks}"
DNS_SERVERS="${var.wireguard_dns_servers}"

echo "=========================================="
echo "WireGuard Server Installation"
echo "=========================================="

INTERNAL_IP=$(curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip)
echo "Server internal IP: $INTERNAL_IP"

EXTERNAL_IP=$(curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip 2>/dev/null || echo "")
if [ -z "$EXTERNAL_IP" ]; then
    EXTERNAL_IP="BASTION_EXTERNAL_IP_HERE"
fi
echo "External IP for clients: $EXTERNAL_IP"

echo "Installing WireGuard..."
apt-get update
apt-get install -y wireguard wireguard-tools qrencode

echo "Generating server keys..."
mkdir -p /etc/wireguard
cd /etc/wireguard

if [ ! -f server_private.key ]; then
    umask 077
    wg genkey | tee server_private.key > /dev/null
    cat server_private.key | wg pubkey | tee server_public.key > /dev/null
fi

SERVER_PRIVATE_KEY=$(cat /etc/wireguard/server_private.key)
SERVER_PUBLIC_KEY=$(cat /etc/wireguard/server_public.key)

echo "Creating server configuration..."
cat > /etc/wireguard/$WG_INTERFACE.conf << WGCONF
[Interface]
Address = $SERVER_IP/24
ListenPort = $WG_PORT
PrivateKey = $SERVER_PRIVATE_KEY

PostUp = sysctl -w net.ipv4.ip_forward=1
PostUp = iptables -t nat -A POSTROUTING -s $WG_NETWORK -o ens4 -j MASQUERADE
PostUp = iptables -A FORWARD -i %i -j ACCEPT
PostUp = iptables -A FORWARD -o %i -j ACCEPT

PostDown = iptables -t nat -D POSTROUTING -s $WG_NETWORK -o ens4 -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT
PostDown = iptables -D FORWARD -o %i -j ACCEPT
WGCONF

chmod 600 /etc/wireguard/$WG_INTERFACE.conf

echo "net.ipv4.ip_forward = 1" | tee /etc/sysctl.d/99-wireguard.conf > /dev/null
sysctl -p /etc/sysctl.d/99-wireguard.conf

systemctl enable wg-quick@$WG_INTERFACE
systemctl start wg-quick@$WG_INTERFACE

mkdir -p /etc/wireguard/clients

cat > /etc/wireguard/server_info << SRVINFO
SERVER_PUBLIC_KEY=$SERVER_PUBLIC_KEY
SERVER_ENDPOINT=$EXTERNAL_IP:$WG_PORT
SERVER_IP=$SERVER_IP
WG_NETWORK=$WG_NETWORK
VPC_NETWORKS=$VPC_NETWORKS
DNS_SERVERS=$DNS_SERVERS
SRVINFO

echo "WireGuard Server Setup Complete!"
echo "Server Public Key: $SERVER_PUBLIC_KEY"
wg show
EOF

  # WireGuard add-user script
  wg_add_user_script = <<-EOF
#!/bin/bash
# Add a new WireGuard user
set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <username>"
    exit 1
fi

USERNAME="$1"
WG_INTERFACE="wg0"
CLIENT_DIR="/etc/wireguard/clients"
SERVER_INFO="/etc/wireguard/server_info"

source $SERVER_INFO

if [ -f "$CLIENT_DIR/$USERNAME.conf" ]; then
    echo "User $USERNAME already exists!"
    exit 1
fi

LAST_IP=$(grep -h "AllowedIPs" /etc/wireguard/$WG_INTERFACE.conf 2>/dev/null | grep -oP '10\.200\.0\.\K[0-9]+' | sort -n | tail -1)
if [ -z "$LAST_IP" ]; then
    NEXT_IP=2
else
    NEXT_IP=$((LAST_IP + 1))
fi

CLIENT_IP="10.200.0.$NEXT_IP"

echo "Creating WireGuard user: $USERNAME with IP $CLIENT_IP"

CLIENT_PRIVATE_KEY=$(wg genkey)
CLIENT_PUBLIC_KEY=$(echo "$CLIENT_PRIVATE_KEY" | wg pubkey)

mkdir -p $CLIENT_DIR

# Build AllowedIPs from VPC_NETWORKS + VPN network
ALLOWED_IPS=$(echo "$VPC_NETWORKS" | tr ',' ', ')
ALLOWED_IPS="$ALLOWED_IPS, 10.200.0.0/24"

cat > $CLIENT_DIR/$USERNAME.conf << CLIENTCONF
[Interface]
# $USERNAME - GamePlatform VPN
PrivateKey = $CLIENT_PRIVATE_KEY
Address = $CLIENT_IP/32
DNS = $DNS_SERVERS
MTU = 1380

[Peer]
PublicKey = $SERVER_PUBLIC_KEY
Endpoint = $SERVER_ENDPOINT
AllowedIPs = $ALLOWED_IPS
PersistentKeepalive = 25
CLIENTCONF

chmod 600 $CLIENT_DIR/$USERNAME.conf

cat >> /etc/wireguard/$WG_INTERFACE.conf << PEERCONF

# $USERNAME
[Peer]
PublicKey = $CLIENT_PUBLIC_KEY
AllowedIPs = $CLIENT_IP/32
PEERCONF

wg syncconf $WG_INTERFACE <(wg-quick strip $WG_INTERFACE)

echo "User $USERNAME created!"
echo "Config file: $CLIENT_DIR/$USERNAME.conf"
cat $CLIENT_DIR/$USERNAME.conf
echo ""
qrencode -t ansiutf8 < $CLIENT_DIR/$USERNAME.conf
EOF

  # WireGuard list-users script
  wg_list_users_script = <<-EOF
#!/bin/bash
# List all WireGuard users

echo "WireGuard Users"
echo "==============="

CLIENT_DIR="/etc/wireguard/clients"

if [ ! -d "$CLIENT_DIR" ] || [ -z "$(ls -A $CLIENT_DIR 2>/dev/null)" ]; then
    echo "No users configured yet."
    exit 0
fi

for conf in $CLIENT_DIR/*.conf; do
    if [ -f "$conf" ]; then
        USERNAME=$(basename "$conf" .conf)
        IP=$(grep "Address" "$conf" | cut -d'=' -f2 | tr -d ' ' | cut -d'/' -f1)
        echo "  $USERNAME: $IP"
    fi
done

echo ""
wg show wg0
EOF

  # WireGuard remove-user script
  wg_remove_user_script = <<-EOF
#!/bin/bash
# Remove a WireGuard user
set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <username>"
    exit 1
fi

USERNAME="$1"
WG_INTERFACE="wg0"
CLIENT_DIR="/etc/wireguard/clients"
WG_CONF="/etc/wireguard/$WG_INTERFACE.conf"

if [ ! -f "$CLIENT_DIR/$USERNAME.conf" ]; then
    echo "User $USERNAME does not exist!"
    exit 1
fi

echo "Removing WireGuard user: $USERNAME"

awk -v user="# $USERNAME" '
    $0 ~ user { skip=1; next }
    skip && /^\[Peer\]/ { skip=0 }
    skip && /^$/ { skip=0; next }
    !skip { print }
' "$WG_CONF" > "$WG_CONF.tmp"
mv "$WG_CONF.tmp" "$WG_CONF"
chmod 600 "$WG_CONF"

rm -f "$CLIENT_DIR/$USERNAME.conf"

wg syncconf $WG_INTERFACE <(wg-quick strip $WG_INTERFACE)

echo "User $USERNAME removed!"
EOF
}

# -----------------------------------------------------------------------------
# CLOUD ROUTER (for VPN)
# -----------------------------------------------------------------------------

resource "google_compute_router" "vpn_router" {
  name    = "${local.name_prefix}-vpn-router"
  project = var.project_id
  region  = var.region
  network = var.vpc_self_link

  bgp {
    asn               = var.cloud_router_asn
    advertise_mode    = "CUSTOM"
    advertised_groups = ["ALL_SUBNETS"]

    # Advertise specific IP ranges
    dynamic "advertised_ip_ranges" {
      for_each = var.advertised_ip_ranges
      content {
        range       = advertised_ip_ranges.value.range
        description = advertised_ip_ranges.value.description
      }
    }
  }
}

# -----------------------------------------------------------------------------
# HA VPN GATEWAY (GCP Side)
# -----------------------------------------------------------------------------

resource "google_compute_ha_vpn_gateway" "gateway" {
  name    = "${local.name_prefix}-vpn-gateway"
  project = var.project_id
  region  = var.region
  network = var.vpc_self_link

  stack_type = "IPV4_ONLY"
}

# -----------------------------------------------------------------------------
# EXTERNAL VPN GATEWAY (Peer Side - Your Network)
# -----------------------------------------------------------------------------

resource "google_compute_external_vpn_gateway" "peer" {
  count = var.peer_vpn_gateway_ip != "" ? 1 : 0

  name            = "${local.name_prefix}-peer-gateway"
  project         = var.project_id
  redundancy_type = "SINGLE_IP_INTERNALLY_REDUNDANT"
  description     = "External VPN gateway for ${var.environment} environment"

  interface {
    id         = 0
    ip_address = var.peer_vpn_gateway_ip
  }
}

# -----------------------------------------------------------------------------
# VPN TUNNELS
# -----------------------------------------------------------------------------

resource "google_compute_vpn_tunnel" "tunnel_0" {
  count = var.peer_vpn_gateway_ip != "" ? 1 : 0

  name                  = "${local.name_prefix}-vpn-tunnel-0"
  project               = var.project_id
  region                = var.region
  vpn_gateway           = google_compute_ha_vpn_gateway.gateway.id
  vpn_gateway_interface = 0
  peer_external_gateway = google_compute_external_vpn_gateway.peer[0].id
  shared_secret         = var.vpn_shared_secret
  router                = google_compute_router.vpn_router.id

  peer_external_gateway_interface = 0
  ike_version                     = 2

  labels = local.common_labels
}

resource "google_compute_vpn_tunnel" "tunnel_1" {
  count = var.peer_vpn_gateway_ip != "" ? 1 : 0

  name                  = "${local.name_prefix}-vpn-tunnel-1"
  project               = var.project_id
  region                = var.region
  vpn_gateway           = google_compute_ha_vpn_gateway.gateway.id
  vpn_gateway_interface = 1
  peer_external_gateway = google_compute_external_vpn_gateway.peer[0].id
  shared_secret         = var.vpn_shared_secret
  router                = google_compute_router.vpn_router.id

  peer_external_gateway_interface = 0
  ike_version                     = 2

  labels = local.common_labels
}

# -----------------------------------------------------------------------------
# ROUTER INTERFACES
# -----------------------------------------------------------------------------

resource "google_compute_router_interface" "interface_0" {
  count = var.peer_vpn_gateway_ip != "" ? 1 : 0

  name       = "${local.name_prefix}-vpn-interface-0"
  project    = var.project_id
  region     = var.region
  router     = google_compute_router.vpn_router.name
  ip_range   = "169.254.0.1/30"
  vpn_tunnel = google_compute_vpn_tunnel.tunnel_0[0].name
}

resource "google_compute_router_interface" "interface_1" {
  count = var.peer_vpn_gateway_ip != "" ? 1 : 0

  name       = "${local.name_prefix}-vpn-interface-1"
  project    = var.project_id
  region     = var.region
  router     = google_compute_router.vpn_router.name
  ip_range   = "169.254.0.5/30"
  vpn_tunnel = google_compute_vpn_tunnel.tunnel_1[0].name
}

# -----------------------------------------------------------------------------
# BGP PEERS
# -----------------------------------------------------------------------------

resource "google_compute_router_peer" "peer_0" {
  count = var.peer_vpn_gateway_ip != "" && var.enable_bgp ? 1 : 0

  name                      = "${local.name_prefix}-bgp-peer-0"
  project                   = var.project_id
  region                    = var.region
  router                    = google_compute_router.vpn_router.name
  peer_ip_address           = "169.254.0.2"
  peer_asn                  = var.peer_asn
  advertised_route_priority = 100
  interface                 = google_compute_router_interface.interface_0[0].name
}

resource "google_compute_router_peer" "peer_1" {
  count = var.peer_vpn_gateway_ip != "" && var.enable_bgp ? 1 : 0

  name                      = "${local.name_prefix}-bgp-peer-1"
  project                   = var.project_id
  region                    = var.region
  router                    = google_compute_router.vpn_router.name
  peer_ip_address           = "169.254.0.6"
  peer_asn                  = var.peer_asn
  advertised_route_priority = 100
  interface                 = google_compute_router_interface.interface_1[0].name
}

# -----------------------------------------------------------------------------
# STATIC ROUTES (Alternative to BGP)
# -----------------------------------------------------------------------------

resource "google_compute_route" "vpn_route" {
  count = var.peer_vpn_gateway_ip != "" && !var.enable_bgp ? 1 : 0

  name             = "${local.name_prefix}-vpn-route"
  project          = var.project_id
  network          = var.vpc_self_link
  dest_range       = var.on_premises_cidr
  priority         = 1000
  next_hop_vpn_tunnel = google_compute_vpn_tunnel.tunnel_0[0].id

  depends_on = [google_compute_vpn_tunnel.tunnel_0]
}

# -----------------------------------------------------------------------------
# FIREWALL RULES FOR VPN
# -----------------------------------------------------------------------------

# Allow traffic from on-premises network via VPN
resource "google_compute_firewall" "allow_vpn_ingress" {
  name    = "${local.name_prefix}-allow-vpn-ingress"
  project = var.project_id
  network = var.vpc_name

  direction = "INGRESS"
  priority  = 900

  source_ranges = [var.on_premises_cidr]

  allow {
    protocol = "tcp"
    ports    = ["22", "443", "3306", "5432", "6379", "8080", "8443", "10250"]
  }

  allow {
    protocol = "udp"
    ports    = ["53"]
  }

  allow {
    protocol = "icmp"
  }

  description = "Allow traffic from on-premises network via VPN"

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

# -----------------------------------------------------------------------------
# BASTION HOST WITH IAP
# -----------------------------------------------------------------------------

# Service account for bastion
resource "google_service_account" "bastion" {
  count = var.enable_bastion ? 1 : 0

  account_id   = "${local.name_prefix}-bastion"
  display_name = "Bastion Host Service Account"
  project      = var.project_id
}

# IAM bindings for bastion service account
resource "google_project_iam_member" "bastion_roles" {
  for_each = var.enable_bastion ? toset([
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/container.developer",
    "roles/container.admin",            # Required to manage GKE resources (ESO, ArgoCD, etc.)
    "roles/compute.instanceAdmin.v1",   # Required to update instance metadata (WireGuard config)
    "roles/secretmanager.secretAccessor", # Required to read secrets (GitHub PAT, etc.)
  ]) : []

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.bastion[0].email}"
}

# Bastion VM instance
resource "google_compute_instance" "bastion" {
  count = var.enable_bastion ? 1 : 0

  name         = "${local.name_prefix}-bastion"
  project      = var.project_id
  zone         = var.bastion_zone
  machine_type = var.bastion_machine_type

  # Required for WireGuard VPN to route traffic between clients and VPC
  can_ip_forward = var.enable_wireguard

  # Boot disk
  boot_disk {
    initialize_params {
      image = var.bastion_image
      size  = var.bastion_disk_size
      type  = "pd-standard"
    }
  }

  # Network interface
  network_interface {
    network    = var.vpc_self_link
    subnetwork = var.subnet_self_link

    # External IP for WireGuard VPN access
    dynamic "access_config" {
      for_each = var.bastion_enable_external_ip ? [1] : []
      content {
        network_tier = "PREMIUM"
      }
    }
  }

  # Service account
  service_account {
    email  = google_service_account.bastion[0].email
    scopes = ["cloud-platform"]
  }

  # Metadata for startup script and WireGuard scripts
  metadata = merge({
    enable-oslogin = "TRUE"
  }, var.enable_wireguard ? {
    # WireGuard management scripts embedded in metadata
    wg-install-script = local.wg_install_script
    wg-add-user       = local.wg_add_user_script
    wg-list-users     = local.wg_list_users_script
    wg-remove-user    = local.wg_remove_user_script
  } : {})

  metadata_startup_script = var.enable_wireguard ? local.wireguard_startup_script : local.bastion_startup_script

  # Shielded VM configuration
  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  # Allow stopping for updates
  allow_stopping_for_update = true

  labels = merge(local.common_labels, {
    purpose = "bastion"
  })

  tags = ["bastion", "iap-ssh", "wireguard-server"]
}

# -----------------------------------------------------------------------------
# FIREWALL RULES FOR BASTION (IAP)
# -----------------------------------------------------------------------------

# Allow IAP to Bastion
resource "google_compute_firewall" "allow_iap_to_bastion" {
  count = var.enable_bastion ? 1 : 0

  name    = "${local.name_prefix}-allow-iap-bastion"
  project = var.project_id
  network = var.vpc_name

  direction = "INGRESS"
  priority  = 1000

  # IAP's IP range
  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["iap-ssh"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  description = "Allow IAP SSH access to bastion host"
}

# Allow SSH from external IPs (use with caution - only enable if needed)
resource "google_compute_firewall" "allow_ssh_external" {
  count = var.enable_bastion && var.enable_ssh_external ? 1 : 0

  name    = "${local.name_prefix}-allow-ssh-external"
  project = var.project_id
  network = var.vpc_name

  direction = "INGRESS"
  priority  = 1000

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["bastion"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  description = "Allow SSH access from external IPs to bastion host"
}

# Allow WireGuard VPN traffic to bastion
resource "google_compute_firewall" "allow_wireguard" {
  count = var.enable_bastion && var.enable_wireguard ? 1 : 0

  name    = "${local.name_prefix}-allow-wireguard"
  project = var.project_id
  network = var.vpc_name

  direction = "INGRESS"
  priority  = 1000

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["wireguard-server"]

  allow {
    protocol = "udp"
    ports    = ["51820"]
  }

  description = "Allow WireGuard VPN traffic"
}

# Allow WireGuard clients to access internal resources
resource "google_compute_firewall" "allow_wireguard_clients" {
  count = var.enable_bastion && var.enable_wireguard ? 1 : 0

  name    = "${local.name_prefix}-allow-wireguard-clients"
  project = var.project_id
  network = var.vpc_name

  direction = "INGRESS"
  priority  = 1000

  source_ranges = ["10.200.0.0/24"]  # WireGuard client network

  allow {
    protocol = "tcp"
    ports    = ["22", "443", "3306", "5432", "6379", "8080", "8443", "10250"]
  }

  allow {
    protocol = "udp"
    ports    = ["53"]
  }

  allow {
    protocol = "icmp"
  }

  description = "Allow WireGuard VPN clients to access internal resources"
}

# Allow Bastion to access internal resources
resource "google_compute_firewall" "allow_bastion_to_internal" {
  count = var.enable_bastion ? 1 : 0

  name    = "${local.name_prefix}-allow-bastion-internal"
  project = var.project_id
  network = var.vpc_name

  direction = "INGRESS"
  priority  = 1000

  source_tags = ["bastion"]

  allow {
    protocol = "tcp"
    ports    = ["22", "443", "3306", "5432", "6379", "8080", "8443", "10250"]
  }

  allow {
    protocol = "icmp"
  }

  description = "Allow bastion to access internal resources"
}

# -----------------------------------------------------------------------------
# IAM FOR IAP TUNNEL
# -----------------------------------------------------------------------------

# Grant IAP tunnel access to specified users/groups
resource "google_iap_tunnel_instance_iam_binding" "bastion_iap" {
  count = var.enable_bastion && length(var.iap_members) > 0 ? 1 : 0

  project  = var.project_id
  zone     = var.bastion_zone
  instance = google_compute_instance.bastion[0].name
  role     = "roles/iap.tunnelResourceAccessor"
  members  = var.iap_members
}
