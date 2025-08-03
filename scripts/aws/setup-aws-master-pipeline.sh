#!/bin/bash

# Setup AWS Master CodeBuild Pipeline
# This script creates AWS resources for the master deployment pipeline

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

# Configuration variables
PROJECT_NAME="mono-repo"
AWS_REGION="us-east-1"
CODEBUILD_PROJECT_NAME="mono-repo-master-pipeline"

print_status "🚀 Setting up AWS Master Deployment Pipeline"
echo "Project: $PROJECT_NAME"
echo "Region: $AWS_REGION"
echo "CodeBuild Project: $CODEBUILD_PROJECT_NAME"
echo ""

# Check if AWS CLI is installed and configured
if ! command -v aws &> /dev/null; then
    print_error "AWS CLI is not installed. Please install it first."
    exit 1
fi

# Check AWS credentials
if ! aws sts get-caller-identity > /dev/null 2>&1; then
    print_error "AWS credentials not configured. Please run 'aws configure' first."
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
print_status "AWS Account ID: $ACCOUNT_ID"

# Prompt for GitHub repository details
echo ""
print_status "📋 GitHub Repository Configuration"
read -p "Enter GitHub repository owner/username: " GITHUB_OWNER
read -p "Enter GitHub repository name: " GITHUB_REPO
read -p "Enter GitHub personal access token (for webhook): " GITHUB_TOKEN

# Prompt for optional Slack webhook
echo ""
read -p "Enter Slack webhook URL (optional, press Enter to skip): " SLACK_WEBHOOK_URL

print_status "🔧 Creating AWS resources..."

# 1. Create S3 bucket for deployment artifacts
DEPLOYMENT_BUCKET="$PROJECT_NAME-deployment-artifacts-$ACCOUNT_ID"
print_status "Creating S3 bucket: $DEPLOYMENT_BUCKET"

if aws s3 ls "s3://$DEPLOYMENT_BUCKET" 2>&1 | grep -q 'NoSuchBucket'; then
    aws s3 mb s3://$DEPLOYMENT_BUCKET --region $AWS_REGION
    aws s3api put-bucket-versioning --bucket $DEPLOYMENT_BUCKET --versioning-configuration Status=Enabled
    print_success "S3 bucket created: $DEPLOYMENT_BUCKET"
else
    print_warning "S3 bucket already exists: $DEPLOYMENT_BUCKET"
fi

# 2. Create IAM role for CodeBuild
CODEBUILD_ROLE_NAME="$PROJECT_NAME-codebuild-service-role"
print_status "Creating CodeBuild service role: $CODEBUILD_ROLE_NAME"

# Create trust policy
cat > /tmp/codebuild-trust-policy.json << EOF
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

# Create role if it doesn't exist
if ! aws iam get-role --role-name $CODEBUILD_ROLE_NAME > /dev/null 2>&1; then
    aws iam create-role --role-name $CODEBUILD_ROLE_NAME --assume-role-policy-document file:///tmp/codebuild-trust-policy.json
    print_success "CodeBuild role created: $CODEBUILD_ROLE_NAME"
else
    print_warning "CodeBuild role already exists: $CODEBUILD_ROLE_NAME"
fi

# Create and attach policy for CodeBuild
cat > /tmp/codebuild-policy.json << EOF
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
      "Resource": "arn:aws:logs:$AWS_REGION:$ACCOUNT_ID:*"
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
        "arn:aws:s3:::$DEPLOYMENT_BUCKET",
        "arn:aws:s3:::$DEPLOYMENT_BUCKET/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "lambda:*",
        "iam:PassRole",
        "ecr:*",
        "codedeploy:*",
        "ssm:GetParameter",
        "ssm:GetParameters"
      ],
      "Resource": "*"
    }
  ]
}
EOF

CODEBUILD_POLICY_NAME="$PROJECT_NAME-codebuild-policy"
aws iam put-role-policy --role-name $CODEBUILD_ROLE_NAME --policy-name $CODEBUILD_POLICY_NAME --policy-document file:///tmp/codebuild-policy.json

# 3. Create IAM role for Lambda execution
LAMBDA_ROLE_NAME="$PROJECT_NAME-lambda-execution-role"
print_status "Creating Lambda execution role: $LAMBDA_ROLE_NAME"

cat > /tmp/lambda-trust-policy.json << EOF
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

if ! aws iam get-role --role-name $LAMBDA_ROLE_NAME > /dev/null 2>&1; then
    aws iam create-role --role-name $LAMBDA_ROLE_NAME --assume-role-policy-document file:///tmp/lambda-trust-policy.json
    aws iam attach-role-policy --role-name $LAMBDA_ROLE_NAME --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
    print_success "Lambda execution role created: $LAMBDA_ROLE_NAME"
else
    print_warning "Lambda execution role already exists: $LAMBDA_ROLE_NAME"
fi

LAMBDA_ROLE_ARN="arn:aws:iam::$ACCOUNT_ID:role/$LAMBDA_ROLE_NAME"

# 4. Create Systems Manager parameters
print_status "Creating Systems Manager parameters..."

aws ssm put-parameter --name "/mono-repo/aws-account-id" --value "$ACCOUNT_ID" --type "String" --overwrite > /dev/null
aws ssm put-parameter --name "/mono-repo/deployment-bucket" --value "$DEPLOYMENT_BUCKET" --type "String" --overwrite > /dev/null
aws ssm put-parameter --name "/mono-repo/lambda-execution-role-arn" --value "$LAMBDA_ROLE_ARN" --type "String" --overwrite > /dev/null

