#!/bin/bash

# Local Development Setup Script
# This script sets up the local development environment for the mono repo project

set -e

echo "🚀 Setting up Mono Repo Local Development Environment..."
echo "=================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
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

# Check if Docker is installed
check_docker() {
    print_status "Checking Docker installation..."
    if command -v docker &> /dev/null; then
        print_success "Docker is installed: $(docker --version)"
    else
        print_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    if command -v docker-compose &> /dev/null; then
        print_success "Docker Compose is installed: $(docker-compose --version)"
    else
        print_error "Docker Compose is not installed. Please install Docker Compose first."
        exit 1
    fi
}

# Check if Node.js is installed
check_nodejs() {
    print_status "Checking Node.js installation..."
    if command -v node &> /dev/null; then
        print_success "Node.js is installed: $(node --version)"
        if command -v npm &> /dev/null; then
            print_success "npm is installed: $(npm --version)"
        else
            print_error "npm is not installed. Please install npm."
            exit 1
        fi
    else
        print_error "Node.js is not installed. Please install Node.js (version 16 or higher)."
        exit 1
    fi
}

# Check if Python is installed
check_python() {
    print_status "Checking Python installation..."
    if command -v python3 &> /dev/null; then
        print_success "Python 3 is installed: $(python3 --version)"
        if command -v pip3 &> /dev/null; then
            print_success "pip3 is installed: $(pip3 --version)"
        else
            print_error "pip3 is not installed. Please install pip3."
            exit 1
        fi
    else
        print_error "Python 3 is not installed. Please install Python 3.8 or higher."
        exit 1
    fi
}

# Install Angular CLI
install_angular_cli() {
    print_status "Checking Angular CLI installation..."
    if command -v ng &> /dev/null; then
        print_success "Angular CLI is already installed: $(ng version --version)"
    else
        print_status "Installing Angular CLI globally..."
        npm install -g @angular/cli
        print_success "Angular CLI installed successfully"
    fi
}

# Install frontend dependencies
install_frontend_deps() {
    print_status "Installing frontend dependencies..."
    cd ui
    if [ -f "package.json" ]; then
        npm install
        print_success "Frontend dependencies installed successfully"
    else
        print_error "package.json not found in ui directory"
        exit 1
    fi
    cd ..
}

# Install backend dependencies
install_backend_deps() {
    print_status "Installing backend dependencies..."
    
    # Install dependencies for each service
    services=("user_service" "notification_service" "analytics_service")
    
    for service in "${services[@]}"; do
        service_path="backend/services/$service"
        if [ -d "$service_path" ]; then
            print_status "Installing dependencies for $service..."
            cd "$service_path"
            if [ -f "requirements.txt" ]; then
                pip3 install -r requirements.txt
                print_success "$service dependencies installed"
            else
                print_warning "requirements.txt not found for $service"
            fi
            cd ../../..
        else
            print_warning "Service directory $service_path not found"
        fi
    done
}

# Create environment files
create_env_files() {
    print_status "Creating environment files..."
    
    # Create .env file for docker-compose
    if [ ! -f ".env" ]; then
        cat > .env << EOF
# Database Configuration
POSTGRES_DB=monorepo_db
POSTGRES_USER=monorepo_user
POSTGRES_PASSWORD=monorepo_pass
POSTGRES_HOST=postgres
POSTGRES_PORT=5432

# Redis Configuration
REDIS_HOST=redis
REDIS_PORT=6379

# Application Configuration
ENVIRONMENT=development
DEBUG=true
LOG_LEVEL=INFO

# API Configuration
API_BASE_URL=http://localhost:8000
UI_BASE_URL=http://localhost:4200

# Service Ports
USER_SERVICE_PORT=8001
NOTIFICATION_SERVICE_PORT=8002
ANALYTICS_SERVICE_PORT=8003
EOF
        print_success "Created .env file"
    else
        print_success ".env file already exists"
    fi
}

# Build Docker images
build_docker_images() {
    print_status "Building Docker images..."
    
    # Build backend service images
    services=("user_service" "notification_service" "analytics_service")
    
    for service in "${services[@]}"; do
        service_path="backend/services/$service"
        if [ -d "$service_path" ] && [ -f "$service_path/Dockerfile" ]; then
            print_status "Building Docker image for $service..."
            docker build -t "mono-repo-$service:latest" "$service_path"
            print_success "$service Docker image built"
        else
            print_warning "Dockerfile not found for $service"
        fi
    done
    
    # Build frontend image
    if [ -f "ui/Dockerfile" ]; then
        print_status "Building Docker image for UI..."
        docker build -t "mono-repo-ui:latest" ui/
        print_success "UI Docker image built"
    else
        print_warning "Dockerfile not found for UI"
    fi
}

# Start development environment
start_dev_environment() {
    print_status "Starting development environment with Docker Compose..."
    
    if [ -f "docker-compose.yml" ]; then
        docker-compose up -d
        print_success "Development environment started"
        
        print_status "Waiting for services to be ready..."
        sleep 10
        
        # Check service health
        print_status "Checking service health..."
        if curl -f http://localhost:4200 > /dev/null 2>&1; then
            print_success "UI is running at http://localhost:4200"
        else
            print_warning "UI might still be starting up"
        fi
        
        print_status "Development environment is ready!"
        echo ""
        echo "🎉 Setup Complete!"
        echo "==================="
        echo "• Frontend (Angular): http://localhost:4200"
        echo "• User Service: http://localhost:8001"
        echo "• Notification Service: http://localhost:8002"
        echo "• Analytics Service: http://localhost:8003"
        echo "• PostgreSQL: localhost:5432"
        echo "• Redis: localhost:6379"
        echo ""
        echo "To stop the environment: docker-compose down"
        echo "To view logs: docker-compose logs -f"
        echo "To rebuild: docker-compose up --build"
        
    else
        print_error "docker-compose.yml not found"
        exit 1
    fi
}

# Run tests
run_tests() {
    print_status "Running tests..."
    
    # Run backend tests
    print_status "Running backend tests..."
    services=("user_service" "notification_service" "analytics_service")
    
    for service in "${services[@]}"; do
        service_path="backend/services/$service"
        if [ -d "$service_path" ] && [ -f "$service_path/test_main.py" ]; then
            print_status "Running tests for $service..."
            cd "$service_path"
            python3 -m pytest test_main.py -v
            print_success "$service tests passed"
            cd ../../..
        else
            print_warning "Tests not found for $service"
        fi
    done
    
    # Run frontend tests
    if [ -d "ui" ] && [ -f "ui/karma.conf.js" ]; then
        print_status "Running frontend tests..."
        cd ui
        npm test -- --watch=false --browsers=ChromeHeadless
        print_success "Frontend tests passed"
        cd ..
    else
        print_warning "Frontend tests not configured"
    fi
}

# Main execution
main() {
    echo "Starting setup process..."
    echo ""
    
    # Check prerequisites
    check_docker
    check_nodejs
    check_python
    
    # Install tools and dependencies
    install_angular_cli
    install_frontend_deps
    install_backend_deps
    
    # Setup environment
    create_env_files
    
    # Build and start
    build_docker_images
    start_dev_environment
    
    # Optionally run tests
    read -p "Do you want to run tests? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        run_tests
    fi
    
    print_success "🎉 Local development environment setup complete!"
}

# Run main function
main "$@"
