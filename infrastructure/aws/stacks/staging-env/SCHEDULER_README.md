# Environment Scheduler - Cost Optimization

Automated shutdown and startup for non-production environments (dev, staging) to reduce AWS costs during off-hours.

## Overview

The scheduler automatically:
- **Shuts down** ECS services and RDS instances during off-hours (default: 20h BRT / 8 PM)
- **Starts up** resources during business hours (default: 6h BRT / 6 AM)
- **Saves state** in DynamoDB to restore exact service configurations
- **Sends notifications** via SNS for monitoring and alerts

## Architecture

```
EventBridge Rules (cron)
    ↓
Lambda Functions (Python)
    ↓
ECS Services + RDS Instance
    ↓
DynamoDB (state tracking)
    ↓
SNS (notifications)
```

## Resources Created

When `enable_scheduler = true`:
- **2 Lambda Functions**: shutdown and startup handlers
- **2 EventBridge Rules**: cron triggers for automated execution
- **1 DynamoDB Table**: state persistence for service restoration
- **1 SNS Topic**: notifications and alerts
- **CloudWatch Alarms**: Lambda error monitoring
- **IAM Roles & Policies**: least-privilege access

## Configuration

### 1. Enable Scheduler

Edit environment tfvars file:

**Dev Environment** (`environments/dev/persistent-env.tfvars`):
```hcl
enable_scheduler = true  # Enable scheduler resources
scheduler_enabled = true # Enable EventBridge rules
```

**Staging Environment** (`environments/stg/staging-env.tfvars`):
```hcl
enable_scheduler = true
scheduler_enabled = true
```

### 2. Customize Schedule (Optional)

Default schedule (Brazil timezone):
- Shutdown: 20h BRT / 8 PM Mon-Fri (23h UTC)
- Startup: 6h BRT / 6 AM Mon-Fri (9h UTC)

To customize, update tfvars:
```hcl
# Example: Shutdown at 21h BRT / 9 PM, Startup at 7h BRT / 7 AM
scheduler_shutdown_cron = "cron(0 0 ? * MON-FRI *)"  # 21h BRT = 0h UTC next day
scheduler_startup_cron  = "cron(0 10 ? * MON-FRI *)" # 7h BRT = 10h UTC
```

Cron format: `cron(minute hour day-of-month month day-of-week year)`

### 3. Enable Notifications (Optional)

Add email for notifications:
```hcl
scheduler_notification_email = "devops@example.com"
```

### 4. Enable RDS Scheduling

Edit postgres tfvars:

**Dev** (`environments/dev/postgres.tfvars`):
```hcl
enable_scheduler = true
```

**Staging** (`environments/stg/postgres.tfvars`):
```hcl
enable_scheduler = true
```

This adds scheduler tags to RDS for identification.

## Deployment

### Via Atlantis (Recommended)

1. Create PR with scheduler changes
2. Comment on PR: `atlantis plan`
3. Review plan output
4. Comment on PR: `atlantis apply`

### Manual Terraform

```bash
cd stacks/persistent-env

# Initialize (if needed)
terraform init

# Plan
terraform plan -var-file=../../environments/dev/persistent-env.tfvars

# Apply
terraform apply -var-file=../../environments/dev/persistent-env.tfvars
```

## Usage

### Automatic Operation

Once deployed, the scheduler runs automatically based on cron schedules. No manual intervention needed.

### Manual Override

To temporarily prevent shutdown/startup, disable EventBridge rules:

```hcl
# In tfvars
scheduler_enabled = false  # Pauses scheduling without destroying resources
```

Apply changes via Atlantis or Terraform.

### Manual Trigger (Testing)

Test Lambda functions manually:

```bash
# Trigger shutdown
aws lambda invoke \
  --function-name project-dev-scheduler-shutdown \
  --region us-east-1 \
  /tmp/shutdown-output.json

# Trigger startup
aws lambda invoke \
  --function-name project-dev-scheduler-startup \
  --region us-east-1 \
  /tmp/startup-output.json
```

## Monitoring

### CloudWatch Logs

Lambda execution logs:
- `/aws/lambda/project-dev-scheduler-shutdown`
- `/aws/lambda/project-dev-scheduler-startup`

### CloudWatch Alarms

Automatic alarms for Lambda errors:
- `project-dev-scheduler-shutdown-errors`
- `project-dev-scheduler-startup-errors`

Alarms publish to SNS topic on error.

### SNS Notifications

Each shutdown/startup operation sends notification with:
- Timestamp
- Number of services affected
- RDS status
- Any errors encountered

## Cost Savings

### Estimated Savings (Dev + Staging)

**Current monthly cost**: $394/month
- Dev: $296/month
- Staging: $98/month

