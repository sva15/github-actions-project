#!/bin/bash

# Setup AWS Secrets and IAM Resources
# This script creates all required secrets, parameters, and IAM resources for the mono repo deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Get AWS account information
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION=$(aws configure get region)

if [ -z "$ACCOUNT_ID" ]; then
    print_error "Not authenticated to AWS. Run: aws configure"
    exit 1
fi

if [ -z "$REGION" ]; then
    print_error "No default region set. Run: aws configure set region us-east-1"
    exit 1
fi

print_status "🔐 Setting up AWS secrets and IAM resources"
echo "Account ID: $ACCOUNT_ID"
echo "Region: $REGION"
echo ""

# 1. Create Systems Manager parameters for different environments
print_status "Creating Systems Manager parameters..."

ENVIRONMENTS=("prod" "staging" "dev" "hotfix")

for ENV in "${ENVIRONMENTS[@]}"; do
    print_status "Setting up parameters for environment: $ENV"
    
    # JWT Secret
    JWT_SECRET=$(openssl rand -base64 32)
    aws ssm put-parameter \
        --name "/mono-repo/$ENV/jwt-secret" \
        --value "$JWT_SECRET" \
        --type "SecureString" \
        --overwrite \
        --description "JWT signing secret for $ENV environment" \
        > /dev/null
    
    # Database Password
    DB_PASSWORD=$(openssl rand -base64 16)
    aws ssm put-parameter \
        --name "/mono-repo/$ENV/db-password" \
        --value "$DB_PASSWORD" \
        --type "SecureString" \
        --overwrite \
        --description "Database password for $ENV environment" \
        > /dev/null
    
    # API Key (example external service)
    API_KEY=$(openssl rand -hex 20)
    aws ssm put-parameter \
        --name "/mono-repo/$ENV/api-key" \
        --value "$API_KEY" \
        --type "SecureString" \
        --overwrite \
        --description "External API key for $ENV environment" \
        > /dev/null
    
    # SMTP Password (for notifications)
    SMTP_PASSWORD=$(openssl rand -base64 16)
    aws ssm put-parameter \
        --name "/mono-repo/$ENV/smtp-password" \
        --value "$SMTP_PASSWORD" \
        --type "SecureString" \
        --overwrite \
        --description "SMTP server password for $ENV environment" \
        > /dev/null
    
    print_success "Parameters created for $ENV environment"
done

echo ""

# 2. Create S3 bucket for deployment artifacts
print_status "Creating S3 bucket for deployment artifacts..."

BUCKET_NAME="mono-repo-deployment-artifacts-$ACCOUNT_ID"
if aws s3 ls "s3://$BUCKET_NAME" 2>&1 | grep -q 'NoSuchBucket'; then
    aws s3 mb s3://$BUCKET_NAME --region $REGION
    
    # Enable versioning
    aws s3api put-bucket-versioning \
        --bucket $BUCKET_NAME \
        --versioning-configuration Status=Enabled
    
    # Set lifecycle policy to clean up old artifacts
    cat > bucket-lifecycle.json << EOF
{
    "Rules": [
        {
            "ID": "DeleteOldArtifacts",
            "Status": "Enabled",
            "Filter": {
                "Prefix": "lambda-deployments/"
            },
            "Expiration": {
                "Days": 30
            },
            "NoncurrentVersionExpiration": {
                "NoncurrentDays": 7
            }
        },
        {
            "ID": "DeleteOldECRDeployments",
            "Status": "Enabled",
            "Filter": {
                "Prefix": "ec2-deployments/"
            },
            "Expiration": {
                "Days": 14
            }
        }
    ]
}
EOF
    
    aws s3api put-bucket-lifecycle-configuration \
        --bucket $BUCKET_NAME \
        --lifecycle-configuration file://bucket-lifecycle.json
    
    rm bucket-lifecycle.json
    
    print_success "S3 bucket created: $BUCKET_NAME"
else
    print_warning "S3 bucket already exists: $BUCKET_NAME"
fi

# Store bucket name in parameter store
aws ssm put-parameter \
    --name "/mono-repo/deployment-bucket" \
    --value "$BUCKET_NAME" \
    --type "String" \
    --overwrite \
    --description "S3 bucket for deployment artifacts" \
    > /dev/null

echo ""

# 3. Create IAM roles
print_status "Creating IAM roles..."

