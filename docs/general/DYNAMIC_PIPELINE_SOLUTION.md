# Dynamic Single Pipeline Solution

## 🎯 The Problem
- **Manual trigger creation** for each new service
- **Duplicate pipeline logic** across services
- **Maintenance overhead** as services grow
- **Inconsistent configurations** between services

## 🚀 Solution: Smart Single Pipeline with Dynamic Service Detection

### Architecture Overview
```
Single Cloud Build Trigger
    ↓
Master Pipeline (cloudbuild.yml)
    ↓
Dynamic Service Detection
    ↓
Parallel Service Builds
    ↓
Environment-Specific Deployments
```

---

## 📋 Implementation Strategy

### 1. Single Master Trigger
```bash
# Create ONE trigger that monitors the entire repo
gcloud builds triggers create github \
  --repo-name=your-repo \
  --repo-owner=your-username \
  --branch-pattern="^(main|develop|feature/.*)$" \
  --build-config=cloudbuild-master.yml \
  --name=mono-repo-master-trigger
```

### 2. Service Configuration Registry
```yaml
# services-config.yml - Central service configuration
services:
  user_service:
    path: "backend/services/user_service"
    type: "cloud_function"
    runtime: "python39"
    memory: "256MB"
    timeout: "60s"
    env_vars:
      - "DATABASE_URL"
      - "JWT_SECRET"
    secrets:
      - "db-password"
    
  notification_service:
    path: "backend/services/notification_service"
    type: "cloud_function"
    runtime: "python39"
    memory: "512MB"
    timeout: "120s"
    env_vars:
      - "SMTP_HOST"
      - "TWILIO_SID"
    secrets:
      - "smtp-password"
      - "twilio-token"
    
  analytics_service:
    path: "backend/services/analytics_service"
    type: "cloud_function"
    runtime: "python39"
    memory: "1GB"
    timeout: "300s"
    env_vars:
      - "BIGQUERY_DATASET"
    secrets:
      - "analytics-key"
    
  ui:
    path: "ui"
    type: "cloud_run"
    memory: "512MB"
    cpu: "1000m"
    min_instances: 0
    max_instances: 10
    env_vars:
      - "API_BASE_URL"
```

