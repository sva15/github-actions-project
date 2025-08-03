# Service-Level Pipeline Triggering Strategies

## 🎯 The Challenge
In a mono repo with multiple services, we need to:
1. **Detect which service changed** in a commit/PR
2. **Trigger only the relevant pipeline** for that service
3. **Avoid unnecessary deployments** of unchanged services
4. **Handle dependencies** between services

---

## 🔧 Strategy 1: Cloud Build Triggers with Path Filters (GCP)

### How it Works:
- Create **separate Cloud Build triggers** for each service
- Use **includedFiles** to monitor specific paths
- Trigger automatically on git push to monitored paths

### Implementation:

#### User Service Trigger
```yaml
# Trigger Name: mono-repo-user-service-trigger
name: mono-repo-user-service-pipeline
description: "Triggers when user service files change"

github:
  owner: your-username
  name: your-repo
  push:
    branch: "^(main|develop|feature/.*)$"

includedFiles:
  - "backend/services/user_service/**"
  - "backend/shared/**"  # Shared dependencies
  
ignoredFiles:
  - "**/*.md"
  - "**/*.txt"
  - "**/test_*.py"  # Don't trigger on test-only changes

filename: "backend/services/user_service/cloudbuild.yml"
```

#### Notification Service Trigger
```yaml
# Trigger Name: mono-repo-notification-service-trigger
name: mono-repo-notification-service-pipeline

github:
  owner: your-username
  name: your-repo
  push:
    branch: "^(main|develop|feature/.*)$"

includedFiles:
  - "backend/services/notification_service/**"
  - "backend/shared/**"
  
filename: "backend/services/notification_service/cloudbuild.yml"
```

#### Analytics Service Trigger
```yaml
# Trigger Name: mono-repo-analytics-service-trigger
name: mono-repo-analytics-service-pipeline

github:
  owner: your-username
  name: your-repo
  push:
    branch: "^(main|develop|feature/.*)$"

includedFiles:
  - "backend/services/analytics_service/**"
  - "backend/shared/**"
  
filename: "backend/services/analytics_service/cloudbuild.yml"
```

### Creating Triggers via gcloud CLI:
```bash
# User Service Trigger
gcloud builds triggers create github \
  --repo-name=your-repo \
  --repo-owner=your-username \
  --branch-pattern="^(main|develop|feature/.*)$" \
  --build-config=backend/services/user_service/cloudbuild.yml \
  --included-files="backend/services/user_service/**,backend/shared/**" \
  --ignored-files="**/*.md,**/*.txt" \
  --name=mono-repo-user-service-trigger

# Notification Service Trigger  
gcloud builds triggers create github \
  --repo-name=your-repo \
  --repo-owner=your-username \
  --branch-pattern="^(main|develop|feature/.*)$" \
  --build-config=backend/services/notification_service/cloudbuild.yml \
  --included-files="backend/services/notification_service/**,backend/shared/**" \
  --ignored-files="**/*.md,**/*.txt" \
  --name=mono-repo-notification-service-trigger

# Analytics Service Trigger
gcloud builds triggers create github \
  --repo-name=your-repo \
  --repo-owner=your-username \
  --branch-pattern="^(main|develop|feature/.*)$" \
  --build-config=backend/services/analytics_service/cloudbuild.yml \
  --included-files="backend/services/analytics_service/**,backend/shared/**" \
  --ignored-files="**/*.md,**/*.txt" \
  --name=mono-repo-analytics-service-trigger

# UI Service Trigger
gcloud builds triggers create github \
  --repo-name=your-repo \
  --repo-owner=your-username \
  --branch-pattern="^(main|develop|feature/.*)$" \
  --build-config=ui/cloudbuild.yml \
  --included-files="ui/**" \
  --ignored-files="**/*.md" \
  --name=mono-repo-ui-trigger
```

---

## 🔧 Strategy 2: AWS CodePipeline with Lambda Change Detection

### How it Works:
- **Single CodePipeline** triggered on any repo change
- **Lambda function** analyzes changed files
- **Conditionally triggers** service-specific CodeBuild projects

### Implementation:

#### Lambda Change Detection Function
```python
import json
import boto3
import subprocess
import os

def lambda_handler(event, context):
    """
    Analyzes git changes and triggers appropriate CodeBuild projects
    """
    codebuild = boto3.client('codebuild')
    
    # Get commit info from CodePipeline
    commit_id = event['CodePipeline.job']['data']['inputArtifacts'][0]['revision']
    
    # Detect changed services
    changed_services = detect_changed_services(commit_id)
    
    # Trigger appropriate builds
    triggered_builds = []
    for service in changed_services:
        build_project = f"mono-repo-{service}-build"
        
        response = codebuild.start_build(
            projectName=build_project,
            environmentVariablesOverride=[
                {
                    'name': 'COMMIT_ID',
                    'value': commit_id
                },
                {
                    'name': 'SERVICE_NAME', 
                    'value': service
                }
            ]
        )
        triggered_builds.append({
            'service': service,
            'buildId': response['build']['id']
        })
    
    return {
        'statusCode': 200,
        'body': json.dumps({
            'triggeredBuilds': triggered_builds,
            'changedServices': changed_services
        })
    }

def detect_changed_services(commit_id):
    """
    Detect which services changed in the commit
    """
    # This would run git diff to detect changes
    # For demo, returning mock data
    changed_files = [
        'backend/services/user_service/main.py',
        'ui/src/app/dashboard/dashboard.component.ts'
    ]
    
    services = set()
    for file_path in changed_files:
        if file_path.startswith('backend/services/'):
            service = file_path.split('/')[2]  # Extract service name
            services.add(service)
        elif file_path.startswith('ui/'):
            services.add('ui')
    
    return list(services)
```