if [ ! -z "$SLACK_WEBHOOK_URL" ]; then
    aws ssm put-parameter --name "/mono-repo/slack/webhook-url" --value "$SLACK_WEBHOOK_URL" --type "SecureString" --overwrite > /dev/null
    print_success "Slack webhook URL stored in Parameter Store"
fi

print_success "Systems Manager parameters created"

# 5. Create CodeBuild project
print_status "Creating CodeBuild project: $CODEBUILD_PROJECT_NAME"

cat > /tmp/codebuild-project.json << EOF
{
  "name": "$CODEBUILD_PROJECT_NAME",
  "description": "Master pipeline for mono-repo deployment to AWS Lambda and EC2",
  "source": {
    "type": "GITHUB",
    "location": "https://github.com/$GITHUB_OWNER/$GITHUB_REPO.git",
    "gitCloneDepth": 1,
    "buildspec": "buildspec-master.yml",
    "auth": {
      "type": "OAUTH",
      "resource": "$GITHUB_TOKEN"
    }
  },
  "artifacts": {
    "type": "S3",
    "location": "$DEPLOYMENT_BUCKET/build-artifacts",
    "packaging": "ZIP"
  },
  "environment": {
    "type": "LINUX_CONTAINER",
    "image": "aws/codebuild/standard:5.0",
    "computeType": "BUILD_GENERAL1_MEDIUM",
    "privilegedMode": true
  },
  "serviceRole": "arn:aws:iam::$ACCOUNT_ID:role/$CODEBUILD_ROLE_NAME",
  "timeoutInMinutes": 60,
  "badgeEnabled": true,
  "logsConfig": {
    "cloudWatchLogs": {
      "status": "ENABLED",
      "groupName": "/aws/codebuild/$CODEBUILD_PROJECT_NAME"
    }
  }
}
EOF

if aws codebuild batch-get-projects --names $CODEBUILD_PROJECT_NAME > /dev/null 2>&1; then
    print_warning "CodeBuild project already exists, updating..."
    aws codebuild update-project --cli-input-json file:///tmp/codebuild-project.json > /dev/null
else
    aws codebuild create-project --cli-input-json file:///tmp/codebuild-project.json > /dev/null
fi

print_success "CodeBuild project created: $CODEBUILD_PROJECT_NAME"

# 6. Create webhook for automatic builds
print_status "Creating GitHub webhook..."

WEBHOOK_PAYLOAD=$(cat << EOF
{
  "filterGroups": [
    [
      {
        "type": "EVENT",
        "pattern": "PUSH"
      },
      {
        "type": "HEAD_REF",
        "pattern": "^refs/heads/(main|develop|feature/.*)$"
      }
    ]
  ]
}
EOF
)

aws codebuild create-webhook --project-name $CODEBUILD_PROJECT_NAME --cli-input-json "$WEBHOOK_PAYLOAD" > /dev/null 2>&1 || print_warning "Webhook may already exist"

print_success "GitHub webhook configured"

# 7. Create ECR repositories for UI images
print_status "Creating ECR repositories..."

ENVIRONMENTS=("prod" "staging" "dev" "hotfix")
for ENV in "${ENVIRONMENTS[@]}"; do
    REPO_NAME="mono-repo-$ENV-ui"
    if ! aws ecr describe-repositories --repository-names $REPO_NAME > /dev/null 2>&1; then
        aws ecr create-repository --repository-name $REPO_NAME > /dev/null
        print_success "ECR repository created: $REPO_NAME"
    else
        print_warning "ECR repository already exists: $REPO_NAME"
    fi
done

# 8. Create CodeDeploy applications and deployment groups
print_status "Creating CodeDeploy applications..."

for ENV in "${ENVIRONMENTS[@]}"; do
    APP_NAME="mono-repo-$ENV-app"
    DEPLOYMENT_GROUP="mono-repo-$ENV-deployment-group"
    
    # Create application
    if ! aws deploy get-application --application-name $APP_NAME > /dev/null 2>&1; then
        aws deploy create-application --application-name $APP_NAME --compute-platform Server > /dev/null
        print_success "CodeDeploy application created: $APP_NAME"
    else
        print_warning "CodeDeploy application already exists: $APP_NAME"
    fi
done

# Cleanup temporary files
rm -f /tmp/codebuild-*.json /tmp/lambda-*.json

print_success "🎉 AWS Master Pipeline setup completed successfully!"
echo ""
print_status "📋 Setup Summary:"
echo "• CodeBuild Project: $CODEBUILD_PROJECT_NAME"
echo "• S3 Artifacts Bucket: $DEPLOYMENT_BUCKET"
echo "• Lambda Execution Role: $LAMBDA_ROLE_NAME"
echo "• CodeBuild Service Role: $CODEBUILD_ROLE_NAME"
echo "• GitHub Repository: $GITHUB_OWNER/$GITHUB_REPO"
echo ""
print_status "🚀 Next Steps:"
echo "1. Push your code to trigger the first build"
echo "2. Monitor builds in AWS CodeBuild console"
echo "3. Check deployed Lambda functions in AWS Lambda console"
echo "4. Verify EC2 deployments in AWS CodeDeploy console"
echo ""
print_status "📊 Useful Commands:"
echo "• View builds: aws codebuild list-builds-for-project --project-name $CODEBUILD_PROJECT_NAME"
echo "• View Lambda functions: aws lambda list-functions"
echo "• View ECR repositories: aws ecr describe-repositories"
echo ""
print_success "✅ AWS deployment pipeline is ready!"
