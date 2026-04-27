# Phase 5: CI/CD Pipeline and Deployment

**Step-by-step guide to building a robust CI/CD pipeline with GitHub Actions, MLflow, and automated deployments**

---

## Current Repo State

No GitHub Actions workflows are currently implemented. Start with CI only, then add deployment.

Build in this order:

1. Backend CI: lint, tests, type check.
2. Frontend CI: install, type check, build.
3. Terraform CI: fmt, validate, plan.
4. Docker build and container scan.
5. Staging deploy.
6. Production deploy with manual approval.
7. Model training and promotion workflows.

Do not start with production deployment workflows before the app has tests and Docker images.

---

## Overview

A production CI/CD pipeline ensures:
1. Code quality through automated testing
2. Security through scanning and best practices
3. Reliable deployments through automated workflows
4. Continuous learning through MLflow integration

### Pipeline Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           GitHub Repository                                  │
│                                                                              │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐                    │
│  │   PR Push   │ →  │  Main Push  │ →  │   Schedule   │                    │
│  └──────┬──────┘    └──────┬──────┘    └──────┬──────┘                    │
│         │                  │                   │                             │
│         ↓                  ↓                   ↓                             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐                    │
│  │     CI      │    │ Deploy      │    │  Weekly     │                    │
│  │   Lint      │    │ Staging     │    │  Retrain    │                    │
│  │   Test      │    │             │    │             │                    │
│  │   Build     │    └──────┬──────┘    └──────┬──────┘                    │
│  └─────────────┘           │                   │                             │
│                            ↓                   ↓                             │
│                    ┌─────────────┐    ┌─────────────┐                    │
│                    │   Manual     │    │  MLflow     │                    │
│                    │   Approval   │    │  Retrain     │                    │
│                    └──────┬──────┘    └──────┬──────┘                    │
│                            ↓                   ↓                             │
│                    ┌─────────────┐    ┌─────────────┐                    │
│                    │ Deploy       │    │  Notify     │                    │
│                    │ Production   │    │  Admin      │                    │
│                    └─────────────┘    └─────────────┘                    │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Security Baseline For Workflows

Prefer GitHub OIDC for AWS access instead of long-lived `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`.

Minimum workflow security checks:

- dependency scan (`pip-audit`, `npm audit`, or Dependabot)
- secret scanning
- container scan (`trivy`)
- Terraform `fmt` and `validate`
- Terraform plan artifact for review
- backend tests before Docker publish
- frontend build before Vercel deploy
- manual approval for production

Add SBOM generation later with `syft` once Docker images exist.

---

## Step 1: GitHub Actions Workflows Directory

### Create Workflows Directory

```bash
cd Skin_Lesion_Classification_backend

mkdir -p .github/workflows
mkdir -p .github/CODEOWNERS

# Create CODEOWNERS file
cat > .github/CODEOWNERS << 'EOF'
# Default code owners
* @your-username

# Infrastructure
/infra/ @devops-team
/.github/workflows/ @devops-team

# ML code
/ml/ @ml-team
/notebooks/ @ml-team
EOF
```

---

## Step 2: CI Pipeline (Every PR)

### Create CI Workflow

Create `.github/workflows/ci.yml`:

