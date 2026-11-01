#!/usr/bin/env bash
set -euo pipefail

# ===== Config =====
REGION="us-east-1"
# Opcional: defina AWS_PROFILE se quiser
# export AWS_PROFILE="meu-perfil"

REPOS=(
  "gameplatform-lobby"
  "gameplatform-nakama"
  "gameplatform-ahsat"
  "gameplatform-afs"
  "gameplatform-postgres"
)

# Expira imagens com tag prefixo pr- após 7 dias
LIFECYCLE_POLICY='{
  "rules": [
    {
      "rulePriority": 1,
      "description": "Expire PR images older than 7 days",
      "selection": {
        "tagStatus": "tagged",
        "tagPrefixList": ["pr-"],
        "countType": "sinceImagePushed",
        "countUnit": "days",
        "countNumber": 7
      },
      "action": { "type": "expire" }
    }
  ]
}'

# ===== Execução =====
echo ">> Conta/Caller:"
aws sts get-caller-identity --output text

for repo in "${REPOS[@]}"; do
  echo "=== Criando/garantindo repositório: ${repo} (${REGION}) ==="
  if aws ecr describe-repositories --repository-names "$repo" --region "$REGION" >/dev/null 2>&1; then
    echo "   - Já existe. Pulando criação."
  else
    aws ecr create-repository --repository-name "$repo" --region "$REGION" \
      --image-tag-mutability MUTABLE \
      --encryption-configuration encryptionType=AES256 \
      >/dev/null
    echo "   - Criado."
  fi

  echo "   - Aplicando lifecycle policy (PR > 7 dias)..."
  aws ecr put-lifecycle-policy \
    --repository-name "$repo" \
    --lifecycle-policy-text "$LIFECYCLE_POLICY" \
    --region "$REGION" >/dev/null

  echo "   - Habilitando Scan on Push..."
  aws ecr put-image-scanning-configuration \
    --repository-name "$repo" \
    --image-scanning-configuration scanOnPush=true \
    --region "$REGION" >/dev/null

  echo "   - Tornando tags IMUTÁVEIS..."
  aws ecr put-image-tag-mutability \
    --repository-name "$repo" \
    --image-tag-mutability IMMUTABLE \
    --region "$REGION" >/dev/null

  URI=$(aws ecr describe-repositories --repository-names "$repo" --region "$REGION" --query 'repositories[0].repositoryUri' --output text)
  echo "   - OK: $URI"
done

echo ">> Concluído."