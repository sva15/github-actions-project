# AWS Deployment Testing Guide

## 🚀 Complete Step-by-Step Testing Guide for AWS

This guide walks you through testing and deploying your mono repo to Amazon Web Services from scratch.

## 📋 Prerequisites Checklist

### 1. AWS Account Setup
- [ ] **AWS Account**: Create account at [aws.amazon.com](https://aws.amazon.com)
- [ ] **Billing Setup**: Add payment method (required for Lambda, EC2, CodeBuild)
- [ ] **Root Account Security**: Enable MFA on root account
- [ ] **IAM User**: Create IAM user with programmatic access (don't use root)

### 2. Local Development Environment
- [ ] **Git**: Installed and configured
- [ ] **AWS CLI**: Install AWS CLI v2
- [ ] **Docker**: Installed and running
- [ ] **Node.js**: Version 18+ for UI development
- [ ] **Python**: Version 3.9+ for backend services
- [ ] **Zip**: For Lambda deployment packages

### 3. GitHub Repository Setup
- [ ] **GitHub Account**: Personal or organization account
- [ ] **Repository**: Create new repo or use existing
- [ ] **Personal Access Token**: Generate with repo permissions

## 🔧 Step 1: Install and Configure AWS CLI

### Install AWS CLI v2

**Windows:**
```powershell
# Download and install from: https://aws.amazon.com/cli/
# Or use Chocolatey
choco install awscli
```

**macOS:**
```bash
# Using Homebrew
brew install awscli
```

**Linux:**
```bash
# Download and install
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

### Configure AWS CLI
```bash
# Configure AWS credentials (use IAM user, not root)
aws configure

# You'll be prompted for:
# AWS Access Key ID: [Your IAM user access key]
# AWS Secret Access Key: [Your IAM user secret key]
# Default region name: us-east-1
# Default output format: json

# Verify configuration
aws sts get-caller-identity
```

## 🏗️ Step 2: Create IAM User and Policies

### Create IAM User for Deployment
```bash
# Create IAM user for deployment
aws iam create-user --user-name mono-repo-deployer

# Create access key
aws iam create-access-key --user-name mono-repo-deployer

# Save the access key and secret - you'll need them!
```

### Create IAM Policy for Deployment
```bash
# Create comprehensive deployment policy
cat > deployment-policy.json << 'EOF'
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "lambda:*",
                "iam:*",
                "s3:*",
                "codebuild:*",
                "codedeploy:*",
                "ec2:*",
                "ecr:*",
                "ssm:*",
                "logs:*",
                "application-autoscaling:*",
                "elasticloadbalancing:*",
                "autoscaling:*",
                "sns:*"
            ],
            "Resource": "*"
        }
    ]
}
EOF

# Create policy
aws iam create-policy \
    --policy-name MonoRepoDeploymentPolicy \
    --policy-document file://deployment-policy.json

# Attach policy to user
aws iam attach-user-policy \
    --user-name mono-repo-deployer \
    --policy-arn arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/MonoRepoDeploymentPolicy
```

## 🔐 Step 3: Setup Required AWS Resources

### Create S3 Bucket for Artifacts
```bash
# Get your account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Create S3 bucket for deployment artifacts
BUCKET_NAME="mono-repo-deployment-artifacts-$ACCOUNT_ID"
aws s3 mb s3://$BUCKET_NAME --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
    --bucket $BUCKET_NAME \
    --versioning-configuration Status=Enabled

echo "Created S3 bucket: $BUCKET_NAME"
```

### Create Lambda Execution Role
```bash
# Create trust policy for Lambda
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

# Create Lambda execution role
aws iam create-role \
    --role-name mono-repo-lambda-execution-role \
    --assume-role-policy-document file://lambda-trust-policy.json

# Attach basic execution policy
aws iam attach-role-policy \
    --role-name mono-repo-lambda-execution-role \
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

# Get role ARN
LAMBDA_ROLE_ARN=$(aws iam get-role --role-name mono-repo-lambda-execution-role --query 'Role.Arn' --output text)
echo "Lambda Role ARN: $LAMBDA_ROLE_ARN"
```

### Create Systems Manager Parameters
```bash
# Store configuration in Parameter Store
aws ssm put-parameter \
    --name "/mono-repo/aws-account-id" \
    --value "$ACCOUNT_ID" \
    --type "String" \
    --overwrite

aws ssm put-parameter \
    --name "/mono-repo/deployment-bucket" \
    --value "$BUCKET_NAME" \
    --type "String" \
    --overwrite

aws ssm put-parameter \
    --name "/mono-repo/lambda-execution-role-arn" \
    --value "$LAMBDA_ROLE_ARN" \
    --type "String" \
    --overwrite

