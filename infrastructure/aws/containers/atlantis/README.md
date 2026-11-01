# Custom Atlantis Image (with Terraform embedded)

This directory builds a custom Atlantis container image that bundles Terraform v1.13.1.
Embedding the Terraform binary avoids runtime downloads that fail in locked-down
or proxied environments (e.g., go-getter "expected a single file: .../archive").

## Files
- `Dockerfile`: Based on `ghcr.io/runatlantis/atlantis:v0.35.1`, copies the pre-downloaded
  Terraform binary into `/usr/local/bin/terraform`, fixes permissions, and sets
  env hints to disable runtime download.
- `terraform`: Terraform v1.13.1 Linux AMD64 binary (executable). Already in this folder.
- `.dockerignore`: Keeps build context minimal.

## Build and Push (ECR)

Set these variables (adjust names as desired):

```bash
export AWS_REGION=us-east-1
export ECR_REPO_NAME=gameplatform-atlantis
export ECR_URI=777777777771.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO_NAME}
export IMAGE_TAG=tf-v1.13.1
```

1) Create ECR repository (idempotent):
```bash
aws ecr describe-repositories --repository-names "$ECR_REPO_NAME" --region "$AWS_REGION" >/dev/null 2>&1 \
  || aws ecr create-repository \
       --repository-name "$ECR_REPO_NAME" \
       --image-tag-mutability IMMUTABLE \
       --image-scanning-configuration scanOnPush=true \
       --encryption-configuration encryptionType=AES256 \
       --region "$AWS_REGION"
```

2) Authenticate Docker to ECR:
```bash
aws ecr get-login-password --region "$AWS_REGION" \
  | docker login --username AWS --password-stdin \
    "${ECR_URI%/*}"
```

3) Build and push the image:
```bash
cd containers/atlantis
# Ensure `terraform` binary here is executable
chmod +x terraform

# Build
docker build -t "$ECR_URI:$IMAGE_TAG" .

# Push
docker push "$ECR_URI:$IMAGE_TAG"
```

## Update Terraform Stack (Atlantis)

In `stacks/atlantis`:
- Set the image to your ECR URI and tag, e.g. in `environments/dev/*.tfvars` or via var override:

```hcl
atlantis_image = "777777777771.dkr.ecr.us-east-1.amazonaws.com/gameplatform-atlantis:tf-v1.13.1"
```

- Ensure the container has these envs (already present in main.tf, just confirm):
```hcl
ATLANTIS_DISABLE_TERRAFORM_DOWNLOAD = "true"
ATLANTIS_TERRAFORM_BIN              = "/usr/local/bin/terraform"
```

Deploy and restart Atlantis:
```bash
# Plan/apply via your reusable workflow
gh workflow run deploy-infrastructure.yml --ref main \
  -f stack=atlantis -f environment=dev -f action=apply -f auto_approve=true

# Force new deployment (optional if your workflow does it)
aws ecs update-service \
  --cluster project-dev-shared-cluster \
  --service project-dev-atlantis \
  --force-new-deployment \
  --region "$AWS_REGION"
```

## Validate
- CloudWatch logs should no longer show Terraform downloading.
- PR comment: `atlantis plan -p dns-and-alb-dev` should proceed to init/validate/plan.
- GitHub commit statuses now update (your PAT has write permissions).

## Notes
- You can upgrade Atlantis version by changing the base tag in the Dockerfile.
- You can upgrade Terraform by replacing `terraform` binary and updating `IMAGE_TAG`.
- Keeping the image in your own ECR aligns with your "no external modules" policy.

