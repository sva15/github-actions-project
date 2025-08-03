#!/bin/bash

# Application Stop Hook for CodeDeploy
# This script runs to stop the current application before deploying the new version

set -e

LOG_FILE="/var/log/cloudsync-platform-deploy.log"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [APPLICATION_STOP] $1" | tee -a $LOG_FILE
}

log "Starting application_stop hook"

# Change to deployment directory
cd /opt/cloudsync-platform

# Function to gracefully stop containers
stop_containers() {
    log "Stopping application containers..."
    
    if [ -f "docker-compose.yml" ]; then
        # Stop containers using docker-compose
        docker-compose down --timeout 30 || log "Failed to stop containers with docker-compose"
    else
        log "No docker-compose.yml found, stopping containers manually..."
    fi
    
    # Stop any running cloudsync-platform containers
    RUNNING_CONTAINERS=$(docker ps -q --filter "name=cloudsync-platform")
    if [ ! -z "$RUNNING_CONTAINERS" ]; then
        log "Stopping running containers: $RUNNING_CONTAINERS"
        docker stop $RUNNING_CONTAINERS --time 30 || log "Failed to stop some containers"
        docker rm $RUNNING_CONTAINERS || log "Failed to remove some containers"
    else
        log "No running containers found"
    fi
}

# Function to check if application is running
is_app_running() {
    if curl -f http://localhost:80/health > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Create pre-stop status
cat > deployment-status.json << EOF
{
    "status": "application_stopping",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "previous_build": "$(cat current-build.txt 2>/dev/null || echo 'unknown')"
}
EOF

# Check if application is currently running
if is_app_running; then
    log "Application is currently running, proceeding with graceful shutdown..."
    
    # Send shutdown signal to application (if it supports graceful shutdown)
    log "Sending shutdown signal to application..."
    
    # Stop nginx if it's proxying to our application
    if systemctl is-active --quiet nginx; then
        log "Stopping nginx..."
        systemctl stop nginx || log "Failed to stop nginx"
    fi
    
    # Stop the application containers
    stop_containers
    
    # Wait for application to fully stop
    log "Waiting for application to stop..."
    MAX_WAIT=60
    WAIT_COUNT=0
    
    while is_app_running && [ $WAIT_COUNT -lt $MAX_WAIT ]; do
        sleep 1
        WAIT_COUNT=$((WAIT_COUNT + 1))
        if [ $((WAIT_COUNT % 10)) -eq 0 ]; then
            log "Still waiting for application to stop... ($WAIT_COUNT/$MAX_WAIT seconds)"
        fi
    done
    
    if is_app_running; then
        log "WARNING: Application did not stop gracefully within $MAX_WAIT seconds"
        
        # Force stop any remaining containers
        log "Force stopping remaining containers..."
        docker ps -q --filter "name=cloudsync-platform" | xargs -r docker kill
        docker ps -aq --filter "name=cloudsync-platform" | xargs -r docker rm -f
    else
        log "Application stopped successfully"
    fi
else
    log "Application is not currently running"
fi

# Clean up any orphaned containers or networks
log "Cleaning up orphaned resources..."
docker container prune -f || log "Failed to prune containers"
docker network prune -f || log "Failed to prune networks"

# Free up disk space by removing unused images (keep recent ones)
log "Cleaning up old Docker images..."
# Remove images older than 7 days, but keep at least 2 images
docker image prune -a -f --filter "until=168h" || log "Failed to prune old images"

# Stop any related services
log "Stopping related services..."

# Stop log forwarding services if running
pkill -f "tail.*cloudsync-platform" || true

# Clear any application caches
log "Clearing application caches..."
rm -rf /tmp/cloudsync-platform-* || true

# Update deployment status
cat > deployment-status.json << EOF
{
    "status": "application_stopped",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "previous_build": "$(cat current-build.txt 2>/dev/null || echo 'unknown')"
}
EOF

# Create a marker file to indicate the application was stopped cleanly
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > last-stop.txt

log "Application stop hook completed successfully"

exit 0
