# GamePlatform Networking Infrastructure

This module creates the core networking infrastructure for the GamePlatform platform, including VPC, subnets, NAT gateways, route tables, and VPC Flow Logs.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    VPC (10.0.0.0/16)                      │
├─────────────────────┬─────────────────────┬─────────────────┤
│   Public Subnet     │   Public Subnet     │   Public Subnet │
│   10.0.1.0/24       │   10.0.2.0/24       │   10.0.3.0/24   │
│   us-east-1a        │   us-east-1b        │   us-east-1c    │
│   ┌─────────────┐   │   ┌─────────────┐   │   ┌─────────────┐
│   │ NAT Gateway │   │   │ NAT Gateway │   │   │ NAT Gateway │
│   └─────────────┘   │   └─────────────┘   │   └─────────────┘
├─────────────────────┼─────────────────────┼─────────────────┤
│  Private Subnet     │  Private Subnet     │  Private Subnet │
│  10.0.11.0/24       │  10.0.12.0/24       │  10.0.13.0/24   │
│  us-east-1a         │  us-east-1b         │  us-east-1c     │
└─────────────────────┴─────────────────────┴─────────────────┘
```

## Resources Created

### Core Networking
- **VPC**: Main virtual private cloud with DNS support
- **Internet Gateway**: Enables internet access for public subnets
- **Public Subnets**: 3 subnets across AZs for load balancers, NAT gateways
- **Private Subnets**: 3 subnets across AZs for applications, databases
- **NAT Gateways**: Enable internet access for private subnets
- **Route Tables**: Separate routing for public and private subnets

### Security & Monitoring
- **VPC Flow Logs**: Network traffic logging for security and troubleshooting
- **CloudWatch Log Groups**: Centralized logging with configurable retention
- **IAM Roles**: Least-privilege access for VPC Flow Logs

## Configuration Options

### High Availability (Production)
```hcl
single_nat_gateway = false  # NAT Gateway per AZ
vpc_flow_logs_retention = 90  # Extended log retention
```

### Cost Optimized (Development/Staging)
```hcl
single_nat_gateway = true   # Single NAT Gateway
vpc_flow_logs_retention = 7 # Shorter log retention
```

## Usage

### 1. Environment Setup

Create environment-specific configuration files:

```bash
# Development environment
environments/dev/networking.tfvars
```

### 2. Backend Configuration

```hcl
# environments/dev/networking-backend.hcl
bucket = "gameplatform-us-east-1-tfstate"
key    = "shared-infrastructure/networking/dev/terraform.tfstate"
region = "us-east-1"
encrypt = true
```

### 3. Deploy Infrastructure

```bash
# Initialize
terraform init -backend-config=../environments/dev/networking-backend.hcl

# Plan
terraform plan -var-file="../environments/dev/networking.tfvars"

# Apply
terraform apply -var-file="../environments/dev/networking.tfvars"
```

## Variables

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `region` | AWS region | `string` | `"us-east-1"` |
| `environment` | Environment name | `string` | Required |
| `vpc_cidr` | VPC CIDR block | `string` | `"10.0.0.0/16"` |
| `availability_zones` | AZ list for subnets | `list(string)` | 3 AZs in us-east-1 |
| `public_subnet_cidrs` | Public subnet CIDRs | `list(string)` | 3x /24 subnets |
| `private_subnet_cidrs` | Private subnet CIDRs | `list(string)` | 3x /24 subnets |
| `enable_nat_gateway` | Enable NAT Gateways | `bool` | `true` |
| `single_nat_gateway` | Use single NAT for cost optimization | `bool` | `false` |
| `enable_vpc_flow_logs` | Enable VPC Flow Logs | `bool` | `true` |
| `vpc_flow_logs_retention` | Flow logs retention (days) | `number` | `30` |

## Outputs

| Name | Description |
|------|-------------|
| `vpc_id` | VPC identifier |
| `public_subnet_ids` | Public subnet identifiers |
| `private_subnet_ids` | Private subnet identifiers |
| `nat_gateway_public_ips` | NAT Gateway public IPs |
| `network_summary` | Complete networking configuration summary |

## Dependencies

This module depends on the following Terraform modules from `gameplatform-terraform`:
- `modules/aws/vpc`
- `modules/aws/subnet`
- `modules/aws/internet-gateway`
- `modules/aws/nat-gateway`
- `modules/aws/route-table`
- `modules/aws/cloudwatch-log-group`
- `modules/aws/iam-role`
- `modules/aws/iam-policy`

## Cost Considerations

### Production Recommendations
- Multiple NAT Gateways for high availability
- Extended log retention for compliance
- Cross-AZ redundancy for all resources

### Development/Staging Optimizations
- Single NAT Gateway to reduce costs
- Shorter log retention periods
- Consider disabling VPC Flow Logs if not needed

## Security Features

- **VPC Flow Logs**: Monitor all network traffic
- **Private Subnets**: Applications isolated from direct internet access
- **NAT Gateways**: Controlled outbound internet access
- **IAM Roles**: Least-privilege access patterns
- **Encryption**: State files encrypted at rest

## Monitoring

### CloudWatch Metrics
- VPC Flow Logs in CloudWatch
- NAT Gateway metrics (data transfer, connection counts)
- Network ACL and Security Group metrics

### Recommended Alarms
- High data transfer costs
- Unusual traffic patterns
- NAT Gateway connection limits

## Troubleshooting

### Common Issues

**NAT Gateway connectivity**:
- Verify route table associations
- Check security group rules
- Confirm NAT Gateway is in public subnet

**DNS resolution issues**:
- Ensure `enable_dns_hostnames = true`
- Verify VPC DNS settings
- Check DHCP option sets

**Flow Logs not appearing**:
- Verify IAM role permissions
- Check CloudWatch log group exists
- Confirm Flow Log is attached to VPC

### Useful Commands

```bash
# Check VPC configuration
aws ec2 describe-vpcs --vpc-ids vpc-xxxxx

# Verify route tables
aws ec2 describe-route-tables --filters "Name=vpc-id,Values=vpc-xxxxx"

# Monitor NAT Gateway
aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=vpc-xxxxx"
```