# Lambda Execution Role
LAMBDA_ROLE_NAME="mono-repo-lambda-execution-role"
if ! aws iam get-role --role-name $LAMBDA_ROLE_NAME > /dev/null 2>&1; then
    # Create trust policy
    cat > lambda-trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
    
    aws iam create-role \
        --role-name $LAMBDA_ROLE_NAME \
        --assume-role-policy-document file://lambda-trust-policy.json \
        --description "Execution role for mono repo Lambda functions" \
        > /dev/null
    
    # Attach basic execution policy
    aws iam attach-role-policy \
        --role-name $LAMBDA_ROLE_NAME \
        --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
    
    # Create custom policy for additional permissions
    cat > lambda-custom-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ssm:GetParameter",
                "ssm:GetParameters",
                "ssm:GetParametersByPath"
            ],
            "Resource": "arn:aws:ssm:$REGION:$ACCOUNT_ID:parameter/mono-repo/*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": "arn:aws:logs:$REGION:$ACCOUNT_ID:*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "dynamodb:GetItem",
                "dynamodb:PutItem",
                "dynamodb:UpdateItem",
                "dynamodb:DeleteItem",
                "dynamodb:Query",
                "dynamodb:Scan"
            ],
            "Resource": "arn:aws:dynamodb:$REGION:$ACCOUNT_ID:table/mono-repo-*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "sns:Publish"
            ],
            "Resource": "arn:aws:sns:$REGION:$ACCOUNT_ID:mono-repo-*"
        }
    ]
}
EOF
    
    aws iam put-role-policy \
        --role-name $LAMBDA_ROLE_NAME \
        --policy-name MonoRepoLambdaCustomPolicy \
        --policy-document file://lambda-custom-policy.json
    
    rm lambda-trust-policy.json lambda-custom-policy.json
    
    print_success "Lambda execution role created: $LAMBDA_ROLE_NAME"
else
    print_warning "Lambda execution role already exists: $LAMBDA_ROLE_NAME"
fi

# EC2 Instance Role
EC2_ROLE_NAME="mono-repo-ec2-instance-role"
if ! aws iam get-role --role-name $EC2_ROLE_NAME > /dev/null 2>&1; then
    # Create trust policy
    cat > ec2-trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
    
    aws iam create-role \
        --role-name $EC2_ROLE_NAME \
        --assume-role-policy-document file://ec2-trust-policy.json \
        --description "Instance role for mono repo EC2 instances" \
        > /dev/null
    
    # Attach policies
    aws iam attach-role-policy \
        --role-name $EC2_ROLE_NAME \
        --policy-arn arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy
    
    aws iam attach-role-policy \
        --role-name $EC2_ROLE_NAME \
        --policy-arn arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforAWSCodeDeploy
    
    # Create custom policy for EC2 instances
    cat > ec2-custom-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ssm:GetParameter",
                "ssm:GetParameters",
                "ssm:GetParametersByPath"
            ],
            "Resource": "arn:aws:ssm:$REGION:$ACCOUNT_ID:parameter/mono-repo/*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ecr:GetAuthorizationToken",
                "ecr:BatchCheckLayerAvailability",
                "ecr:GetDownloadUrlForLayer",
                "ecr:BatchGetImage"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject"
            ],
            "Resource": "arn:aws:s3:::$BUCKET_NAME/*"
        }
    ]
}
EOF
    
    aws iam put-role-policy \
        --role-name $EC2_ROLE_NAME \
        --policy-name MonoRepoEC2CustomPolicy \
        --policy-document file://ec2-custom-policy.json
    
    # Create instance profile
    aws iam create-instance-profile --instance-profile-name $EC2_ROLE_NAME > /dev/null
    aws iam add-role-to-instance-profile \
        --instance-profile-name $EC2_ROLE_NAME \
        --role-name $EC2_ROLE_NAME
    
    rm ec2-trust-policy.json ec2-custom-policy.json
    
    print_success "EC2 instance role created: $EC2_ROLE_NAME"
else
    print_warning "EC2 instance role already exists: $EC2_ROLE_NAME"
fi

