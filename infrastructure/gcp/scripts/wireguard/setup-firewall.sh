#!/bin/bash
# Create firewall rule for WireGuard VPN
# Run this once from your local machine
# NOTE: If using Terraform 07-vpn-bastion with enable_wireguard=true,
#       the firewall rule is already created by Terraform.

set -e

PROJECT_ID="project-nonprod-env"
VPC_NAME="gameplatform-nonprod-vpc"
ZONE="us-east1-b"

echo "Creating firewall rule for WireGuard (UDP 51820)..."

gcloud compute firewall-rules create gameplatform-nonprod-allow-wireguard \
    --project="${PROJECT_ID}" \
    --network="${VPC_NAME}" \
    --direction=INGRESS \
    --priority=1000 \
    --action=ALLOW \
    --rules=udp:51820 \
    --source-ranges=0.0.0.0/0 \
    --target-tags=wireguard-server \
    --description="Allow WireGuard VPN connections"

echo "Adding wireguard-server tag to bastion..."

gcloud compute instances add-tags project-dev-bastion \
    --project="${PROJECT_ID}" \
    --zone="${ZONE}" \
    --tags=wireguard-server

echo "Done! Firewall rule created and bastion tagged."
