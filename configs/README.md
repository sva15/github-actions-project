# ⚙️ Configuration Index

## 🌐 Google Cloud Platform (GCP)
- [services-config.yml](gcp/services-config.yml) - GCP service definitions and settings

## ☁️ Amazon Web Services (AWS)
- [aws-services-config.yml](aws/aws-services-config.yml) - AWS service definitions and settings

## 🔧 Configuration Structure

### **Service Definitions**
Each configuration file defines:
- **Backend Services**: Runtime, memory, timeout, environment variables
- **Frontend Services**: Instance types, scaling, container settings
- **Environment Overrides**: Different settings per environment
- **IAM Roles**: Security and permissions
- **Monitoring**: Logging and alerting configuration

### **GCP Configuration Features**
- **Cloud Functions**: Python runtime, memory, timeout, environment variables
- **Cloud Run**: Container settings, scaling, ingress configuration
- **Secret Manager**: Integration with secrets and parameters
- **Service Accounts**: Dedicated accounts per service
- **Environment Variables**: Complete variable management

### **AWS Configuration Features**
- **Lambda Functions**: Python runtime, memory, timeout, concurrency settings
- **EC2 Instances**: Instance types, auto-scaling, security groups
- **Parameter Store**: Integration with secrets and parameters
- **IAM Roles**: Execution roles and policies
- **Environment Variables**: Complete variable management

## 🎯 Environment-Specific Overrides

### **Production (prod)**
- **Higher memory allocation**: 512MB - 2048MB
- **Longer timeouts**: 90s - 300s
- **Reserved concurrency**: Performance guarantees
- **Larger instances**: t3.large, multiple replicas
- **Enhanced monitoring**: Full logging and alerting

### **Staging**
- **Medium resources**: 256MB - 1024MB
- **Standard timeouts**: 60s - 240s
- **Limited concurrency**: Cost optimization
- **Medium instances**: t3.small, fewer replicas
- **Standard monitoring**: Basic logging

### **Development (dev)**
- **Minimal resources**: 256MB - 512MB
- **Short timeouts**: 60s - 120s
- **No reserved concurrency**: Cost optimization
- **Small instances**: t3.micro, single replica
- **Basic monitoring**: Essential logs only

### **Hotfix**
- **Minimal resources**: Same as dev
- **Fast deployment**: Quick rollout for fixes
- **Single instance**: Minimal footprint
- **Focused monitoring**: Error tracking

## 🔐 Security Configuration

### **Secrets Management**
- **GCP**: Secret Manager integration
- **AWS**: Systems Manager Parameter Store
- **Environment Variables**: Secure injection
- **IAM Roles**: Least privilege access

### **Network Security**
- **VPC Configuration**: Private networking
- **Security Groups**: Firewall rules
- **Ingress Controls**: Access restrictions
- **SSL/TLS**: Encrypted communications

## 📊 Configuration Examples

### **Lambda Function Configuration**
```yaml
user_service:
  runtime: python3.9
  memory: 256
  timeout: 60
  environment:
    - DATABASE_URL
    - JWT_SECRET_KEY
  parameters:
    - /mono-repo/{env}/jwt-secret
```

### **Cloud Function Configuration**
```yaml
user_service:
  runtime: python39
  memory: 256Mi
  timeout: 60s
  environment:
    - DATABASE_URL
    - JWT_SECRET_KEY
  secrets:
    - jwt-secret
```

## 🎯 Quick Reference

| **Configuration** | **Purpose** | **Used By** |
|-------------------|-------------|-------------|
| `gcp/services-config.yml` | GCP service definitions | Cloud Build pipeline |
| `aws/aws-services-config.yml` | AWS service definitions | CodeBuild pipeline |
| Environment overrides | Per-environment settings | Both pipelines |
| Secret references | Secure configuration | Both pipelines |
