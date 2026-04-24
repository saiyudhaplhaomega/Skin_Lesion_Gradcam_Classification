# Environment Setup Guide

**Complete local development environment setup for the Skin Lesion Analysis Platform**

---

## Overview

This guide walks through setting up your local development environment for all components of the platform. Follow the phases in order - each builds on the previous.

---

## Prerequisites Checklist

Before starting, ensure you have:

- [ ] Git installed and configured
- [ ] AWS CLI configured with credentials
- [ ] GitHub account with access to repositories
- [ ] macOS, Linux, or Windows (with WSL2 for best experience)

---

## Phase 0: Base Tools

### Install Core Dependencies

**macOS:**
```bash
# Install Homebrew (if not installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install tools
brew install git node python@3.10 terraform docker docker-compose

# Install pyenv for Python version management
brew install pyenv
echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.zshrc
echo 'command -v pyenv-install || export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.zshrc
eval "$(pyenv init -)"
```

**Windows (WSL2):**
```bash
# Install WSL2
wsl --install -d Ubuntu-22.04

# Inside WSL
sudo apt update && sudo apt upgrade -y
sudo apt install -y git curl wget unzip python3.10 python3-pip

# Install Node.js
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs

# Install Docker
sudo apt install -y docker.io docker-compose
sudo usermod -aG docker $USER

# Install Terraform
wget https://releases.hashicorp.com/terraform_1.5.0_linux_amd64.zip
sudo unzip terraform_1.5.0_linux_amd64.zip -d /usr/local/bin/
```

**Linux (Ubuntu/Debian):**
```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y git curl wget unzip python3.10 python3-pip nodejs npm
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
```

### Install AWS CLI

```bash
# AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Configure
aws configure
# Enter: AWS Access Key ID, Secret Access Key, region (us-east-1), output format (json)
```

### Install Python Tools

```bash
# Create project directory
mkdir -p ~/projects/skin_lesion
cd ~/projects/skin_lesion

# Install pyenv (macOS)
pyenv install 3.10.12
pyenv local 3.10.12

# Verify Python
python --version  # Should show 3.10.12

# Install pipx and essential tools
python -m pip install --user pipx
pipx install pipenv
pipx install black
pipx install ruff
pipx install mypy

# Install AWS tools
pip install awscli boto3
```

---

## Phase 1: Infrastructure Setup

### Clone Repository and Navigate

```bash
cd ~/projects/skin_lesion
git clone https://github.com/saiyudhaplhaomega/Skin_Lesion_Gradcam_Classification.git
cd Skin_Lesion_Gradcam_Classification
```

### Configure Terraform Backend (Local State)

```bash
cd infra/terraform

# Create backend config for local development
cat > backend.tf << 'EOF'
terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}
EOF

# Initialize
make init
```

### Configure Environment Variables

```bash
# Create environments/dev.tfvars
cat > environments/dev.tfvars << 'EOF'
aws_region   = "us-east-1"
environment  = "dev"
account_id   = "YOUR_ACCOUNT_ID"
db_username  = "skinlesionadmin"
db_password  = "DevPassword123!"
pagerduty_webhook_arn = ""
EOF
```

### Deploy Development Infrastructure

```bash
# Plan (preview what will be created)
make plan ENV=dev

# Apply (creates infrastructure)
make apply ENV=dev

# Note the VPC ID, Subnet IDs, and other outputs
make output
```

### Verify Infrastructure

```bash
# Check VPC exists
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=skin-lesion-dev" --query 'Vpcs'

# Check RDS instance
aws rds describe-db-instances --db-instance-identifier skin-lesion-dev --query 'DBInstances[0].Endpoint'

# Check S3 buckets
aws s3 ls | grep skin-lesion
```

---

## Phase 2: Backend Setup

### Navigate to Backend

```bash
cd ~/projects/skin_lesion/Skin_Lesion_Gradcam_Classification/Skin_Lesion_Classification_backend
```

### Create Virtual Environment

