# Reusable Workflows Migration Guide

## Overview

This guide outlines the migration strategy from a mono repository to individual service repositories using reusable GitHub Actions workflows. This approach ensures consistent CI/CD standards while avoiding code duplication across multiple repositories.

## Repository Structure After Migration

### Central Reusable Workflows Repository
```
your-org/reusable-workflows/
├── .github/
│   └── workflows/
│       ├── python-service-ci.yml    # Python services & agents
│       ├── ui-ci.yml                # UI applications
│       └── manual-trigger.yml       # Manual workflow dispatcher
└── README.md
```

### Individual Service Repositories
```
your-org/analytics-service/          # Individual service repo
├── .github/
│   └── workflows/
│       ├── ci.yml                   # Calls reusable workflow
│       └── manual.yml               # Manual trigger workflow
├── src/                             # Service source code
├── tests/                           # Service tests
├── requirements.txt                 # Dependencies
├── sonar-project.properties         # SonarQube config
└── README.md

your-org/user-service/               # Another service repo
your-org/notification-service/       # Another service repo
your-org/chatbot-agent/             # Agent repo
your-org/rag-agent/                 # Agent repo
your-org/assistant-agent/           # Agent repo
your-org/cloudsync-ui/              # UI repo
```

## Reusable Workflows

### 1. Python Service CI/CD (`python-service-ci.yml`)

**Purpose**: Handles Python backend services and agents
**Features**:
- Code quality checks (Black, isort, Flake8, mypy)
- Unit tests with configurable coverage threshold
- SonarQube integration with branch conditions
- Professional step summaries
- Artifact uploads

**Key Inputs**:
- `service-name`: Name of the service
- `python-version`: Python version (default: 3.11)
- `coverage-threshold`: Coverage percentage (default: 90)
- `sonar-project-key`: Individual SonarQube project key
- `working-directory`: Service directory (default: '.')

### 2. UI CI/CD (`ui-ci.yml`)

**Purpose**: Handles Angular/React/Vue UI applications
**Features**:
- Code quality checks (ESLint, Prettier, TypeScript)
- Unit tests with coverage reporting
- Build validation and artifact creation
- SonarQube integration for frontend
- Multi-package manager support (npm, yarn, pnpm)

**Key Inputs**:
- `ui-name`: Name of the UI application
- `node-version`: Node.js version (default: 18)
- `package-manager`: Package manager (default: npm)
- `build-command`: Build command (default: npm run build)
- `test-command`: Test command (default: npm run test:ci)

### 3. Manual Trigger (`manual-trigger.yml`)

**Purpose**: Provides on-demand workflow execution
**Features**:
- Service type detection (python-service, ui, agent)
- Configurable execution options
- Flexible parameter inputs
- Calls appropriate reusable workflow

## Migration Steps

### Phase 1: Setup Reusable Workflows Repository

1. **Create Central Repository**:
   ```bash
   # Create new repository
   git clone https://github.com/your-org/reusable-workflows.git
   cd reusable-workflows
   
   # Copy reusable workflow files
   mkdir -p .github/workflows
   cp reusable-workflows/*.yml .github/workflows/
   
   # Commit and push
   git add .
   git commit -m "Add reusable GitHub Actions workflows"
   git push origin main
   ```

2. **Configure Repository Settings**:
   - Make repository public or ensure proper access permissions
   - Add repository secrets if needed
   - Configure branch protection for main branch

### Phase 2: Create Individual Service Repositories

For each service/agent/ui, create a new repository:

1. **Analytics Service Example**:
   ```bash
   # Create new repository
   git clone https://github.com/your-org/analytics-service.git
   cd analytics-service
   
   # Copy service code from mono repo
   cp -r ../github-actions-project/backend/services/analytics_service/* .
   
   # Copy workflow files
   mkdir -p .github/workflows
   cp ../github-actions-project/examples/analytics-service-repo/.github/workflows/* .github/workflows/
   
   # Update workflow references
   sed -i 's/your-org/actual-org-name/g' .github/workflows/*.yml
   
   # Commit and push
   git add .
   git commit -m "Initial analytics service setup with reusable workflows"
   git push origin main
   ```

2. **Repeat for All Services**:
   - user-service
   - notification-service
   - chatbot-agent
   - rag-agent
   - assistant-agent
   - cloudsync-ui

### Phase 3: Configure SonarQube Projects

1. **Create Individual SonarQube Projects**:
   - `sva15_analytics-service`
   - `sva15_user-service`
   - `sva15_notification-service`
   - `sva15_chatbot-agent`
   - `sva15_rag-agent`
   - `sva15_assistant-agent`
   - `sva15_cloudsync-ui`

