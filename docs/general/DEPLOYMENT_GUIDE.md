# Deployment Guide

This guide provides step-by-step instructions for deploying the mono repo application to both GCP and AWS.

## Prerequisites

### Required Tools
- Docker Desktop
- Node.js 18+ and npm
- Python 3.9+
- Git
- GCP CLI (`gcloud`)
- AWS CLI (`aws`)

### Required Accounts
- Google Cloud Platform account with billing enabled
- AWS account with appropriate permissions
- Docker Hub account (for container registry)

## Local Development Setup

### 1. Clone and Setup
```bash
git clone <repository-url>
cd mono-repo-project
```

### 2. Backend Services Setup
```bash
# Install Python dependencies for each service
cd backend/services/user_service
pip install -r requirements.txt

cd ../notification_service
pip install -r requirements.txt

cd ../analytics_service
pip install -r requirements.txt
```

### 3. Frontend Setup
```bash
cd ui
npm install
```

### 4. Run with Docker Compose
```bash
# From project root
docker-compose up --build
```

Access the application:
- Frontend: http://localhost:3000
- User Service: http://localhost:3001
- Notification Service: http://localhost:3002
- Analytics Service: http://localhost:3003

## GCP Deployment

### 1. Setup GCP Project
```bash
# Create new project
gcloud projects create your-project-id

# Set as default project
gcloud config set project your-project-id

# Enable required APIs
gcloud services enable cloudfunctions.googleapis.com
gcloud services enable run.googleapis.com
gcloud services enable cloudbuild.googleapis.com
```

### 2. Deploy Backend Services to Cloud Functions
```bash
# Deploy User Service
cd backend/services/user_service
gcloud functions deploy user-service \
  --runtime python39 \
  --trigger-http \
  --entry-point gcp_handler \
  --allow-unauthenticated

# Deploy Notification Service
cd ../notification_service
gcloud functions deploy notification-service \
  --runtime python39 \
  --trigger-http \
  --entry-point gcp_handler \
  --allow-unauthenticated

# Deploy Analytics Service
cd ../analytics_service
gcloud functions deploy analytics-service \
  --runtime python39 \
  --trigger-http \
  --entry-point gcp_handler \
  --allow-unauthenticated
```

### 3. Deploy Frontend to Cloud Run
```bash
cd ui

# Build and deploy
gcloud run deploy mono-repo-ui \
  --source . \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated
```

### 4. Update Environment Configuration
Update `ui/src/environments/environment.prod.ts` with your Cloud Function URLs.

## AWS Deployment

### 1. Setup AWS Resources
```bash
# Create S3 bucket for deployments
aws s3 mb s3://your-deployment-bucket

# Create IAM role for Lambda functions
aws iam create-role --role-name lambda-execution-role \
  --assume-role-policy-document file://lambda-trust-policy.json
```

### 2. Deploy Backend Services to Lambda
```bash
# Package and deploy each service
cd backend/services/user_service

# Create deployment package
mkdir deployment
cp main.py deployment/
pip install -r requirements.txt -t deployment/
cd deployment && zip -r ../user-service.zip .

# Deploy to Lambda
aws lambda create-function \
  --function-name user-service \
  --runtime python3.9 \
  --role arn:aws:iam::your-account:role/lambda-execution-role \
  --handler main.lambda_handler \
  --zip-file fileb://user-service.zip

# Repeat for other services...
```

### 3. Setup API Gateway
```bash
# Create REST API
aws apigateway create-rest-api --name mono-repo-api

# Configure routes and integrate with Lambda functions
# (Detailed steps would be service-specific)
```

### 4. Deploy Frontend to EC2
```bash
# Build Docker image
cd ui
docker build -t mono-repo-ui .

# Push to ECR
aws ecr create-repository --repository-name mono-repo-ui
docker tag mono-repo-ui:latest your-account.dkr.ecr.region.amazonaws.com/mono-repo-ui:latest
docker push your-account.dkr.ecr.region.amazonaws.com/mono-repo-ui:latest

# Deploy to EC2 using ECS or direct Docker deployment
```

## CI/CD Pipeline Setup

### 1. GitHub Secrets Configuration
Add the following secrets to your GitHub repository:

#### Docker Hub
- `DOCKER_USERNAME`
- `DOCKER_PASSWORD`

#### GCP
- `GCP_PROJECT_ID`
- `GCP_SA_KEY` (Service Account JSON key)

#### AWS
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_LAMBDA_ROLE_ARN`
- `AWS_S3_BUCKET`

#### Optional
- `SLACK_WEBHOOK_URL` (for notifications)
- `SNYK_TOKEN` (for security scanning)

### 2. Pipeline Triggers
The CI/CD pipelines are triggered by:
- Push to `main` or `develop` branches
- Pull requests to `main` branch
- Changes to specific paths (`backend/**` or `ui/**`)

### 3. Pipeline Stages

#### Backend Pipeline
1. **Test**: Unit tests, linting, security scanning
2. **Build**: Docker image building and pushing
3. **Deploy**: Deployment to GCP Cloud Functions and AWS Lambda
4. **Notify**: Slack notifications

#### Frontend Pipeline
1. **Test**: Unit tests, linting, e2e tests
2. **Security**: Dependency scanning
3. **Build**: Docker image building and pushing
4. **Deploy**: Deployment to GCP Cloud Run and AWS EC2
5. **Performance**: Lighthouse performance testing
6. **Notify**: Slack notifications

## Monitoring and Logging

### GCP Monitoring
- Cloud Functions logs: Available in Cloud Logging
- Cloud Run logs: Available in Cloud Logging
- Set up alerts and dashboards in Cloud Monitoring

### AWS Monitoring
- Lambda logs: Available in CloudWatch Logs
- EC2 logs: Configure CloudWatch agent
- Set up CloudWatch alarms and dashboards

## Troubleshooting

### Common Issues

#### Build Failures
- Check Node.js/Python versions
- Verify all dependencies are installed
- Check for syntax errors in code

#### Deployment Failures
- Verify cloud provider credentials
- Check service quotas and limits
- Review deployment logs

#### Runtime Errors
- Check application logs
- Verify environment variables
- Test API endpoints individually

### Debug Commands
```bash
# Check Docker container logs
docker logs container-name

# Test API endpoints
curl -X GET https://your-api-endpoint/health

# Check GCP function logs
gcloud functions logs read function-name

# Check AWS Lambda logs
aws logs describe-log-groups --log-group-name-prefix /aws/lambda/
```

## Security Considerations

### Best Practices
- Use environment variables for sensitive data
- Enable HTTPS for all endpoints
- Implement proper authentication and authorization
- Regular security updates and dependency scanning
- Monitor for suspicious activities

### Security Features Implemented
- Docker security scanning
- Dependency vulnerability checking
- CORS configuration
- Security headers in Nginx
- Input validation in backend services

## Performance Optimization

### Frontend
- Angular production build optimization
- Gzip compression in Nginx
- CDN integration (recommended)
- Lazy loading for routes

### Backend
- Function cold start optimization
- Connection pooling for databases
- Caching strategies
- Resource allocation tuning

## Cost Optimization

### GCP
- Use Cloud Functions for variable workloads
- Configure Cloud Run min/max instances
- Monitor usage with Cloud Billing

### AWS
- Use Lambda for event-driven workloads
- Configure auto-scaling for EC2
- Monitor costs with AWS Cost Explorer

## Backup and Recovery

### Data Backup
- Database backups (if using managed databases)
- Configuration backups
- Container image versioning

### Disaster Recovery
- Multi-region deployment (recommended)
- Automated failover procedures
- Regular recovery testing
