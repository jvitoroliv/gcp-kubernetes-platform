#!/bin/bash
# List all WireGuard users
# Run this ON THE BASTION: sudo /etc/wireguard/list-users.sh

echo "=========================================="
echo "WireGuard Users"
echo "=========================================="
echo ""

CLIENT_DIR="/etc/wireguard/clients"

if [ ! -d "${CLIENT_DIR}" ] || [ -z "$(ls -A ${CLIENT_DIR} 2>/dev/null)" ]; then
    echo "No users configured yet."
    echo "Run: sudo /etc/wireguard/add-user.sh <username>"
    exit 0
fi

echo "Username          IP Address      Status"
echo "--------          ----------      ------"

for conf in ${CLIENT_DIR}/*.conf; do
    if [ -f "$conf" ]; then
        USERNAME=$(basename "$conf" .conf)
        IP=$(grep "Address" "$conf" | cut -d'=' -f2 | tr -d ' ' | cut -d'/' -f1)

        # Check if peer is connected
        PUBKEY=$(grep -A1 "# ${USERNAME}" /etc/wireguard/wg0.conf | grep PublicKey | cut -d'=' -f2 | tr -d ' ')
        if [ -n "$PUBKEY" ]; then
            HANDSHAKE=$(wg show wg0 latest-handshakes 2>/dev/null | grep "$PUBKEY" | awk '{print $2}')
            if [ -n "$HANDSHAKE" ] && [ "$HANDSHAKE" != "0" ]; then
                # Check if handshake is recent (within 3 minutes)
                NOW=$(date +%s)
                AGO=$((NOW - HANDSHAKE))
                if [ $AGO -lt 180 ]; then
                    STATUS="Connected"
                else
                    STATUS="Offline"
                fi
            else
                STATUS="Never connected"
            fi
        else
            STATUS="Unknown"
        fi

        printf "%-17s %-15s %s\n" "$USERNAME" "$IP" "$STATUS"
    fi
done

echo ""
echo "=========================================="
echo "Server Status"
echo "=========================================="
wg show wg0