2. **Configure Shared Token**:
   - Create organization-level token in SonarCloud
   - Add `SONAR_TOKEN` secret to each repository
   - Test token permissions across all projects

### Phase 4: Update Repository Secrets

For each individual repository, add required secrets:

```bash
# GitHub CLI method
gh secret set SONAR_TOKEN --body "your-sonar-token" --repo your-org/analytics-service
gh secret set SONAR_TOKEN --body "your-sonar-token" --repo your-org/user-service
# ... repeat for all repositories
```

## Workflow Usage Examples

### Individual Service Repository Workflow

```yaml
# .github/workflows/ci.yml
name: Analytics Service CI/CD

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  ci-cd:
    uses: your-org/reusable-workflows/.github/workflows/python-service-ci.yml@main
    with:
      service-name: 'analytics-service'
      python-version: '3.11'
      coverage-threshold: 90
      sonar-project-key: 'sva15_analytics-service'
      sonar-organization: 'sva15'
    secrets:
      SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
```

### Manual Workflow Example

```yaml
# .github/workflows/manual.yml
name: Manual Analytics Service CI/CD

on:
  workflow_dispatch:
    inputs:
      run-sonarqube:
        description: 'Run SonarQube analysis'
        type: boolean
        default: false

jobs:
  manual-ci-cd:
    uses: your-org/reusable-workflows/.github/workflows/manual-trigger.yml@main
    with:
      service-type: 'python-service'
      service-name: 'analytics-service'
      run-sonarqube: ${{ inputs.run-sonarqube }}
      sonar-project-key: 'sva15_analytics-service'
      sonar-organization: 'sva15'
    secrets:
      SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
```

## Benefits of This Approach

### 1. **Consistency**
- Same quality standards across all repositories
- Centralized workflow maintenance
- Consistent reporting and logging

### 2. **Maintainability**
- Single source of truth for CI/CD logic
- Easy updates across all services
- Reduced code duplication

### 3. **Scalability**
- Easy addition of new services
- Flexible configuration per service
- Independent service development

### 4. **Security**
- Centralized secret management
- Consistent security practices
- Audit trail for all changes

## Configuration Matrix

| Repository | Service Type | Coverage | SonarQube Project |
|------------|-------------|----------|-------------------|
| analytics-service | python-service | 90% | sva15_analytics-service |
| user-service | python-service | 90% | sva15_user-service |
| notification-service | python-service | 90% | sva15_notification-service |
| chatbot-agent | python-service | 85% | sva15_chatbot-agent |
| rag-agent | python-service | 85% | sva15_rag-agent |
| assistant-agent | python-service | 85% | sva15_assistant-agent |
| cloudsync-ui | ui | 80% | sva15_cloudsync-ui |

## Testing Strategy

### 1. **Reusable Workflow Testing**
- Test workflows in reusable-workflows repository
- Validate all input parameters work correctly
- Test secret passing and permissions

### 2. **Individual Repository Testing**
- Test workflow calls from each service repository
- Validate SonarQube integration per project
- Test manual workflows with different parameters

### 3. **Integration Testing**
- Test cross-repository dependencies
- Validate artifact sharing if needed
- Test deployment pipelines

## Rollback Strategy

If issues arise during migration:

1. **Keep Mono Repo Active**: Maintain original mono repo as backup
2. **Gradual Migration**: Migrate one service at a time
3. **Feature Flags**: Use branch conditions to control workflow execution
4. **Monitoring**: Track workflow success rates and performance

## Maintenance Guidelines

### 1. **Reusable Workflow Updates**
- Use semantic versioning for workflow releases
- Test changes in development environment first
- Update documentation with each change

### 2. **Service Repository Updates**
- Pin workflow versions for stability: `@v1.0.0`
- Update workflow references during maintenance windows
- Monitor for breaking changes in reusable workflows

### 3. **SonarQube Management**
- Monitor token expiration dates
- Validate project permissions regularly
- Update quality gates consistently across projects

## Success Metrics

- **Migration Completion**: 100% of services migrated successfully
- **Workflow Consistency**: All services use same quality standards
- **Performance**: CI/CD runtime maintained or improved
- **Quality**: Coverage and quality gate pass rates maintained
- **Maintainability**: Reduced workflow maintenance overhead

## Conclusion

This reusable workflow approach provides a scalable, maintainable solution for migrating from mono repo to individual service repositories while maintaining consistent CI/CD standards and reducing code duplication.
