# AWS Deployment Setup Guide

## 🚀 Overview

This guide provides comprehensive instructions for setting up the AWS deployment pipeline for your mono repo project. The pipeline automatically deploys:

- **Backend Services**: Python functions to AWS Lambda
- **Frontend Application**: Angular UI to EC2 instances via Docker containers

## 📋 Prerequisites

### Required Tools
- AWS CLI v2 installed and configured
- Docker installed and running
- Git repository with your mono repo code
- GitHub personal access token (for webhooks)

### AWS Account Requirements
- AWS account with appropriate permissions
- IAM permissions for:
  - Lambda functions
  - EC2 instances
  - CodeBuild projects
  - CodeDeploy applications
  - ECR repositories
  - S3 buckets
  - Systems Manager parameters

## 🔧 Quick Setup

### 1. Run the Setup Script

```bash
chmod +x setup-aws-master-pipeline.sh
./setup-aws-master-pipeline.sh
```

The script will prompt you for:
- GitHub repository owner/username
- GitHub repository name
- GitHub personal access token
- Slack webhook URL (optional)

### 2. Verify AWS Resources

After running the setup script, verify these resources were created:

```bash
# Check CodeBuild project
aws codebuild batch-get-projects --names mono-repo-master-pipeline

# Check S3 bucket
aws s3 ls mono-repo-deployment-artifacts-YOUR-ACCOUNT-ID

# Check IAM roles
aws iam get-role --role-name mono-repo-codebuild-service-role
aws iam get-role --role-name mono-repo-lambda-execution-role

# Check ECR repositories
aws ecr describe-repositories --repository-names mono-repo-prod-ui
```

## 📁 File Structure

Your repository should have this structure:

```
mono-repo/
├── aws-services-config.yml          # AWS service definitions
├── buildspec-master.yml             # CodeBuild pipeline
├── setup-aws-master-pipeline.sh     # Setup script
├── backend/
│   └── services/
│       ├── user_service/
│       │   ├── main.py
│       │   └── requirements.txt
│       ├── notification_service/
│       │   ├── main.py
│       │   └── requirements.txt
│       └── analytics_service/
│           ├── main.py
│           └── requirements.txt
└── ui/
    ├── Dockerfile
    ├── package.json
    └── src/
```

## 🔄 Deployment Process

### Automatic Deployment Triggers

The pipeline automatically triggers on:
- **Push to `main`** → Deploys to `prod` environment
- **Push to `develop`** → Deploys to `staging` environment
- **Push to `feature/*`** → Deploys to `dev` environment
- **Push to `hotfix/*`** → Deploys to `hotfix` environment

### Service Detection

The pipeline automatically detects which services changed by:
1. Comparing git diff with service paths in `aws-services-config.yml`
2. Only deploying services that have actual code changes
3. Skipping deployment if no services changed

### Backend Services (Lambda)

For each changed backend service:
1. **Package Creation**: Creates deployment ZIP with dependencies
2. **S3 Upload**: Uploads package to S3 artifacts bucket
3. **Lambda Deployment**: Creates/updates Lambda function
4. **Configuration**: Sets memory, timeout, environment variables
5. **Function URL**: Creates public HTTPS endpoint

### Frontend Service (EC2)

For the UI service:
1. **Docker Build**: Builds container image from Dockerfile
2. **ECR Push**: Pushes image to Elastic Container Registry
3. **CodeDeploy Package**: Creates deployment package with scripts
4. **EC2 Deployment**: Deploys via CodeDeploy to Auto Scaling Group

## 🏗️ AWS Resources Created

### Core Infrastructure

| Resource Type | Name Pattern | Purpose |
|---------------|--------------|---------|
| CodeBuild Project | `mono-repo-master-pipeline` | Main deployment pipeline |
| S3 Bucket | `mono-repo-deployment-artifacts-{account-id}` | Build artifacts storage |
| IAM Role | `mono-repo-codebuild-service-role` | CodeBuild execution permissions |
| IAM Role | `mono-repo-lambda-execution-role` | Lambda function permissions |

### Lambda Functions

