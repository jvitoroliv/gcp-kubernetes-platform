#!/bin/bash
# Add a new WireGuard user
# Run this ON THE BASTION: sudo /etc/wireguard/add-user.sh <username>

set -e

if [ -z "$1" ]; then
    echo "Usage: sudo $0 <username>"
    echo "Example: sudo $0 joao"
    exit 1
fi

USERNAME="$1"
WG_INTERFACE="wg0"
CLIENT_DIR="/etc/wireguard/clients"
SERVER_INFO="/etc/wireguard/server_info"

# Load server info
source ${SERVER_INFO}

# Check if user already exists
if [ -f "${CLIENT_DIR}/${USERNAME}.conf" ]; then
    echo "User ${USERNAME} already exists!"
    echo "Config file: ${CLIENT_DIR}/${USERNAME}.conf"
    exit 1
fi

# Find next available IP
LAST_IP=$(grep -h "AllowedIPs" /etc/wireguard/${WG_INTERFACE}.conf 2>/dev/null | grep -oP '10\.200\.0\.\K[0-9]+' | sort -n | tail -1)
if [ -z "${LAST_IP}" ]; then
    NEXT_IP=2  # First client gets .2 (server is .1)
else
    NEXT_IP=$((LAST_IP + 1))
fi

CLIENT_IP="10.200.0.${NEXT_IP}"

echo "=========================================="
echo "Creating WireGuard user: ${USERNAME}"
echo "Client IP: ${CLIENT_IP}"
echo "=========================================="

# Generate client keys
echo "Generating keys..."
CLIENT_PRIVATE_KEY=$(wg genkey)
CLIENT_PUBLIC_KEY=$(echo "${CLIENT_PRIVATE_KEY}" | wg pubkey)

# Create client config
echo "Creating client config..."
mkdir -p ${CLIENT_DIR}

cat > ${CLIENT_DIR}/${USERNAME}.conf << EOF
[Interface]
# ${USERNAME} - GamePlatform Nonprod VPN (dev + stg access)
PrivateKey = ${CLIENT_PRIVATE_KEY}
Address = ${CLIENT_IP}/32
DNS = 10.100.0.58, 8.8.8.8
MTU = 1380

[Peer]
# GamePlatform Nonprod VPN Server
PublicKey = ${SERVER_PUBLIC_KEY}
Endpoint = ${SERVER_ENDPOINT}
# Dev: 10.100.0.0/20 (subnet), 10.104.0.0/14 (pods), 10.108.0.0/20 (services)
# Stg: 10.48.0.0/20 (subnet), 10.52.0.0/14 (pods), 10.64.0.0/20 (services)
# Runners: 10.120.0.0/20 (subnet), 10.124.0.0/14 (pods), 10.128.0.0/20 (services)
# Masters: 172.16.0.0/28 (dev), 172.16.1.0/28 (runners), 172.16.2.0/28 (stg)
# Cloud SQL: 10.148.0.0/20
# VPN: 10.200.0.0/24
AllowedIPs = 10.48.0.0/20, 10.52.0.0/14, 10.64.0.0/20, 10.100.0.0/20, 10.104.0.0/14, 10.108.0.0/20, 10.120.0.0/20, 10.124.0.0/14, 10.128.0.0/20, 172.16.0.0/28, 172.16.1.0/28, 172.16.2.0/28, 10.200.0.0/24, 10.148.0.0/20
PersistentKeepalive = 25
EOF

chmod 600 ${CLIENT_DIR}/${USERNAME}.conf

# Add peer to server config
echo "Adding peer to server..."
cat >> /etc/wireguard/${WG_INTERFACE}.conf << EOF

# ${USERNAME}
[Peer]
PublicKey = ${CLIENT_PUBLIC_KEY}
AllowedIPs = ${CLIENT_IP}/32
EOF

# Reload WireGuard to apply changes
echo "Reloading WireGuard..."
wg syncconf ${WG_INTERFACE} <(wg-quick strip ${WG_INTERFACE})

echo ""
echo "=========================================="
echo "User ${USERNAME} created successfully!"
echo "=========================================="
echo ""
echo "Client IP: ${CLIENT_IP}"
echo "Config file: ${CLIENT_DIR}/${USERNAME}.conf"
echo ""

# Show config content
echo "--- CONFIG FILE (send to user) ---"
cat ${CLIENT_DIR}/${USERNAME}.conf
echo "--- END CONFIG ---"
echo ""

# Generate QR code
echo "--- QR CODE (for mobile) ---"
qrencode -t ansiutf8 < ${CLIENT_DIR}/${USERNAME}.conf
echo ""

echo "Instructions for user:"
echo "1. Download WireGuard from https://www.wireguard.com/install/"
echo "2. Import the config file above (or scan QR code on mobile)"
echo "3. Click 'Activate' to connect"
echo ""
echo "To get the config file, run:"
echo "  sudo cat ${CLIENT_DIR}/${USERNAME}.conf"
