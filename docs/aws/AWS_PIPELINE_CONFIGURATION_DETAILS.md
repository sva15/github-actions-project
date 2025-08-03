# AWS Pipeline Configuration Details

## 📋 Overview

This document explains all the configuration details that are extracted from `aws-services-config.yml` and passed to the AWS deployment pipeline for both Lambda functions and EC2/UI deployments.

## 🔧 **Lambda Function Deployment Details**

### **Configuration Parameters Extracted:**

#### **1. Basic Function Configuration**
```yaml
# From aws-services-config.yml
RUNTIME=$(yq eval ".services.$SERVICE.runtime" aws-services-config.yml)           # python3.9
MEMORY=$(yq eval ".services.$SERVICE.memory" aws-services-config.yml)             # 256, 512, 1024
TIMEOUT=$(yq eval ".services.$SERVICE.timeout" aws-services-config.yml)           # 60, 120, 300
HANDLER=$(yq eval ".services.$SERVICE.handler" aws-services-config.yml)           # main.lambda_handler
ARCHITECTURE=$(yq eval ".services.$SERVICE.architecture" aws-services-config.yml) # x86_64
DESCRIPTION=$(yq eval ".services.$SERVICE.description" aws-services-config.yml)   # Service description
```

#### **2. Environment-Specific Overrides**
```yaml
# Environment-specific settings (prod, staging, dev, hotfix)
ENV_MEMORY=$(yq eval ".environments.$ENV.overrides.$SERVICE.memory // $MEMORY" aws-services-config.yml)
ENV_TIMEOUT=$(yq eval ".environments.$ENV.overrides.$SERVICE.timeout // $TIMEOUT" aws-services-config.yml)
RESERVED_CONCURRENCY=$(yq eval ".environments.$ENV.overrides.$SERVICE.reserved_concurrency // .services.$SERVICE.config.reserved_concurrency" aws-services-config.yml)
PROVISIONED_CONCURRENCY=$(yq eval ".environments.$ENV.overrides.$SERVICE.provisioned_concurrency // .services.$SERVICE.config.provisioned_concurrency" aws-services-config.yml)
```

#### **3. Environment Variables**
```yaml
# Built dynamically from config
ENV_VARS="{\"ENVIRONMENT\":\"$ENV\",\"LOG_LEVEL\":\"INFO\""

# Additional variables from service config
for each env_var in service.env_vars:
  VAR_NAME=$(yq eval ".services.$SERVICE.env_vars[$i].name" aws-services-config.yml)
  VAR_DEFAULT=$(yq eval ".services.$SERVICE.env_vars[$i].default" aws-services-config.yml)
  # Added to ENV_VARS JSON string
```

#### **4. Lambda-Specific Features**
- **Reserved Concurrency**: Controls maximum concurrent executions
- **Provisioned Concurrency**: Pre-warmed instances for better performance
- **Function URL**: Automatically created for HTTP access
- **Dead Letter Queue**: Configured if specified in config
- **VPC Configuration**: Applied if enabled in config

### **Example Lambda Deployment Command:**
```bash
aws lambda create-function \
  --function-name prod-user-service \
  --runtime python3.9 \
  --role arn:aws:iam::123456789012:role/mono-repo-lambda-execution-role \
  --handler main.lambda_handler \
  --code S3Bucket=deployment-bucket,S3Key=lambda-deployments/prod/user_service/build-123.zip \
  --memory-size 512 \
  --timeout 90 \
  --environment Variables='{"ENVIRONMENT":"prod","LOG_LEVEL":"INFO","DATABASE_URL":"PLACEHOLDER_DATABASE_URL","JWT_SECRET_KEY":"PLACEHOLDER_JWT_SECRET_KEY"}' \
  --description "User management service with CRUD operations" \
  --architectures x86_64

# Additional configurations
aws lambda put-reserved-concurrency-config \
  --function-name prod-user-service \
  --reserved-concurrent-executions 100

aws lambda put-provisioned-concurrency-config \
  --function-name prod-user-service \
  --qualifier $VERSION \
  --provisioned-concurrent-executions 10
```

---

## 🖥️ **EC2/UI Deployment Details**

### **Configuration Parameters Extracted:**

