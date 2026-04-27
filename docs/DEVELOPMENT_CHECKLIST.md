# Unified Development Checklist

**Complete checklist for setting up and developing the Skin Lesion Analysis Platform**

---

## Overview

This checklist provides a sequential, step-by-step guide through all 5 development phases. Each phase builds on the previous, so complete them in order.

---

## Prerequisites (Complete Before Anything)

### Account Setup
- [ ] AWS account created with billing enabled
- [ ] GitHub account created with access to repositories
- [ ] Expo account created for mobile development
- [ ] Apple Developer account (for iOS mobile, $99/year)
- [ ] Google Play Developer account (for Android, $25 one-time)

### Local Development Environment
- [ ] Git installed and configured
  ```bash
  git config --global user.name "Your Name"
  git config --global user.email "you@example.com"
  ```
- [ ] Python 3.10+ installed (use pyenv or installer)
  ```bash
  python --version  # Should be 3.10.x or higher
  ```
- [ ] Node.js 20+ installed (use nvm)
  ```bash
  node --version  # Should be 20.x
  ```
- [ ] Docker Desktop installed (for local containers)
  ```bash
  docker --version
  docker-compose --version
  ```
- [ ] AWS CLI v2 installed and configured
  ```bash
  aws configure
  aws sts get-caller-identity  # Verify credentials work
  ```
- [ ] Terraform installed (for infrastructure)
  ```bash
  terraform --version  # Should be 1.5+
  ```

### IDE Setup
- [ ] VS Code installed with extensions:
  - Python (Microsoft)
  - Pylance (Microsoft)
  - ESLint
  - Prettier
  - Tailwind CSS IntelliSense
  - GitLens
- [ ] JetBrains PyCharm (optional, for Python)
- [ ] JetBrains WebStorm (optional, for JavaScript/TypeScript)

### Clone Repositories
```bash
# Create project directory
mkdir -p ~/projects/skin_lesion
cd ~/projects/skin_lesion

# Clone root architecture/infrastructure repo
git clone https://github.com/saiyudhaplhaomega/Skin_Lesion_Gradcam_Classification.git
cd Skin_Lesion_Gradcam_Classification

# Backend, frontend, and research are separate repos.
# Clone or place them as sibling directories inside this folder:
#   Skin_Lesion_Classification_backend/
#   Skin_Lesion_Classification_frontend/
#   Skin_Lesion_XAI_research/
```

---

## Phase 0: Reality Check and Learning Plan

Complete this before applying Terraform or building dashboards.

- [ ] Read `docs/PRODUCTION_BUILD_REVIEW.md`.
- [ ] Confirm backend FastAPI app does not exist yet and must be built from scratch.
- [ ] Confirm frontend is a scaffold and the patient upload flow is the first UI target.
- [ ] Confirm mobile app is future work after the backend/web API stabilizes.
- [ ] Confirm CI/CD workflows do not exist yet and CI should be built before deploy workflows.
- [ ] Decide whether first backend `/predict` uses a mock model response or real local checkpoint. Recommended: mock first, then real model.
- [ ] Write down your first vertical slice: upload image -> backend validates -> mocked prediction -> frontend displays result.

---

## Phase 1: Infrastructure Setup

**Estimated Time:** 2-3 days
**Prerequisite:** All prerequisites above

### AWS Account Configuration
- [ ] Set up AWS budget alerts
  ```bash
  # In AWS Console: Billing > Budgets > Create budget
  # Set alert at $50, $100, $200/month
  ```
- [ ] Enable MFA on root account
- [ ] Create IAM user for development (not using root keys)
- [ ] Configure AWS credentials profile
  ```bash
  aws configure --profile skin-lesion-dev
  export AWS_PROFILE=skin-lesion-dev
  ```

### Terraform Infrastructure
- [ ] Navigate to infrastructure directory
  ```bash
  cd infra/terraform
  ```
- [ ] Create backend configuration
  ```bash
  cat > backend.tf << 'EOF'
  terraform {
    backend "local" {
      path = "terraform.tfstate"
    }
  }
  EOF
  ```
- [ ] Create development variables
  ```bash
  cat > environments/dev.tfvars << 'EOF'
  aws_region   = "us-east-1"
  environment  = "dev"
  account_id   = "YOUR_ACCOUNT_ID"
  db_username  = "skinlesionadmin"
  db_password  = "DevPassword123!"
  pagerduty_webhook_arn = ""
  EOF
  ```
