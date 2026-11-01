# WireGuard VPN Setup for GamePlatform GCP

This sets up WireGuard VPN on the bastion host, allowing team members to access all GCP resources (GKE clusters for dev + stg, Cloud SQL, etc.) from their local machines.

## Automated Setup (via Terraform)

If you deployed with `enable_wireguard = true` in the 07-vpn-bastion stack, WireGuard is already installed and configured. Just get the client config:

```bash
# Get admin client config from instance metadata
gcloud compute instances describe project-dev-bastion \
    --zone=us-east1-b \
    --project=project-nonprod-env \
    --format='get(metadata.items[wg-client-config])' > ~/wireguard-gameplatform.conf

# Import in WireGuard client and connect
```

## Manual Setup (if needed)

### Step 1: Create Firewall Rule (run once, from your local machine)

```bash
chmod +x scripts/wireguard/setup-firewall.sh
./scripts/wireguard/setup-firewall.sh
```

### Step 2: Add External IP to Bastion (if not already present)

```bash
# Check current IPs
gcloud compute instances describe project-dev-bastion \
    --zone=us-east1-b \
    --project=project-nonprod-env \
    --format="get(networkInterfaces[0].accessConfigs)"

# If no external IP, add one:
gcloud compute instances add-access-config project-dev-bastion \
    --zone=us-east1-b \
    --project=project-nonprod-env
```

### Step 3: Install WireGuard Server (run on bastion)

```bash
# SSH into bastion
gcloud compute ssh project-dev-bastion \
    --zone=us-east1-b \
    --tunnel-through-iap \
    --project=project-nonprod-env

# Upload and run install script (from another terminal)
gcloud compute scp scripts/wireguard/install-wireguard-server.sh \
    project-dev-bastion:/tmp/ \
    --zone=us-east1-b \
    --tunnel-through-iap \
    --project=project-nonprod-env

# On bastion:
chmod +x /tmp/install-wireguard-server.sh
sudo /tmp/install-wireguard-server.sh

# Copy management scripts
sudo cp /tmp/add-user.sh /etc/wireguard/
sudo cp /tmp/list-users.sh /etc/wireguard/
sudo cp /tmp/remove-user.sh /etc/wireguard/
sudo chmod +x /etc/wireguard/*.sh
```

## Managing Users

### Add a User

```bash
# On bastion
sudo /etc/wireguard/add-user.sh joao
```

This will:
1. Generate keys for the user
2. Create a config file
3. Show the config and QR code
4. Automatically add them to the server

### List Users

```bash
sudo /etc/wireguard/list-users.sh
```

### Remove a User

```bash
sudo /etc/wireguard/remove-user.sh joao
```

### Get a User's Config

```bash
sudo cat /etc/wireguard/clients/joao.conf
```

## For Team Members

### Installation

1. Download WireGuard:
   - **Windows**: https://www.wireguard.com/install/ (download .msi)
   - **macOS**: App Store → search "WireGuard"
   - **Linux**: `sudo apt install wireguard` or `sudo dnf install wireguard-tools`
   - **iOS/Android**: App Store / Play Store → search "WireGuard"

2. Import the `.conf` file you received:
   - **Windows/macOS**: Click "Import tunnel(s) from file"
   - **Linux**: `sudo cp gameplatform-dev.conf /etc/wireguard/ && sudo wg-quick up gameplatform-dev`
   - **Mobile**: Scan the QR code

3. Click "Activate" to connect

### What You Can Access When Connected

- **GKE Cluster**: `kubectl` commands work directly
- **Cloud SQL**: `10.x.x.x:5432` (PostgreSQL)
- **Internal Services**: All VPC resources
- **Bastion**: `10.200.0.1`

### Verify Connection

```bash
# Check VPN is connected
ping 10.200.0.1

# Access GKE dev cluster
gcloud container clusters get-credentials project-dev-workloads \
    --region us-east1 \
    --project project-nonprod-env \
    --internal-ip

kubectl get nodes

# Access GKE stg cluster
gcloud container clusters get-credentials project-stg-workloads \
    --region us-east1 \
    --project project-nonprod-env \
    --internal-ip

kubectl get nodes
```

## Network Ranges

| Network | CIDR | Description |
|---------|------|-------------|
| VPN Clients | 10.200.0.0/24 | WireGuard clients |
| **Dev Cluster** | | |
| Dev Subnet | 10.100.0.0/20 | GKE nodes |
| Dev Pods | 10.104.0.0/14 | Pod IPs |
| Dev Services | 10.108.0.0/20 | Service IPs |
| Dev Master | 172.16.0.0/28 | Control plane |
| **Stg Cluster** | | |
| Stg Subnet | 10.48.0.0/20 | GKE nodes |
| Stg Pods | 10.52.0.0/14 | Pod IPs |
| Stg Services | 10.64.0.0/20 | Service IPs |
| Stg Master | 172.16.2.0/28 | Control plane |
| **Runners Cluster** | | |
| Runners Subnet | 10.120.0.0/20 | GKE nodes |
| Runners Pods | 10.124.0.0/14 | Pod IPs |
| Runners Services | 10.128.0.0/20 | Service IPs |
| Runners Master | 172.16.1.0/28 | Control plane |

## Troubleshooting

### Can't connect to VPN

1. Check bastion has external IP
2. Check firewall rule exists: `gcloud compute firewall-rules list --filter="name=gameplatform-nonprod-allow-wireguard" --project=project-nonprod-env`
3. Check WireGuard is running on bastion: `sudo wg show`

### Connected but can't reach resources

1. Check IP forwarding: `cat /proc/sys/net/ipv4/ip_forward` (should be 1)
2. Check iptables rules: `sudo iptables -t nat -L POSTROUTING`
3. Check routes in client config include the right networks

### Check server logs

```bash
sudo journalctl -u wg-quick@wg0 -f
```