#### **1. EC2 Instance Configuration**
```yaml
# From aws-services-config.yml
INSTANCE_TYPE=$(yq eval ".services.$SERVICE.ec2.instance_type" aws-services-config.yml)     # t3.medium, t3.large
AMI_ID=$(yq eval ".services.$SERVICE.ec2.ami_id" aws-services-config.yml)                   # ami-0c02fb55956c7d316
KEY_PAIR=$(yq eval ".services.$SERVICE.ec2.key_pair" aws-services-config.yml)               # EC2 key pair name
SECURITY_GROUPS=$(yq eval ".services.$SERVICE.ec2.security_groups[]" aws-services-config.yml) # Security group IDs
```

#### **2. Auto Scaling Configuration**
```yaml
# Environment-specific capacity settings
MIN_CAPACITY=$(yq eval ".environments.$ENV.overrides.$SERVICE.min_capacity // .services.$SERVICE.ec2.min_capacity" aws-services-config.yml)      # 1, 2
MAX_CAPACITY=$(yq eval ".environments.$ENV.overrides.$SERVICE.max_capacity // .services.$SERVICE.ec2.max_capacity" aws-services-config.yml)      # 3, 10
DESIRED_CAPACITY=$(yq eval ".environments.$ENV.overrides.$SERVICE.desired_capacity // .services.$SERVICE.ec2.desired_capacity" aws-services-config.yml) # 1, 2
```

#### **3. Container Configuration**
```yaml
# Docker container settings
CONTAINER_PORT=$(yq eval ".services.$SERVICE.container.port // 80" aws-services-config.yml) # 80, 4200, 8080
ECR_REPOSITORY="$ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/mono-repo-$ENV-ui"
```

#### **4. Environment Variables for Containers**
```yaml
# Built dynamically from config
EC2_ENV_VARS="ENVIRONMENT=$ENV,LOG_LEVEL=INFO"

# Additional variables from service config
for each env_var in service.env_vars:
  VAR_NAME=$(yq eval ".services.$SERVICE.env_vars[$i].name" aws-services-config.yml)
  VAR_DEFAULT=$(yq eval ".services.$SERVICE.env_vars[$i].default" aws-services-config.yml)
  # Added to EC2_ENV_VARS comma-separated string
```

### **Example Docker Run Command (in CodeDeploy script):**
```bash
docker run -d --name mono-repo-prod-ui -p 80:80 \
  -e ENVIRONMENT=prod \
  -e LOG_LEVEL=INFO \
  -e API_BASE_URL=PLACEHOLDER_API_BASE_URL \
  -e NODE_ENV=production \
  --restart unless-stopped \
  --log-driver=awslogs \
  --log-opt awslogs-group=/aws/ec2/mono-repo-prod-ui \
  --log-opt awslogs-region=us-east-1 \
  --log-opt awslogs-stream=$(hostname) \
  123456789012.dkr.ecr.us-east-1.amazonaws.com/mono-repo-prod-ui:latest
```

---

## 📊 **Configuration Matrix by Environment**

| Environment | Lambda Memory | Lambda Timeout | EC2 Instance | Min/Max/Desired Capacity |
|-------------|---------------|----------------|--------------|--------------------------|
| **prod**    | 512-2048 MB   | 90-300s        | t3.large     | 2/10/2                   |
| **staging** | 256-1024 MB   | 60-240s        | t3.small     | 1/3/1                    |
| **dev**     | 256-512 MB    | 60-120s        | t3.micro     | 1/2/1                    |
| **hotfix**  | 256-512 MB    | 60-120s        | t3.micro     | 1/1/1                    |

---

## 🔐 **Security & IAM Configuration**

### **IAM Roles Used:**
```yaml
# From Parameter Store
LAMBDA_EXECUTION_ROLE_ARN="/mono-repo/lambda-execution-role-arn"
EC2_INSTANCE_ROLE_ARN="/mono-repo/ec2-instance-role-arn"
CODEBUILD_SERVICE_ROLE_ARN="/mono-repo/codebuild-service-role-arn"
```

### **Secrets Management:**
```yaml
# Parameters from AWS Systems Manager Parameter Store
/mono-repo/{env}/jwt-secret
/mono-repo/{env}/db-password
/mono-repo/{env}/api-key
/mono-repo/{env}/smtp-password
/mono-repo/{env}/twilio-auth-token
/mono-repo/{env}/fcm-server-key
/mono-repo/{env}/redis-auth-token
```