- [ ] Initialize Terraform
  ```bash
  make init
  ```
- [ ] Plan infrastructure
  ```bash
  make plan ENV=dev
  ```
- [ ] Apply infrastructure
  ```bash
  make apply ENV=dev
  ```
- [ ] Note outputs (VPC ID, Subnet IDs, RDS endpoint)

### Verify Infrastructure
- [ ] Check VPC exists
  ```bash
  aws ec2 describe-vpcs --filters "Name=tag:Name,Values=skin-lesion-dev"
  ```
- [ ] Check RDS instance
  ```bash
  aws rds describe-db-instances --db-instance-identifier skin-lesion-dev
  ```
- [ ] Check S3 buckets created
  ```bash
  aws s3 ls | grep skin-lesion
  ```
- [ ] Check ElastiCache (Redis)
  ```bash
  aws elasticache describe-replication-groups
  ```

### Cognito Setup
- [ ] Create Patient User Pool
  ```bash
  # In AWS Console: Cognito > Create user pool
  # - Pool name: skin-lesion-patients-dev
  # - Email verification
  # - Password policy: default
  # - App client: skin-lesion-web-app
  ```
- [ ] Create Doctor User Pool
  ```bash
  # In AWS Console: Cognito > Create user pool
  # - Pool name: skin-lesion-doctors-dev
  # - Admin approval required
  # - App client: skin-lesion-web-app
  ```
- [ ] Note Pool IDs and Client IDs for later

### ECR Repositories
- [ ] Create ECR repository for backend
  ```bash
  aws ecr create-repository --repository-name skin-lesion-backend
  ```
- [ ] Note repository URLs

### Phase 1 Complete When:
- [ ] VPC with public/private subnets across 3 AZs
- [ ] RDS PostgreSQL instance running
- [ ] ElastiCache Redis running
- [ ] S3 buckets created (models, training, exports)
- [ ] Cognito User Pools configured
- [ ] ECS task definitions ready

---

## Phase 2: Backend Development

**Estimated Time:** 5-7 days
**Prerequisite:** Phase 1 complete

### Project Setup
- [ ] Navigate to backend directory
  ```bash
  cd Skin_Lesion_Classification_backend
  ```
- [ ] Create Python virtual environment
  ```bash
  python -m venv venv
  source venv/bin/activate  # Linux/macOS
  # venv\Scripts\activate   # Windows
  ```
- [ ] Install dependencies
  ```bash
  pip install -r requirements.txt
  ```
- [ ] Create .env file
  ```bash
  cp .env.example .env
  # Fill in all values from Phase 1 outputs
  ```

### Database Setup
- [ ] Create database tables
  ```bash
  python -c "from app.db.session import init_db; import asyncio; asyncio.run(init_db())"
  ```
- [ ] Verify tables created
  ```bash
  # Connect to RDS
  psql postgresql://skinlesionadmin:DevPassword123!@skin-lesion-dev.xxxx.us-east-1.rds.amazonaws.com:5432/skinlesion
  \dt
  ```

### ML Model Setup
- [ ] Create model directory
  ```bash
  mkdir -p ml/outputs/models
  ```
- [ ] Download pre-trained ResNet50 (or use placeholder)
  ```bash
  # For production, model will be loaded from S3
  # For local dev, create mock model:
  python -c "
  import torch
  model = torch.hub.load('pytorch/vision', 'resnet50', pretrained=True)
  torch.save(model.state_dict(), 'ml/outputs/models/resnet50_best.pth')
  "
  ```

### API Development
- [ ] Implement user authentication endpoints
- [ ] Implement /predict endpoint
- [ ] Implement /explain endpoint (Grad-CAM)
- [ ] Implement /feedback endpoint
- [ ] Implement expert opinions endpoint
- [ ] Implement admin endpoints
- [ ] Add database models and migrations
- [ ] Add Redis caching layer

### Verify Backend
- [ ] Run local development server
  ```bash
  uvicorn app.main:app --reload --port 8080
  ```
- [ ] Test health endpoint
  ```bash
  curl http://localhost:8080/health
  ```
- [ ] Test API docs
  ```bash
  open http://localhost:8080/docs
  ```