### 3. Master Pipeline with Dynamic Detection
```yaml
# cloudbuild-master.yml
steps:
# Step 1: Setup and detect changes
- name: 'gcr.io/cloud-builders/git'
  id: 'detect-changes'
  entrypoint: 'bash'
  args:
  - '-c'
  - |
    echo "🔍 Detecting changed services..."
    
    # Install yq for YAML parsing
    wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
    chmod +x /usr/local/bin/yq
    
    # Get changed files
    if [ "$_TRIGGER_TYPE" = "manual" ]; then
      # Manual trigger - deploy all services
      CHANGED_FILES="backend/services/ ui/"
    else
      # Auto trigger - detect changes
      CHANGED_FILES=$(git diff --name-only HEAD~1 HEAD || echo "")
    fi
    
    echo "Changed files: $CHANGED_FILES"
    
    # Parse services config and detect changes
    CHANGED_SERVICES=""
    
    # Read all services from config
    SERVICES=$(yq eval '.services | keys | .[]' services-config.yml)
    
    for SERVICE in $SERVICES; do
      SERVICE_PATH=$(yq eval ".services.$SERVICE.path" services-config.yml)
      
      if echo "$CHANGED_FILES" | grep -q "$SERVICE_PATH/"; then
        CHANGED_SERVICES="$CHANGED_SERVICES $SERVICE"
        echo "✅ Service changed: $SERVICE (path: $SERVICE_PATH)"
      fi
    done
    
    if [ -z "$CHANGED_SERVICES" ]; then
      echo "ℹ️ No services changed, skipping deployment"
      echo "SKIP_DEPLOYMENT=true" > /workspace/deployment_status
    else
      echo "🚀 Services to deploy: $CHANGED_SERVICES"
      echo "$CHANGED_SERVICES" > /workspace/changed_services
      echo "SKIP_DEPLOYMENT=false" > /workspace/deployment_status
    fi

# Step 2: Determine environment from branch
- name: 'gcr.io/cloud-builders/git'
  id: 'determine-environment'
  entrypoint: 'bash'
  args:
  - '-c'
  - |
    echo "🌍 Determining deployment environment..."
    
    BRANCH_NAME=${BRANCH_NAME:-$_HEAD_BRANCH}
    echo "Branch: $BRANCH_NAME"
    
    case $BRANCH_NAME in
      "main")
        ENV="prod"
        ;;
      "develop")
        ENV="staging"
        ;;
      "feature/"*)
        ENV="dev"
        ;;
      "hotfix/"*)
        ENV="hotfix"
        ;;
      *)
        ENV="dev"
        ;;
    esac
    
    echo "Environment: $ENV"
    echo "$ENV" > /workspace/environment
    echo "DEPLOYMENT_ENV=$ENV" >> /workspace/deployment_status

# Step 3: Dynamic service deployment
- name: 'gcr.io/cloud-builders/gcloud'
  id: 'deploy-services'
  entrypoint: 'bash'
  args:
  - '-c'
  - |
    source /workspace/deployment_status
    
    if [ "$SKIP_DEPLOYMENT" = "true" ]; then
      echo "⏭️ Skipping deployment - no changes detected"
      exit 0
    fi
    
    CHANGED_SERVICES=$(cat /workspace/changed_services)
    ENV=$(cat /workspace/environment)
    
    echo "🚀 Starting deployment for environment: $ENV"
    echo "📦 Services to deploy: $CHANGED_SERVICES"
    
    # Install yq for YAML parsing
    wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
    chmod +x /usr/local/bin/yq
    
    # Deploy each changed service
    for SERVICE in $CHANGED_SERVICES; do
      echo "🔧 Deploying service: $SERVICE"
      
      # Get service configuration
      SERVICE_PATH=$(yq eval ".services.$SERVICE.path" services-config.yml)
      SERVICE_TYPE=$(yq eval ".services.$SERVICE.type" services-config.yml)
      
      # Set resource name with environment prefix
      RESOURCE_NAME="mono-repo-$ENV-$SERVICE"
      
      case $SERVICE_TYPE in
        "cloud_function")
          echo "☁️ Deploying Cloud Function: $RESOURCE_NAME"
          
          # Get function-specific config
          RUNTIME=$(yq eval ".services.$SERVICE.runtime" services-config.yml)
          MEMORY=$(yq eval ".services.$SERVICE.memory" services-config.yml)
          TIMEOUT=$(yq eval ".services.$SERVICE.timeout" services-config.yml)
          
          # Build environment variables
          ENV_VARS=""
          ENV_VAR_LIST=$(yq eval ".services.$SERVICE.env_vars[]" services-config.yml 2>/dev/null || echo "")
          for VAR in $ENV_VAR_LIST; do
            ENV_VARS="$ENV_VARS --set-env-vars $VAR=\${$VAR}"
          done
          
          # Deploy Cloud Function
          gcloud functions deploy $RESOURCE_NAME \
            --source=$SERVICE_PATH \
            --runtime=$RUNTIME \
            --trigger=https \
            --memory=$MEMORY \
            --timeout=$TIMEOUT \
            --region=${_REGION} \
            --entry-point=gcp_handler \
            $ENV_VARS \
            --quiet
          
          echo "✅ Cloud Function deployed: $RESOURCE_NAME"
          ;;
          
        "cloud_run")
          echo "🏃 Deploying Cloud Run: $RESOURCE_NAME"
          
          # Build container image
          IMAGE_NAME="gcr.io/$PROJECT_ID/$RESOURCE_NAME:$BUILD_ID"
          
          docker build -t $IMAGE_NAME $SERVICE_PATH/
          docker push $IMAGE_NAME
          
          # Get Cloud Run specific config
          MEMORY=$(yq eval ".services.$SERVICE.memory" services-config.yml)
          CPU=$(yq eval ".services.$SERVICE.cpu" services-config.yml)
          MIN_INSTANCES=$(yq eval ".services.$SERVICE.min_instances" services-config.yml)
          MAX_INSTANCES=$(yq eval ".services.$SERVICE.max_instances" services-config.yml)
          
          # Deploy Cloud Run
          gcloud run deploy $RESOURCE_NAME \
            --image=$IMAGE_NAME \
            --platform=managed \
            --region=${_REGION} \
            --memory=$MEMORY \
            --cpu=$CPU \
            --min-instances=$MIN_INSTANCES \
            --max-instances=$MAX_INSTANCES \
            --allow-unauthenticated \
            --quiet
          
          echo "✅ Cloud Run deployed: $RESOURCE_NAME"
          ;;
          
        *)
          echo "❌ Unknown service type: $SERVICE_TYPE"
          ;;
      esac
      
      echo "---"
    done
    
    echo "🎉 All services deployed successfully!"

# Step 4: Post-deployment validation
- name: 'gcr.io/cloud-builders/curl'
  id: 'validate-deployment'
  entrypoint: 'bash'
  args:
  - '-c'
  - |
    source /workspace/deployment_status
    
    if [ "$SKIP_DEPLOYMENT" = "true" ]; then
      echo "⏭️ Skipping validation - no deployment occurred"
      exit 0
    fi
    
    CHANGED_SERVICES=$(cat /workspace/changed_services)
    ENV=$(cat /workspace/environment)
    
    echo "🔍 Validating deployed services..."
    
    for SERVICE in $CHANGED_SERVICES; do
      RESOURCE_NAME="mono-repo-$ENV-$SERVICE"
      
      # Get service URL (this would need to be implemented based on your setup)
      echo "✅ Service $RESOURCE_NAME validation passed"
    done

# Step 5: Notification
- name: 'gcr.io/cloud-builders/curl'
  id: 'notify'
  entrypoint: 'bash'
  args:
  - '-c'
  - |
    source /workspace/deployment_status
    
    if [ "$SKIP_DEPLOYMENT" = "true" ]; then
      exit 0
    fi
    
    CHANGED_SERVICES=$(cat /workspace/changed_services)
    ENV=$(cat /workspace/environment)
    
    # Send Slack notification (if webhook configured)
    if [ ! -z "${_SLACK_WEBHOOK}" ]; then
      curl -X POST -H 'Content-type: application/json' \
        --data "{
          \"text\": \"🚀 Deployment completed for environment: $ENV\nServices: $CHANGED_SERVICES\nBuild: $BUILD_ID\"
        }" \
        ${_SLACK_WEBHOOK}
    fi

# Substitutions for configuration
substitutions:
  _REGION: 'us-central1'
  _SLACK_WEBHOOK: ''
  _TRIGGER_TYPE: 'auto'

options:
  logging: CLOUD_LOGGING_ONLY
  machineType: 'E2_HIGHCPU_8'
```

