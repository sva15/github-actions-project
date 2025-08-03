#!/bin/bash

# Setup GCP Secrets and Service Accounts
# This script creates all required secrets and service accounts for the mono repo deployment

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

# Get project configuration
PROJECT_ID=$(gcloud config get-value project)
if [ -z "$PROJECT_ID" ]; then
    print_error "No project configured. Run: gcloud config set project YOUR-PROJECT-ID"
    exit 1
fi

print_status "🔐 Setting up secrets and service accounts for project: $PROJECT_ID"
echo ""

# 1. Create Secret Manager secrets
print_status "Creating Secret Manager secrets..."

# JWT Secret
JWT_SECRET=$(openssl rand -base64 32)
if ! gcloud secrets describe jwt-secret > /dev/null 2>&1; then
    echo -n "$JWT_SECRET" | gcloud secrets create jwt-secret --data-file=-
    print_success "Created secret: jwt-secret"
else
    print_warning "Secret already exists: jwt-secret"
fi

# Database Password
DB_PASSWORD=$(openssl rand -base64 16)
if ! gcloud secrets describe db-password > /dev/null 2>&1; then
    echo -n "$DB_PASSWORD" | gcloud secrets create db-password --data-file=-
    print_success "Created secret: db-password"
else
    print_warning "Secret already exists: db-password"
fi

# API Key (example external service)
API_KEY=$(openssl rand -hex 20)
if ! gcloud secrets describe api-key > /dev/null 2>&1; then
    echo -n "$API_KEY" | gcloud secrets create api-key --data-file=-
    print_success "Created secret: api-key"
else
    print_warning "Secret already exists: api-key"
fi

# SMTP Password (for notifications)
SMTP_PASSWORD=$(openssl rand -base64 16)
if ! gcloud secrets describe smtp-password > /dev/null 2>&1; then
    echo -n "$SMTP_PASSWORD" | gcloud secrets create smtp-password --data-file=-
    print_success "Created secret: smtp-password"
else
    print_warning "Secret already exists: smtp-password"
fi

echo ""

# 2. Create service accounts
print_status "Creating service accounts..."

# User Service Account
USER_SA="user-service"
if ! gcloud iam service-accounts describe "${USER_SA}@${PROJECT_ID}.iam.gserviceaccount.com" > /dev/null 2>&1; then
    gcloud iam service-accounts create $USER_SA \
        --description="Service account for user service" \
        --display-name="User Service"
    print_success "Created service account: $USER_SA"
else
    print_warning "Service account already exists: $USER_SA"
fi

# Notification Service Account
NOTIFICATION_SA="notification-service"
if ! gcloud iam service-accounts describe "${NOTIFICATION_SA}@${PROJECT_ID}.iam.gserviceaccount.com" > /dev/null 2>&1; then
    gcloud iam service-accounts create $NOTIFICATION_SA \
        --description="Service account for notification service" \
        --display-name="Notification Service"
    print_success "Created service account: $NOTIFICATION_SA"
else
    print_warning "Service account already exists: $NOTIFICATION_SA"
fi

# Analytics Service Account
ANALYTICS_SA="analytics-service"
if ! gcloud iam service-accounts describe "${ANALYTICS_SA}@${PROJECT_ID}.iam.gserviceaccount.com" > /dev/null 2>&1; then
    gcloud iam service-accounts create $ANALYTICS_SA \
        --description="Service account for analytics service" \
        --display-name="Analytics Service"
    print_success "Created service account: $ANALYTICS_SA"
else
    print_warning "Service account already exists: $ANALYTICS_SA"
fi

# UI Service Account
UI_SA="ui-service"
if ! gcloud iam service-accounts describe "${UI_SA}@${PROJECT_ID}.iam.gserviceaccount.com" > /dev/null 2>&1; then
    gcloud iam service-accounts create $UI_SA \
        --description="Service account for UI service" \
        --display-name="UI Service"
    print_success "Created service account: $UI_SA"
else
    print_warning "Service account already exists: $UI_SA"
fi

echo ""

# 3. Grant IAM permissions
print_status "Granting IAM permissions..."

# Grant Secret Manager access to service accounts
SERVICE_ACCOUNTS=("$USER_SA" "$NOTIFICATION_SA" "$ANALYTICS_SA" "$UI_SA")

for SA in "${SERVICE_ACCOUNTS[@]}"; do
    # Secret Manager Secret Accessor
    gcloud projects add-iam-policy-binding $PROJECT_ID \
        --member="serviceAccount:${SA}@${PROJECT_ID}.iam.gserviceaccount.com" \
        --role="roles/secretmanager.secretAccessor" \
        --quiet
    
    # Cloud Logging Writer
    gcloud projects add-iam-policy-binding $PROJECT_ID \
        --member="serviceAccount:${SA}@${PROJECT_ID}.iam.gserviceaccount.com" \
        --role="roles/logging.logWriter" \
        --quiet
    
    # Cloud Monitoring Metric Writer
    gcloud projects add-iam-policy-binding $PROJECT_ID \
        --member="serviceAccount:${SA}@${PROJECT_ID}.iam.gserviceaccount.com" \
        --role="roles/monitoring.metricWriter" \
        --quiet
    
    print_success "Granted permissions to: $SA"
done