```yaml
name: CI

on:
  pull_request:
    branches: [main, develop]
  push:
    branches: [main]

env:
  NODE_VERSION: "20"
  PYTHON_VERSION: "3.10"
  AWS_REGION: us-east-1

jobs:
  # ============ Backend CI ============
  backend-ci:
    name: Backend CI
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: ${{ env.PYTHON_VERSION }}

      - name: Cache pip packages
        uses: actions/cache@v4
        with:
          path: ~/.cache/pip
          key: ${{ runner.os }}-pip-${{ hashFiles('**/requirements.txt') }}
          restore-keys: |
            ${{ runner.os }}-pip-

      - name: Install Python dependencies
        run: |
          pip install -r requirements.txt

      - name: Lint with Ruff
        run: |
          pip install ruff
          ruff check app/ --output-format=github

      - name: Type check with MyPy
        run: |
          pip install mypy
          mypy app/ --ignore-missing-imports

      - name: Run pytest
        run: |
          pip install pytest pytest-asyncio pytest-cov httpx
          pytest tests/ -v --cov=app --cov-report=xml

      - name: Security scan with Bandit
        run: |
          pip install bandit
          bandit -r app/ -f json -o bandit-report.json
        continue-on-error: true

  # ============ Frontend CI ============
  frontend-ci:
    name: Frontend CI
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: ../Skin_Lesion_Classification_frontend

    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        with:
          path: Skin_Lesion_Classification_frontend

      - name: Set up Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: "npm"
          cache-dependency-path: ../Skin_Lesion_Classification_frontend/package-lock.json

      - name: Install dependencies
        run: npm ci

      - name: Lint with ESLint
        run: npm run lint || true

      - name: Type check with TypeScript
        run: npm run type-check || true

      - name: Run tests
        run: npm test -- --passWithNoTests || true

      - name: Build
        run: npm run build
        env:
          NEXT_PUBLIC_API_URL: http://localhost:8080

  # ============ Mobile CI ============
  mobile-ci:
    name: Mobile CI
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: ../SkinLesionMobile

    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        with:
          path: SkinLesionMobile

      - name: Set up Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: "npm"
          cache-dependency-path: ../SkinLesionMobile/package-lock.json

      - name: Install dependencies
        run: npm ci

      - name: Type check with TypeScript
        run: npx tsc --noEmit || true

      - name: EAS credentials setup
        if: contains(github.ref, 'main')
        uses: expo/expo-github-action/setup@v8
        with:
          eas-version: latest
          token: ${{ secrets.EXPO_TOKEN }}

  # ============ Docker Build Test ============
  docker-build:
    name: Docker Build Test
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: backend

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Login to Amazon ECR
        uses: aws-actions/amazon-ecr-login@v2
        with:
          region: ${{ env.AWS_REGION }}

      - name: Build Docker image
        run: |
          docker build -t skin-lesion-backend:test \
            --build-arg BUILDKIT_INLINE_CACHE=1 \
            .

      - name: Run container health check
        run: |
          docker run -d --name test-container \
            -p 8080:8080 \
            --health-cmd="curl -f http://localhost:8080/health || exit 1" \
            skin-lesion-backend:test

          sleep 30
          docker logs test-container
          docker stop test-container

  # ============ Dependency Review ============
  dependency-review:
    name: Dependency Review
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Dependency Review
        uses: actions/dependency-review-action@v4
```

---

## Step 3: Backend Deployment Pipeline

### Create Backend Deployment Workflow

Create `.github/workflows/deploy-backend.yml`:

