#!/bin/bash
# WireGuard Server Installation Script for Bastion
# Run this ON THE BASTION via SSH

set -e

# Configuration
WG_INTERFACE="wg0"
WG_PORT="51820"
WG_NETWORK="10.200.0.0/24"  # VPN client network
SERVER_IP="10.200.0.1"
# VPC CIDRs for nonprod (dev + stg + runners clusters in shared VPC)
# Dev: 10.100.0.0/20 (subnet), 10.104.0.0/14 (pods), 10.108.0.0/20 (services), 172.16.0.0/28 (master)
# Stg: 10.48.0.0/20 (subnet), 10.52.0.0/14 (pods), 10.64.0.0/20 (services), 172.16.2.0/28 (master)
# Runners: 10.120.0.0/20 (subnet), 10.124.0.0/14 (pods), 10.128.0.0/20 (services), 172.16.1.0/28 (master)
VPC_NETWORKS="10.48.0.0/20,10.52.0.0/14,10.64.0.0/20,10.100.0.0/20,10.104.0.0/14,10.108.0.0/20,10.120.0.0/20,10.124.0.0/14,10.128.0.0/20,172.16.0.0/28,172.16.1.0/28,172.16.2.0/28"

echo "=========================================="
echo "WireGuard Server Installation"
echo "=========================================="

# Get server's internal IP (for routing)
INTERNAL_IP=$(curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip)
echo "Server internal IP: ${INTERNAL_IP}"

# Get external IP for clients to connect
EXTERNAL_IP=$(curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip 2>/dev/null || echo "")

if [ -z "${EXTERNAL_IP}" ]; then
    echo "No external IP found. Clients will need to connect via IAP tunnel or you need to add an external IP."
    echo "For now, we'll set up the server. You can add an external IP later."
    EXTERNAL_IP="BASTION_EXTERNAL_IP_HERE"
fi
echo "External IP for clients: ${EXTERNAL_IP}"

# Install WireGuard
echo ""
echo "Installing WireGuard..."
sudo apt-get update
sudo apt-get install -y wireguard wireguard-tools qrencode

# Generate server keys
echo ""
echo "Generating server keys..."
sudo mkdir -p /etc/wireguard
cd /etc/wireguard

if [ ! -f server_private.key ]; then
    umask 077
    wg genkey | sudo tee server_private.key > /dev/null
    sudo cat server_private.key | wg pubkey | sudo tee server_public.key > /dev/null
    echo "Server keys generated."
else
    echo "Server keys already exist, skipping..."
fi

SERVER_PRIVATE_KEY=$(sudo cat /etc/wireguard/server_private.key)
SERVER_PUBLIC_KEY=$(sudo cat /etc/wireguard/server_public.key)

echo "Server Public Key: ${SERVER_PUBLIC_KEY}"

# Create server config
echo ""
echo "Creating server configuration..."
sudo tee /etc/wireguard/${WG_INTERFACE}.conf > /dev/null << EOF
[Interface]
Address = ${SERVER_IP}/24
ListenPort = ${WG_PORT}
PrivateKey = ${SERVER_PRIVATE_KEY}

# Enable IP forwarding and NAT when interface comes up
PostUp = sysctl -w net.ipv4.ip_forward=1
PostUp = iptables -t nat -A POSTROUTING -s ${WG_NETWORK} -o ens4 -j MASQUERADE
PostUp = iptables -A FORWARD -i %i -j ACCEPT
PostUp = iptables -A FORWARD -o %i -j ACCEPT

# Clean up when interface goes down
PostDown = iptables -t nat -D POSTROUTING -s ${WG_NETWORK} -o ens4 -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT
PostDown = iptables -D FORWARD -o %i -j ACCEPT

# Peers will be added below by the add-user script
EOF

sudo chmod 600 /etc/wireguard/${WG_INTERFACE}.conf

# Enable IP forwarding permanently
echo ""
echo "Enabling IP forwarding..."
echo "net.ipv4.ip_forward = 1" | sudo tee /etc/sysctl.d/99-wireguard.conf > /dev/null
sudo sysctl -p /etc/sysctl.d/99-wireguard.conf

# Enable and start WireGuard
echo ""
echo "Starting WireGuard..."
sudo systemctl enable wg-quick@${WG_INTERFACE}
sudo systemctl start wg-quick@${WG_INTERFACE}

# Create directories for user configs
sudo mkdir -p /etc/wireguard/clients

# Save server info for client generation script
sudo tee /etc/wireguard/server_info > /dev/null << EOF
SERVER_PUBLIC_KEY=${SERVER_PUBLIC_KEY}
SERVER_ENDPOINT=${EXTERNAL_IP}:${WG_PORT}
SERVER_IP=${SERVER_IP}
WG_NETWORK=${WG_NETWORK}
VPC_NETWORKS=${VPC_NETWORKS}
EOF

echo ""
echo "=========================================="
echo "WireGuard Server Setup Complete!"
echo "=========================================="
echo ""
echo "Server Public Key: ${SERVER_PUBLIC_KEY}"
echo "Server Endpoint: ${EXTERNAL_IP}:${WG_PORT}"
echo ""
echo "VPN Network: ${WG_NETWORK}"
echo "Routes to VPC: ${VPC_NETWORKS}"
echo ""
echo "Next: Run 'sudo /etc/wireguard/add-user.sh <username>' to create user configs"
echo ""

# Show status
sudo wg show