echo "Parameters stored in Systems Manager"
```

## 📁 Step 4: Prepare Your Repository

### Verify File Structure
```bash
# Your repository should have these files:
tree -I 'node_modules|__pycache__|*.pyc'
```

Expected structure:
```
mono-repo/
├── aws-services-config.yml
├── buildspec-master.yml
├── setup-aws-master-pipeline.sh
├── backend/
│   └── services/
│       ├── user_service/
│       │   ├── main.py
│       │   ├── requirements.txt
│       │   └── test_main.py
│       ├── notification_service/
│       │   ├── main.py
│       │   ├── requirements.txt
│       │   └── test_main.py
│       └── analytics_service/
│           ├── main.py
│           ├── requirements.txt
│           └── test_main.py
└── ui/
    ├── Dockerfile
    ├── package.json
    ├── angular.json
    └── src/
```

## 🧪 Step 5: Local Testing Before Deployment

### Test Backend Services Locally
```bash
# Test user service
cd backend/services/user_service
python -m pytest test_main.py -v

# Test with local Lambda handler
python -c "
import main
event = {'action': 'get_user', 'user_id': 'test-123'}
context = type('Context', (), {'aws_request_id': 'test'})()
result = main.lambda_handler(event, context)
print('Result:', result)
"

# Test notification service  
cd ../notification_service
python -m pytest test_main.py -v

# Test analytics service
cd ../analytics_service
python -m pytest test_main.py -v

cd ../../..
```

### Test Frontend Locally
```bash
# Install dependencies and test
cd ui
npm install
npm run test
npm run build

# Test Docker build
docker build -t test-ui .
docker run -d -p 8080:80 --name test-ui test-ui
curl http://localhost:8080

# Cleanup
docker stop test-ui && docker rm test-ui
cd ..
```

## 🔑 Step 6: Create Secrets and Parameters

### Create Application Secrets
```bash
# Create secrets in Parameter Store (SecureString type)
aws ssm put-parameter \
    --name "/mono-repo/prod/jwt-secret" \
    --value "$(openssl rand -base64 32)" \
    --type "SecureString" \
    --overwrite

aws ssm put-parameter \
    --name "/mono-repo/prod/db-password" \
    --value "$(openssl rand -base64 16)" \
    --type "SecureString" \
    --overwrite

aws ssm put-parameter \
    --name "/mono-repo/prod/api-key" \
    --value "$(openssl rand -hex 20)" \
    --type "SecureString" \
    --overwrite

aws ssm put-parameter \
    --name "/mono-repo/prod/smtp-password" \
    --value "$(openssl rand -base64 16)" \
    --type "SecureString" \
    --overwrite

# Create staging secrets
aws ssm put-parameter \
    --name "/mono-repo/staging/jwt-secret" \
    --value "$(openssl rand -base64 32)" \
    --type "SecureString" \
    --overwrite

aws ssm put-parameter \
    --name "/mono-repo/staging/db-password" \
    --value "$(openssl rand -base64 16)" \
    --type "SecureString" \
    --overwrite

echo "Secrets created in Parameter Store"
```

### Verify Parameters
```bash
# List all parameters
aws ssm describe-parameters --filters "Key=Name,Values=/mono-repo"
```

## 🚀 Step 7: Run the AWS Setup Script

### Make Script Executable and Run
```bash
# Make script executable
chmod +x setup-aws-master-pipeline.sh

# Run the setup script
./setup-aws-master-pipeline.sh
```

**The script will prompt you for:**
- GitHub repository owner/username
- GitHub repository name  
- GitHub personal access token
- Slack webhook URL (optional)

### Verify Setup
```bash
# Check if CodeBuild project was created
aws codebuild batch-get-projects --names mono-repo-master-pipeline

# Check ECR repositories
aws ecr describe-repositories

# Check CodeDeploy applications
aws deploy list-applications
```

## 📤 Step 8: Push Code and Trigger First Build

### Commit and Push Changes
```bash
# Add all files
git add .

# Commit changes
git commit -m "Add AWS deployment pipeline with master buildspec"

# Push to main branch (triggers production deployment)
git push origin main
```

### Monitor the Build
```bash
# Watch build progress
aws codebuild list-builds-for-project --project-name mono-repo-master-pipeline

# Get detailed build logs (replace BUILD_ID with actual ID)
aws codebuild batch-get-builds --ids BUILD_ID
```

## 🔍 Step 9: Verify Deployments

### Check Lambda Functions
```bash
# List deployed functions
aws lambda list-functions --query 'Functions[?starts_with(FunctionName, `prod-`)]'

# Test user service function
aws lambda invoke \
    --function-name prod-user-service \
    --payload '{"action": "get_user", "user_id": "test-123"}' \
    response.json