# CodeBuild Service Role
CODEBUILD_ROLE_NAME="mono-repo-codebuild-service-role"
if ! aws iam get-role --role-name $CODEBUILD_ROLE_NAME > /dev/null 2>&1; then
    # Create trust policy
    cat > codebuild-trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codebuild.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
    
    aws iam create-role \
        --role-name $CODEBUILD_ROLE_NAME \
        --assume-role-policy-document file://codebuild-trust-policy.json \
        --description "Service role for mono repo CodeBuild project" \
        > /dev/null
    
    # Create comprehensive policy for CodeBuild
    cat > codebuild-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": "arn:aws:logs:$REGION:$ACCOUNT_ID:*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:GetObjectVersion",
                "s3:PutObject",
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::$BUCKET_NAME",
                "arn:aws:s3:::$BUCKET_NAME/*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "lambda:*"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "iam:PassRole"
            ],
            "Resource": "arn:aws:iam::$ACCOUNT_ID:role/mono-repo-*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ecr:*"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "codedeploy:*"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ssm:GetParameter",
                "ssm:GetParameters",
                "ssm:GetParametersByPath"
            ],
            "Resource": "arn:aws:ssm:$REGION:$ACCOUNT_ID:parameter/mono-repo/*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:CreateTags",
                "ec2:DescribeImages",
                "ec2:DescribeInstances",
                "ec2:DescribeSecurityGroups",
                "ec2:DescribeSubnets",
                "ec2:DescribeVpcs"
            ],
            "Resource": "*"
        }
    ]
}
EOF
    
    aws iam put-role-policy \
        --role-name $CODEBUILD_ROLE_NAME \
        --policy-name MonoRepoCodeBuildPolicy \
        --policy-document file://codebuild-policy.json
    
    rm codebuild-trust-policy.json codebuild-policy.json
    
    print_success "CodeBuild service role created: $CODEBUILD_ROLE_NAME"
else
    print_warning "CodeBuild service role already exists: $CODEBUILD_ROLE_NAME"
fi

echo ""

# 4. Store role ARNs in parameter store
print_status "Storing role ARNs in Parameter Store..."

LAMBDA_ROLE_ARN="arn:aws:iam::$ACCOUNT_ID:role/$LAMBDA_ROLE_NAME"
EC2_ROLE_ARN="arn:aws:iam::$ACCOUNT_ID:role/$EC2_ROLE_NAME"
CODEBUILD_ROLE_ARN="arn:aws:iam::$ACCOUNT_ID:role/$CODEBUILD_ROLE_NAME"

aws ssm put-parameter \
    --name "/mono-repo/lambda-execution-role-arn" \
    --value "$LAMBDA_ROLE_ARN" \
    --type "String" \
    --overwrite \
    --description "Lambda execution role ARN" \
    > /dev/null

aws ssm put-parameter \
    --name "/mono-repo/ec2-instance-role-arn" \
    --value "$EC2_ROLE_ARN" \
    --type "String" \
    --overwrite \
    --description "EC2 instance role ARN" \
    > /dev/null

aws ssm put-parameter \
    --name "/mono-repo/codebuild-service-role-arn" \
    --value "$CODEBUILD_ROLE_ARN" \
    --type "String" \
    --overwrite \
    --description "CodeBuild service role ARN" \
    > /dev/null

aws ssm put-parameter \
    --name "/mono-repo/aws-account-id" \
    --value "$ACCOUNT_ID" \
    --type "String" \
    --overwrite \
    --description "AWS Account ID" \
    > /dev/null

print_success "Role ARNs stored in Parameter Store"

echo ""

# 5. Create ECR repositories for different environments
print_status "Creating ECR repositories..."

for ENV in "${ENVIRONMENTS[@]}"; do
    REPO_NAME="mono-repo-$ENV-ui"
    if ! aws ecr describe-repositories --repository-names $REPO_NAME > /dev/null 2>&1; then
        aws ecr create-repository --repository-name $REPO_NAME > /dev/null
        
        # Set lifecycle policy to manage image retention
        cat > ecr-lifecycle-policy.json << 'EOF'
{
    "rules": [
        {
            "rulePriority": 1,
            "description": "Keep last 10 images",
            "selection": {
                "tagStatus": "tagged",
                "countType": "imageCountMoreThan",
                "countNumber": 10
            },
            "action": {
                "type": "expire"
            }
        },
        {
            "rulePriority": 2,
            "description": "Delete untagged images older than 1 day",
            "selection": {
                "tagStatus": "untagged",
                "countType": "sinceImagePushed",
                "countUnit": "days",
                "countNumber": 1
            },
            "action": {
                "type": "expire"
            }
        }
    ]
}
EOF
        
        aws ecr put-lifecycle-policy \
            --repository-name $REPO_NAME \
            --lifecycle-policy-text file://ecr-lifecycle-policy.json \
            > /dev/null
        
        print_success "ECR repository created: $REPO_NAME"
    else
        print_warning "ECR repository already exists: $REPO_NAME"
    fi
done

rm -f ecr-lifecycle-policy.json