| Environment | Function Name | Runtime | Memory | Timeout |
|-------------|---------------|---------|---------|---------|
| prod | `prod-user-service` | python3.9 | 512 MB | 90s |
| prod | `prod-notification-service` | python3.9 | 1024 MB | 180s |
| prod | `prod-analytics-service` | python3.9 | 2048 MB | 300s |
| staging | `staging-user-service` | python3.9 | 256 MB | 60s |
| staging | `staging-notification-service` | python3.9 | 512 MB | 120s |
| staging | `staging-analytics-service` | python3.9 | 1024 MB | 240s |

### ECR Repositories

| Repository Name | Purpose |
|-----------------|---------|
| `mono-repo-prod-ui` | Production UI images |
| `mono-repo-staging-ui` | Staging UI images |
| `mono-repo-dev-ui` | Development UI images |
| `mono-repo-hotfix-ui` | Hotfix UI images |

### CodeDeploy Applications

| Application Name | Deployment Group | Target |
|------------------|------------------|---------|
| `mono-repo-prod-app` | `mono-repo-prod-deployment-group` | Production EC2 instances |
| `mono-repo-staging-app` | `mono-repo-staging-deployment-group` | Staging EC2 instances |
| `mono-repo-dev-app` | `mono-repo-dev-deployment-group` | Development EC2 instances |

## 🔐 Security Configuration

### IAM Roles and Policies

#### CodeBuild Service Role
```json
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
        "lambda:*",
        "ecr:*",
        "codedeploy:*",
        "ssm:GetParameter"
      ],
      "Resource": "*"
    }
  ]
}
```

#### Lambda Execution Role
- `AWSLambdaBasicExecutionRole` (managed policy)
- Custom policies for service-specific permissions

### Systems Manager Parameters

| Parameter Name | Type | Purpose |
|----------------|------|---------|
| `/mono-repo/aws-account-id` | String | AWS account ID |
| `/mono-repo/deployment-bucket` | String | S3 artifacts bucket |
| `/mono-repo/lambda-execution-role-arn` | String | Lambda execution role ARN |
| `/mono-repo/slack/webhook-url` | SecureString | Slack notifications |

## 🌍 Environment Configuration

### Environment Mapping

| Branch Pattern | Environment | Resource Suffix |
|----------------|-------------|-----------------|
| `main` | prod | `prod-` |
| `develop` | staging | `staging-` |
| `feature/*` | dev | `dev-` |
| `hotfix/*` | hotfix | `hotfix-` |

### Resource Scaling by Environment

#### Production
- Lambda: Higher memory, longer timeout, reserved concurrency
- EC2: Larger instances, multiple AZs, higher capacity

#### Staging
- Lambda: Medium resources, moderate concurrency
- EC2: Medium instances, reduced capacity

#### Development
- Lambda: Minimal resources, basic concurrency
- EC2: Small instances, single instance

## 🔍 Monitoring and Logging

### CloudWatch Logs

| Log Group | Purpose |
|-----------|---------|
| `/aws/codebuild/mono-repo-master-pipeline` | Build logs |
| `/aws/lambda/prod-user-service` | Lambda function logs |
| `/aws/codedeploy/mono-repo-prod-app` | Deployment logs |

### Notifications

- **Slack Integration**: Build status and deployment notifications
- **SNS Topics**: Critical alerts and failures
- **CloudWatch Alarms**: Performance and error monitoring

## 🚨 Troubleshooting

### Common Issues

#### 1. Build Fails with Permission Errors
```bash
# Check CodeBuild role permissions
aws iam get-role-policy --role-name mono-repo-codebuild-service-role --policy-name mono-repo-codebuild-policy

# Verify S3 bucket permissions
aws s3api get-bucket-policy --bucket mono-repo-deployment-artifacts-YOUR-ACCOUNT-ID
```

#### 2. Lambda Deployment Fails
```bash
# Check Lambda execution role
aws iam get-role --role-name mono-repo-lambda-execution-role

# Verify function exists
aws lambda get-function --function-name prod-user-service
```

#### 3. ECR Push Fails
```bash
# Login to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin YOUR-ACCOUNT-ID.dkr.ecr.us-east-1.amazonaws.com

# Check repository exists
aws ecr describe-repositories --repository-names mono-repo-prod-ui
```