- [ ] Run unit tests
  ```bash
  pytest tests/ -v
  ```

### Docker Build
- [ ] Build Docker image
  ```bash
  docker build -t skin-lesion-backend:test .
  ```
- [ ] Run with docker-compose
  ```bash
  docker-compose up --build
  ```
- [ ] Verify all services start
  ```bash
  docker-compose ps
  ```

### Push Backend to GitHub
- [ ] Initialize git (if not already)
  ```bash
  cd Skin_Lesion_Classification_backend
  git init
  git add .
  git commit -m "Initial backend commit"
  ```
- [ ] Create GitHub repo and push
  ```bash
  # Create repo on GitHub, then:
  git remote add origin https://github.com/yourusername/Skin_Lesion_Classification_backend.git
  git push -u origin main
  ```

### Phase 2 Complete When:
- [ ] All API endpoints implemented and tested
- [ ] Database models created and migrated
- [ ] Redis caching working
- [ ] Docker image builds successfully
- [ ] Unit tests passing (>80% coverage)
- [ ] Code pushed to GitHub

---

## Phase 3: Frontend Development

**Estimated Time:** 5-7 days
**Prerequisite:** Phase 2 complete (backend API working)

### Project Setup
- [ ] Navigate to frontend directory
  ```bash
  cd Skin_Lesion_Classification_frontend
  ```
- [ ] Install dependencies
  ```bash
  npm install
  ```
- [ ] Create .env.local
  ```bash
  cat > .env.local << 'EOF'
  NEXT_PUBLIC_API_URL=http://localhost:8080
  NEXT_PUBLIC_AWS_REGION=us-east-1
  NEXT_PUBLIC_COGNITO_PATIENT_POOL_ID=us-east-1_xxx
  NEXT_PUBLIC_COGNITO_DOCTOR_POOL_ID=us-east-1_yyy
  NEXT_PUBLIC_COGNITO_IDENTITY_POOL_ID=us-east-1:zzz
  EOF
  ```

### Component Development
- [ ] Implement AuthContext for authentication
- [ ] Implement Login page
- [ ] Implement Register page
- [ ] Implement Patient Dashboard
  - [ ] Image uploader component
  - [ ] Prediction display component
  - [ ] XAI heatmap viewer
  - [ ] Method selector
  - [ ] Feedback consent component
- [ ] Implement Doctor Dashboard
  - [ ] Case list component
  - [ ] Expert opinion form
- [ ] Implement Admin Dashboard
  - [ ] Training pool management
  - [ ] Doctor approval list
  - [ ] Stats display

### Landing Page
- [ ] Create public landing page
- [ ] Add features section
- [ ] Add XAI methods explanation
- [ ] Add privacy policy page

### Error Handling
- [ ] Create ErrorBoundary component
- [ ] Add global error handling
- [ ] Add loading states
- [ ] Add empty states

### Verify Frontend
- [ ] Run development server
  ```bash
  npm run dev
  ```
- [ ] Test login flow
- [ ] Test prediction flow
- [ ] Test role-based routing
- [ ] Run type check
  ```bash
  npm run type-check
  ```
- [ ] Run lint
  ```bash
  npm run lint
  ```
- [ ] Test build
  ```bash
  npm run build
  ```

### Deploy to Vercel (Preview)
- [ ] Install Vercel CLI
  ```bash
  npm install -g vercel
  ```
- [ ] Connect to Vercel project
  ```bash
  vercel
  ```
- [ ] Configure environment variables in Vercel dashboard
- [ ] Deploy preview for testing

### Push Frontend to GitHub
- [ ] Initialize git
  ```bash
  cd Skin_Lesion_Classification_frontend
  git init
  git add .
  git commit -m "Initial frontend commit"
  ```
- [ ] Create GitHub repo and push
  ```bash
  git remote add origin https://github.com/yourusername/Skin_Lesion_Classification_frontend.git
  git push -u origin main
  ```

### Phase 3 Complete When:
- [ ] All pages implemented and tested
- [ ] Login/Register flows working
- [ ] Patient upload and prediction flow working
- [ ] Doctor review flow working
- [ ] Admin dashboard working
- [ ] Mobile responsive
- [ ] Code pushed to GitHub

---

## Phase 4: Mobile Development

**Estimated Time:** 5-7 days
**Prerequisite:** Phase 3 complete (frontend working)

