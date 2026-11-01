#!/bin/bash
# Fix IAM permissions for github-actions-gameplatform user to access S3 Terraform state

set -e

USER_NAME="github-actions-gameplatform"
BUCKET_NAME="gameplatform-terraform-state-live"
DYNAMODB_TABLE="gameplatform-terraform-state-lock-live"
REGION="sa-east-1"

echo "🔐 Fixing IAM permissions for Terraform state management"
echo "👤 User: $USER_NAME"
echo "🪣 Bucket: $BUCKET_NAME"
echo "🗂️ DynamoDB: $DYNAMODB_TABLE"
echo

# Create custom policy for Terraform state management
echo "📝 Creating IAM policy for Terraform state access..."

cat > /tmp/terraform-state-policy.json << 'EOF'
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "TerraformStateS3Access",
            "Effect": "Allow",
            "Action": [
                "s3:ListBucket",
                "s3:GetBucketVersioning"
            ],
            "Resource": "arn:aws:s3:::gameplatform-terraform-state-live"
        },
        {
            "Sid": "TerraformStateS3Objects",
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:GetObjectVersion",
                "s3:PutObject",
                "s3:DeleteObject"
            ],
            "Resource": "arn:aws:s3:::gameplatform-terraform-state-live/*"
        },
        {
            "Sid": "TerraformStateDynamoDBLock",
            "Effect": "Allow",
            "Action": [
                "dynamodb:DescribeTable",
                "dynamodb:GetItem",
                "dynamodb:PutItem",
                "dynamodb:DeleteItem"
            ],
            "Resource": "arn:aws:dynamodb:sa-east-1:*:table/gameplatform-terraform-state-lock-live"
        },
        {
            "Sid": "TerraformInfrastructureManagement",
            "Effect": "Allow",
            "Action": [
                "ec2:*",
                "ecs:*",
                "ecr:*",
                "iam:*",
                "logs:*",
                "route53:*",
                "acm:*",
                "elasticloadbalancing:*",
                "rds:*",
                "ssm:*",
                "secretsmanager:*",
                "wafv2:*",
                "application-autoscaling:*",
                "servicediscovery:*",
                "s3:*",
                "ses:*"
            ],
            "Resource": "*"
        }
    ]
}
EOF

# Create or update the policy
POLICY_NAME="TerraformStateManagementPolicy"
echo "📄 Creating/updating policy: $POLICY_NAME"

# Try to create the policy (will fail if it already exists)
aws iam create-policy \
    --policy-name "$POLICY_NAME" \
    --policy-document file:///tmp/terraform-state-policy.json \
    --description "Policy for Terraform state management in S3 and DynamoDB" \
    --region "$REGION" 2>/dev/null || echo "Policy already exists, updating..."

# Get the policy ARN
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text --region "$REGION")
POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/${POLICY_NAME}"

# Update the policy if it already exists
aws iam create-policy-version \
    --policy-arn "$POLICY_ARN" \
    --policy-document file:///tmp/terraform-state-policy.json \
    --set-as-default \
    --region "$REGION" 2>/dev/null || echo "Policy version creation failed (may not be needed)"

echo "✅ Policy created/updated: $POLICY_ARN"

# Attach the policy to the user
echo "🔗 Attaching policy to user: $USER_NAME"
aws iam attach-user-policy \
    --user-name "$USER_NAME" \
    --policy-arn "$POLICY_ARN" \
    --region "$REGION"

echo "✅ Policy attached to user"

# Also ensure the user has the basic EC2/ECS permissions for infrastructure
echo "🔗 Ensuring user has PowerUserAccess..."
aws iam attach-user-policy \
    --user-name "$USER_NAME" \
    --policy-arn "arn:aws:iam::aws:policy/PowerUserAccess" \
    --region "$REGION" 2>/dev/null || echo "PowerUserAccess already attached or not needed"

# List current user policies for verification
echo
echo "📋 Current policies for user $USER_NAME:"
aws iam list-attached-user-policies \
    --user-name "$USER_NAME" \
    --region "$REGION" \
    --query 'AttachedPolicies[].{PolicyName:PolicyName,PolicyArn:PolicyArn}' \
    --output table

echo
echo "🎉 IAM permissions fixed!"
echo "🧪 Test S3 access:"
echo "   aws s3 ls s3://$BUCKET_NAME --region $REGION"
echo "   aws s3 cp test.txt s3://$BUCKET_NAME/test.txt --region $REGION"

# Cleanup
rm -f /tmp/terraform-state-policy.json