#!/usr/bin/env bash
set -euo pipefail

# Build and push custom Atlantis image with embedded Terraform

AWS_REGION=${AWS_REGION:-us-east-1}
ECR_REPO_NAME=${ECR_REPO_NAME:-gameplatform-atlantis}
IMAGE_TAG=${IMAGE_TAG:-v-1.0.0}
ACCOUNT_ID=${ACCOUNT_ID:-777777777775}
ECR_URI="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO_NAME}"

echo "[+] Using region: ${AWS_REGION}"
echo "[+] ECR repo: ${ECR_URI}"
echo "[+] Image tag: ${IMAGE_TAG}"

echo "[+] Ensuring ECR repository exists..."
if ! aws ecr describe-repositories --repository-names "${ECR_REPO_NAME}" --region "${AWS_REGION}" >/dev/null 2>&1; then
  aws ecr create-repository \
    --repository-name "${ECR_REPO_NAME}" \
    --image-tag-mutability IMMUTABLE \
    --image-scanning-configuration scanOnPush=true \
    --encryption-configuration encryptionType=AES256 \
    --region "${AWS_REGION}" >/dev/null
  echo "[+] Created ECR repository: ${ECR_REPO_NAME}"
else
  echo "[+] ECR repository already exists"
fi

echo "[+] Logging in to ECR..."
aws ecr get-login-password --region "${AWS_REGION}" | docker login --username AWS --password-stdin "${ECR_URI%/*}"

echo "[+] Building image..."
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "${SCRIPT_DIR}"
chmod +x terraform
docker build --no-cache --platform=linux/amd64 -t "${ECR_URI}:${IMAGE_TAG}" .

echo "[+] Pushing image..."
docker push "${ECR_URI}:${IMAGE_TAG}"

echo "[✓] Done. Use this image in stacks/atlantis: ${ECR_URI}:${IMAGE_TAG}"