# Grant additional permissions for specific services
# Analytics service needs BigQuery access (if using BigQuery)
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:${ANALYTICS_SA}@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role="roles/bigquery.dataEditor" \
    --quiet

# Notification service needs Pub/Sub access (if using Pub/Sub)
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:${NOTIFICATION_SA}@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role="roles/pubsub.publisher" \
    --quiet

echo ""

# 4. Grant secret access to specific service accounts
print_status "Granting secret access permissions..."

# JWT secret - accessible by user service and UI service
gcloud secrets add-iam-policy-binding jwt-secret \
    --member="serviceAccount:${USER_SA}@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role="roles/secretmanager.secretAccessor" \
    --quiet

gcloud secrets add-iam-policy-binding jwt-secret \
    --member="serviceAccount:${UI_SA}@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role="roles/secretmanager.secretAccessor" \
    --quiet

# DB password - accessible by all backend services
for SA in "$USER_SA" "$NOTIFICATION_SA" "$ANALYTICS_SA"; do
    gcloud secrets add-iam-policy-binding db-password \
        --member="serviceAccount:${SA}@${PROJECT_ID}.iam.gserviceaccount.com" \
        --role="roles/secretmanager.secretAccessor" \
        --quiet
done

# SMTP password - accessible by notification service
gcloud secrets add-iam-policy-binding smtp-password \
    --member="serviceAccount:${NOTIFICATION_SA}@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role="roles/secretmanager.secretAccessor" \
    --quiet

# API key - accessible by all services
for SA in "${SERVICE_ACCOUNTS[@]}"; do
    gcloud secrets add-iam-policy-binding api-key \
        --member="serviceAccount:${SA}@${PROJECT_ID}.iam.gserviceaccount.com" \
        --role="roles/secretmanager.secretAccessor" \
        --quiet
done

print_success "Secret access permissions configured"

echo ""

# 5. Create Cloud Build service account permissions
print_status "Configuring Cloud Build permissions..."

# Get Cloud Build service account
CLOUD_BUILD_SA="${PROJECT_ID}@cloudbuild.gserviceaccount.com"

# Grant Cloud Build the ability to act as service accounts
for SA in "${SERVICE_ACCOUNTS[@]}"; do
    gcloud iam service-accounts add-iam-policy-binding \
        "${SA}@${PROJECT_ID}.iam.gserviceaccount.com" \
        --member="serviceAccount:${CLOUD_BUILD_SA}" \
        --role="roles/iam.serviceAccountUser" \
        --quiet
done

print_success "Cloud Build permissions configured"

echo ""

# 6. Display summary
print_status "📋 Setup Summary:"
echo ""
echo "🔐 Secrets Created:"
echo "  • jwt-secret (JWT signing key)"
echo "  • db-password (Database password)"
echo "  • api-key (External API key)"
echo "  • smtp-password (SMTP server password)"
echo ""
echo "👤 Service Accounts Created:"
echo "  • user-service@${PROJECT_ID}.iam.gserviceaccount.com"
echo "  • notification-service@${PROJECT_ID}.iam.gserviceaccount.com"
echo "  • analytics-service@${PROJECT_ID}.iam.gserviceaccount.com"
echo "  • ui-service@${PROJECT_ID}.iam.gserviceaccount.com"
echo ""
echo "🔑 Permissions Granted:"
echo "  • Secret Manager access"
echo "  • Cloud Logging access"
echo "  • Cloud Monitoring access"
echo "  • Service-specific permissions"
echo ""

# 7. Generate environment file for local testing
print_status "Creating .env file for local testing..."

cat > .env.example << EOF
# Environment variables for local testing
# Copy this to .env and update values as needed

# Database Configuration
DATABASE_URL=postgresql://user:${DB_PASSWORD}@localhost:5432/mono_repo_db
DB_PASSWORD=${DB_PASSWORD}

# JWT Configuration
JWT_SECRET_KEY=${JWT_SECRET}

# External API Configuration
API_KEY=${API_KEY}
API_BASE_URL=https://api.example.com

# SMTP Configuration (for notifications)
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=your-email@gmail.com
SMTP_PASSWORD=${SMTP_PASSWORD}

# Environment
ENVIRONMENT=development
LOG_LEVEL=DEBUG

# CORS Configuration
CORS_ORIGINS=http://localhost:4200,http://localhost:8080

# GCP Configuration
PROJECT_ID=${PROJECT_ID}
REGION=us-central1
EOF

print_success "Created .env.example file"

echo ""
print_status "🎯 Next Steps:"
echo "1. Copy .env.example to .env and update values"
echo "2. Test services locally with: python -m pytest"
echo "3. Run the master pipeline setup: ./setup-master-trigger.sh"
echo "4. Deploy to GCP: git push origin main"
echo ""
print_success "✅ GCP secrets and service accounts setup completed!"

# 8. Verify setup
print_status "🔍 Verifying setup..."

echo "Checking secrets..."
gcloud secrets list --format="table(name,createTime)" --filter="name:(jwt-secret OR db-password OR api-key OR smtp-password)"

echo ""
echo "Checking service accounts..."
gcloud iam service-accounts list --format="table(email,displayName)" --filter="email:(user-service OR notification-service OR analytics-service OR ui-service)"

echo ""
print_success "🎉 Setup verification completed!"