**Savings scenarios**:
| Schedule | Hours Off | Savings/Month | Savings/Year |
|----------|-----------|---------------|--------------|
| Nights only (9h/day) | 27% | $106 | $1,272 |
| Half day (12h/day) | 50% | $197 | $2,364 |
| Nights + weekends | 67% | $264 | $3,168 |

**ROI**: Scheduler costs ~$1/month, savings start immediately.

## Safety Features

### State Persistence

Before shutdown, the scheduler saves:
- ECS service desired counts
- RDS instance status
- Timestamp for tracking

State stored in DynamoDB with 7-day TTL.

### Restore Accuracy

On startup, scheduler restores exact previous state:
- Services return to original task counts
- No manual reconfiguration needed

### RDS Safeguards

- Only stops if RDS status is "available"
- Waits for RDS to be available before starting ECS services
- 5-minute timeout for RDS startup

### Error Handling

- Lambda retries on transient failures
- Errors logged to CloudWatch
- SNS notifications on failures
- CloudWatch alarms trigger on repeated errors

## Troubleshooting

### Services didn't shut down

Check:
1. EventBridge rule enabled: `scheduler_enabled = true`
2. Lambda execution logs for errors
3. IAM permissions correct

### Services didn't start up

Check:
1. RDS started successfully (may take 5-10 minutes)
2. DynamoDB has saved state
3. Lambda timeout (default 5 minutes)

### Missing state in DynamoDB

State expires after 7 days (TTL). If services were off longer than 7 days, manual intervention needed:

```bash
# Manually set ECS service count
aws ecs update-service \
  --cluster project-dev-shared-cluster \
  --service project-dev-nakama \
  --desired-count 1
```

### RDS won't stop

Check:
- RDS status must be "available" to stop
- Cannot stop RDS with pending modifications
- Some RDS types (Aurora) cannot be stopped, only paused

## Schedule Examples

### Conservative (Nights Only) - DEFAULT
```hcl
# Shutdown: 20h BRT / 8 PM Mon-Fri
scheduler_shutdown_cron = "cron(0 23 ? * MON-FRI *)"
# Startup: 6h BRT / 6 AM Mon-Fri
scheduler_startup_cron  = "cron(0 9 ? * MON-FRI *)"
```

### Moderate (Extended Hours)
```hcl
# Shutdown: 21h BRT / 9 PM Mon-Fri
scheduler_shutdown_cron = "cron(0 0 ? * TUE-SAT *)"  # 21h Mon-Fri = 0h UTC Tue-Sat
# Startup: 5h BRT / 5 AM Mon-Fri
scheduler_startup_cron  = "cron(0 8 ? * MON-FRI *)"
```

### Aggressive (Nights + Weekends)
```hcl
# Shutdown: 19h BRT / 7 PM Fri, All day Sat-Sun
scheduler_shutdown_cron = "cron(0 22 ? * FRI *)"
# Startup: 6h BRT / 6 AM Mon only
scheduler_startup_cron  = "cron(0 9 ? * MON *)"
```

## Disable Scheduler

### Temporarily (Pause)
```hcl
scheduler_enabled = false  # Keeps resources but disables triggers
```

### Permanently (Remove)
```hcl
enable_scheduler = false  # Destroys all scheduler resources
```

Apply via Atlantis or Terraform.

## FAQs

**Q: Does this affect production (live environment)?**
A: No. Scheduler only applies to `dev` and `stg` environments. Live environment is never touched.

**Q: What happens if I need to work during off-hours?**
A: Manually start services via AWS Console or CLI, or temporarily disable scheduler with `scheduler_enabled = false`.

**Q: Can I customize which services to shutdown?**
A: Currently all ECS services in the cluster are managed. To exclude specific services, modify Lambda code to filter by service name/tags.

**Q: What if Lambda fails during shutdown?**
A: Services continue running. CloudWatch alarm triggers and SNS sends notification. Manual intervention may be needed.

**Q: Does RDS data persist during shutdown?**
A: Yes. RDS "stop" preserves all data. It's like hibernation, not deletion.

**Q: Can I schedule per-service instead of environment-wide?**
A: Not currently. Scheduler operates at environment level (all services together). Custom per-service logic can be added to Lambda code.

## Support

For issues or questions:
1. Check CloudWatch logs: `/aws/lambda/gameplatform-{env}-scheduler-*`
2. Review CloudWatch alarms
3. Check SNS topic for error notifications
4. Review this README for troubleshooting steps

## References

- [AWS Lambda Documentation](https://docs.aws.amazon.com/lambda/)
- [EventBridge Cron Expressions](https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-cron-expressions.html)
- [RDS Stop/Start](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_StopInstance.html)
- [ECS Update Service](https://docs.aws.amazon.com/AmazonECS/latest/APIReference/API_UpdateService.html)
