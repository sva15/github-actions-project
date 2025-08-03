#!/bin/bash

# GCP Prerequisites Validation Script
# This script checks if your environment is ready for GCP deployment

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
    echo -e "${GREEN}[✅ PASS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[⚠️  WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[❌ FAIL]${NC} $1"
}

ERRORS=0
WARNINGS=0

print_status "🔍 Validating GCP Deployment Prerequisites..."
echo ""

# Check 1: gcloud CLI
print_status "Checking Google Cloud SDK..."
if command -v gcloud &> /dev/null; then
    GCLOUD_VERSION=$(gcloud version --format="value(Google Cloud SDK)" 2>/dev/null)
    print_success "gcloud CLI installed (version: $GCLOUD_VERSION)"
    
    # Check if authenticated
    if gcloud auth list --filter=status:ACTIVE --format="value(account)" | head -n1 | grep -q "@"; then
        ACTIVE_ACCOUNT=$(gcloud auth list --filter=status:ACTIVE --format="value(account)" | head -n1)
        print_success "Authenticated as: $ACTIVE_ACCOUNT"
    else
        print_error "Not authenticated. Run: gcloud auth login"
        ERRORS=$((ERRORS + 1))
    fi
    
    # Check project configuration
    PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
    if [ ! -z "$PROJECT_ID" ]; then
        print_success "Project configured: $PROJECT_ID"
    else
        print_error "No project configured. Run: gcloud config set project YOUR-PROJECT-ID"
        ERRORS=$((ERRORS + 1))
    fi
    
    # Check region configuration
    REGION=$(gcloud config get-value compute/region 2>/dev/null)
    if [ ! -z "$REGION" ]; then
        print_success "Region configured: $REGION"
    else
        print_warning "No default region set. Run: gcloud config set compute/region us-central1"
        WARNINGS=$((WARNINGS + 1))
    fi
else
    print_error "gcloud CLI not found. Install from: https://cloud.google.com/sdk/docs/install"
    ERRORS=$((ERRORS + 1))
fi

echo ""

# Check 2: Docker
print_status "Checking Docker..."
if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker --version | cut -d' ' -f3 | cut -d',' -f1)
    print_success "Docker installed (version: $DOCKER_VERSION)"
    
    # Check if Docker daemon is running
    if docker info &> /dev/null; then
        print_success "Docker daemon is running"
    else
        print_error "Docker daemon not running. Start Docker Desktop or service"
        ERRORS=$((ERRORS + 1))
    fi
else
    print_error "Docker not found. Install from: https://docs.docker.com/get-docker/"
    ERRORS=$((ERRORS + 1))
fi

echo ""

# Check 3: Git
print_status "Checking Git..."
if command -v git &> /dev/null; then
    GIT_VERSION=$(git --version | cut -d' ' -f3)
    print_success "Git installed (version: $GIT_VERSION)"
    
    # Check git configuration
    if git config user.name &> /dev/null && git config user.email &> /dev/null; then
        GIT_USER=$(git config user.name)
        GIT_EMAIL=$(git config user.email)
        print_success "Git configured (user: $GIT_USER, email: $GIT_EMAIL)"
    else
        print_warning "Git not configured. Run: git config --global user.name 'Your Name' && git config --global user.email 'your@email.com'"
        WARNINGS=$((WARNINGS + 1))
    fi
else
    print_error "Git not found. Install from: https://git-scm.com/downloads"
    ERRORS=$((ERRORS + 1))
fi

echo ""

# Check 4: Node.js (for UI)
print_status "Checking Node.js..."
if command -v node &> /dev/null; then
    NODE_VERSION=$(node --version)
    print_success "Node.js installed (version: $NODE_VERSION)"
    
    # Check npm
    if command -v npm &> /dev/null; then
        NPM_VERSION=$(npm --version)
        print_success "npm installed (version: $NPM_VERSION)"
    else
        print_warning "npm not found"
        WARNINGS=$((WARNINGS + 1))
    fi
else
    print_error "Node.js not found. Install from: https://nodejs.org/"
    ERRORS=$((ERRORS + 1))
fi

echo ""

# Check 5: Python (for backend)
print_status "Checking Python..."
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version | cut -d' ' -f2)
    print_success "Python installed (version: $PYTHON_VERSION)"
    
    # Check pip
    if command -v pip3 &> /dev/null; then
        PIP_VERSION=$(pip3 --version | cut -d' ' -f2)
        print_success "pip installed (version: $PIP_VERSION)"
    else
        print_warning "pip3 not found"
        WARNINGS=$((WARNINGS + 1))
    fi
else
    print_error "Python 3 not found. Install from: https://www.python.org/downloads/"
    ERRORS=$((ERRORS + 1))
fi

echo ""

# Check 6: Required files
print_status "Checking project files..."
REQUIRED_FILES=(
    "services-config.yml"
    "cloudbuild-master.yml"
    "setup-master-trigger.sh"
    "backend/services/user_service/main.py"
    "backend/services/notification_service/main.py"
    "backend/services/analytics_service/main.py"
    "ui/Dockerfile"
    "ui/package.json"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        print_success "Found: $file"
    else
        print_error "Missing: $file"
        ERRORS=$((ERRORS + 1))
    fi
done

echo ""

# Check 7: GCP APIs (if project is configured)
if [ ! -z "$PROJECT_ID" ]; then
    print_status "Checking GCP APIs..."
    
    REQUIRED_APIS=(
        "cloudbuild.googleapis.com"
        "cloudfunctions.googleapis.com"
        "run.googleapis.com"
        "containerregistry.googleapis.com"
        "secretmanager.googleapis.com"
    )
    
    for api in "${REQUIRED_APIS[@]}"; do
        if gcloud services list --enabled --filter="name:$api" --format="value(name)" | grep -q "$api"; then
            print_success "API enabled: $api"
        else
            print_warning "API not enabled: $api (will be enabled by setup script)"
            WARNINGS=$((WARNINGS + 1))
        fi
    done
fi

echo ""

# Check 8: Billing (if project is configured)
if [ ! -z "$PROJECT_ID" ]; then
    print_status "Checking billing..."
    
    if gcloud billing projects describe "$PROJECT_ID" --format="value(billingEnabled)" 2>/dev/null | grep -q "True"; then
        print_success "Billing is enabled"
    else
        print_error "Billing not enabled. Enable billing in GCP Console"
        ERRORS=$((ERRORS + 1))
    fi
fi

echo ""

# Summary
print_status "📊 Validation Summary:"
echo "Errors: $ERRORS"
echo "Warnings: $WARNINGS"

if [ $ERRORS -eq 0 ]; then
    print_success "🎉 All critical prerequisites met! You're ready for GCP deployment."
    echo ""
    print_status "Next steps:"
    echo "1. Run: chmod +x setup-master-trigger.sh"
    echo "2. Run: ./setup-master-trigger.sh"
    echo "3. Push your code to trigger deployment"
    
    if [ $WARNINGS -gt 0 ]; then
        echo ""
        print_warning "Please address the warnings above for optimal experience."
    fi
else
    print_error "❌ $ERRORS critical issues found. Please fix them before proceeding."
    echo ""
    print_status "Common fixes:"
    echo "• Install missing tools"
    echo "• Run: gcloud auth login"
    echo "• Run: gcloud config set project YOUR-PROJECT-ID"
    echo "• Enable billing in GCP Console"
    echo "• Create missing project files"
fi

echo ""
print_status "For detailed setup instructions, see: GCP_DEPLOYMENT_TESTING_GUIDE.md"