echo ""

# 6. Generate environment file for local testing
print_status "Creating .env file for local testing..."

cat > .env.example << EOF
# Environment variables for local testing
# Copy this to .env and update values as needed

# AWS Configuration
AWS_REGION=$REGION
AWS_ACCOUNT_ID=$ACCOUNT_ID

# Database Configuration
DATABASE_URL=postgresql://user:password@localhost:5432/mono_repo_db

# JWT Configuration (will be loaded from Parameter Store in AWS)
JWT_SECRET_KEY=local-jwt-secret-for-testing

# External API Configuration
API_KEY=local-api-key-for-testing
API_BASE_URL=https://api.example.com

# SMTP Configuration (for notifications)
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=your-email@gmail.com
SMTP_PASSWORD=local-smtp-password-for-testing

# Environment
ENVIRONMENT=development
LOG_LEVEL=DEBUG

# CORS Configuration
CORS_ORIGINS=http://localhost:4200,http://localhost:8080

# Lambda Configuration
LAMBDA_TIMEOUT=60
LAMBDA_MEMORY=256

# EC2 Configuration
INSTANCE_TYPE=t3.micro
MIN_CAPACITY=1
MAX_CAPACITY=3
DESIRED_CAPACITY=1
EOF

print_success "Created .env.example file"

echo ""

# 7. Display summary
print_status "📋 Setup Summary:"
echo ""
echo "🔐 Parameters Created (per environment: prod, staging, dev, hotfix):"
echo "  • /mono-repo/{env}/jwt-secret"
echo "  • /mono-repo/{env}/db-password"
echo "  • /mono-repo/{env}/api-key"
echo "  • /mono-repo/{env}/smtp-password"
echo ""
echo "🏗️ Infrastructure Resources:"
echo "  • S3 Bucket: $BUCKET_NAME"
echo "  • Lambda Execution Role: $LAMBDA_ROLE_NAME"
echo "  • EC2 Instance Role: $EC2_ROLE_NAME"
echo "  • CodeBuild Service Role: $CODEBUILD_ROLE_NAME"
echo ""
echo "📦 ECR Repositories:"
for ENV in "${ENVIRONMENTS[@]}"; do
    echo "  • mono-repo-$ENV-ui"
done
echo ""
echo "🔑 Parameter Store Configuration:"
echo "  • /mono-repo/aws-account-id"
echo "  • /mono-repo/deployment-bucket"
echo "  • /mono-repo/lambda-execution-role-arn"
echo "  • /mono-repo/ec2-instance-role-arn"
echo "  • /mono-repo/codebuild-service-role-arn"
echo ""

print_status "🎯 Next Steps:"
echo "1. Copy .env.example to .env and update values for local testing"
echo "2. Test services locally with: python -m pytest"
echo "3. Run the master pipeline setup: ./setup-aws-master-pipeline.sh"
echo "4. Deploy to AWS: git push origin main"
echo ""

print_success "✅ AWS secrets and IAM resources setup completed!"

# 8. Verify setup
print_status "🔍 Verifying setup..."

echo "Checking parameters..."
aws ssm describe-parameters --filters "Key=Name,Values=/mono-repo" --query 'Parameters[].Name' --output table

echo ""
echo "Checking IAM roles..."
aws iam list-roles --query 'Roles[?starts_with(RoleName, `mono-repo-`)].RoleName' --output table

echo ""
echo "Checking ECR repositories..."
aws ecr describe-repositories --query 'repositories[?starts_with(repositoryName, `mono-repo-`)].repositoryName' --output table

echo ""
echo "Checking S3 bucket..."
aws s3 ls s3://$BUCKET_NAME

echo ""
print_success "🎉 Setup verification completed!"

# 9. Cost estimation
print_status "💰 Estimated AWS Costs:"
echo "Monthly estimates for production environment:"
echo "• Lambda Functions: $25-60 (moderate traffic)"
echo "• EC2 Instances (t3.medium): $25-35 (always-on)"
echo "• Application Load Balancer: $20-25"
echo "• CodeBuild: $15-40 (daily builds)"
echo "• S3 Storage: $5-15 (artifacts and logs)"
echo "• ECR Storage: $5-10 (container images)"
echo "• Parameter Store: $1-5 (parameter requests)"
echo "• Data Transfer: $10-30 (depending on usage)"
echo "• Total Estimated: $106-220/month"
echo ""
print_warning "💡 Tip: Use smaller instances and scale-to-zero for dev/staging to reduce costs"