```yaml
name: Deploy Backend

on:
  push:
    branches: [main]
    paths:
      - "backend/**"
      - ".github/workflows/deploy-backend.yml"

env:
  AWS_REGION: us-east-1
  ECR_REPOSITORY: skin-lesion-backend
  ECS_CLUSTER: skin-lesion-prod
  ECS_SERVICE: skin-lesion-backend

jobs:
  deploy-staging:
    name: Deploy to Staging
    runs-on: ubuntu-latest
    environment: staging

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Login to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v2

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Build and push Docker image
        uses: docker/build-push-action@v5
        with:
          context: ./backend
          push: true
          tags: |
            ${{ steps.login-ecr.outputs.registry }}/${{ env.ECR_REPOSITORY }}:staging-${{ github.sha }}
            ${{ steps.login-ecr.outputs.registry }}/${{ env.ECR_REPOSITORY }}:staging-latest
          cache-from: |
            type=gha
            cache-to=type=gha,mode=max
          cache-to: |
            type=gha,mode=max

      - name: Update ECS task definition
        id: task-def
        uses: aws-actions/amazon-ecs-render-task-definition@v1
        with:
          task-definition: ./backend/ecs-task-definition-staging.json
          container-name: backend
          image: ${{ steps.login-ecr.outputs.registry }}/${{ env.ECR_REPOSITORY }}:staging-${{ github.sha }}

      - name: Deploy to ECS Staging
        uses: aws-actions/amazon-ecs-deploy-task-definition@v2
        with:
          task-definition: ${{ steps.task-def.outputs.task-definition }}
          service: ${{ env.ECS_SERVICE }}-staging
          cluster: ${{ env.ECS_CLUSTER }}
          wait-for-service-stability: true

      - name: Health check
        run: |
          sleep 30
          curl -f https://staging-api.skinlesion.com/api/v1/health || exit 1

  deploy-production:
    name: Deploy to Production
    needs: deploy-staging
    runs-on: ubuntu-latest
    environment: production

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Wait for manual approval
        run: |
          echo "Waiting for manual approval..."
          echo "Please review the staging deployment before approving."

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Login to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v2

      - name: Pull staging image
        run: |
          docker pull ${{ steps.login-ecr.outputs.registry }}/${{ env.ECR_REPOSITORY }}:staging-${{ github.sha }}
          docker tag ${{ steps.login-ecr.outputs.registry }}/${{ env.ECR_REPOSITORY }}:staging-${{ github.sha }} \
            ${{ steps.login-ecr.outputs.registry }}/${{ env.ECR_REPOSITORY }}:prod-${{ github.sha }}
          docker tag ${{ steps.login-ecr.outputs.registry }}/${{ env.ECR_REPOSITORY }}:staging-${{ github.sha }} \
            ${{ steps.login-ecr.outputs.registry }}/${{ env.ECR_REPOSITORY }}:prod-latest
          docker push ${{ steps.login-ecr.outputs.registry }}/${{ env.ECR_REPOSITORY }}:prod-${{ github.sha }}
          docker push ${{ steps.login-ecr.outputs.registry }}/${{ env.ECR_REPOSITORY }}:prod-latest

      - name: Update ECS task definition
        id: task-def
        uses: aws-actions/amazon-ecs-render-task-definition@v1
        with:
          task-definition: ./backend/ecs-task-definition-prod.json
          container-name: backend
          image: ${{ steps.login-ecr.outputs.registry }}/${{ env.ECR_REPOSITORY }}:prod-${{ github.sha }}

      - name: Deploy to ECS Production (Rolling Update)
        uses: aws-actions/amazon-ecs-deploy-task-definition@v2
        with:
          task-definition: ${{ steps.task-def.outputs.task-definition }}
          service: ${{ env.ECS_SERVICE }}
          cluster: ${{ env.ECS_CLUSTER }}
          deployment-controller: ECS
          desired-count: 3
          minimum-healthy-percent: 100
          maximum-percent: 200
          wait-for-service-stability: true

      - name: Health check
        run: |
          sleep 60
          curl -f https://api.skinlesion.com/api/v1/health || exit 1

      - name: Notify Success
        if: success()
        run: |
          echo "Backend deployed successfully to production!"
```

---

## Step 4: Frontend Deployment Pipeline

### Create Frontend Deployment Workflow

Create `.github/workflows/deploy-frontend.yml`:

