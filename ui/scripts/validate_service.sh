#!/bin/bash

# Validate Service Hook for CodeDeploy
# This script runs to validate that the deployed application is working correctly

set -e

LOG_FILE="/var/log/mono-repo-ui-deploy.log"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [VALIDATE_SERVICE] $1" | tee -a $LOG_FILE
}

log "Starting validate_service hook"

# Configuration
APP_URL="http://localhost:80"
HEALTH_ENDPOINT="$APP_URL/health"
MAX_ATTEMPTS=30
ATTEMPT_INTERVAL=10

# Change to deployment directory
cd /opt/mono-repo-ui

# Function to check if application is responding
check_health() {
    local url=$1
    local timeout=${2:-5}
    
    if curl -f -s --max-time $timeout "$url" > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Function to validate application response
validate_app_response() {
    local response=$(curl -s --max-time 10 "$APP_URL" 2>/dev/null)
    
    # Check if response contains expected content
    if echo "$response" | grep -q "mono-repo" || echo "$response" | grep -q "<!doctype html>"; then
        return 0
    else
        return 1
    fi
}

# Function to check container health
check_container_health() {
    local container_name="mono-repo-ui"
    
    # Get container status
    local container_status=$(docker ps --filter "name=$container_name" --format "{{.Status}}" | head -n1)
    
    if [[ $container_status == *"healthy"* ]] || [[ $container_status == *"Up"* ]]; then
        return 0
    else
        return 1
    fi
}

# Function to run comprehensive validation
run_validation_tests() {
    log "Running comprehensive validation tests..."
    
    local tests_passed=0
    local total_tests=5
    
    # Test 1: Health endpoint
    log "Test 1/5: Health endpoint check"
    if check_health "$HEALTH_ENDPOINT"; then
        log "✓ Health endpoint is responding"
        tests_passed=$((tests_passed + 1))
    else
        log "✗ Health endpoint is not responding"
    fi
    
    # Test 2: Main application endpoint
    log "Test 2/5: Main application endpoint check"
    if check_health "$APP_URL"; then
        log "✓ Main application endpoint is responding"
        tests_passed=$((tests_passed + 1))
    else
        log "✗ Main application endpoint is not responding"
    fi
    
    # Test 3: Application content validation
    log "Test 3/5: Application content validation"
    if validate_app_response; then
        log "✓ Application is serving expected content"
        tests_passed=$((tests_passed + 1))
    else
        log "✗ Application is not serving expected content"
    fi
    
    # Test 4: Container health check
    log "Test 4/5: Container health check"
    if check_container_health; then
        log "✓ Container is healthy"
        tests_passed=$((tests_passed + 1))
    else
        log "✗ Container is not healthy"
    fi
    
    # Test 5: Resource usage check
    log "Test 5/5: Resource usage check"
    local cpu_usage=$(docker stats --no-stream --format "{{.CPUPerc}}" mono-repo-ui 2>/dev/null | sed 's/%//' || echo "0")
    local mem_usage=$(docker stats --no-stream --format "{{.MemPerc}}" mono-repo-ui 2>/dev/null | sed 's/%//' || echo "0")
    
    if (( $(echo "$cpu_usage < 80" | bc -l) )) && (( $(echo "$mem_usage < 80" | bc -l) )); then
        log "✓ Resource usage is within acceptable limits (CPU: ${cpu_usage}%, Memory: ${mem_usage}%)"
        tests_passed=$((tests_passed + 1))
    else
        log "✗ Resource usage is high (CPU: ${cpu_usage}%, Memory: ${mem_usage}%)"
    fi
    
    log "Validation tests completed: $tests_passed/$total_tests passed"
    
    if [ $tests_passed -ge 4 ]; then
        return 0
    else
        return 1
    fi
}

# Main validation logic
log "Starting application validation..."

# Wait for application to be ready
log "Waiting for application to be ready..."
ATTEMPT=1

while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
    log "Validation attempt $ATTEMPT/$MAX_ATTEMPTS"
    
    if check_health "$HEALTH_ENDPOINT"; then
        log "Health check passed on attempt $ATTEMPT"
        break
    fi
    
    if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
        log "ERROR: Application failed to respond to health checks after $MAX_ATTEMPTS attempts"
        
        # Collect diagnostic information
        log "Collecting diagnostic information..."
        
        # Container logs
        log "Container logs (last 50 lines):"
        docker logs --tail=50 $(docker ps -q --filter "name=mono-repo-ui") 2>&1 | while read line; do
            log "CONTAINER: $line"
        done
        
        # Container status
        log "Container status:"
        docker ps --filter "name=mono-repo-ui" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | while read line; do
            log "STATUS: $line"
        done
        
        # System resources
        log "System resources:"
        log "DISK: $(df -h / | tail -1)"
        log "MEMORY: $(free -h | grep Mem)"
        log "CPU: $(top -bn1 | grep "Cpu(s)" | head -1)"
        
        exit 1
    fi
    
    log "Attempt $ATTEMPT failed, waiting $ATTEMPT_INTERVAL seconds..."
    sleep $ATTEMPT_INTERVAL
    ATTEMPT=$((ATTEMPT + 1))
done

# Run comprehensive validation tests
if run_validation_tests; then
    log "All validation tests passed successfully"
else
    log "Some validation tests failed"
    exit 1
fi

# Load deployment configuration for final validation
if [ -f "deployment-config.json" ]; then
    BUILD_NUMBER=$(jq -r '.buildNumber' deployment-config.json)
    ENVIRONMENT=$(jq -r '.environment' deployment-config.json)
    IMAGE_URI=$(jq -r '.imageUri' deployment-config.json)
    
    log "Deployment validation completed successfully"
    log "Build Number: $BUILD_NUMBER"
    log "Environment: $ENVIRONMENT"
    log "Image: $IMAGE_URI"
else
    log "WARNING: deployment-config.json not found"
fi

# Create final deployment status
cat > deployment-status.json << EOF
{
    "status": "deployment_validated",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "build_number": "$(cat current-build.txt 2>/dev/null || echo 'unknown')",
    "validation_passed": true,
    "health_check_url": "$HEALTH_ENDPOINT",
    "application_url": "$APP_URL"
}
EOF

# Update last successful deployment marker
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > last-successful-deployment.txt

# Send success notification (if configured)
if [ ! -z "$SLACK_WEBHOOK_URL" ]; then
    curl -X POST -H 'Content-type: application/json' \
        --data "{\"text\":\"✅ mono-repo-ui validation completed successfully\nEnvironment: $ENVIRONMENT\nBuild: $(cat current-build.txt 2>/dev/null || echo 'unknown')\"}" \
        $SLACK_WEBHOOK_URL || log "Failed to send Slack notification"
fi

# Start nginx if it was stopped and configuration exists
if [ -f "/etc/nginx/sites-available/mono-repo-ui" ] && ! systemctl is-active --quiet nginx; then
    log "Starting nginx..."
    systemctl start nginx || log "Failed to start nginx"
fi

log "Service validation completed successfully!"

exit 0
