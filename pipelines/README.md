# 🚀 Pipelines Index

## 🌐 Google Cloud Platform (GCP)
- [cloudbuild-master.yml](gcp/cloudbuild-master.yml) - GCP master pipeline for dynamic deployment

## ☁️ Amazon Web Services (AWS)
- [buildspec-master.yml](aws/buildspec-master.yml) - AWS master pipeline for dynamic deployment

## 🔄 Pipeline Features

### **Dynamic Service Detection**
- ✅ Automatically detects changed services
- ✅ Environment-aware deployments (prod, staging, dev, hotfix)
- ✅ Parallel service deployment
- ✅ Rollback capabilities

### **GCP Cloud Build Pipeline**
- **Trigger**: GitHub webhook or manual
- **Environment Detection**: Based on branch name
- **Backend**: Deploys to Cloud Functions
- **Frontend**: Deploys to Cloud Run
- **Configuration**: Uses `configs/gcp/services-config.yml`

### **AWS CodeBuild Pipeline**
- **Trigger**: GitHub webhook or manual
- **Environment Detection**: Based on branch name
- **Backend**: Deploys to Lambda Functions
- **Frontend**: Deploys to EC2 via CodeDeploy
- **Configuration**: Uses `configs/aws/aws-services-config.yml`

## 🎯 Environment Mapping

| **Branch** | **Environment** | **GCP Deployment** | **AWS Deployment** |
|------------|-----------------|-------------------|-------------------|
| `main` | prod | Cloud Functions + Cloud Run | Lambda + EC2 |
| `develop` | staging | Cloud Functions + Cloud Run | Lambda + EC2 |
| `feature/*` | dev | Cloud Functions + Cloud Run | Lambda + EC2 |
| `hotfix/*` | hotfix | Cloud Functions + Cloud Run | Lambda + EC2 |

## 🔧 Pipeline Configuration

### **GCP Pipeline Steps**
1. **Install**: Dependencies and tools
2. **Pre-build**: Detect changes and environment
3. **Build**: Deploy Cloud Functions and Cloud Run
4. **Post-build**: Validation and notifications

### **AWS Pipeline Steps**
1. **Install**: Dependencies and tools
2. **Pre-build**: Detect changes and environment
3. **Build**: Deploy Lambda and EC2 applications
4. **Post-build**: Validation and notifications

## 🚀 Triggering Deployments

### **Automatic Triggers**
```bash
# Push to main branch (prod deployment)
git push origin main

# Push to develop branch (staging deployment)
git push origin develop

# Push to feature branch (dev deployment)
git push origin feature/new-feature
```

### **Manual Triggers**
```bash
# GCP
gcloud builds submit --config pipelines/gcp/cloudbuild-master.yml

# AWS
aws codebuild start-build --project-name mono-repo-master-pipeline
```