### Project Setup
- [ ] Navigate to mobile directory
  ```bash
  cd SkinLesionMobile
  ```
- [ ] Install dependencies
  ```bash
  npm install
  npx expo install
  ```
- [ ] Configure app.json
  ```bash
  # Edit app.json with your project settings
  # Set bundleIdentifier for iOS
  # Set package for Android
  ```
- [ ] Set up EAS build
  ```bash
  eas login
  eas build:configure
  ```

### Screen Development
- [ ] Implement Auth screens
  - [ ] Login screen
  - [ ] Register screen
- [ ] Implement Patient screens
  - [ ] Home/upload screen
  - [ ] History screen
- [ ] Implement Doctor screens
  - [ ] Patient list
  - [ ] Case review
- [ ] Implement Admin screens
  - [ ] Dashboard with stats
  - [ ] Training pool management
- [ ] Implement Profile screen

### Mobile-Specific Features
- [ ] Set up push notifications
  ```bash
  npx expo install expo-notifications
  ```
- [ ] Configure camera permissions
- [ ] Configure secure storage for tokens
- [ ] Add offline storage for predictions
  ```bash
  npm install @react-native-async-storage/async-storage
  ```

### Platform-Specific Setup

#### iOS
- [ ] Create Apple Developer account
- [ ] Set up App ID in Apple Developer portal
- [ ] Configure provisioning profile
- [ ] Set up push notification certificates
- [ ] Build for iOS Simulator
  ```bash
  eas build --platform ios --profile preview
  ```
- [ ] Build for App Store
  ```bash
  eas build --platform ios --profile production
  ```

#### Android
- [ ] Create Google Play Developer account
- [ ] Set up Google Cloud project
- [ ] Configure Play Store listing
- [ ] Set up push notification credentials
- [ ] Build debug APK
  ```bash
  eas build --platform android --profile preview
  ```
- [ ] Build production APK/AAB
  ```bash
  eas build --platform android --profile production
  ```

### Verify Mobile App
- [ ] Test on iOS Simulator
  ```bash
  npx expo run:ios
  ```
- [ ] Test on Android Emulator
  ```bash
  npx expo run:android
  ```
- [ ] Test on physical device (Expo Go)
  ```bash
  npx expo start
  # Scan QR code with Expo Go app
  ```
- [ ] Test authentication flow
- [ ] Test image upload
- [ ] Test push notifications

### Push Mobile to GitHub
- [ ] Initialize git
  ```bash
  cd SkinLesionMobile
  git init
  git add .
  git commit -m "Initial mobile commit"
  ```
- [ ] Create GitHub repo and push
  ```bash
  git remote add origin https://github.com/yourusername/SkinLesionMobile.git
  git push -u origin main
  ```

### Phase 4 Complete When:
- [ ] All screens implemented
- [ ] Authentication working
- [ ] Image upload and prediction working
- [ ] Push notifications configured
- [ ] iOS build successful
- [ ] Android build successful
- [ ] Code pushed to GitHub

---

## Phase 5: CI/CD and Deployment

**Estimated Time:** 3-5 days
**Prerequisite:** Phases 2, 3, 4 complete

### GitHub Actions Setup
- [ ] Add GitHub secrets
  ```bash
  # In GitHub repo: Settings > Secrets
  AWS_ACCESS_KEY_ID=xxx
  AWS_SECRET_ACCESS_KEY=xxx
  VERCEL_TOKEN=xxx
  EXPO_TOKEN=xxx
  ```
- [ ] Verify CI workflow runs on PR
- [ ] Verify backend deployment to staging
- [ ] Verify frontend deployment to Vercel

### Backend Deployment
- [ ] Create ECS cluster (if not via Terraform)
- [ ] Create task definitions
  ```bash
  # Create ecs-task-definition-prod.json
  ```
- [ ] Deploy to ECS staging
  ```bash
  # Via GitHub Actions on merge to main
  ```
- [ ] Verify staging deployment
- [ ] Manual approval for production
- [ ] Verify production deployment
- [ ] Set up health checks
- [ ] Configure auto-scaling

### Frontend Deployment
- [ ] Connect to Vercel
  ```bash
  vercel --prod
  ```
- [ ] Configure production environment variables
- [ ] Set up preview deployments for PRs
- [ ] Verify production URL works
- [ ] Configure custom domain (optional)