```yaml
name: Deploy Frontend

on:
  push:
    branches: [main]
    paths:
      - "Skin_Lesion_Classification_frontend/**"

env:
  VERCEL_ORG_ID: ${{ secrets.VERCEL_ORG_ID }}
  VERCEL_PROJECT_ID: ${{ secrets.VERCEL_PROJECT_ID }}

jobs:
  deploy-preview:
    name: Deploy Preview
    runs-on: ubuntu-latest
    environment: preview
    if: github.event_name == 'pull_request'

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Node.js
        uses: actions/setup-node@v4
        with:
          node-version: "20"
          cache: "npm"
          cache-dependency-path: Skin_Lesion_Classification_frontend/package-lock.json

      - name: Install Vercel CLI
        run: npm install -g vercel

      - name: Pull Vercel Environment Information
        run: vercel pull --yes --environment=preview --token=${{ secrets.VERCEL_TOKEN }}

      - name: Build Project Artifacts
        run: vercel build --token=${{ secrets.VERCEL_TOKEN }}
        working-directory: Skin_Lesion_Classification_frontend

      - name: Deploy Preview to Vercel
        id: deploy
        run: |
          vercel deploy --prebuilt --token=${{ secrets.VERCEL_TOKEN }}
        working-directory: Skin_Lesion_Classification_frontend

      - name: Comment PR with preview URL
        uses: actions/github-script@v7
        with:
          script: |
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: `🚀 Preview deployed to: ${{ steps.deploy.outputs.url }}`
            })

  deploy-production:
    name: Deploy Production
    runs-on: ubuntu-latest
    environment: production
    if: github.ref == 'refs/heads/main'

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Node.js
        uses: actions/setup-node@v4
        with:
          node-version: "20"
          cache: "npm"
          cache-dependency-path: Skin_Lesion_Classification_frontend/package-lock.json

      - name: Install Vercel CLI
        run: npm install -g vercel

      - name: Pull Vercel Environment Information
        run: vercel pull --yes --environment=production --token=${{ secrets.VERCEL_TOKEN }}

      - name: Build Project Artifacts
        run: vercel build --prod --token=${{ secrets.VERCEL_TOKEN }}
        working-directory: Skin_Lesion_Classification_frontend

      - name: Deploy Production to Vercel
        run: vercel deploy --prebuilt --prod --token=${{ secrets.VERCEL_TOKEN }}
        working-directory: Skin_Lesion_Classification_frontend
```

---

## Step 5: Quarterly Batch Retraining Pipeline

### Curation Pipeline Overview

```
Patient consents → pending_review (doctor validation) → pending_admin (admin approval) → approved (training pool)
                                                                                                        ↓
                                                                                               Batch retraining (quarterly)
                                                                                                        ↓
                                                                                               Human review in MLflow
                                                                                                        ↓
                                                                                               Manual promotion
```

### Create Batch Retraining Workflow

Create `.github/workflows/batch-retrain.yml`:

