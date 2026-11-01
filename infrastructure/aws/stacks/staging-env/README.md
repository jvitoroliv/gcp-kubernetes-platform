# GamePlatform Staging Environment Stack

This stack creates the staging environment for GamePlatform with the dedicated ECS cluster `GamePlatform-stg`.

## Architecture

The staging environment includes:

### Core Infrastructure
- **ECS Cluster**: GamePlatform-stg (dedicated staging cluster)
- **Service Discovery**: DNS-based service discovery namespace
- **Security Groups**: Staging-configured security groups
- **IAM Roles**: Task and execution roles for ECS services

### Services Deployed
1. **Nakama** (Game Server) - `nakama.stg.gameplatform.click`
2. **Lobby** (Next.js Frontend) - `app.stg.gameplatform.click`
3. **AFS** (Asset File Service) - `afs.stg.gameplatform.click`
4. **AHSAT** (Analytics) - `ahsat.stg.gameplatform.click`
5. **AES** (Email Service) - `aes.stg.gameplatform.click`
6. **Lobby Backend** (NestJS API) - `lobby-backend.stg.gameplatform.click`

### Staging Configuration
- **Resource Allocation**: 1 vCPU, 2 GB RAM per service (configurable)
- **Scaling**: 1 instance per service (cost-optimized for staging)
- **Monitoring**: Moderate log retention (14 days)
- **Health Checks**: Comprehensive health monitoring
- **Circuit Breaker**: Deployment circuit breaker with rollback
- **Security**: Scoped S3 permissions
- **Region**: us-east-1 (same as dev environment)

## Configuration

### Required Variables
- `domain_name`: Staging domain (default: stg.gameplatform.click)
- `environment`: Environment name (stg)
- `container_images`: Container image URIs for all services
- `database_password`: Staging database password

### Resource Configuration
- `nakama_cpu`: 2048 (2 vCPU) - configurable
- `nakama_memory`: 4096 (4 GB) - configurable
- `cpu`: 1024 (1 vCPU) - configurable
- `memory`: 2048 (2 GB) - configurable
- `desired_count`: 1 instance per service
- `log_retention_days`: 14 days

## Dependencies

This stack requires the following infrastructure to exist:
- VPC with public/private subnets (us-east-1)
- Application Load Balancer (project-stg-shared-alb)
- Route53 hosted zone (stg.gameplatform.click)
- SSL certificate (*.stg.gameplatform.click)
- RDS database instance

## Usage

### Deploy via Terraform (Manual)

1. Navigate to stack directory:
   ```bash
   cd stacks/staging-env
   ```

2. Initialize with backend configuration:
   ```bash
   terraform init -backend-config=../../environments/stg/staging-env-backend.hcl
   ```

3. Plan deployment:
   ```bash
   terraform plan -var-file=../../environments/stg/staging-env.tfvars
   ```

4. Apply changes:
   ```bash
   terraform apply -var-file=../../environments/stg/staging-env.tfvars
   ```

### Deploy via Atlantis (Recommended)

Comment on pull request with:
```
atlantis plan -d stacks/staging-env -var-file=../../environments/stg/staging-env.tfvars
atlantis apply -d stacks/staging-env
```

## Service URLs

After deployment, services will be available at:
- https://nakama.stg.gameplatform.click (Nakama Game Server)
- https://app.stg.gameplatform.click (Lobby Frontend)
- https://afs.stg.gameplatform.click (Asset File Service)
- https://ahsat.stg.gameplatform.click (Analytics Service)
- https://aes.stg.gameplatform.click (Email Service)
- https://lobby-backend.stg.gameplatform.click (Backend API)

## Notes

- Staging uses the **us-east-1** region (same as dev, different from live's sa-east-1)
- DNS is delegated from parent zone `gameplatform.click` (account 777777777777)
- Container images are stored in dev AWS account (777777777771)
- Staging is designed for pre-production testing with production-like configuration but lower costs
