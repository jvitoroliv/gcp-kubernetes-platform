#!/bin/bash
# Remove a WireGuard user
# Run this ON THE BASTION: sudo /etc/wireguard/remove-user.sh <username>

set -e

if [ -z "$1" ]; then
    echo "Usage: sudo $0 <username>"
    echo "Example: sudo $0 joao"
    exit 1
fi

USERNAME="$1"
WG_INTERFACE="wg0"
CLIENT_DIR="/etc/wireguard/clients"
WG_CONF="/etc/wireguard/${WG_INTERFACE}.conf"

# Check if user exists
if [ ! -f "${CLIENT_DIR}/${USERNAME}.conf" ]; then
    echo "User ${USERNAME} does not exist!"
    exit 1
fi

echo "=========================================="
echo "Removing WireGuard user: ${USERNAME}"
echo "=========================================="

# Get client public key
CLIENT_PRIVATE_KEY=$(grep "PrivateKey" "${CLIENT_DIR}/${USERNAME}.conf" | cut -d'=' -f2 | tr -d ' ')
CLIENT_PUBLIC_KEY=$(echo "${CLIENT_PRIVATE_KEY}" | wg pubkey)

# Remove from server config (remove the peer block)
echo "Removing peer from server config..."
# Create temp file without this peer
awk -v user="# ${USERNAME}" '
    $0 ~ user { skip=1; next }
    skip && /^\[Peer\]/ { skip=0 }
    skip && /^$/ { skip=0; next }
    !skip { print }
' "${WG_CONF}" > "${WG_CONF}.tmp"
mv "${WG_CONF}.tmp" "${WG_CONF}"
chmod 600 "${WG_CONF}"

# Remove client config file
echo "Removing client config..."
rm -f "${CLIENT_DIR}/${USERNAME}.conf"

# Reload WireGuard
echo "Reloading WireGuard..."
wg syncconf ${WG_INTERFACE} <(wg-quick strip ${WG_INTERFACE})

echo ""
echo "User ${USERNAME} removed successfully!"