---

## 🔧 Strategy 3: GitHub Actions with External API Triggers

### How it Works:
- **GitHub Actions** detects changes and runs tests
- **External API calls** trigger cloud pipelines
- **Secure token-based** authentication

### Implementation:

```yaml
# .github/workflows/trigger-deployments.yml
name: Trigger Service Deployments

on:
  push:
    branches: [main, develop, 'feature/*']

jobs:
  detect-changes:
    runs-on: ubuntu-latest
    outputs:
      changed-services: ${{ steps.changes.outputs.services }}
    
    steps:
    - uses: actions/checkout@v3
      with:
        fetch-depth: 2
    
    - name: Detect changed services
      id: changes
      run: |
        # Get changed files
        CHANGED_FILES=$(git diff --name-only HEAD~1 HEAD)
        
        # Detect services
        SERVICES=""
        if echo "$CHANGED_FILES" | grep -q "backend/services/user_service/"; then
          SERVICES="$SERVICES user_service"
        fi
        if echo "$CHANGED_FILES" | grep -q "backend/services/notification_service/"; then
          SERVICES="$SERVICES notification_service"  
        fi
        if echo "$CHANGED_FILES" | grep -q "backend/services/analytics_service/"; then
          SERVICES="$SERVICES analytics_service"
        fi
        if echo "$CHANGED_FILES" | grep -q "ui/"; then
          SERVICES="$SERVICES ui"
        fi
        
        echo "services=$SERVICES" >> $GITHUB_OUTPUT
        echo "Changed services: $SERVICES"

  trigger-gcp-builds:
    needs: detect-changes
    runs-on: ubuntu-latest
    if: needs.detect-changes.outputs.changed-services != ''
    
    steps:
    - name: Trigger GCP Cloud Build
      run: |
        SERVICES="${{ needs.detect-changes.outputs.changed-services }}"
        BRANCH_NAME=${GITHUB_REF#refs/heads/}
        
        for SERVICE in $SERVICES; do
          echo "Triggering build for service: $SERVICE"
          
          # Get trigger ID for service
          case $SERVICE in
            "user_service")
              TRIGGER_ID="${{ secrets.GCP_USER_SERVICE_TRIGGER_ID }}"
              ;;
            "notification_service") 
              TRIGGER_ID="${{ secrets.GCP_NOTIFICATION_SERVICE_TRIGGER_ID }}"
              ;;
            "analytics_service")
              TRIGGER_ID="${{ secrets.GCP_ANALYTICS_SERVICE_TRIGGER_ID }}"
              ;;
            "ui")
              TRIGGER_ID="${{ secrets.GCP_UI_TRIGGER_ID }}"
              ;;
          esac
          
          # Trigger Cloud Build via API
          curl -X POST \
            "https://cloudbuild.googleapis.com/v1/projects/${{ secrets.GCP_PROJECT_ID }}/triggers/$TRIGGER_ID:run" \
            -H "Authorization: Bearer ${{ secrets.GCP_ACCESS_TOKEN }}" \
            -H "Content-Type: application/json" \
            -d "{
              \"branchName\": \"$BRANCH_NAME\",
              \"substitutions\": {
                \"_SERVICE_NAME\": \"$SERVICE\",
                \"_BRANCH_NAME\": \"$BRANCH_NAME\"
              }
            }"
        done

  trigger-aws-builds:
    needs: detect-changes  
    runs-on: ubuntu-latest
    if: needs.detect-changes.outputs.changed-services != ''
    
    steps:
    - name: Configure AWS credentials
      uses: aws-actions/configure-aws-credentials@v2
      with:
        aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
        aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        aws-region: us-east-1
    
    - name: Trigger AWS CodeBuild
      run: |
        SERVICES="${{ needs.detect-changes.outputs.changed-services }}"
        BRANCH_NAME=${GITHUB_REF#refs/heads/}
        
        for SERVICE in $SERVICES; do
          echo "Triggering AWS build for service: $SERVICE"
          
          PROJECT_NAME="mono-repo-$SERVICE"
          
          aws codebuild start-build \
            --project-name $PROJECT_NAME \
            --environment-variables-override \
              name=BRANCH_NAME,value=$BRANCH_NAME \
              name=SERVICE_NAME,value=$SERVICE
        done
```

---

## 🔧 Strategy 4: Master Pipeline with Service Detection

### How it Works:
- **Single master pipeline** triggered on any change
- **Built-in change detection** within the pipeline
- **Conditional execution** of service-specific steps

