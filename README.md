# CloudSync Platform

A full-stack application with Angular frontend and Python backend services, designed for deployment on both GCP (Cloud Run/Cloud Functions) and AWS (EC2/Lambda).

## Project Structure

**Organized by Cloud Provider:**
```
mono-repo/
├── docs/           # Documentation (gcp/, aws/, general/)
├── scripts/        # Setup scripts (gcp/, aws/, general/)
├── pipelines/      # CI/CD pipelines (gcp/, aws/)
├── configs/        # Service configs (gcp/, aws/)
├── backend/        # Python microservices
├── ui/             # Angular frontend
├── tests/          # Unit and integration tests
└── .github/        # GitHub Actions workflows
```

**For detailed structure:** See [PROJECT_STRUCTURE.md](PROJECT_STRUCTURE.md)

## Features

### Backend Services (Python)
- **User Service**: CRUD operations for user management
- **Notification Service**: Email, SMS, and push notification handling
- **Analytics Service**: Event tracking and metrics collection

### Frontend Service (Angular)
- **UI Service**: Angular Material dashboard with charts and analytics

## Deployment Targets

| Cloud | Backend | Frontend | Pipeline |
|-------|---------|----------|---------|
| **GCP** | Cloud Functions | Cloud Run | Cloud Build |
| **AWS** | Lambda Functions | EC2 + Docker | CodeBuild |

## Quick Start

### Google Cloud Platform
```bash
# 1. Validate environment
./scripts/gcp/validate-gcp-prerequisites.sh

# 2. Setup secrets and service accounts
./scripts/gcp/setup-gcp-secrets.sh

# 3. Deploy via Cloud Build
gcloud builds submit --config pipelines/gcp/cloudbuild-master.yml

# Full guide: docs/gcp/GCP_DEPLOYMENT_TESTING_GUIDE.md
```

### Amazon Web Services
```bash
# 1. Validate environment
./scripts/aws/validate-aws-prerequisites.sh

# 2. Setup secrets and IAM resources
./scripts/aws/setup-aws-secrets.sh

# 3. Setup master pipeline
./scripts/aws/setup-aws-master-pipeline.sh

# 4. Deploy via CodeBuild (triggered by git push)
git push origin main

# Full guide: docs/aws/AWS_DEPLOYMENT_TESTING_GUIDE.md
```

### Local Development
```bash
# Setup local environment
./scripts/general/setup-local-dev.sh

# Run with Docker Compose
docker-compose up
```

## Technology Stack

### Backend
- **Language**: Python 3.9+
- **Framework**: Functions Framework (for GCP/AWS compatibility)
- **Testing**: pytest, pytest-cov
- **Deployment**: Docker containers, Cloud Functions, Lambda

### Frontend
- **Framework**: Angular 16+
- **UI Library**: Angular Material
- **Charts**: Chart.js with ng2-charts
- **Build Tool**: Angular CLI
- **Deployment**: Docker with Nginx

## API Endpoints

### User Service
- `POST /users` - Create user
- `GET /users/{id}` - Get user by ID
- `PUT /users/{id}` - Update user
- `DELETE /users/{id}` - Delete user

### Notification Service
- `POST /notifications` - Send notification
- `GET /notifications/{id}` - Get notification status
- `GET /notifications?recipient={email}` - Get notifications by recipient

### Analytics Service
- `POST /analytics/events` - Track event
- `GET /analytics/analytics` - Get event analytics
- `GET /analytics/users/{id}` - Get user analytics
- `POST /analytics/metrics` - Record metric
- `GET /analytics/metrics/{name}` - Get metric statistics

## Environment Configuration

### Development
Update `ui/src/environments/environment.ts` with your local service URLs.

### Production
Update `ui/src/environments/environment.prod.ts` with your deployed service URLs.

## Testing

### Backend Tests
Each service includes comprehensive unit tests:
```bash
cd backend/services/{service_name}
pytest test_main.py -v --cov=main --cov-report=html
```

### Frontend Tests
```bash
cd ui
npm test                    # Run unit tests
npm run test:ci            # Run tests in CI mode
npm run e2e                # Run end-to-end tests
```

## CI/CD Pipeline

The project includes GitHub Actions workflows for:
- **Backend**: Python unit tests, linting, security scanning
- **Frontend**: Angular build, tests, linting
- **Deployment**: Automated deployment to GCP and AWS
- **Docker**: Container building and pushing to registries

## Monitoring and Logging

### Backend Services
- Structured logging with Python logging module
- Health check endpoints for container orchestration
- Error tracking and performance monitoring

### Frontend
- Angular error handling and logging
- Performance monitoring
- User analytics tracking

## Security

### Backend
- Input validation and sanitization
- CORS configuration
- Rate limiting (when deployed with API Gateway)
- Environment-based configuration

### Frontend
- Content Security Policy headers
- XSS protection
- Secure HTTP headers via Nginx configuration

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/new-feature`
3. Commit changes: `git commit -am 'Add new feature'`
4. Push to branch: `git push origin feature/new-feature`
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For support and questions:
- Create an issue in the GitHub repository
- Check the documentation in the `docs/` folder
- Review the API documentation and examples
