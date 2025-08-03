#!/bin/bash

# After Install Hook for CodeDeploy
# This script runs after the application files are copied to the instance

set -e

LOG_FILE="/var/log/cloudsync-platform-deploy.log"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [AFTER_INSTALL] $1" | tee -a $LOG_FILE
}

log "Starting after_install hook"

# Change to deployment directory
cd /opt/cloudsync-platform

# Set correct permissions
log "Setting file permissions..."
chown -R ec2-user:ec2-user /opt/cloudsync-platform
chmod +x deploy.sh

# Validate deployment files
log "Validating deployment files..."
REQUIRED_FILES=("deployment-config.json" "deploy.sh")

for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        log "ERROR: Required file $file is missing"
        exit 1
    fi
done

# Load and validate deployment configuration
log "Validating deployment configuration..."
if [ -f "deployment-config.json" ]; then
    IMAGE_URI=$(jq -r '.imageUri' deployment-config.json)
    BUILD_NUMBER=$(jq -r '.buildNumber' deployment-config.json)
    ENVIRONMENT=$(jq -r '.environment' deployment-config.json)
    
    if [ "$IMAGE_URI" = "null" ] || [ "$BUILD_NUMBER" = "null" ] || [ "$ENVIRONMENT" = "null" ]; then
        log "ERROR: Invalid deployment configuration"
        exit 1
    fi
    
    log "Deployment configuration validated successfully"
    log "Image URI: $IMAGE_URI"
    log "Build Number: $BUILD_NUMBER"
    log "Environment: $ENVIRONMENT"
else
    log "ERROR: deployment-config.json not found"
    exit 1
fi

# Create backup of previous deployment (if exists)
if [ -f "current-build.txt" ]; then
    PREVIOUS_BUILD=$(cat current-build.txt)
    log "Creating backup of previous deployment (build: $PREVIOUS_BUILD)..."
    
    mkdir -p backups
    BACKUP_DIR="backups/build-$PREVIOUS_BUILD-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    
    # Backup configuration files
    cp -f current-build.txt "$BACKUP_DIR/" 2>/dev/null || true
    cp -f last-deployment.txt "$BACKUP_DIR/" 2>/dev/null || true
    cp -f .env "$BACKUP_DIR/" 2>/dev/null || true
    cp -f docker-compose.yml "$BACKUP_DIR/" 2>/dev/null || true
    
    log "Backup created at $BACKUP_DIR"
    
    # Clean up old backups (keep last 5)
    find backups -maxdepth 1 -type d -name "build-*" | sort | head -n -5 | xargs rm -rf
fi

# Set up monitoring and alerting (if enabled)
if [ "$ENABLE_MONITORING" = "true" ]; then
    log "Setting up monitoring configuration..."
    
    # Create CloudWatch configuration
    cat > cloudwatch-config.json << EOF
{
    "logs": {
        "logs_collected": {
            "files": {
                "collect_list": [
                    {
                        "file_path": "/var/log/cloudsync-platform-deploy.log",
                        "log_group_name": "/aws/ec2/cloudsync-platform/deployment",
                        "log_stream_name": "{instance_id}-deployment"
                    },
                    {
                        "file_path": "/var/log/cloudsync-platform/*.log",
                        "log_group_name": "/aws/ec2/cloudsync-platform/application",
                        "log_stream_name": "{instance_id}-application"
                    }
                ]
            }
        }
    },
    "metrics": {
        "namespace": "MonoRepo/UI",
        "metrics_collected": {
            "cpu": {
                "measurement": [
                    "cpu_usage_idle",
                    "cpu_usage_iowait",
                    "cpu_usage_user",
                    "cpu_usage_system"
                ],
                "metrics_collection_interval": 60
            },
            "disk": {
                "measurement": [
                    "used_percent"
                ],
                "metrics_collection_interval": 60,
                "resources": [
                    "*"
                ]
            },
            "mem": {
                "measurement": [
                    "mem_used_percent"
                ],
                "metrics_collection_interval": 60
            }
        }
    }
}
EOF
    
    # Start CloudWatch agent if installed
    if command -v /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl &> /dev/null; then
        /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
            -a fetch-config -m ec2 -c file:cloudwatch-config.json -s
        log "CloudWatch agent configured and started"
    fi
fi

# Set up nginx reverse proxy (if nginx is installed)
if command -v nginx &> /dev/null; then
    log "Configuring nginx reverse proxy..."
    
    cat > /etc/nginx/sites-available/cloudsync-platform << EOF
server {
    listen 80;
    server_name _;
    
    # Health check endpoint
    location /health {
        proxy_pass http://localhost:80/health;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    
    # Main application
    location / {
        proxy_pass http://localhost:80;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # Enable gzip compression
        gzip on;
        gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
    }
}
EOF
    
    # Enable the site
    ln -sf /etc/nginx/sites-available/cloudsync-platform /etc/nginx/sites-enabled/
    
    # Test nginx configuration
    nginx -t || log "Nginx configuration test failed"
fi

# Create deployment status file
cat > deployment-status.json << EOF
{
    "status": "after_install_completed",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "build_number": "$BUILD_NUMBER",
    "environment": "$ENVIRONMENT",
    "image_uri": "$IMAGE_URI"
}
EOF

log "After install hook completed successfully"

exit 0