```yaml
name: Batch ML Retraining

on:
  workflow_dispatch:
    inputs:
      dry_run:
        description: Dry run (no training)
        required: false
        default: "false"
        type: string

env:
  AWS_REGION: us-east-1
  S3_BUCKET: skin-lesion-training
  MLFLOW_TRACKING_URI: https://mlflow.skinlesion.com

jobs:
  check-pool-size:
    name: Check Training Pool
    runs-on: ubuntu-latest

    outputs:
      pool_size: ${{ steps.check.outputs.pool_size }}
      can_retrain: ${{ steps.check.outputs.can_retrain }}

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Check S3 approved pool size
        id: check
        run: |
          COUNT=$(aws s3api list-objects-v2 \
            --bucket ${{ env.S3_BUCKET }} \
            --prefix "approved/" \
            --suffix ".jpg" \
            --query 'length(Contents)' \
            --output text)

          echo "Approved pool size: $COUNT"

          # Minimum 5000 approved cases for batch retraining
          MIN_IMAGES=5000
          if [ "$COUNT" -ge "$MIN_IMAGES" ]; then
            echo "can_retrain=true" >> $GITHUB_OUTPUT
          else
            echo "can_retrain=false" >> $GITHUB_OUTPUT
          fi

          echo "pool_size=$COUNT" >> $GITHUB_OUTPUT

  retrain:
    name: ML Batch Retraining
    needs: check-pool-size
    runs-on: ubuntu-latest
    if: needs.check-pool-size.outputs.can_retrain == 'true'

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: "3.10"

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Install Python dependencies
        run: |
          pip install boto3 mlflow torch torchvision timm scikit-learn pandas numpy tqdm

      - name: Download approved training pool
        run: |
          aws s3 sync s3://${{ env.S3_BUCKET }}/approved/ ./training_pool/
          echo "Downloaded $(find ./training_pool -type f | wc -l) files"

      - name: Load production model from MLflow
        run: |
          mlflow models pull skin-lesion:Production \
            --output-dir ./models/production || \
            echo "Using local fallback model"

      - name: Run batch retraining
        if: inputs.dry_run != 'true'
        run: |
          python ml/scripts/retrain.py \
            --training-pool-dir ./training_pool \
            --model-path ./models/production \
            --mlflow-uri ${{ env.MLFLOW_TRACKING_URI }} \
            --epochs 5 \
            --batch-size 16

      - name: Dry run (no training)
        if: inputs.dry_run == 'true'
        run: |
          echo "Dry run mode - no actual training performed"
          echo "Would train on $(find ./training_pool -type f | wc -l) images"

      - name: Register new model version
        if: inputs.dry_run != 'true'
        run: |
          mlflow models register \
            --name skin-lesion \
            --file ./models/new_model \
            --description "Fine-tuned on curated training pool (quarterly batch)"

      - name: Compare with production model
        if: inputs.dry_run != 'true'
        run: |
          echo "Comparing new model with production..."
          # In production, this would:
          # 1. Evaluate both models on held-out test set
          # 2. Compare AUC
          # 3. If AUC improvement > 0.005, tag as PROMOTE
          # 4. Otherwise, tag as DISCARD

      - name: Notify admin
        if: always()
        run: |
          if [ "${{ needs.check-pool-size.outputs.can_retrain }}" == "true" ]; then
            echo "Batch retraining completed. Please review in MLflow."
            # In production, would send Slack/email notification
          else
            echo "Pool size below minimum (need 5000). Retraining skipped."
          fi
```

---

## Step 6: ECS Task Definitions

### Create Staging Task Definition

Create `backend/ecs-task-definition-staging.json`:

```json
{
  "family": "skin-lesion-backend-staging",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "1024",
  "memory": "2048",
  "containerDefinitions": [
    {
      "name": "backend",
      "image": "{{IMAGE}}",
      "essential": true,
      "portMappings": [
        {
          "containerPort": 8080,
          "protocol": "tcp"
        }
      ],
      "environment": [
        {
          "name": "ENVIRONMENT",
          "value": "staging"
        },
        {
          "name": "DATABASE_URL",
          "value": "{{$secrets.DATABASE_URL_STAGING}}"
        },
        {
          "name": "REDIS_URL",
          "value": "{{$secrets.REDIS_URL_STAGING}}"
        }
      ],
      "secrets": [
        {
          "name": "DATABASE_URL",
          "valueFrom": "arn:aws:secretsmanager:us-east-1:123456789:secret:skin-lesion/staging/db-url"
        },
        {
          "name": "AWS_ACCESS_KEY_ID",
          "valueFrom": "arn:aws:secretsmanager:us-east-1:123456789:secret:skin-lesion/shared/aws-access-key"
        },
        {
          "name": "AWS_SECRET_ACCESS_KEY",
          "valueFrom": "arn:aws:secretsmanager:us-east-1:123456789:secret:skin-lesion/shared/aws-secret-key"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/skin-lesion-staging",
          "awslogs-region": "us-east-1",
          "awslogs-stream-prefix": "ecs"
        }
      },
      "healthCheck": {
        "command": ["CMD-SHELL", "curl -f http://localhost:8080/health || exit 1"],
        "interval": 30,
        "timeout": 5,
        "retries": 3,
        "startPeriod": 60
      }
    }
  ]
}
```

---

## Step 7: GitHub Secrets

### Required Secrets

