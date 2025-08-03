# 🔧 Scripts Index

## 🌐 Google Cloud Platform (GCP)
- [setup-gcp-secrets.sh](gcp/setup-gcp-secrets.sh) - Create GCP secrets and service accounts
- [validate-gcp-prerequisites.sh](gcp/validate-gcp-prerequisites.sh) - Validate GCP environment

## ☁️ Amazon Web Services (AWS)
- [setup-aws-master-pipeline.sh](aws/setup-aws-master-pipeline.sh) - Setup AWS master pipeline
- [setup-aws-secrets.sh](aws/setup-aws-secrets.sh) - Create AWS secrets and IAM resources
- [validate-aws-prerequisites.sh](aws/validate-aws-prerequisites.sh) - Validate AWS environment

## 🔄 General Scripts
- [setup-local-dev.sh](general/setup-local-dev.sh) - Local development environment setup
- [setup-master-trigger.sh](general/setup-master-trigger.sh) - Master pipeline trigger setup

## 🚀 Execution Order

### **GCP Deployment**
```bash
1. ./scripts/gcp/validate-gcp-prerequisites.sh
2. ./scripts/gcp/setup-gcp-secrets.sh
3. Deploy via Cloud Build
```

### **AWS Deployment**
```bash
1. ./scripts/aws/validate-aws-prerequisites.sh
2. ./scripts/aws/setup-aws-secrets.sh
3. ./scripts/aws/setup-aws-master-pipeline.sh
4. Deploy via CodeBuild
```

### **Local Development**
```bash
1. ./scripts/general/setup-local-dev.sh
2. docker-compose up
```

## 🎯 Quick Reference

| **Script** | **Purpose** | **Prerequisites** |
|------------|-------------|-------------------|
| `validate-*-prerequisites.sh` | Check environment | Cloud CLI installed |
| `setup-*-secrets.sh` | Create secrets/IAM | Cloud CLI authenticated |
| `setup-aws-master-pipeline.sh` | Setup CodeBuild | AWS secrets created |
| `setup-local-dev.sh` | Local environment | Docker installed |