---

## 🚀 **Deployment Process Flow**

### **1. Pre-Build Phase**
- ✅ Determine environment from branch name
- ✅ Detect changed services using git diff
- ✅ Load service configurations from `aws-services-config.yml`

### **2. Build Phase - Lambda Functions**
- ✅ Extract all configuration parameters
- ✅ Build environment variables JSON
- ✅ Package Python dependencies
- ✅ Create ZIP deployment package
- ✅ Upload to S3
- ✅ Deploy/update Lambda function with all settings
- ✅ Configure reserved/provisioned concurrency
- ✅ Create Function URL

### **3. Build Phase - EC2/UI**
- ✅ Extract EC2 and container configuration
- ✅ Build environment variables string
- ✅ Build and push Docker image to ECR
- ✅ Create CodeDeploy package with scripts
- ✅ Generate appspec.yml with lifecycle hooks
- ✅ Deploy to Auto Scaling Group via CodeDeploy

### **4. Post-Build Phase**
- ✅ Validate deployments
- ✅ Collect service URLs
- ✅ Send Slack notifications
- ✅ Generate deployment summary

---

## 📝 **Configuration Files Used**

### **1. aws-services-config.yml**
- Service definitions and configurations
- Environment-specific overrides
- IAM roles and policies
- Build and deployment settings

### **2. buildspec-master.yml**
- CodeBuild pipeline definition
- Dynamic service detection logic
- Deployment commands and scripts

### **3. Parameter Store**
- Secrets and sensitive configuration
- IAM role ARNs
- Account and infrastructure details

---

## ✅ **What's Included in Each Deployment**

### **Lambda Functions Get:**
- ✅ **Runtime**: Python 3.9
- ✅ **Memory**: Environment-specific (256MB - 2048MB)
- ✅ **Timeout**: Environment-specific (60s - 300s)
- ✅ **Handler**: main.lambda_handler
- ✅ **Architecture**: x86_64
- ✅ **Environment Variables**: All configured variables
- ✅ **IAM Role**: Lambda execution role with required permissions
- ✅ **Reserved Concurrency**: Performance control
- ✅ **Provisioned Concurrency**: Pre-warmed instances (prod only)
- ✅ **Function URL**: HTTP access endpoint
- ✅ **Description**: Service description from config

### **EC2/UI Deployments Get:**
- ✅ **Instance Type**: Environment-specific (t3.micro - t3.large)
- ✅ **Auto Scaling**: Min/Max/Desired capacity
- ✅ **Docker Container**: Built and pushed to ECR
- ✅ **Environment Variables**: All configured variables
- ✅ **Port Mapping**: Container port to host port 80
- ✅ **Health Checks**: Container health validation
- ✅ **Logging**: CloudWatch logs integration
- ✅ **Restart Policy**: unless-stopped
- ✅ **CodeDeploy**: Blue-green deployment with lifecycle hooks

---

## 🎯 **Missing Configuration (To Be Added)**

### **Currently Using Placeholders:**
- ❌ **Database URLs**: Need actual connection strings
- ❌ **API Keys**: Need real external service keys
- ❌ **SMTP Credentials**: Need actual email service details
- ❌ **VPC Configuration**: Currently disabled
- ❌ **Load Balancer URLs**: Need actual ALB endpoints

### **Recommendations:**
1. **Update Parameter Store** with real values after deployment
2. **Configure VPC** for production security
3. **Set up Load Balancer** for UI service
4. **Enable monitoring** and alerting
5. **Configure custom domains** for services

---

## 💡 **Key Benefits of This Configuration**

1. **🔄 Dynamic**: Automatically detects changed services
2. **🌍 Environment-Aware**: Different settings per environment
3. **🔧 Configurable**: All settings in YAML config file
4. **🔐 Secure**: Uses IAM roles and Parameter Store
5. **📊 Scalable**: Auto scaling and concurrency controls
6. **📝 Comprehensive**: Includes logging, monitoring, health checks
7. **🚀 Production-Ready**: Blue-green deployments with rollback

Your AWS pipeline is now fully configured to deploy both Lambda functions and EC2 applications with all the necessary parameters! 🎉