### Implementation:

```yaml
# master-pipeline-cloudbuild.yml
steps:
# Step 1: Detect changed services
- name: 'gcr.io/cloud-builders/git'
  entrypoint: 'bash'
  args:
  - '-c'
  - |
    # Get changed files between commits
    CHANGED_FILES=$(git diff --name-only HEAD~1 HEAD)
    echo "Changed files: $CHANGED_FILES"
    
    # Detect services
    CHANGED_SERVICES=""
    if echo "$CHANGED_FILES" | grep -q "backend/services/user_service/"; then
      CHANGED_SERVICES="$CHANGED_SERVICES user_service"
    fi
    if echo "$CHANGED_FILES" | grep -q "backend/services/notification_service/"; then
      CHANGED_SERVICES="$CHANGED_SERVICES notification_service"
    fi
    if echo "$CHANGED_FILES" | grep -q "backend/services/analytics_service/"; then
      CHANGED_SERVICES="$CHANGED_SERVICES analytics_service"
    fi
    if echo "$CHANGED_FILES" | grep -q "ui/"; then
      CHANGED_SERVICES="$CHANGED_SERVICES ui"
    fi
    
    echo "Changed services: $CHANGED_SERVICES"
    echo "$CHANGED_SERVICES" > /workspace/changed_services.txt

# Step 2: Build and deploy user service (conditional)
- name: 'gcr.io/cloud-builders/gcloud'
  entrypoint: 'bash'
  args:
  - '-c'
  - |
    CHANGED_SERVICES=$(cat /workspace/changed_services.txt)
    if echo "$CHANGED_SERVICES" | grep -q "user_service"; then
      echo "Building user service..."
      gcloud builds submit backend/services/user_service/ \
        --config=backend/services/user_service/cloudbuild.yml \
        --substitutions=_SERVICE_NAME=user_service,_BRANCH_NAME=$BRANCH_NAME
    else
      echo "User service unchanged, skipping..."
    fi

# Step 3: Build and deploy notification service (conditional)  
- name: 'gcr.io/cloud-builders/gcloud'
  entrypoint: 'bash'
  args:
  - '-c'
  - |
    CHANGED_SERVICES=$(cat /workspace/changed_services.txt)
    if echo "$CHANGED_SERVICES" | grep -q "notification_service"; then
      echo "Building notification service..."
      gcloud builds submit backend/services/notification_service/ \
        --config=backend/services/notification_service/cloudbuild.yml \
        --substitutions=_SERVICE_NAME=notification_service,_BRANCH_NAME=$BRANCH_NAME
    else
      echo "Notification service unchanged, skipping..."
    fi

# Step 4: Build and deploy analytics service (conditional)
- name: 'gcr.io/cloud-builders/gcloud'  
  entrypoint: 'bash'
  args:
  - '-c'
  - |
    CHANGED_SERVICES=$(cat /workspace/changed_services.txt)
    if echo "$CHANGED_SERVICES" | grep -q "analytics_service"; then
      echo "Building analytics service..."
      gcloud builds submit backend/services/analytics_service/ \
        --config=backend/services/analytics_service/cloudbuild.yml \
        --substitutions=_SERVICE_NAME=analytics_service,_BRANCH_NAME=$BRANCH_NAME
    else
      echo "Analytics service unchanged, skipping..."
    fi

# Step 5: Build and deploy UI (conditional)
- name: 'gcr.io/cloud-builders/gcloud'
  entrypoint: 'bash' 
  args:
  - '-c'
  - |
    CHANGED_SERVICES=$(cat /workspace/changed_services.txt)
    if echo "$CHANGED_SERVICES" | grep -q "ui"; then
      echo "Building UI..."
      gcloud builds submit ui/ \
        --config=ui/cloudbuild.yml \
        --substitutions=_SERVICE_NAME=ui,_BRANCH_NAME=$BRANCH_NAME
    else
      echo "UI unchanged, skipping..."
    fi

substitutions:
  _BRANCH_NAME: ${BRANCH_NAME}
```

---

## 📊 Comparison of Strategies

| Strategy | Pros | Cons | Best For |
|----------|------|------|----------|
| **Path-based Triggers** | Simple, automatic, parallel execution | Many triggers to manage | Small to medium teams |
| **Lambda Detection** | Centralized logic, flexible | Complex setup, AWS-specific | AWS-heavy environments |
| **GitHub Actions + API** | Familiar workflow, secure | API rate limits, complexity | GitHub-centric teams |
| **Master Pipeline** | Single pipeline, simple setup | Sequential execution, slower | Simple deployments |

---

## 🎯 Recommended Approach

For your use case, I recommend **Strategy 1: Path-based Triggers** because:

1. ✅ **Automatic detection** - No manual intervention needed
2. ✅ **Parallel execution** - Services deploy simultaneously  
3. ✅ **Simple to understand** - Clear path-to-pipeline mapping
4. ✅ **Secure** - No credentials in GitHub Actions
5. ✅ **Scalable** - Easy to add new services

Would you like me to implement the path-based trigger strategy for your services?
