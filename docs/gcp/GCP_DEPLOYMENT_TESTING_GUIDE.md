# GCP Deployment Testing Guide

## 🚀 Complete Step-by-Step Testing Guide for GCP

This guide walks you through testing and deploying your mono repo to Google Cloud Platform from scratch.

## 📋 Prerequisites Checklist

### 1. Google Cloud Account Setup
- [ ] **Google Cloud Account**: Create account at [cloud.google.com](https://cloud.google.com)
- [ ] **Billing Account**: Enable billing (required for Cloud Build, Cloud Functions, Cloud Run)
- [ ] **New Project**: Create a new GCP project for testing

### 2. Local Development Environment
- [ ] **Git**: Installed and configured
- [ ] **Google Cloud SDK**: Install `gcloud` CLI
- [ ] **Docker**: Installed and running
- [ ] **Node.js**: Version 18+ for UI development
- [ ] **Python**: Version 3.9+ for backend services

### 3. GitHub Repository Setup
- [ ] **GitHub Account**: Personal or organization account
- [ ] **Repository**: Create new repo or use existing
- [ ] **Personal Access Token**: Generate with repo permissions

## 🔧 Step 1: Install and Configure Google Cloud SDK

### Install gcloud CLI

**Windows:**
```powershell
# Download and install from: https://cloud.google.com/sdk/docs/install
# Or use Chocolatey
choco install gcloudsdk
```

**macOS:**
```bash
# Using Homebrew
brew install --cask google-cloud-sdk
```

**Linux:**
```bash
# Download and install
curl https://sdk.cloud.google.com | bash
exec -l $SHELL
```

### Configure gcloud
```bash
# Login to Google Cloud
gcloud auth login

# Set your project (replace with your project ID)
gcloud config set project YOUR-PROJECT-ID

# Set default region
gcloud config set compute/region us-central1

# Verify configuration
gcloud config list
```

## 🏗️ Step 2: Enable Required APIs

```bash
# Enable all required APIs
gcloud services enable cloudbuild.googleapis.com
gcloud services enable cloudfunctions.googleapis.com
gcloud services enable run.googleapis.com
gcloud services enable containerregistry.googleapis.com
gcloud services enable secretmanager.googleapis.com
gcloud services enable logging.googleapis.com
gcloud services enable monitoring.googleapis.com

# Verify APIs are enabled
gcloud services list --enabled
```

## 🔐 Step 3: Set Up IAM Permissions

### Create Service Account for Cloud Build
```bash
# Create service account
gcloud iam service-accounts create mono-repo-cloudbuild \
    --description="Service account for mono repo Cloud Build" \
    --display-name="Mono Repo Cloud Build"

# Get your project ID
PROJECT_ID=$(gcloud config get-value project)

# Grant necessary roles
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:mono-repo-cloudbuild@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/cloudbuild.builds.builder"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:mono-repo-cloudbuild@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/cloudfunctions.developer"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:mono-repo-cloudbuild@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/run.developer"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:mono-repo-cloudbuild@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/storage.admin"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:mono-repo-cloudbuild@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/secretmanager.secretAccessor"
```

## 📁 Step 4: Prepare Your Repository

### Clone and Setup Repository
```bash
# Clone your repository (or create new one)
git clone https://github.com/YOUR-USERNAME/YOUR-REPO.git
cd YOUR-REPO

# Copy all the files we created to your repository
# Make sure you have these files:
# - services-config.yml
# - cloudbuild-master.yml  
# - setup-master-trigger.sh
# - backend/services/user_service/main.py
# - backend/services/notification_service/main.py
# - backend/services/analytics_service/main.py
# - ui/Dockerfile
# - ui/package.json
# - ui/src/...
```

### Verify File Structure
```bash
# Your repository should look like this:
tree -I 'node_modules|__pycache__|*.pyc'
```

Expected structure:
```
mono-repo/
├── services-config.yml
├── cloudbuild-master.yml
├── setup-master-trigger.sh
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
docker run -d -p 8080:80 test-ui
curl http://localhost:8080

# Cleanup
docker stop $(docker ps -q --filter ancestor=test-ui)
cd ..
```

## 🔑 Step 6: Create Secrets (Optional)

```bash
# Create sample secrets for testing
gcloud secrets create mono-repo-db-password --data-file=<(echo -n "test-password-123")
gcloud secrets create mono-repo-jwt-secret --data-file=<(echo -n "test-jwt-secret-456")
gcloud secrets create mono-repo-api-key --data-file=<(echo -n "test-api-key-789")

# Verify secrets
gcloud secrets list
```

## 🚀 Step 7: Run the Setup Script

### Make Script Executable and Run
```bash
# Make script executable
chmod +x setup-master-trigger.sh

# Run the setup script
./setup-master-trigger.sh
```

**The script will prompt you for:**
- GitHub repository owner/username
- GitHub repository name  
- GitHub personal access token
- Slack webhook URL (optional)

### Verify Setup
```bash
# Check if trigger was created
gcloud builds triggers list

# Check if required APIs are enabled
gcloud services list --enabled | grep -E "(cloudbuild|cloudfunctions|run)"
```

## 📤 Step 8: Push Code and Trigger First Build

### Commit and Push Changes
```bash
# Add all files
git add .

# Commit changes
git commit -m "Add GCP deployment pipeline with master trigger"

# Push to main branch (triggers production deployment)
git push origin main
```

### Monitor the Build
```bash
# Watch build progress
gcloud builds list --limit=5

# Get detailed build logs (replace BUILD_ID with actual ID)
gcloud builds log BUILD_ID --stream
```

## 🔍 Step 9: Verify Deployments

### Check Cloud Functions
```bash
# List deployed functions
gcloud functions list

# Test user service function
FUNCTION_URL=$(gcloud functions describe prod-user-service --region=us-central1 --format="value(httpsTrigger.url)")
echo "User Service URL: $FUNCTION_URL"

# Test the function
curl -X POST "$FUNCTION_URL" \
  -H "Content-Type: application/json" \
  -d '{"action": "create_user", "user_data": {"name": "Test User", "email": "test@example.com"}}'
```

### Check Cloud Run Service
```bash
# List Cloud Run services
gcloud run services list

# Get UI service URL
UI_URL=$(gcloud run services describe prod-ui --region=us-central1 --format="value(status.url)")
echo "UI Service URL: $UI_URL"

# Test the UI
curl -I "$UI_URL"
```

### Test Complete Flow
```bash
# Test all services
echo "Testing User Service..."
curl -X POST "$FUNCTION_URL" \
  -H "Content-Type: application/json" \
  -d '{"action": "get_user", "user_id": "test-123"}'

echo "Testing Notification Service..."
NOTIFICATION_URL=$(gcloud functions describe prod-notification-service --region=us-central1 --format="value(httpsTrigger.url)")
curl -X POST "$NOTIFICATION_URL" \
  -H "Content-Type: application/json" \
  -d '{"action": "send_notification", "notification_data": {"type": "email", "recipient": "test@example.com", "message": "Test notification"}}'

echo "Testing Analytics Service..."
ANALYTICS_URL=$(gcloud functions describe prod-analytics-service --region=us-central1 --format="value(httpsTrigger.url)")
curl -X POST "$ANALYTICS_URL" \
  -H "Content-Type: application/json" \
  -d '{"action": "track_event", "event_data": {"event_type": "test", "user_id": "test-123"}}'

echo "Testing UI..."
curl -s "$UI_URL" | grep -o "<title>.*</title>"
```

## 🧪 Step 10: Test Different Environments

### Test Staging Environment
```bash
# Create and push to develop branch
git checkout -b develop
git push origin develop

# Monitor staging deployment
gcloud builds list --limit=3
```

### Test Development Environment  
```bash
# Create and push to feature branch
git checkout -b feature/test-deployment
git push origin feature/test-deployment

# Check dev services
gcloud functions list | grep dev-
gcloud run services list | grep dev-
```

## 🔧 Step 11: Troubleshooting Common Issues

### Build Failures
```bash
# Get build details
BUILD_ID=$(gcloud builds list --limit=1 --format="value(id)")
gcloud builds describe $BUILD_ID

# Check build logs
gcloud builds log $BUILD_ID

# Common issues and fixes:
# 1. API not enabled: gcloud services enable [API_NAME]
# 2. Permission denied: Check IAM roles
# 3. Quota exceeded: Check quotas in console
# 4. Source not found: Verify GitHub connection
```

### Function Deployment Issues
```bash
# Check function status
gcloud functions describe FUNCTION_NAME --region=us-central1

# View function logs
gcloud functions logs read FUNCTION_NAME --region=us-central1 --limit=50

# Common issues:
# 1. Runtime error: Check requirements.txt
# 2. Memory limit: Increase memory in services-config.yml
# 3. Timeout: Increase timeout in services-config.yml
```

### Cloud Run Issues
```bash
# Check service status
gcloud run services describe SERVICE_NAME --region=us-central1

# View service logs
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=SERVICE_NAME" --limit=50

# Common issues:
# 1. Container won't start: Check Dockerfile
# 2. Port binding: Ensure app listens on $PORT
# 3. Memory issues: Increase memory allocation
```

## 📊 Step 12: Performance Testing

### Load Testing Functions
```bash
# Install Apache Bench for testing
# Windows: Download from Apache website
# macOS: brew install httpie
# Linux: apt-get install apache2-utils

# Test function performance
ab -n 100 -c 10 -p test-payload.json -T application/json $FUNCTION_URL

# Create test payload file
echo '{"action": "get_user", "user_id": "test-123"}' > test-payload.json
```

### Monitor Resources
```bash
# Check Cloud Function metrics
gcloud functions describe prod-user-service --region=us-central1 --format="table(name,status,updateTime)"

# Check Cloud Run metrics  
gcloud run services describe prod-ui --region=us-central1 --format="table(metadata.name,status.conditions[0].type,status.conditions[0].status)"
```

## 🔄 Step 13: Cleanup (When Done Testing)

### Delete Resources
```bash
# Delete Cloud Functions
gcloud functions delete prod-user-service --region=us-central1 --quiet
gcloud functions delete prod-notification-service --region=us-central1 --quiet
gcloud functions delete prod-analytics-service --region=us-central1 --quiet

# Delete Cloud Run services
gcloud run services delete prod-ui --region=us-central1 --quiet

# Delete build triggers
TRIGGER_ID=$(gcloud builds triggers list --format="value(id)" --filter="name:mono-repo-master-trigger")
gcloud builds triggers delete $TRIGGER_ID --quiet

# Delete secrets
gcloud secrets delete mono-repo-db-password --quiet
gcloud secrets delete mono-repo-jwt-secret --quiet
gcloud secrets delete mono-repo-api-key --quiet
```

## ✅ Success Checklist

After completing all steps, you should have:

- [ ] ✅ **Cloud Functions deployed** and responding to HTTP requests
- [ ] ✅ **Cloud Run service deployed** and serving the UI
- [ ] ✅ **Build trigger working** for automatic deployments
- [ ] ✅ **Environment-based deployments** (main→prod, develop→staging, feature→dev)
- [ ] ✅ **Monitoring and logging** working in Cloud Console
- [ ] ✅ **All services communicating** properly
- [ ] ✅ **Performance acceptable** under load testing

## 🎯 Expected Results

### Successful Deployment Should Show:

1. **Cloud Functions**:
   ```
   prod-user-service        ACTIVE    HTTP Trigger
   prod-notification-service ACTIVE    HTTP Trigger  
   prod-analytics-service   ACTIVE    HTTP Trigger
   ```

2. **Cloud Run Services**:
   ```
   prod-ui    READY    https://prod-ui-xxx-uc.a.run.app
   ```

3. **Build Triggers**:
   ```
   mono-repo-master-trigger    ENABLED    GitHub Push
   ```

## 📞 Getting Help

### GCP Console Links
- **Cloud Build**: https://console.cloud.google.com/cloud-build/builds
- **Cloud Functions**: https://console.cloud.google.com/functions/list
- **Cloud Run**: https://console.cloud.google.com/run
- **Logs**: https://console.cloud.google.com/logs

### Useful Commands
```bash
# Quick health check
gcloud functions list --format="table(name,status,httpsTrigger.url)"
gcloud run services list --format="table(metadata.name,status.url)"

# View recent builds
gcloud builds list --limit=5 --format="table(id,status,createTime,duration)"

# Check quotas
gcloud compute project-info describe --format="table(quotas.metric,quotas.usage,quotas.limit)"
```

---

## 🎉 Congratulations!

If you've completed all steps successfully, you now have a fully functional GCP deployment pipeline that:
- ✅ Automatically detects changed services
- ✅ Deploys backend functions to Cloud Functions
- ✅ Deploys frontend to Cloud Run
- ✅ Supports multiple environments
- ✅ Includes monitoring and logging
- ✅ Scales automatically based on demand

**Next**: Ready to test AWS deployment? Let me know when you want the AWS testing guide!