### Mobile Deployment
- [ ] Set up EAS credentials
  ```bash
  eas credentials --platform ios
  eas credentials --platform android
  ```
- [ ] Submit to App Store
  ```bash
  eas submit --platform ios --latest
  ```
- [ ] Submit to Google Play
  ```bash
  eas submit --platform android --latest
  ```
- [ ] Wait for review (1-3 days for App Store, 1-7 days for Play Store)

### MLflow Setup
- [ ] Deploy MLflow server
  ```bash
  # Via Docker or AWS
  docker run -d -p 5001:5000 \
    -e AWS_ACCESS_KEY_ID=xxx \
    -e AWS_SECRET_ACCESS_KEY=xxx \
    -v mlflow_data:/mlflow \
    ghcr.io/mlflow/mlflow:latest \
    mlflow server --backend-store-uri postgresql://... \
    --default-artifact-root s3://...
  ```
- [ ] Create model registry
  ```bash
  mlflow models register --name skin-lesion --model-path ./model
  ```
- [ ] Set up model stages (Staging, Production)

### Monitoring Setup
- [ ] Configure CloudWatch dashboards
- [ ] Set up alerts for:
  - [ ] ECS CPU > 80%
  - [ ] ECS memory > 80%
  - [ ] ALB 5xx error rate > 1%
  - [ ] RDS connections > 80%
- [ ] Configure Sentry for error tracking
- [ ] Set up log aggregation

### Documentation
- [ ] Review all BUILD_*.md guides
- [ ] Fill in specific values (account IDs, pool IDs, etc.)
- [ ] Update ARCHITECTURE.md with production URLs
- [ ] Create runbook for common operations
- [ ] Document escalation procedures

### Security Checklist
- [ ] Review SECURITY_CHECKLIST.md
- [ ] Verify all items checked
- [ ] Complete sign-off table
- [ ] Address any findings

### Phase 5 Complete When:
- [ ] CI/CD pipelines working
- [ ] Backend deployed to ECS production
- [ ] Frontend deployed to Vercel production
- [ ] Mobile apps in App Store and Play Store
- [ ] MLflow tracking configured
- [ ] Monitoring and alerts active
- [ ] Security checklist complete

---

## Post-Launch Checklist

### Pre-Launch
- [ ] Final security review
- [ ] Load testing
  ```bash
  # Run k6 load test
  k6 run tests/load.js
  ```
- [ ] Penetration testing (or schedule)
- [ ] GDPR compliance verified
- [ ] Privacy policy published
- [ ] Terms of service published

### Launch Day
- [ ] Monitor dashboards
- [ ] Watch error rates
- [ ] Enable on-call rotation
- [ ] Have rollback plan ready

### Post-Launch (Week 1)
- [ ] Monitor user feedback
- [ ] Track prediction volume
- [ ] Monitor training pool growth
- [ ] Address any bugs

### Post-Launch (Ongoing)
- [ ] Quarterly batch retraining (when pool >= 5000)
- [ ] Monthly dependency updates
- [ ] Quarterly security reviews
- [ ] Monitor model performance

---

## Troubleshooting Quick Reference

| Problem | Quick Fix |
|---------|----------|
| Backend won't start | Check DATABASE_URL, REDIS_URL env vars |
| Model not loading | Check S3 bucket, MODEL_PATH env var |
| CORS errors | Check ALLOWED_ORIGINS in backend config |
| Mobile build fails | Run `eas build:configure` again |
| Expo Go not loading | Clear cache: `expo start --clear` |
| Git push rejected | Pull first: `git pull origin main` |
| Terraform state locked | `terraform force-unlock LOCK_ID` |

---

## Useful Commands Reference

```bash
# Backend
cd Skin_Lesion_Classification_backend
source venv/bin/activate
uvicorn app.main:app --reload --port 8080
pytest tests/ -v

# Frontend
cd Skin_Lesion_Classification_frontend
npm run dev

# Mobile
cd SkinLesionMobile
npx expo start
npx expo run:ios

# Infrastructure
cd infra/terraform
make plan ENV=dev
make apply ENV=dev

# Docker
docker-compose up --build
docker-compose down

# AWS
aws ecs list-tasks --cluster skin-lesion-prod
aws logs tail /ecs/skin-lesion-prod --follow
```