Add these in GitHub repository Settings > Secrets:

```bash
# AWS
AWS_ACCESS_KEY_ID=AKIA...
AWS_SECRET_ACCESS_KEY=...

# Vercel
VERCEL_TOKEN=...
VERCEL_ORG_ID=...
VERCEL_PROJECT_ID=...

# Expo (for mobile)
EXPO_TOKEN=...

# Database
DATABASE_URL_STAGING=postgresql+asyncpg://...
DATABASE_URL_PRODUCTION=postgresql+asyncpg://...

# Redis
REDIS_URL_STAGING=redis://...
REDIS_URL_PRODUCTION=redis://...
```

---

## Step 8: MLflow Setup

### Create MLflow Tracking Server

Create `ml/scripts/mlflow_setup.sh`:

```bash
#!/bin/bash
# MLflow Tracking Server Setup

# Using AWS ECR for container registry
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin 123456789.dkr.ecr.us-east-1.amazonaws.com

# Pull MLflow image
docker pull ghcr.io/mlflow/mlflow:latest

# Run MLflow server
docker run -d \
  --name mlflow-server \
  -p 5001:5000 \
  -v mlflow_data:/app/mlflow_data \
  -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
  -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
  -e MLFLOW_S3_ENDPOINT_URL=https://s3.us-east-1.amazonaws.com \
  -e MLFLOW_TRACKING_URI=s3://skin-lesion-mlflow/ \
  ghcr.io/mlflow/mlflow:latest \
  mlflow server \
  --backend-store-uri postgresql://$DB_USER:$DB_PASSWORD@$DB_HOST:5432/mlflow \
  --default-artifact-root s3://skin-lesion-mlflow/ \
  --host 0.0.0.0 \
  --port 5000
```

---

## CI/CD Summary

### Workflows Created

```
.github/workflows/
├── ci.yml                    # PR checks (lint, test, build)
├── deploy-backend.yml        # Backend staging + production
├── deploy-frontend.yml      # Frontend preview + production
├── deploy-mobile.yml        # Mobile EAS builds
└── batch-retrain.yml        # Manual batch ML retraining
```

### Pipeline Flow

1. **PR Created** → CI runs (lint, test, build)
2. **PR Merged** → Deploy to staging
3. **Manual Approval** → Deploy to production
4. **Curated Pool ≥ 5000** → Admin manually triggers batch retraining
5. **Human Review** → Admin reviews MLflow metrics
6. **Manual Promotion** → Admin promotes model in MLflow (never auto-promoted)

---

## Step 5.5: Mobile Deployment Pipeline

### Create Mobile Deployment Workflow

Create `.github/workflows/deploy-mobile.yml`:

