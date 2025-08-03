#!/bin/bash

# AWS Prerequisites Validation Script
# This script checks if your environment is ready for AWS deployment

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

print_status "🔍 Validating AWS Deployment Prerequisites..."
echo ""

# Check 1: AWS CLI
print_status "Checking AWS CLI..."
if command -v aws &> /dev/null; then
    AWS_VERSION=$(aws --version | cut -d' ' -f1 | cut -d'/' -f2)
    print_success "AWS CLI installed (version: $AWS_VERSION)"
    
    # Check if authenticated
    if aws sts get-caller-identity &> /dev/null; then
        ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
        USER_ARN=$(aws sts get-caller-identity --query Arn --output text)
        print_success "Authenticated as: $USER_ARN"
        print_success "Account ID: $ACCOUNT_ID"
    else
        print_error "Not authenticated. Run: aws configure"
        ERRORS=$((ERRORS + 1))
    fi
    
    # Check region configuration
    REGION=$(aws configure get region 2>/dev/null)
    if [ ! -z "$REGION" ]; then
        print_success "Region configured: $REGION"
    else
        print_error "No default region set. Run: aws configure set region us-east-1"
        ERRORS=$((ERRORS + 1))
    fi
    
    # Check output format
    OUTPUT_FORMAT=$(aws configure get output 2>/dev/null)
    if [ ! -z "$OUTPUT_FORMAT" ]; then
        print_success "Output format: $OUTPUT_FORMAT"
    else
        print_warning "No output format set. Run: aws configure set output json"
        WARNINGS=$((WARNINGS + 1))
    fi
else
    print_error "AWS CLI not found. Install from: https://aws.amazon.com/cli/"
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

# Check 6: Zip utility
print_status "Checking zip utility..."
if command -v zip &> /dev/null; then
    ZIP_VERSION=$(zip -v | head -n2 | tail -n1 | cut -d' ' -f4)
    print_success "zip installed (version: $ZIP_VERSION)"
else
    print_error "zip not found. Install: apt-get install zip (Linux) or brew install zip (macOS)"
    ERRORS=$((ERRORS + 1))
fi

echo ""

# Check 7: Required files
print_status "Checking project files..."
REQUIRED_FILES=(
    "aws-services-config.yml"
    "buildspec-master.yml"
    "setup-aws-master-pipeline.sh"
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

# Check 8: AWS Permissions (if authenticated)
if [ ! -z "$ACCOUNT_ID" ]; then
    print_status "Checking AWS permissions..."
    
    # Test basic permissions
    PERMISSION_TESTS=(
        "s3:ListAllMyBuckets"
        "lambda:ListFunctions"
        "iam:ListRoles"
        "codebuild:ListProjects"
        "ssm:DescribeParameters"
    )
    
    # Test S3 access
    if aws s3 ls &> /dev/null; then
        print_success "S3 access: OK"
    else
        print_warning "S3 access: Limited or denied"
        WARNINGS=$((WARNINGS + 1))
    fi
    
    # Test Lambda access
    if aws lambda list-functions --max-items 1 &> /dev/null; then
        print_success "Lambda access: OK"
    else
        print_warning "Lambda access: Limited or denied"
        WARNINGS=$((WARNINGS + 1))
    fi
    
    # Test IAM access
    if aws iam list-roles --max-items 1 &> /dev/null; then
        print_success "IAM access: OK"
    else
        print_warning "IAM access: Limited or denied"
        WARNINGS=$((WARNINGS + 1))
    fi
    
    # Test CodeBuild access
    if aws codebuild list-projects &> /dev/null; then
        print_success "CodeBuild access: OK"
    else
        print_warning "CodeBuild access: Limited or denied"
        WARNINGS=$((WARNINGS + 1))
    fi
    
    # Test Systems Manager access
    if aws ssm describe-parameters --max-items 1 &> /dev/null; then
        print_success "Systems Manager access: OK"
    else
        print_warning "Systems Manager access: Limited or denied"
        WARNINGS=$((WARNINGS + 1))
    fi
fi

echo ""

# Check 9: AWS Account Limits
if [ ! -z "$ACCOUNT_ID" ]; then
    print_status "Checking AWS service limits..."
    
    # Check Lambda limits
    if aws lambda get-account-settings &> /dev/null; then
        LAMBDA_CONCURRENT=$(aws lambda get-account-settings --query 'AccountLimit.ConcurrentExecutions' --output text)
        if [ "$LAMBDA_CONCURRENT" != "None" ] && [ "$LAMBDA_CONCURRENT" -gt 0 ]; then
            print_success "Lambda concurrent executions limit: $LAMBDA_CONCURRENT"
        else
            print_warning "Lambda concurrent executions limit not available"
            WARNINGS=$((WARNINGS + 1))
        fi
    fi
    
    # Check EC2 limits (this requires specific region)
    if [ ! -z "$REGION" ]; then
        # Try to describe instances to test EC2 access
        if aws ec2 describe-instances --max-items 1 &> /dev/null; then
            print_success "EC2 access: OK"
        else
            print_warning "EC2 access: Limited or denied"
            WARNINGS=$((WARNINGS + 1))
        fi
    fi
fi

echo ""

# Check 10: Billing and Cost Management
if [ ! -z "$ACCOUNT_ID" ]; then
    print_status "Checking billing access..."
    
    # Test Cost Explorer access (may not be available in all regions/accounts)
    if aws ce get-cost-and-usage \
        --time-period Start=$(date -d '7 days ago' +%Y-%m-%d),End=$(date +%Y-%m-%d) \
        --granularity DAILY \
        --metrics BlendedCost &> /dev/null; then
        print_success "Cost Explorer access: OK"
    else
        print_warning "Cost Explorer access: Limited (this is normal for new accounts)"
        WARNINGS=$((WARNINGS + 1))
    fi
fi

echo ""

# Summary
print_status "📊 Validation Summary:"
echo "Errors: $ERRORS"
echo "Warnings: $WARNINGS"

if [ $ERRORS -eq 0 ]; then
    print_success "🎉 All critical prerequisites met! You're ready for AWS deployment."
    echo ""
    print_status "Next steps:"
    echo "1. Run: chmod +x setup-aws-master-pipeline.sh"
    echo "2. Run: ./setup-aws-master-pipeline.sh"
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
    echo "• Run: aws configure"
    echo "• Set default region: aws configure set region us-east-1"
    echo "• Check IAM permissions for your user"
    echo "• Create missing project files"
fi

echo ""

# Additional recommendations
print_status "💡 Recommendations:"
echo "• Use IAM user (not root account) for deployment"
echo "• Enable MFA on your AWS account"
echo "• Set up billing alerts in AWS Console"
echo "• Review AWS service quotas for your region"
echo "• Consider using AWS Organizations for multi-account setup"

echo ""
print_status "For detailed setup instructions, see: AWS_DEPLOYMENT_TESTING_GUIDE.md"

# Cost estimation
if [ $ERRORS -eq 0 ]; then
    echo ""
    print_status "💰 Estimated Monthly Costs (Production):"
    echo "• Lambda Functions: $25-60 (moderate traffic)"
    echo "• EC2 Instances: $25-35 (t3.medium always-on)"
    echo "• Load Balancer: $20-25 (Application Load Balancer)"
    echo "• CodeBuild: $15-40 (daily builds)"
    echo "• S3 Storage: $5-15 (artifacts and logs)"
    echo "• Data Transfer: $10-30 (depending on usage)"
    echo "• Total Estimated: $100-205/month"
    echo ""
    print_warning "💡 Tip: Use t3.micro instances and scale-to-zero for dev/staging to reduce costs"
fi