cat response.json
```

### Check EC2 Deployment
```bash
# Check CodeDeploy deployments
aws deploy list-deployments --application-name mono-repo-prod-app

# Check Auto Scaling Groups
aws autoscaling describe-auto-scaling-groups --query 'AutoScalingGroups[?starts_with(AutoScalingGroupName, `mono-repo-prod`)]'

# Check Load Balancers
aws elbv2 describe-load-balancers --query 'LoadBalancers[?starts_with(LoadBalancerName, `mono-repo-prod`)]'
```

### Test Complete Flow
```bash
# Test Lambda functions directly
echo "Testing User Service..."
aws lambda invoke \
    --function-name prod-user-service \
    --payload '{"action": "create_user", "user_data": {"name": "Test User", "email": "test@example.com"}}' \
    user_response.json

echo "Testing Notification Service..."
aws lambda invoke \
    --function-name prod-notification-service \
    --payload '{"action": "send_notification", "notification_data": {"type": "email", "recipient": "test@example.com", "message": "Test notification"}}' \
    notification_response.json

echo "Testing Analytics Service..."
aws lambda invoke \
    --function-name prod-analytics-service \
    --payload '{"action": "track_event", "event_data": {"event_type": "test", "user_id": "test-123"}}' \
    analytics_response.json

# Check responses
echo "User Service Response:"
cat user_response.json
echo -e "\nNotification Service Response:"
cat notification_response.json
echo -e "\nAnalytics Service Response:"
cat analytics_response.json
```

## 🧪 Step 10: Test Different Environments

### Test Staging Environment
```bash
# Create and push to develop branch
git checkout -b develop
git push origin develop

# Monitor staging deployment
aws codebuild list-builds-for-project --project-name mono-repo-master-pipeline --sort-order DESCENDING
```

### Test Development Environment  
```bash
# Create and push to feature branch
git checkout -b feature/test-aws-deployment
git push origin feature/test-aws-deployment

# Check dev functions
aws lambda list-functions --query 'Functions[?starts_with(FunctionName, `dev-`)]'
```

## 🔧 Step 11: Troubleshooting Common Issues

### Build Failures
```bash
# Get build details
BUILD_ID=$(aws codebuild list-builds-for-project --project-name mono-repo-master-pipeline --sort-order DESCENDING --query 'ids[0]' --output text)
aws codebuild batch-get-builds --ids $BUILD_ID

# Common issues and fixes:
# 1. IAM permissions: Check CodeBuild service role
# 2. S3 access: Verify bucket permissions
# 3. Parameter not found: Check Systems Manager parameters
# 4. ECR access: Verify ECR permissions
```

### Lambda Deployment Issues
```bash
# Check function status
aws lambda get-function --function-name prod-user-service

# View function logs
aws logs describe-log-groups --log-group-name-prefix /aws/lambda/prod-user-service
aws logs get-log-events --log-group-name /aws/lambda/prod-user-service --log-stream-name LATEST

# Common issues:
# 1. Runtime error: Check requirements.txt and dependencies
# 2. Permission denied: Check Lambda execution role
# 3. Timeout: Increase timeout in aws-services-config.yml
# 4. Memory limit: Increase memory allocation
```

### EC2 Deployment Issues
```bash
# Check CodeDeploy deployment status
DEPLOYMENT_ID=$(aws deploy list-deployments --application-name mono-repo-prod-app --query 'deployments[0]' --output text)
aws deploy get-deployment --deployment-id $DEPLOYMENT_ID

# Check Auto Scaling Group
aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names mono-repo-prod-asg

# Common issues:
# 1. Instance launch failure: Check AMI and security groups
# 2. CodeDeploy agent: Ensure agent is installed on instances
# 3. Application not starting: Check Docker and container logs
# 4. Health check failure: Verify application health endpoint
```

### ECR Issues
```bash
# Login to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com

# Check repository
aws ecr describe-repositories --repository-names mono-repo-prod-ui

# List images
aws ecr list-images --repository-name mono-repo-prod-ui
```

## 📊 Step 12: Performance Testing

### Load Testing Lambda Functions
```bash
# Install artillery for load testing
npm install -g artillery

# Create load test configuration
cat > lambda-load-test.yml << 'EOF'
config:
  target: 'https://lambda-url-here'
  phases:
    - duration: 60
      arrivalRate: 10
scenarios:
  - name: "Test Lambda Function"
    requests:
      - post:
          url: "/"
          json:
            action: "get_user"
            user_id: "test-123"
EOF

