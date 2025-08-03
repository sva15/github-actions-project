# Cloud Deployment Setup Guide

This guide provides detailed instructions for setting up the deployment infrastructure for both GCP and AWS.

## 📋 Prerequisites

### GCP Setup
- Google Cloud Platform account with billing enabled
- `gcloud` CLI installed and configured
- Docker installed locally
- Required APIs enabled:
  - Cloud Build API
  - Cloud Functions API
  - Cloud Run API
  - Container Registry API

### AWS Setup
- AWS account with appropriate permissions
- AWS CLI installed and configured
- CodeBuild and CodeDeploy services access
- EC2 instances with CodeDeploy agent installed

## 🔧 GCP Deployment Setup

### 1. Enable Required APIs
```bash
gcloud services enable cloudbuild.googleapis.com
gcloud services enable cloudfunctions.googleapis.com
gcloud services enable run.googleapis.com
gcloud services enable containerregistry.googleapis.com
```

### 2. Create Cloud Build Triggers

#### Backend Services Triggers
```bash
# User Service Trigger
gcloud builds triggers create github \
  --repo-name=your-repo-name \
  --repo-owner=your-github-username \
  --branch-pattern="^main$|^develop$" \
  --build-config=backend/services/user_service/cloudbuild.yml \
  --included-files="backend/services/user_service/**" \
  --name=user-service-trigger

# Notification Service Trigger
gcloud builds triggers create github \
  --repo-name=your-repo-name \
  --repo-owner=your-github-username \
  --branch-pattern="^main$|^develop$" \
  --build-config=backend/services/notification_service/cloudbuild.yml \
  --included-files="backend/services/notification_service/**" \
  --name=notification-service-trigger

# Analytics Service Trigger
gcloud builds triggers create github \
  --repo-name=your-repo-name \
  --repo-owner=your-github-username \
  --branch-pattern="^main$|^develop$" \
  --build-config=backend/services/analytics_service/cloudbuild.yml \
  --included-files="backend/services/analytics_service/**" \
  --name=analytics-service-trigger
```

#### Frontend Trigger
```bash
# UI Service Trigger
gcloud builds triggers create github \
  --repo-name=your-repo-name \
  --repo-owner=your-github-username \
  --branch-pattern="^main$|^develop$" \
  --build-config=ui/cloudbuild.yml \
  --included-files="ui/**" \
  --name=ui-service-trigger
```

### 3. Set up IAM Permissions
```bash
# Get the Cloud Build service account
PROJECT_ID=$(gcloud config get-value project)
CLOUD_BUILD_SA="${PROJECT_ID}@cloudbuild.gserviceaccount.com"

# Grant necessary permissions
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${CLOUD_BUILD_SA}" \
  --role="roles/cloudfunctions.developer"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${CLOUD_BUILD_SA}" \
  --role="roles/run.developer"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${CLOUD_BUILD_SA}" \
  --role="roles/iam.serviceAccountUser"
```

## 🔧 AWS Deployment Setup

### 1. Create S3 Bucket for Deployments
```bash
aws s3 mb s3://your-deployment-bucket-name
aws s3api put-bucket-versioning \
  --bucket your-deployment-bucket-name \
  --versioning-configuration Status=Enabled
```

### 2. Create IAM Roles

#### Lambda Execution Role
```bash
# Create trust policy
cat > lambda-trust-policy.json << EOF
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

# Create the role
aws iam create-role \
  --role-name mono-repo-lambda-execution-role \
  --assume-role-policy-document file://lambda-trust-policy.json

# Attach policies
aws iam attach-role-policy \
  --role-name mono-repo-lambda-execution-role \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
```

#### CodeBuild Service Role
```bash
# Create trust policy for CodeBuild
cat > codebuild-trust-policy.json << EOF
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

# Create the role
aws iam create-role \
  --role-name mono-repo-codebuild-role \
  --assume-role-policy-document file://codebuild-trust-policy.json

# Create and attach custom policy
cat > codebuild-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "s3:GetObject",
        "s3:PutObject",
        "lambda:UpdateFunctionCode",
        "lambda:CreateFunction",
        "lambda:UpdateFunctionConfiguration",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:GetAuthorizationToken"
      ],
      "Resource": "*"
    }
  ]
}
EOF

aws iam put-role-policy \
  --role-name mono-repo-codebuild-role \
  --policy-name mono-repo-codebuild-policy \
  --policy-document file://codebuild-policy.json
```

### 3. Create ECR Repository
```bash
aws ecr create-repository --repository-name mono-repo-ui
```

### 4. Set up Parameter Store Values
```bash
# Store configuration in Parameter Store
aws ssm put-parameter \
  --name "/mono-repo/deployment-bucket" \
  --value "your-deployment-bucket-name" \
  --type "String"

aws ssm put-parameter \
  --name "/mono-repo/lambda-execution-role-arn" \
  --value "arn:aws:iam::YOUR-ACCOUNT-ID:role/mono-repo-lambda-execution-role" \
  --type "String"

aws ssm put-parameter \
  --name "/mono-repo/environment" \
  --value "production" \
  --type "String"

aws ssm put-parameter \
  --name "/mono-repo/aws-account-id" \
  --value "YOUR-ACCOUNT-ID" \
  --type "String"
```

### 5. Create CodeBuild Projects