```bash
# Create and activate venv
python -m venv venv
source venv/bin/activate  # Linux/macOS
# venv\Scripts\activate   # Windows

# Install dependencies
pip install -r requirements.txt
```

### Configure Environment

```bash
# Create .env file
cat > .env << 'EOF'
# Application
APP_NAME="Skin Lesion Analysis API (Dev)"
APP_VERSION="1.0.0"
DEBUG=true

# AWS
AWS_REGION=us-east-1
AWS_ACCOUNT_ID=YOUR_ACCOUNT_ID

# Cognito (from Terraform outputs)
COGNITO_PATIENT_POOL_ID=us-east-1_xxxxxxxx
COGNITO_DOCTOR_POOL_ID=us-east-1_yyyyyyyy
COGNITO_PATIENT_CLIENT_ID=xxxxxxxxxxxxx
COGNITO_DOCTOR_CLIENT_ID=yyyyyyyyyyyy
COGNITO_IDENTITY_POOL_ID=us-east-1:zzzzzzzz
COGNITO_ISSUER_URL=https://cognito-idp.us-east-1.amazonaws.com

# Database
DATABASE_URL=postgresql+asyncpg://skinlesionadmin:DevPassword123!@skin-lesion-dev.xxxxxxxxx.us-east-1.rds.amazonaws.com:5432/skinlesion
DATABASE_POOL_SIZE=5

# Redis (from Terraform outputs)
REDIS_URL=redis://skin-lesion-dev.xxxxxxxxx.use1.cache.amazonaws.com:6379/0

# S3
S3_BUCKET_MODELS=skin-lesion-models-dev-YOUR_ACCOUNT
S3_BUCKET_TRAINING=skin-lesion-training-dev-YOUR_ACCOUNT

# ML
MODEL_NAME=skin-lesion
BASE_MODEL_ARCH=resnet50
FALLBACK_MODEL_PATH=./ml/outputs/models/resnet50_best.pth
MLFLOW_TRACKING_URI=file:./mlruns

# Auth (local mock for development)
USE_MOCK_AUTH=true
MOCK_USER_ROLE=patient

# Security
SECRET_KEY=dev-secret-key-change-in-production
EOF
```

### Download Pre-trained Model (or Use Placeholder)

```bash
# Create model directory
mkdir -p ml/outputs/models

# For development, create a mock model (actual model file not included in repo)
# The model will be loaded from S3 in production
# For local dev without model, the API returns mock predictions

# Download a small placeholder (optional)
# curl -o ml/outputs/models/resnet50_best.pth https://download.pytorch.org/models/resnet50-0676ba61.pth
```

### Initialize Database

```bash
# Run migrations (if using Alembic)
alembic upgrade head

# Or create tables directly
python -c "from app.db.session import init_db; import asyncio; asyncio.run(init_db())"
```

### Start Backend Locally

```bash
# With hot reload
uvicorn app.main:app --reload --port 8080 --host 0.0.0.0

# Or using docker-compose (recommended for full stack)
docker-compose up --build
```

### Verify Backend

```bash
# Health check
curl http://localhost:8080/health

# Should return: {"status":"healthy"}

# Test prediction endpoint (requires auth)
# See Phase 3 for frontend integration
```

---

## Phase 3: Frontend Setup

### Navigate to Frontend

```bash
cd ~/projects/skin_lesion/Skin_Lesion_Gradcam_Classification/Skin_Lesion_Classification_frontend
```

### Install Dependencies

```bash
# Use Node 20
nvm use 20
npm install
```

### Configure Environment

```bash
# Create .env.local
cat > .env.local << 'EOF'
NEXT_PUBLIC_API_URL=http://localhost:8080
NEXT_PUBLIC_AWS_REGION=us-east-1
NEXT_PUBLIC_COGNITO_PATIENT_POOL_ID=us-east-1_xxxxxxxx
NEXT_PUBLIC_COGNITO_DOCTOR_POOL_ID=us-east-1_yyyyyyyy
NEXT_PUBLIC_COGNITO_IDENTITY_POOL_ID=us-east-1:zzzzzzzz
EOF
```