# Run load test
artillery run lambda-load-test.yml
```

### Monitor Resources
```bash
# Check Lambda metrics
aws cloudwatch get-metric-statistics \
    --namespace AWS/Lambda \
    --metric-name Duration \
    --dimensions Name=FunctionName,Value=prod-user-service \
    --statistics Average \
    --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
    --period 300

# Check EC2 metrics
aws cloudwatch get-metric-statistics \
    --namespace AWS/EC2 \
    --metric-name CPUUtilization \
    --dimensions Name=AutoScalingGroupName,Value=mono-repo-prod-asg \
    --statistics Average \
    --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
    --period 300
```

## 🔄 Step 13: Cleanup (When Done Testing)

### Delete Resources
```bash
# Delete Lambda functions
aws lambda delete-function --function-name prod-user-service
aws lambda delete-function --function-name prod-notification-service
aws lambda delete-function --function-name prod-analytics-service

# Delete CodeBuild project
aws codebuild delete-project --name mono-repo-master-pipeline

# Delete CodeDeploy applications
aws deploy delete-application --application-name mono-repo-prod-app

# Delete ECR repositories
aws ecr delete-repository --repository-name mono-repo-prod-ui --force

# Delete S3 bucket (remove all objects first)
aws s3 rm s3://$BUCKET_NAME --recursive
aws s3 rb s3://$BUCKET_NAME

# Delete IAM resources
aws iam detach-role-policy --role-name mono-repo-lambda-execution-role --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
aws iam delete-role --role-name mono-repo-lambda-execution-role

# Delete parameters
aws ssm delete-parameter --name "/mono-repo/aws-account-id"
aws ssm delete-parameter --name "/mono-repo/deployment-bucket"
aws ssm delete-parameter --name "/mono-repo/lambda-execution-role-arn"
```

## ✅ Success Checklist

After completing all steps, you should have:

- [ ] ✅ **Lambda Functions deployed** and responding to invocations
- [ ] ✅ **EC2 instances running** with Docker containers
- [ ] ✅ **CodeBuild pipeline working** for automatic deployments
- [ ] ✅ **Environment-based deployments** (main→prod, develop→staging, feature→dev)
- [ ] ✅ **Load balancer configured** for UI access
- [ ] ✅ **Monitoring and logging** working in CloudWatch
- [ ] ✅ **All services communicating** properly
- [ ] ✅ **Performance acceptable** under load testing

## 🎯 Expected Results

### Successful Deployment Should Show:

1. **Lambda Functions**:
   ```
   prod-user-service        Active    https://lambda-url.lambda-url.us-east-1.on.aws/
   prod-notification-service Active    https://lambda-url.lambda-url.us-east-1.on.aws/
   prod-analytics-service   Active    https://lambda-url.lambda-url.us-east-1.on.aws/
   ```

2. **EC2 Deployment**:
   ```
   Auto Scaling Group: mono-repo-prod-asg    Desired: 2, Running: 2
   Load Balancer: mono-repo-prod-alb         Active
   Target Group: mono-repo-prod-tg           Healthy: 2
   ```

3. **CodeBuild Project**:
   ```
   mono-repo-master-pipeline    Enabled    GitHub Webhook
   ```

## 📞 Getting Help

### AWS Console Links
- **CodeBuild**: https://console.aws.amazon.com/codesuite/codebuild/projects
- **Lambda**: https://console.aws.amazon.com/lambda/home
- **EC2**: https://console.aws.amazon.com/ec2/home
- **CodeDeploy**: https://console.aws.amazon.com/codesuite/codedeploy/applications
- **CloudWatch**: https://console.aws.amazon.com/cloudwatch/home

### Useful Commands
```bash
# Quick health check
aws lambda list-functions --query 'Functions[?starts_with(FunctionName, `prod-`)].[FunctionName,Runtime,LastModified]' --output table

# View recent builds
aws codebuild list-builds-for-project --project-name mono-repo-master-pipeline --sort-order DESCENDING

# Check deployment status
aws deploy list-deployments --application-name mono-repo-prod-app --query 'deployments[0:5]' --output table

# Monitor costs
aws ce get-cost-and-usage \
    --time-period Start=$(date -d '7 days ago' +%Y-%m-%d),End=$(date +%Y-%m-%d) \
    --granularity DAILY \
    --metrics BlendedCost \
    --group-by Type=DIMENSION,Key=SERVICE
```

---

## 🎉 Congratulations!

If you've completed all steps successfully, you now have a fully functional AWS deployment pipeline that:
- ✅ Automatically detects changed services
- ✅ Deploys backend functions to Lambda
- ✅ Deploys frontend to EC2 with Docker
- ✅ Supports multiple environments
- ✅ Includes monitoring and logging
- ✅ Scales automatically based on demand

**Your AWS deployment is production-ready!** 🚀
