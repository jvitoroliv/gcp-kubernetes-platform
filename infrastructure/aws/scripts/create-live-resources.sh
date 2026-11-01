#!/bin/bash
# Criar recursos AWS necessários para live environment
set -e

BUCKET="gameplatform-terraform-state-live"
DYNAMODB_TABLE="gameplatform-terraform-state-lock-live"
REGION="sa-east-1"

echo "CRIANDO RECURSOS AWS PARA LIVE ENVIRONMENT"
echo "BUCKET: $BUCKET"
echo "DYNAMODB: $DYNAMODB_TABLE"
echo "REGION: $REGION"
echo

# Verificar credenciais
echo "VERIFICANDO CREDENCIAIS AWS..."
aws sts get-caller-identity --region $REGION

# Criar bucket S3
echo "CRIANDO BUCKET S3..."
if aws s3 ls "s3://$BUCKET" --region $REGION >/dev/null 2>&1; then
    echo "BUCKET JÁ EXISTE"
else
    aws s3 mb "s3://$BUCKET" --region $REGION
    echo "BUCKET CRIADO"
fi

# Configurar bucket
echo "CONFIGURANDO BUCKET..."
aws s3api put-bucket-versioning \
    --bucket "$BUCKET" \
    --versioning-configuration Status=Enabled \
    --region $REGION

aws s3api put-bucket-encryption \
    --bucket "$BUCKET" \
    --server-side-encryption-configuration '{
        "Rules": [
            {
                "ApplyServerSideEncryptionByDefault": {
                    "SSEAlgorithm": "AES256"
                }
            }
        ]
    }' \
    --region $REGION

# Criar tabela DynamoDB
echo "CRIANDO TABELA DYNAMODB..."
if aws dynamodb describe-table --table-name "$DYNAMODB_TABLE" --region $REGION >/dev/null 2>&1; then
    echo "TABELA JÁ EXISTE"
else
    aws dynamodb create-table \
        --table-name "$DYNAMODB_TABLE" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
        --region $REGION

    echo "AGUARDANDO TABELA FICAR ATIVA..."
    aws dynamodb wait table-exists --table-name "$DYNAMODB_TABLE" --region $REGION
    echo "TABELA CRIADA"
fi

# Criar estados vazios para todos os stacks
STATE_KEYS=(
    "networking/terraform.tfstate"
    "dns-and-alb/terraform.tfstate"
    "atlantis/terraform.tfstate"
    "postgres/terraform.tfstate"
    "runners/terraform.tfstate"
    "live-env/terraform.tfstate"
)

echo "CRIANDO ESTADOS VAZIOS..."
for key in "${STATE_KEYS[@]}"; do
    echo "CRIANDO: $key"
    if aws s3 ls "s3://$BUCKET/$key" --region $REGION >/dev/null 2>&1; then
        echo "JÁ EXISTE: $key"
    else
        echo '{"version":4,"terraform_version":"1.6.0","serial":1,"lineage":"00000000-0000-0000-0000-000000000000","outputs":{},"resources":[]}' | \
        aws s3 cp - "s3://$BUCKET/$key" --region $REGION
        echo "CRIADO: $key"
    fi
done

echo
echo "RECURSOS CRIADOS COM SUCESSO!"
echo "TESTE: aws s3 ls s3://$BUCKET --region $REGION"
echo "TESTE: aws dynamodb describe-table --table-name $DYNAMODB_TABLE --region $REGION"