### Start Frontend

```bash
npm run dev
```

### Verify Frontend

Open http://localhost:3000 in your browser

---

## Phase 4: Mobile Setup (Expo)

### Navigate to Mobile

```bash
cd ~/projects/skin_lesion/Skin_Lesion_Gradcam_Classification/SkinLesionMobile
```

### Install Dependencies

```bash
npm install
npx expo install
```

### Configure Environment

```bash
# Create app.json with correct settings
# (Already configured in the repo)

# Environment variables via eas.json or .env
cat > .env << 'EOF'
EXPO_PUBLIC_API_URL=http://localhost:8080
EXPO_PUBLIC_AWS_REGION=us-east-1
EOF
```

### Run on Device/Simulator

```bash
# Start Expo
npx expo start

# Run on iOS (requires Xcode)
npx expo run:ios

# Run on Android (requires Android Studio)
npx expo run:android

# Run on Web
npx expo start --web
```

---

## Phase 5: Full Stack (Docker Compose)

For complete local development with all services:

```bash
cd ~/projects/skin_lesion/Skin_Lesion_Gradcam_Classification/Skin_Lesion_Classification_backend

# Start all services
docker-compose up --build

# This starts:
# - PostgreSQL database
# - Redis cache
# - Backend API
# - ML model server (placeholder)
```

Access services:
- Backend API: http://localhost:8080
- API Docs: http://localhost:8080/docs
- Frontend: http://localhost:3000 (separate terminal)

---

## Verification Checklist

After setup, verify each component:

### Backend Verification

```bash
# 1. Health check
curl http://localhost:8080/health
# Expected: {"status":"healthy"}

# 2. API docs accessible
curl http://localhost:8080/openapi.json | head -20

# 3. Test mock auth
curl -X POST http://localhost:8080/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"test123"}'
```

### Frontend Verification

```bash
# 1. Page loads without errors
# 2. Navigation works
# 3. Login flow functional
# 4. No console errors (F12 > Console)
```

### Database Verification

```bash
# Connect to database
psql postgresql://skinlesionadmin:DevPassword123!@localhost:5432/skinlesion

# Check tables
\dt

# Check users table has no rows (clean start)
SELECT COUNT(*) FROM users;
```

---

## Common Setup Issues

### Python Version Mismatch

```bash
# If you get "SyntaxError" or "Module not found"
# Check Python version
python --version  # Must be 3.10

# If wrong version
pyenv install 3.10.12
pyenv local 3.10.12
```

### Node Version Mismatch

```bash
# If npm install fails
node --version  # Must be 20
nvm install 20
nvm use 20
```

### Port Already in Use

```bash
# Find what's using port 8080
lsof -i :8080

# Kill it
kill -9 $(lsof -t -i :8080)

# Or use different port
uvicorn app.main:app --port 8081
```

### AWS Credentials Not Found

```bash
# Check credentials
aws configure

# Verify with
aws sts get-caller-identity

# If using named profiles
aws configure --profile myprofile
export AWS_PROFILE=myprofile
```

### Docker Permission Denied (Linux)

```bash
# Add yourself to docker group
sudo usermod -aG docker $USER
# Log out and back in
newgrp docker
```

---

## Useful Commands Reference

```bash
# Backend
cd Skin_Lesion_Classification_backend
source venv/bin/activate
uvicorn app.main:app --reload --port 8080

# Frontend
cd Skin_Lesion_Classification_frontend
npm run dev

# Mobile
cd SkinLesionMobile
npx expo start

# Infrastructure
cd infra/terraform
make plan ENV=dev
make apply ENV=dev
make destroy ENV=dev

# Docker
docker ps
docker logs -f <container_id>
docker-compose up --build
```

---

## Next Steps

After environment setup:

1. **Read the ARCHITECTURE.md** to understand system design
2. **Follow BUILD_PHASE_2_BACKEND.md** to understand backend implementation
3. **Set up local testing** with `pytest tests/`
4. **Configure pre-commit hooks** for lint/type check
5. **Join team Slack** for development communication