#### Backend Services
```bash
# User Service CodeBuild Project
cat > user-service-codebuild.json << EOF
{
  "name": "mono-repo-user-service",
  "source": {
    "type": "GITHUB",
    "location": "https://github.com/your-username/your-repo.git",
    "buildspec": "backend/services/user_service/buildspec.yml"
  },
  "artifacts": {
    "type": "S3",
    "location": "your-deployment-bucket-name/artifacts"
  },
  "environment": {
    "type": "LINUX_CONTAINER",
    "image": "aws/codebuild/standard:5.0",
    "computeType": "BUILD_GENERAL1_MEDIUM"
  },
  "serviceRole": "arn:aws:iam::YOUR-ACCOUNT-ID:role/mono-repo-codebuild-role"
}
EOF

aws codebuild create-project --cli-input-json file://user-service-codebuild.json

# Repeat for notification-service and analytics-service...
```

#### Frontend CodeBuild Project
```bash
cat > ui-codebuild.json << EOF
{
  "name": "mono-repo-ui",
  "source": {
    "type": "GITHUB",
    "location": "https://github.com/your-username/your-repo.git",
    "buildspec": "ui/buildspec.yml"
  },
  "artifacts": {
    "type": "S3",
    "location": "your-deployment-bucket-name/ui-deployments"
  },
  "environment": {
    "type": "LINUX_CONTAINER",
    "image": "aws/codebuild/standard:5.0",
    "computeType": "BUILD_GENERAL1_MEDIUM",
    "privilegedMode": true
  },
  "serviceRole": "arn:aws:iam::YOUR-ACCOUNT-ID:role/mono-repo-codebuild-role"
}
EOF

aws codebuild create-project --cli-input-json file://ui-codebuild.json
```

### 6. Set up CodeDeploy for UI

#### Create CodeDeploy Application
```bash
aws deploy create-application \
  --application-name mono-repo-ui \
  --compute-platform Server
```

#### Create Deployment Group
```bash
# First, create a service role for CodeDeploy
cat > codedeploy-trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codedeploy.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

aws iam create-role \
  --role-name mono-repo-codedeploy-role \
  --assume-role-policy-document file://codedeploy-trust-policy.json

aws iam attach-role-policy \
  --role-name mono-repo-codedeploy-role \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole

# Create deployment group
aws deploy create-deployment-group \
  --application-name mono-repo-ui \
  --deployment-group-name production-deployment-group \
  --service-role-arn arn:aws:iam::YOUR-ACCOUNT-ID:role/mono-repo-codedeploy-role \
  --ec2-tag-filters Key=Environment,Value=production,Type=KEY_AND_VALUE
```

## 🖥️ EC2 Setup for CodeDeploy

### 1. Launch EC2 Instance
```bash
# Launch EC2 instance with appropriate security groups and IAM role
aws ec2 run-instances \
  --image-id ami-0abcdef1234567890 \
  --count 1 \
  --instance-type t3.medium \
  --key-name your-key-pair \
  --security-group-ids sg-12345678 \
  --iam-instance-profile Name=mono-repo-ec2-role \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=mono-repo-ui-server},{Key=Environment,Value=production}]'
```

### 2. Install CodeDeploy Agent on EC2
```bash
# SSH into your EC2 instance and run:
sudo yum update -y
sudo yum install -y ruby wget

# Download and install CodeDeploy agent
cd /home/ec2-user
wget https://aws-codedeploy-us-east-1.s3.us-east-1.amazonaws.com/latest/install
chmod +x ./install
sudo ./install auto

# Start the CodeDeploy agent
sudo service codedeploy-agent start
sudo chkconfig codedeploy-agent on
```

## 🔐 Security Configuration

### Environment Variables
Create `.env` files for each environment:

#### GCP Environment Variables
```bash
# Set in Cloud Build substitutions
_REGION=us-central1
_ENVIRONMENT=production
```

#### AWS Environment Variables
```bash
# Set in Parameter Store
/mono-repo/deployment-bucket
/mono-repo/lambda-execution-role-arn
/mono-repo/environment
/mono-repo/aws-account-id
```

## 🚀 Deployment Commands

### Manual Deployment

#### GCP
```bash
# Trigger builds manually
gcloud builds submit --config=backend/services/user_service/cloudbuild.yml backend/services/user_service/
gcloud builds submit --config=ui/cloudbuild.yml ui/
```

#### AWS
```bash
# Start CodeBuild projects
aws codebuild start-build --project-name mono-repo-user-service
aws codebuild start-build --project-name mono-repo-ui
```

## 📊 Monitoring and Logging

### GCP Monitoring
- Cloud Logging: Automatic log collection
- Cloud Monitoring: Set up alerts and dashboards
- Error Reporting: Automatic error tracking

### AWS Monitoring
- CloudWatch Logs: Configure log groups
- CloudWatch Metrics: Custom metrics and alarms
- X-Ray: Distributed tracing (optional)

## 🔧 Troubleshooting

### Common Issues

#### GCP
1. **Build fails with permission errors**: Check IAM roles
2. **Function deployment timeout**: Increase timeout in cloudbuild.yml
3. **Container registry access denied**: Verify Docker authentication

#### AWS
1. **CodeBuild fails**: Check service role permissions
2. **Lambda deployment fails**: Verify execution role
3. **CodeDeploy fails**: Check EC2 instance tags and agent status

### Debug Commands

#### GCP
```bash
# Check build logs
gcloud builds log BUILD_ID

# Check function logs
gcloud functions logs read FUNCTION_NAME

# Check Cloud Run logs
gcloud logging read "resource.type=cloud_run_revision"
```

#### AWS
```bash
# Check CodeBuild logs
aws logs describe-log-streams --log-group-name /aws/codebuild/PROJECT_NAME

# Check Lambda logs
aws logs describe-log-streams --log-group-name /aws/lambda/FUNCTION_NAME

# Check CodeDeploy status
aws deploy get-deployment --deployment-id DEPLOYMENT_ID
```

This setup provides a robust, scalable deployment infrastructure for your CloudSync Platform across both GCP and AWS platforms.
