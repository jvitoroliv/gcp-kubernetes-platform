# Persistent Environment Template

This directory contains the Terraform configuration for creating any environments for PRs in the GamePlatform project.

## Architecture

- **Single Template**: One fixed template that creates one environment at a time
- **Variable-Based**: All PR-specific values passed as Terraform variables via Atlantis
- **No Commits**: No files are modified or committed - everything is handled via Atlantis commands
- **Module-Based**: Uses modules from `gameplatform-terraform` repository (similar to shared-infrastructure)

## Services Deployed

1. **Server** (ECS Service):
   - Nakama (port 7350, 7351)
   - AFS (port 8080)
   - AHSAT (port 8080)

2. **Lobby** (ECS Service):
   - Next.js frontend (port 3000)

## URLs

- **Server**: `https://pr-{PR_NUMBER}.dev.gameplatform.click`
- **Lobby**: `https://lobby-pr-{PR_NUMBER}.dev.gameplatform.click`

## Usage

### Via GitHub Actions Workflow

1. The workflow `check-and-deploy-pr.yml` automatically:
   - Builds container images
   - Generates Atlantis command with all variables
   - Posts command in PR comment

### Via Atlantis Commands

Execute these commands **in the PR**:

```bash
# Plan (with all variables)
atlantis plan -d environment -var="pr_number=6" -var="git_sha=abc123" -var="container_images={nakama=\"ecr_url:tag\",...}" [other vars]

# Apply (after reviewing plan)
atlantis apply -d environment

# Destroy (cleanup)
atlantis destroy -d environment
```

## Variables

Required variables passed via `-var` flags:

- `pr_number`: PR number for identification
- `git_sha`: Git commit SHA
- `container_images`: Object with nakama, afs, ahsat, lobby image URLs
- `database_password`: RDS password (sensitive)

Optional variables with defaults:
- `domain_name`: "dev.gameplatform.click"
- `environment`: "dev"
- `aws_region`: "us-east-1"
- `nakama_port`: 7350
- `lobby_port`: 3000
- `cpu`: 512
- `memory`: 1024
- `desired_count`: 1
- `log_retention_days`: 7

## State Management

- **Backend**: S3 bucket `gameplatform-us-east-1-tfstate`
- **Key**: `environment/terraform.tfstate` (single state file)
- **DynamoDB**: `project-dev-shared-terraform-locks` for locking

## Infrastructure

Uses existing shared infrastructure:
- ✅ VPC: `project-dev-vpc`
- ✅ ALB: `project-dev-shared-alb`
- ✅ ECS Cluster: `project-dev-shared-cluster`
- ✅ RDS: `project-dev-shared-db`
- ✅ Route53: `dev.gameplatform.click`
- ✅ ACM: `*.dev.gameplatform.click`

## Limitations

- **One Environment**: Only one environment can be active at a time
- **Manual Cleanup**: Must run `atlantis destroy` manually when done
- **RDS Shared**: All environments use the same shared RDS instance

## Cost

Estimated cost: ~$5-15 USD per day (ECS Fargate tasks only, shared infrastructure already exists)

## Monitoring

- CloudWatch logs: `/ecs/project-dev-pr-{NUMBER}-server` and `-lobby`
- ALB target group health checks
- ECS service status in AWS console