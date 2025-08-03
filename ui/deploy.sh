#!/bin/bash

# Deploy script for mono-repo-ui on EC2 with CodeDeploy
# This script handles the deployment of the Angular application using Docker

set -e

# Configuration
APP_NAME="mono-repo-ui"
DEPLOYMENT_DIR="/opt/mono-repo-ui"
DOCKER_COMPOSE_FILE="$DEPLOYMENT_DIR/docker-compose.yml"
ENV_FILE="$DEPLOYMENT_DIR/.env"
LOG_FILE="/var/log/mono-repo-ui-deploy.log"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $LOG_FILE
}

log "Starting deployment of $APP_NAME"

# Change to deployment directory
cd $DEPLOYMENT_DIR

# Load deployment configuration
if [ -f "deployment-config.json" ]; then
    IMAGE_URI=$(jq -r '.imageUri' deployment-config.json)
    BUILD_NUMBER=$(jq -r '.buildNumber' deployment-config.json)
    ENVIRONMENT=$(jq -r '.environment' deployment-config.json)
    log "Loaded deployment config - Build: $BUILD_NUMBER, Environment: $ENVIRONMENT"
else
    log "ERROR: deployment-config.json not found"
    exit 1
fi

# Stop existing containers
log "Stopping existing containers..."
docker-compose -f $DOCKER_COMPOSE_FILE down --remove-orphans || log "No existing containers to stop"

# Login to ECR
log "Logging in to ECR..."
aws ecr get-login-password --region $AWS_DEFAULT_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com

# Pull the new image
log "Pulling new Docker image: $IMAGE_URI"
docker pull $IMAGE_URI

# Create environment file
log "Creating environment configuration..."
cat > $ENV_FILE << EOF
# Environment Configuration
ENVIRONMENT=$ENVIRONMENT
IMAGE_URI=$IMAGE_URI
BUILD_NUMBER=$BUILD_NUMBER
APP_PORT=80
HOST_PORT=80

# AWS Configuration
AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION
AWS_ACCOUNT_ID=$AWS_ACCOUNT_ID

# Application Configuration
NODE_ENV=production
API_BASE_URL=${API_BASE_URL:-http://localhost:3000}
EOF

# Create docker-compose.yml
log "Creating Docker Compose configuration..."
cat > $DOCKER_COMPOSE_FILE << EOF
version: '3.8'

services:
  mono-repo-ui:
    image: $IMAGE_URI
    container_name: mono-repo-ui-$BUILD_NUMBER
    ports:
      - "\${HOST_PORT}:80"
    environment:
      - NODE_ENV=\${NODE_ENV}
      - ENVIRONMENT=\${ENVIRONMENT}
      - API_BASE_URL=\${API_BASE_URL}
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:80/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.mono-repo-ui.rule=Host(\`\${HOST_DOMAIN:-localhost}\`)"
      - "traefik.http.services.mono-repo-ui.loadbalancer.server.port=80"
    networks:
      - app-network

networks:
  app-network:
    driver: bridge
EOF

# Start the new containers
log "Starting new containers..."
docker-compose -f $DOCKER_COMPOSE_FILE --env-file $ENV_FILE up -d

# Wait for the application to be ready
log "Waiting for application to be ready..."
MAX_ATTEMPTS=30
ATTEMPT=0

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    if curl -f http://localhost:80/health > /dev/null 2>&1; then
        log "Application is ready and responding to health checks"
        break
    fi
    
    ATTEMPT=$((ATTEMPT + 1))
    log "Attempt $ATTEMPT/$MAX_ATTEMPTS - Application not ready yet, waiting..."
    sleep 10
done

if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
    log "ERROR: Application failed to start within expected time"
    
    # Show container logs for debugging
    log "Container logs:"
    docker-compose -f $DOCKER_COMPOSE_FILE logs --tail=50
    
    exit 1
fi

# Clean up old images (keep last 3)
log "Cleaning up old Docker images..."
docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}" | grep mono-repo-ui | tail -n +4 | awk '{print $3}' | xargs -r docker rmi || log "No old images to clean up"

# Update nginx configuration if needed
if [ -f "/etc/nginx/sites-available/mono-repo-ui" ]; then
    log "Reloading nginx configuration..."
    nginx -t && systemctl reload nginx || log "Nginx reload failed"
fi

# Create deployment marker
echo "$BUILD_NUMBER" > $DEPLOYMENT_DIR/current-build.txt
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > $DEPLOYMENT_DIR/last-deployment.txt

log "Deployment completed successfully!"
log "Build Number: $BUILD_NUMBER"
log "Environment: $ENVIRONMENT"
log "Image: $IMAGE_URI"

# Send deployment notification (optional)
if [ ! -z "$SLACK_WEBHOOK_URL" ]; then
    curl -X POST -H 'Content-type: application/json' \
        --data "{\"text\":\"✅ mono-repo-ui deployed successfully\nBuild: $BUILD_NUMBER\nEnvironment: $ENVIRONMENT\"}" \
        $SLACK_WEBHOOK_URL || log "Failed to send Slack notification"
fi

exit 0
