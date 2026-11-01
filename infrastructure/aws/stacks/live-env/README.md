# GamePlatform Live Environment Stack

This stack creates the production live environment for GamePlatform with the dedicated ECS cluster `GamePlatform-live`.

## Architecture

The live environment includes:

### Core Infrastructure
- **ECS Cluster**: GamePlatform-live (dedicated production cluster)
- **Service Discovery**: DNS-based service discovery namespace
- **Security Groups**: Production-configured security groups
- **IAM Roles**: Task and execution roles for ECS services

### Services Deployed
1. **Nakama** (Game Server) - `api.live.gameplatform.click`
2. **Lobby** (Next.js Frontend) - `app.live.gameplatform.click`
3. **AFS** (Asset File Service) - `afs.live.gameplatform.click`
4. **AHSAT** (Analytics) - `ahsat.live.gameplatform.click`
5. **AES** (Email Service) - `aes.live.gameplatform.click`
6. **Lobby Backend** (NestJS API) - `lobby-backend.live.gameplatform.click`

### Production Optimizations
- **Resource Allocation**: 2 vCPU, 4 GB RAM per service (configurable)
- **Scaling**: 2 instances minimum per service for high availability
- **Monitoring**: Extended log retention (30 days)
- **Health Checks**: Comprehensive health monitoring
- **Circuit Breaker**: Deployment circuit breaker with rollback
- **Security**: Production-scoped S3 permissions

## Configuration

### Required Variables
- `domain_name`: Production domain (default: live.gameplatform.click)
- `environment`: Environment name (live)
- `container_images`: Container image URIs for all services
- `database_password`: Production database password

### Resource Configuration
- `nakama_cpu`: 2048 (2 vCPU) - configurable
- `nakama_memory`: 4096 (4 GB) - configurable
- `cpu`: 1024 (1 vCPU) - configurable
- `memory`: 1024 (1 GB) - configurable
- `desired_count`: 2 instances per service
- `log_retention_days`: 30 days

## Dependencies

This stack requires the following infrastructure to exist:
- VPC with public/private subnets
- Application Load Balancer
- Route53 hosted zone
- SSL certificate
- RDS database instance

## Usage

1. Configure backend.hcl and tfvars files
2. Initialize Terraform: `terraform init -backend-config=backend.hcl`
3. Plan: `terraform plan -var-file=terraform.tfvars`
4. Apply: `terraform apply -var-file=terraform.tfvars`

## Service URLs

After deployment, services will be available at:
- https://api.live.gameplatform.click (Nakama)
- https://app.live.gameplatform.click (Lobby)
- https://afs.live.gameplatform.click (Asset File Service)
- https://ahsat.live.gameplatform.click (Analytics)
- https://aes.live.gameplatform.click (Email Service)
- https://lobby-backend.live.gameplatform.click (Backend API)