#!/bin/bash

# Setup Master Cloud Build Trigger
# This script creates a single Cloud Build trigger that handles all services dynamically

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Configuration
TRIGGER_NAME="mono-repo-master-trigger"
TRIGGER_DESCRIPTION="Master pipeline for dynamic service deployment"
BUILD_CONFIG="cloudbuild-master.yml"
REGION="us-central1"

print_status "Setting up Master Cloud Build Trigger..."
echo "=================================================="

# Check if gcloud is installed and authenticated
if ! command -v gcloud &> /dev/null; then
    print_error "gcloud CLI is not installed. Please install it first."
    exit 1
fi

# Check if user is authenticated
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | head -n1 > /dev/null; then
    print_error "Not authenticated with gcloud. Please run 'gcloud auth login' first."
    exit 1
fi

# Get current project
PROJECT_ID=$(gcloud config get-value project)
if [ -z "$PROJECT_ID" ]; then
    print_error "No GCP project set. Please run 'gcloud config set project YOUR_PROJECT_ID' first."
    exit 1
fi

print_status "Using GCP Project: $PROJECT_ID"

# Prompt for repository information
echo ""
print_status "Please provide your GitHub repository information:"
read -p "GitHub Username/Organization: " GITHUB_OWNER
read -p "Repository Name: " REPO_NAME

if [ -z "$GITHUB_OWNER" ] || [ -z "$REPO_NAME" ]; then
    print_error "GitHub owner and repository name are required."
    exit 1
fi

# Optional: Slack webhook for notifications
echo ""
read -p "Slack Webhook URL (optional, press Enter to skip): " SLACK_WEBHOOK

# Check if trigger already exists
print_status "Checking if trigger already exists..."
if gcloud builds triggers describe $TRIGGER_NAME --region=$REGION > /dev/null 2>&1; then
    print_warning "Trigger '$TRIGGER_NAME' already exists."
    read -p "Do you want to delete and recreate it? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_status "Deleting existing trigger..."
        gcloud builds triggers delete $TRIGGER_NAME --region=$REGION --quiet
        print_success "Existing trigger deleted."
    else
        print_status "Keeping existing trigger. Exiting."
        exit 0
    fi
fi

# Enable required APIs
print_status "Enabling required APIs..."
gcloud services enable cloudbuild.googleapis.com
gcloud services enable cloudfunctions.googleapis.com
gcloud services enable run.googleapis.com
gcloud services enable secretmanager.googleapis.com

# Create the trigger
print_status "Creating master Cloud Build trigger..."

SUBSTITUTIONS="_REGION=$REGION"
if [ ! -z "$SLACK_WEBHOOK" ]; then
    SUBSTITUTIONS="$SUBSTITUTIONS,_SLACK_WEBHOOK=$SLACK_WEBHOOK"
fi

gcloud builds triggers create github \
    --repo-name=$REPO_NAME \
    --repo-owner=$GITHUB_OWNER \
    --branch-pattern="^(main|develop|feature/.*|hotfix/.*)$" \
    --build-config=$BUILD_CONFIG \
    --name=$TRIGGER_NAME \
    --description="$TRIGGER_DESCRIPTION" \
    --region=$REGION \
    --substitutions="$SUBSTITUTIONS"

if [ $? -eq 0 ]; then
    print_success "Master trigger created successfully!"
else
    print_error "Failed to create trigger."
    exit 1
fi

# Set up IAM permissions for Cloud Build service account
print_status "Setting up IAM permissions..."

PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format="value(projectNumber)")
CLOUD_BUILD_SA="${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com"

print_status "Cloud Build Service Account: $CLOUD_BUILD_SA"

# Grant necessary permissions
ROLES=(
    "roles/cloudfunctions.developer"
    "roles/run.developer"
    "roles/iam.serviceAccountUser"
    "roles/storage.admin"
    "roles/secretmanager.secretAccessor"
)

for ROLE in "${ROLES[@]}"; do
    print_status "Granting role: $ROLE"
    gcloud projects add-iam-policy-binding $PROJECT_ID \
        --member="serviceAccount:$CLOUD_BUILD_SA" \
        --role="$ROLE" \
        --quiet
done

print_success "IAM permissions configured."

# Create example secrets (optional)
echo ""
read -p "Do you want to create example secrets in Secret Manager? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_status "Creating example secrets..."
    
    # Create example secrets
    echo "example-db-password" | gcloud secrets create db-password --data-file=- --quiet 2>/dev/null || print_warning "Secret 'db-password' may already exist"
    echo "example-jwt-secret" | gcloud secrets create jwt-secret --data-file=- --quiet 2>/dev/null || print_warning "Secret 'jwt-secret' may already exist"
    echo "example-smtp-password" | gcloud secrets create smtp-password --data-file=- --quiet 2>/dev/null || print_warning "Secret 'smtp-password' may already exist"
    
    print_success "Example secrets created. Please update them with real values."
fi

# Display summary
echo ""
echo "🎉 Setup Complete!"
echo "==================="
echo "• Trigger Name: $TRIGGER_NAME"
echo "• Repository: $GITHUB_OWNER/$REPO_NAME"
echo "• Build Config: $BUILD_CONFIG"
echo "• Region: $REGION"
echo "• Project: $PROJECT_ID"
echo ""
echo "📋 Next Steps:"
echo "1. Push changes to your repository to trigger the pipeline"
echo "2. Monitor builds in Cloud Build console:"
echo "   https://console.cloud.google.com/cloud-build/builds?project=$PROJECT_ID"
echo "3. Update secrets in Secret Manager with real values"
echo "4. Configure environment variables in services-config.yml"
echo ""
echo "🔧 Manual Trigger (for testing):"
echo "gcloud builds triggers run $TRIGGER_NAME --branch=main --region=$REGION"
echo ""
echo "📊 View Trigger Details:"
echo "gcloud builds triggers describe $TRIGGER_NAME --region=$REGION"

print_success "Master pipeline setup completed successfully!"