#### 4. CodeDeploy Fails
```bash
# Check deployment status
aws deploy get-deployment --deployment-id d-XXXXXXXXX

# View deployment logs
aws logs get-log-events --log-group-name /aws/codedeploy/mono-repo-prod-app
```

### Debug Commands

```bash
# View recent builds
aws codebuild list-builds-for-project --project-name mono-repo-master-pipeline --sort-order DESCENDING

# Get build details
aws codebuild batch-get-builds --ids BUILD-ID

# List Lambda functions
aws lambda list-functions --query 'Functions[?starts_with(FunctionName, `prod-`)]'

# Check ECR images
aws ecr list-images --repository-name mono-repo-prod-ui
```

## 🔄 Manual Operations

### Trigger Manual Build
```bash
aws codebuild start-build --project-name mono-repo-master-pipeline
```

### Update Lambda Function
```bash
aws lambda update-function-code \
  --function-name prod-user-service \
  --s3-bucket mono-repo-deployment-artifacts-YOUR-ACCOUNT-ID \
  --s3-key lambda-deployments/prod/user_service/latest.zip
```

### Rollback Deployment
```bash
# Stop current deployment
aws deploy stop-deployment --deployment-id d-XXXXXXXXX --auto-rollback-enabled

# Create rollback deployment
aws deploy create-deployment \
  --application-name mono-repo-prod-app \
  --deployment-group-name mono-repo-prod-deployment-group \
  --revision revisionType=S3,s3Location="{bucket=mono-repo-deployment-artifacts-YOUR-ACCOUNT-ID,key=previous-version.zip,bundleType=zip}"
```

## 📊 Cost Optimization

### Resource Optimization Tips

1. **Lambda Functions**
   - Use ARM64 architecture for better price/performance
   - Set appropriate memory allocation
   - Enable provisioned concurrency only for prod

2. **EC2 Instances**
   - Use Spot instances for dev/staging
   - Right-size instances based on load
   - Enable Auto Scaling based on metrics

3. **Storage**
   - Set S3 lifecycle policies for build artifacts
   - Use ECR lifecycle policies for old images
   - Enable CloudWatch log retention policies

### Cost Monitoring
```bash
# View Lambda costs
aws ce get-cost-and-usage \
  --time-period Start=2024-01-01,End=2024-01-31 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=SERVICE
```

## 🔄 Maintenance

### Regular Tasks

1. **Weekly**
   - Review build logs for errors
   - Check Lambda function performance
   - Monitor EC2 instance health

2. **Monthly**
   - Clean up old S3 artifacts
   - Review and optimize Lambda memory settings
   - Update base AMIs for EC2 instances

3. **Quarterly**
   - Review IAM permissions
   - Update runtime versions
   - Optimize resource allocation

### Updates and Upgrades

```bash
# Update CodeBuild project
aws codebuild update-project --name mono-repo-master-pipeline --cli-input-json file://updated-project.json

# Update Lambda runtime
aws lambda update-function-configuration \
  --function-name prod-user-service \
  --runtime python3.11
```

## 📞 Support

### AWS Resources
- [AWS CodeBuild Documentation](https://docs.aws.amazon.com/codebuild/)
- [AWS Lambda Documentation](https://docs.aws.amazon.com/lambda/)
- [AWS CodeDeploy Documentation](https://docs.aws.amazon.com/codedeploy/)

### Monitoring Dashboards
- AWS CodeBuild Console: Build history and logs
- AWS Lambda Console: Function metrics and logs
- AWS CodeDeploy Console: Deployment status
- CloudWatch Console: Custom metrics and alarms

---

## ✅ Checklist

- [ ] AWS CLI installed and configured
- [ ] GitHub repository created with mono repo code
- [ ] GitHub personal access token generated
- [ ] Setup script executed successfully
- [ ] First deployment triggered and completed
- [ ] Lambda functions accessible via URLs
- [ ] EC2 application accessible via load balancer
- [ ] Monitoring and alerts configured
- [ ] Team access and permissions configured

---

**🎉 Your AWS deployment pipeline is ready for production use!**