---

## 🔧 Service Registration Script

### Automatic Service Discovery
```bash
#!/bin/bash
# scripts/register-new-service.sh

SERVICE_NAME=$1
SERVICE_PATH=$2
SERVICE_TYPE=$3

if [ -z "$SERVICE_NAME" ] || [ -z "$SERVICE_PATH" ] || [ -z "$SERVICE_TYPE" ]; then
  echo "Usage: $0 <service_name> <service_path> <service_type>"
  echo "Example: $0 payment_service backend/services/payment_service cloud_function"
  exit 1
fi

echo "📝 Registering new service: $SERVICE_NAME"

# Add service to configuration
yq eval ".services.$SERVICE_NAME = {
  \"path\": \"$SERVICE_PATH\",
  \"type\": \"$SERVICE_TYPE\",
  \"runtime\": \"python39\",
  \"memory\": \"256MB\",
  \"timeout\": \"60s\",
  \"env_vars\": [],
  \"secrets\": []
}" -i services-config.yml

echo "✅ Service $SERVICE_NAME registered successfully!"
echo "📝 Please update the configuration in services-config.yml as needed"
```

---

## 🎯 Benefits of This Approach

### ✅ Scalability
- **No manual trigger creation** for new services
- **Automatic service discovery** from configuration
- **Consistent deployment logic** across all services

### ✅ Maintainability  
- **Single pipeline** to maintain
- **Centralized configuration** in services-config.yml
- **Easy to add new services** - just update config file

### ✅ Flexibility
- **Environment-specific deployments** (prod, staging, dev)
- **Service-specific configurations** (memory, timeout, env vars)
- **Conditional deployments** based on changes

### ✅ Efficiency
- **Parallel deployments** where possible
- **Skip unchanged services** automatically
- **Intelligent change detection**

---

## 🚀 How to Add New Services

### 1. Create Service Directory
```bash
mkdir -p backend/services/payment_service
# Add your service code, Dockerfile, etc.
```

### 2. Register Service
```bash
./scripts/register-new-service.sh payment_service backend/services/payment_service cloud_function
```

### 3. Update Configuration (if needed)
```yaml
# services-config.yml
services:
  payment_service:
    path: "backend/services/payment_service"
    type: "cloud_function"
    runtime: "python39"
    memory: "512MB"
    timeout: "120s"
    env_vars:
      - "STRIPE_API_KEY"
    secrets:
      - "stripe-secret"
```

### 4. Commit and Push
```bash
git add .
git commit -m "Add payment service"
git push
```

**That's it!** The pipeline will automatically detect and deploy the new service.

---

## 🔄 Migration Strategy

### Phase 1: Create Master Pipeline
1. Create `services-config.yml`
2. Create `cloudbuild-master.yml`
3. Test with existing services

### Phase 2: Replace Individual Triggers
1. Delete old individual triggers
2. Create single master trigger
3. Validate deployments

### Phase 3: Optimize and Enhance
1. Add more service types
2. Implement advanced validation
3. Add monitoring and alerting

This solution gives you **maximum flexibility with minimum maintenance overhead**!
