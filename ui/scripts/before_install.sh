#!/bin/bash

# Before Install Hook for CodeDeploy
# This script runs before the application files are copied to the instance

set -e

LOG_FILE="/var/log/mono-repo-ui-deploy.log"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [BEFORE_INSTALL] $1" | tee -a $LOG_FILE
}

log "Starting before_install hook"

# Update system packages
log "Updating system packages..."
yum update -y

# Install required packages
log "Installing required packages..."
yum install -y docker jq curl wget unzip

# Install Docker Compose
log "Installing Docker Compose..."
if ! command -v docker-compose &> /dev/null; then
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
fi

# Install AWS CLI v2 if not present
log "Checking AWS CLI installation..."
if ! command -v aws &> /dev/null; then
    log "Installing AWS CLI v2..."
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    ./aws/install
    rm -rf awscliv2.zip aws/
fi

# Start and enable Docker service
log "Starting Docker service..."
systemctl start docker
systemctl enable docker

# Add ec2-user to docker group
log "Adding ec2-user to docker group..."
usermod -a -G docker ec2-user

# Create application directory
log "Creating application directory..."
mkdir -p /opt/mono-repo-ui
chown -R ec2-user:ec2-user /opt/mono-repo-ui

# Create log directory
log "Creating log directory..."
mkdir -p /var/log/mono-repo-ui
chown -R ec2-user:ec2-user /var/log/mono-repo-ui

# Set up environment variables
log "Setting up environment variables..."
cat > /etc/environment << EOF
AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION:-us-east-1}
AWS_ACCOUNT_ID=${AWS_ACCOUNT_ID}
PATH="/usr/local/bin:/usr/bin:/bin"
EOF

# Source environment variables
source /etc/environment

# Clean up any existing containers with the same name
log "Cleaning up existing containers..."
docker stop mono-repo-ui-* 2>/dev/null || true
docker rm mono-repo-ui-* 2>/dev/null || true

# Pull base images to speed up deployment
log "Pre-pulling base images..."
docker pull nginx:alpine || log "Failed to pre-pull nginx image"

# Set up log rotation
log "Setting up log rotation..."
cat > /etc/logrotate.d/mono-repo-ui << EOF
/var/log/mono-repo-ui/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    create 644 ec2-user ec2-user
}

/var/log/mono-repo-ui-deploy.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 root root
}
EOF

# Install CloudWatch agent (optional)
if [ "$INSTALL_CLOUDWATCH_AGENT" = "true" ]; then
    log "Installing CloudWatch agent..."
    wget https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
    rpm -U ./amazon-cloudwatch-agent.rpm
    rm -f amazon-cloudwatch-agent.rpm
fi

# Create health check endpoint script
log "Creating health check script..."
cat > /opt/mono-repo-ui/health-check.sh << 'EOF'
#!/bin/bash
# Health check script for the application

HEALTH_URL="http://localhost:80/health"
MAX_ATTEMPTS=5
ATTEMPT=0

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    if curl -f $HEALTH_URL > /dev/null 2>&1; then
        echo "Health check passed"
        exit 0
    fi
    
    ATTEMPT=$((ATTEMPT + 1))
    echo "Health check attempt $ATTEMPT/$MAX_ATTEMPTS failed"
    sleep 2
done

echo "Health check failed after $MAX_ATTEMPTS attempts"
exit 1
EOF

chmod +x /opt/mono-repo-ui/health-check.sh
chown ec2-user:ec2-user /opt/mono-repo-ui/health-check.sh

log "Before install hook completed successfully"

exit 0