```yaml
name: Deploy Mobile

on:
  push:
    branches: [main]
    paths:
      - "SkinLesionMobile/**"
      - ".github/workflows/deploy-mobile.yml"

env:
  EAS_BUILD_PROFILE: production

jobs:
  build-ios:
    name: Build iOS
    runs-on: ubuntu-latest
    environment: production
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Node.js
        uses: actions/setup-node@v4
        with:
          node-version: "20"
          cache: "npm"
          cache-dependency-path: SkinLesionMobile/package-lock.json

      - name: Setup EAS
        uses: expo/expo-github-action/setup@v8
        with:
          eas-version: latest
          token: ${{ secrets.EXPO_TOKEN }}

      - name: Install dependencies
        run: npm ci
        working-directory: SkinLesionMobile

      - name: Build iOS (Simulator)
        if: github.event_name == 'pull_request'
        run: eas build --platform ios --profile preview --non-interactive
        working-directory: SkinLesionMobile
        env:
          EXPO_TOKEN: ${{ secrets.EXPO_TOKEN }}

      - name: Build iOS (Production)
        if: github.ref == 'refs/heads/main' && github.event_name != 'pull_request'
        run: eas build --platform ios --profile production --non-interactive
        working-directory: SkinLesionMobile
        env:
          EXPO_TOKEN: ${{ secrets.EXPO_TOKEN }}

      - name: Upload build artifacts
        uses: actions/upload-artifact@v4
        with:
          name: ios-build
          path: SkinLesionMobile/android-key.keystore
          retention-days: 1

  build-android:
    name: Build Android
    runs-on: ubuntu-latest
    environment: production
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Node.js
        uses: actions/setup-node@v4
        with:
          node-version: "20"
          cache: "npm"
          cache-dependency-path: SkinLesionMobile/package-lock.json

      - name: Setup EAS
        uses: expo/expo-github-action/setup@v8
        with:
          eas-version: latest
          token: ${{ secrets.EXPO_TOKEN }}

      - name: Install dependencies
        run: npm ci
        working-directory: SkinLesionMobile

      - name: Build Android (Preview)
        if: github.event_name == 'pull_request'
        run: eas build --platform android --profile preview --non-interactive
        working-directory: SkinLesionMobile
        env:
          EXPO_TOKEN: ${{ secrets.EXPO_TOKEN }}

      - name: Build Android (Production)
        if: github.ref == 'refs/heads/main' && github.event_name != 'pull_request'
        run: eas build --platform android --profile production --non-interactive
        working-directory: SkinLesionMobile
        env:
          EXPO_TOKEN: ${{ secrets.EXPO_TOKEN }}

      - name: Upload build artifacts
        uses: actions/upload-artifact@v4
        with:
          name: android-build
          path: SkinLesionMobile/android/app/build/outputs/apk/**/*.apk
          retention-days: 1

  submit-ios:
    name: Submit iOS to App Store
    needs: build-ios
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main' && github.event_name != 'pull_request'
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup EAS
        uses: expo/expo-github-action/setup@v8
        with:
          eas-version: latest
          token: ${{ secrets.EXPO_TOKEN }}

      - name: Submit iOS App
        run: eas submit --platform ios --latest --non-interactive
        working-directory: SkinLesionMobile
        env:
          EXPO_TOKEN: ${{ secrets.EXPO_TOKEN }}
          APPLE_ID: ${{ secrets.APPLE_ID }}
          APPLE_APP_SPECIFIC_PASSWORD: ${{ secrets.APPLE_APP_SPECIFIC_PASSWORD }}
          APPLE_TEAM_ID: ${{ secrets.APPLE_TEAM_ID }}

  submit-android:
    name: Submit Android to Play Store
    needs: build-android
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main' && github.event_name != 'pull_request'
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup EAS
        uses: expo/expo-github-action/setup@v8
        with:
          eas-version: latest
          token: ${{ secrets.EXPO_TOKEN }}

      - name: Submit Android App
        run: eas submit --platform android --latest --non-interactive
        working-directory: SkinLesionMobile
        env:
          EXPO_TOKEN: ${{ secrets.EXPO_TOKEN }}
          ANDROID_SERVICE_ACCOUNT_KEY_PATH: ./path-to-service-account.json
```

### Create Database Migration Workflow

Create `.github/workflows/db-migration.yml`:

```yaml
name: Database Migrations

on:
  push:
    branches: [main]
    paths:
      - "backend/**"
      - ".github/workflows/db-migration.yml"

env:
  AWS_REGION: us-east-1

jobs:
  migrate:
    name: Run Database Migrations
    runs-on: ubuntu-latest
    environment: staging

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: "3.10"

      - name: Install dependencies
        run: |
          pip install -r backend/requirements.txt
          pip install alembic

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Get secrets from Secrets Manager
        run: |
          DATABASE_URL=$(aws secretsmanager get-secret-value \
            --secret-id skin-lesion/staging/db-url \
            --query SecretString \
            --output text)
          echo "DATABASE_URL=$DATABASE_URL" >> $GITHUB_ENV

      - name: Run Alembic migrations
        run: |
          cd backend
          alembic upgrade head
        env:
          DATABASE_URL: ${{ env.DATABASE_URL }}

      - name: Verify migration
        run: |
          cd backend
          alembic current

  migrate-production:
    name: Run Production Migrations
    needs: migrate
    runs-on: ubuntu-latest
    environment: production
    if: github.ref == 'refs/heads/main'
    concurrency:
      group: prod-migrations
      cancel-in-progress: false

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: "3.10"

      - name: Install dependencies
        run: |
          pip install -r backend/requirements.txt
          pip install alembic

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Get secrets from Secrets Manager
        run: |
          DATABASE_URL=$(aws secretsmanager get-secret-value \
            --secret-id skin-lesion/prod/db-url \
            --query SecretString \
            --output text)
          echo "DATABASE_URL=$DATABASE_URL" >> $GITHUB_ENV

      - name: Create backup snapshot
        run: |
          aws rds create-db-snapshot \
            --db-instance-identifier skin-lesion-prod \
            --snapshot-identifier pre-migration-$(date +%Y%m%d%H%M)
        continue-on-error: true

      - name: Run Alembic migrations (dry run first)
        run: |
          cd backend
          alembic upgrade head --dry-run
        env:
          DATABASE_URL: ${{ env.DATABASE_URL }}

      - name: Manual approval for production migrations
        run: |
          echo "Production migration requires manual approval"
          echo "Run the following after approval:"
          echo "alembic upgrade head"

      - name: Notify failure
        if: failure()
        run: |
          echo "Database migration failed"
          # Would send Slack/email notification here
```

### Curation Pipeline Summary

| Stage | Actor | Action | Storage |
|-------|-------|--------|---------|
| Patient consents | Patient | Opt-in checkbox | pending_review/ |
| Doctor validates | Doctor | Expert opinion | pending_admin/ |
| Admin approves | Admin | Approve/Reject | approved/ |
| Retrain | System | Fine-tune (manual) | - |
| Promote | Admin | Human approval | Production |

### Environment Setup

| Environment | URL | Trigger |
|------------|-----|---------|
| Preview (Frontend) | *.vercel.app | Every PR |
| Staging (Backend) | staging-api.skinlesion.com | Merge to main |
| Production | api.skinlesion.com | Manual approval |

### Secrets Required

| Secret | Used By | Purpose |
|--------|---------|---------|
| AWS_ACCESS_KEY_ID | All workflows | AWS authentication |
| AWS_SECRET_ACCESS_KEY | All workflows | AWS authentication |
| VERCEL_TOKEN | Frontend deploy | Vercel authentication |
| EXPO_TOKEN | Mobile deploy | Expo authentication |
| DATABASE_URL_* | Backend | Database connection |
| REDIS_URL_* | Backend | Redis connection |

---

## Next Steps

**Phase 5 Complete!**

You now have:
1. Automated testing for every PR
2. Docker builds with caching
3. Staging and production deployments
4. Frontend preview deployments for PRs
5. Quarterly batch ML retraining pipeline (manual trigger)
6. MLflow integration for experiment tracking
7. Human-in-the-loop curation pipeline (doctor + admin approval)

### Final Steps

1. **Review all guides** and fill in your specific values (AWS account ID, Cognito pool IDs, etc.)
2. **Set up GitHub repository** with all workflows
3. **Configure AWS resources** using Phase 1 infrastructure guide
4. **Set up MLflow** for experiment tracking
5. **Configure EAS** for mobile builds
6. **Test everything** in staging before production
7. **Set up monitoring** with CloudWatch and Sentry

### Additional Resources

- AWS ECS Documentation: https://docs.aws.amazon.com/ecs/
- GitHub Actions: https://docs.github.com/en/actions
- MLflow: https://mlflow.org/docs/latest/index.html
- Expo EAS: https://docs.expo.dev/build/eas-json/
