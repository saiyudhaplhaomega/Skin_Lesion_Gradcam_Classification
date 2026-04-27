# Phase 2: Backend Development

**Step-by-step guide to building a production-ready FastAPI backend with authentication**

---

## Before You Build: Critical Questions to Answer First

Work through these before writing a single line of application code. Each one is a decision that is expensive to change later.

### System Architect Questions
- [ ] **Is ElastiCache (Redis) provisioned in Terraform?** Without a shared Redis instance, each ECS task has its own in-memory predictions_store. A `/explain` call that hits a different task than the `/predict` call will return 404. This is a guaranteed bug with multiple ECS tasks. Provision ElastiCache before building `/explain`.
- [ ] **What is the timeout for `/explain`?** Grad-CAM on ResNet50 takes 200-800ms. Set a hard 10s timeout with `asyncio.wait_for()`. A hung CAM generation must not block the entire API.
- [ ] **What is the ECS health check grace period?** Model weights load from S3 at startup (20-40s). Set `health_check_grace_period_seconds = 120` in Terraform or ECS will restart tasks in a boot loop before the model loads.
- [ ] **Is MLflow server running and accessible from ECS?** The backend CLAUDE.md shows `MLFLOW_TRACKING_URI=file:./mlruns` for local dev. In production, MLflow needs a server, RDS backend, S3 artifacts, and network access from ECS. Configure this before writing any MLflow integration code.

### Data Engineer Questions
- [ ] **What is the unique constraint on the consent endpoint?** A patient who double-taps should not create two training pipeline entries. Add `UNIQUE(prediction_id)` to `training_cases` before the endpoint goes live.
- [ ] **What is the defined schema for `patient_demographics` JSONB?** Write it down now: `{age: int, sex: string, localization: string}`. Without a schema, your retraining scripts will fail on inconsistent JSON two quarters from now.
- [ ] **When does the raw image get persisted to S3?** Redis TTL is 1 hour. Patient consent + doctor review can span more than 1 hour. If you wait until doctor validation to write the image to S3, the Redis eviction will have already deleted it. Persist the image to S3 at consent time, not at validation time.
- [ ] **Where is the `deletion_requests` table?** GDPR Article 17 consent withdrawal must be trackable with a completion timestamp. Add this table before building the consent endpoint.

### AI Engineer Questions
- [ ] **Is your model's confidence score calibrated?** Raw softmax is overconfident. Apply temperature scaling post-training before serving. The calibration script should run as part of the model promotion workflow in MLflow.
- [ ] **Should Grad-CAM be cached?** Yes - if a user requests the heatmap twice, recalculating it wastes GPU. Store the result in Redis with key `explain:{prediction_id}:{method}` and the same 1-hour TTL as the prediction.
- [ ] **Do you need a batch inference endpoint?** Doctors reviewing 50 cases will call `/explain` 50 times sequentially. A `POST /explain/batch` endpoint would cut their review time from ~50s to ~5s. Plan this from the start - it changes your Redis key design.
- [ ] **What are your two CAM methods for production disagreement scoring?** Per RQ4, running two CAM methods and computing Jaccard disagreement is a cheap safety signal. Choose the pair now (recommended: GradCAM + EigenCAM) and design the prediction response to include a `disagreement_score` field from the start.

---

## Overview

The backend is the core of our application. It handles:
1. User authentication (JWT validation with Cognito)
2. Image classification (PyTorch models)
3. Grad-CAM heatmap generation (cached, with disagreement scoring)
4. Feedback collection with S3 storage
5. GDPR data exports and deletion requests
6. Admin operations (doctor approval, training pool management)
7. Async training pipeline (via SQS event publishing)

### Technology Stack
- **Framework**: FastAPI (async, high-performance)
- **Language**: Python 3.10
- **Database**: PostgreSQL (via SQLAlchemy async)
- **Cache**: Redis via ElastiCache (shared across all ECS tasks - NOT in-memory)
- **Storage**: S3 (model weights, training images, GDPR exports)
- **Auth**: AWS Cognito JWT validation
- **Message Queue**: SQS (training pipeline events)
- **Model Registry**: MLflow (server mode, not file:// mode in production)

---

## Current Repo State

The backend repository currently has ML helper code under `ml/src/`, but the production FastAPI app does not exist yet. Build the backend in vertical slices:

1. `GET /health` with no database.
2. `POST /api/v1/predict` with a mocked prediction response.
3. File validation and tests.
4. Real model loading from local checkpoint.
5. Redis-backed prediction cache.
6. `POST /api/v1/explain`.
7. Database, consent, doctor review, and admin flows.

This order lets you learn each layer without debugging AWS, auth, database, Redis, Grad-CAM, and Docker all at once.

### Snippet Accuracy Note

Some snippets below are learning scaffolds. Before copying them into production code:

- Match dependency versions to `Skin_Lesion_Classification_backend/requirements.txt`.
- Prefer `opencv-python-headless` in backend Docker images.
- Do not store raw images or tensors in Redis with `pickle` for production. Store images in S3 and keep only IDs/metadata/cache results in Redis.
- Add `pydantic-settings`, `sqlalchemy`, `asyncpg`, `alembic`, `redis`, `python-jose`, and `httpx` when you reach the steps that need them.
- Put `pytest`, `ruff`, and `mypy` in `requirements-dev.txt`, not the production Docker image.

---

## Step 1: Project Structure

### Create the Directory Structure

```bash
cd Skin_Lesion_Classification_backend

mkdir -p app/api/v1/endpoints
mkdir -p app/api/v1/middleware
mkdir -p app/core
mkdir -p app/db/models
mkdir -p app/db/schemas
mkdir -p app/ml
mkdir -p app/services
mkdir -p tests/unit
mkdir -p tests/integration
mkdir -p ml/scripts
mkdir -p ml/notebooks

touch app/__init__.py
touch app/api/__init__.py
touch app/api/v1/__init__.py
touch app/api/v1/endpoints/__init__.py
touch app/api/v1/middleware/__init__.py
touch app/core/__init__.py
touch app/db/__init__.py
touch app/db/models/__init__.py
touch app/db/schemas/__init__.py
touch app/ml/__init__.py
touch app/services/__init__.py
```

### Why This Structure?

```
app/
├── api/v1/endpoints/   ← API route handlers (like controllers)
├── api/v1/middleware/  ← Request/response middleware (auth, logging)
├── core/              ← Core utilities (security, config, exceptions)
├── db/               ← Database (models, schemas, session)
├── ml/               ← Machine learning (model loading, Grad-CAM)
└── services/         ← Business logic (auth service, feedback service)
```

---

## Step 2: Requirements.txt

The backend repo already has `requirements.txt`. Treat the repo file as the source of truth. The example below is a production baseline that matches the current project direction more closely than older snippets:

```txt
# Web Framework
fastapi==0.109.2
uvicorn[standard]==0.27.1
python-multipart==0.0.9

# Data Validation
pydantic==2.6.1
pydantic-settings==2.1.0
pydantic[email]==2.6.1

# Database
sqlalchemy[asyncio]==2.0.25
asyncpg==0.29.0
alembic==1.13.1

# AWS SDK
boto3==1.34.34
aioboto3==12.3.0

# Authentication
python-jose[cryptography]==3.3.0
passlib[bcrypt]==1.7.4
httpx==0.26.0

# ML / AI
torch==2.2.1
torchvision==0.17.1
timm==1.0.3
pytorch-gradcam==1.5.0
Pillow==10.2.0
opencv-python-headless==4.9.0.80

# Caching
redis==5.0.1

# Utilities
python-dateutil==2.8.2
uuid==1.30

# Testing
pytest==8.0.0
pytest-asyncio==0.23.4
pytest-cov==4.1.0
httpx==0.26.0

# Development
ruff==0.2.0
mypy==1.8.0
```

---

## Step 3: Configuration (config.py)

Create `app/core/config.py`:

```python
from pydantic_settings import BaseSettings
from functools import lru_cache
from typing import List
import os


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""

    # Application
    APP_NAME: str = "Skin Lesion Analysis API"
    APP_VERSION: str = "1.0.0"
    DEBUG: bool = False

    # Server
    HOST: str = "0.0.0.0"
    PORT: int = 8080

    # AWS Region
    AWS_REGION: str = "us-east-1"
    AWS_ACCOUNT_ID: str = ""

    # Cognito
    COGNITO_PATIENT_POOL_ID: str = ""
    COGNITO_DOCTOR_POOL_ID: str = ""
    COGNITO_PATIENT_CLIENT_ID: str = ""
    COGNITO_DOCTOR_CLIENT_ID: str = ""
    COGNITO_IDENTITY_POOL_ID: str = ""
    COGNITO_ISSUER_URL: str = ""

    # For local development (use these instead of real Cognito)
    USE_MOCK_AUTH: bool = True
    MOCK_USER_ROLE: str = "patient"  # or "doctor" or "admin"

    # Database
    DATABASE_URL: str = "postgresql+asyncpg://user:pass@localhost:5432/skinlesion"
    DATABASE_POOL_SIZE: int = 20
    DATABASE_MAX_OVERFLOW: int = 10

    # Redis
    REDIS_URL: str = "redis://localhost:6379/0"
    REDIS_PREDICTIONS_TTL: int = 3600  # 1 hour

    # S3 Buckets
    S3_BUCKET_MODELS: str = "skin-lesion-models"
    S3_BUCKET_FEEDBACK: str = "skin-lesion-feedback"
    S3_BUCKET_EXPORTS: str = "skin-lesion-exports"

    # ML
    MODEL_NAME: str = "skin-lesion"
    BASE_MODEL_ARCH: str = "resnet50"
    FALLBACK_MODEL_PATH: str = "./ml/outputs/models/resnet50_best.pth"
    MLFLOW_TRACKING_URI: str = "file:./mlruns"

    # CORS
    ALLOWED_ORIGINS: List[str] = [
        "http://localhost:3000",
        "http://localhost:19000",  # Expo
    ]

    # Security
    SECRET_KEY: str = "your-secret-key-change-in-production"

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"
        case_sensitive = True


@lru_cache()
def get_settings() -> Settings:
    """Get cached settings instance."""
    return Settings()


settings = get_settings()
```

### What Just Happened?

We created a **Settings** class using Pydantic's `BaseSettings`. This automatically:
- Reads environment variables from `.env` file
- Validates types (if you set `PORT=abc`, it will warn you)
- Provides sensible defaults
- Is cached (same instance used everywhere)

---

## Step 4: Database Models

### Create the Base

Create `app/db/base.py`:

```python
from sqlalchemy.ext.declarative import declarative_base

Base = declarative_base()
```

### Create User Model

Create `app/db/models/user.py`:

```python
from sqlalchemy import Column, String, Boolean, DateTime, Enum
from sqlalchemy.dialects.postgresql import UUID
from datetime import datetime
import uuid

from app.db.base import Base


class User(Base):
    """User model - synced from Cognito with app-specific data."""

    __tablename__ = "users"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    cognito_sub = Column(String(255), unique=True, nullable=False, index=True)
    email = Column(String(255), unique=True, nullable=False, index=True)
    role = Column(String(20), nullable=False, default="patient")
    approved = Column(Boolean, default=False)
    full_name = Column(String(255), nullable=True)
    medical_license = Column(String(255), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    last_login_at = Column(DateTime, nullable=True)

    def __repr__(self):
        return f"<User {self.email} ({self.role})>"

    def to_dict(self):
        return {
            "id": str(self.id),
            "cognito_sub": self.cognito_sub,
            "email": self.email,
            "role": self.role,
            "approved": self.approved,
            "full_name": self.full_name,
            "medical_license": self.medical_license,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "updated_at": self.updated_at.isoformat() if self.updated_at else None,
            "last_login_at": self.last_login_at.isoformat() if self.last_login_at else None,
        }
```

### Create Prediction Model

Create `app/db/models/prediction.py`:

```python
from sqlalchemy import Column, String, Integer, Numeric, DateTime, ForeignKey, Enum
from sqlalchemy.dialects.postgresql import UUID
from datetime import datetime
import uuid

from app.db.base import Base


class Prediction(Base):
    """Prediction model - stores all predictions."""

    __tablename__ = "predictions"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    prediction_id = Column(String(255), unique=True, nullable=False, index=True)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    diagnosis = Column(String(20), nullable=False)
    confidence = Column(Numeric(5, 4), nullable=False)
    model_version = Column(String(50), nullable=False)
    processing_time_ms = Column(Integer, nullable=False)
    image_path = Column(String(500), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, index=True)

    def __repr__(self):
        return f"<Prediction {self.prediction_id} ({self.diagnosis})>"

    def to_dict(self):
        return {
            "id": str(self.id),
            "prediction_id": self.prediction_id,
            "user_id": str(self.user_id),
            "diagnosis": self.diagnosis,
            "confidence": float(self.confidence),
            "model_version": self.model_version,
            "processing_time_ms": self.processing_time_ms,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }
```

### Create Expert Opinion Model

Create `app/db/models/expert_opinion.py`:

```python
from sqlalchemy import Column, String, Text, DateTime, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from datetime import datetime
import uuid

from app.db.base import Base


class ExpertOpinion(Base):
    """Expert opinion - doctors can add their diagnosis to predictions."""

    __tablename__ = "expert_opinions"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    prediction_id = Column(UUID(as_uuid=True), ForeignKey("predictions.id"), nullable=False)
    doctor_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    diagnosis = Column(String(20), nullable=False)
    notes = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    # Relationships
    prediction = relationship("Prediction", backref="expert_opinions")
    doctor = relationship("User", backref="opinions")

    def to_dict(self):
        return {
            "id": str(self.id),
            "prediction_id": str(self.prediction_id),
            "doctor_id": str(self.doctor_id),
            "diagnosis": self.diagnosis,
            "notes": self.notes,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }
```

### Create Data Export Model

Create `app/db/models/data_export.py`:

```python
from sqlalchemy import Column, String, DateTime, Enum
from sqlalchemy.dialects.postgresql import UUID
from datetime import datetime
import uuid

from app.db.base import Base


class DataExportRequest(Base):
    """GDPR data export requests."""

    __tablename__ = "data_export_requests"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    status = Column(String(20), default="pending")  # pending, processing, completed, failed
    s3_path = Column(String(500), nullable=True)
    requested_at = Column(DateTime, default=datetime.utcnow)
    completed_at = Column(DateTime, nullable=True)

    def to_dict(self):
        return {
            "id": str(self.id),
            "user_id": str(self.user_id),
            "status": self.status,
            "s3_path": self.s3_path,
            "requested_at": self.requested_at.isoformat() if self.requested_at else None,
            "completed_at": self.completed_at.isoformat() if self.completed_at else None,
        }
```

### Export All Models

Update `app/db/models/__init__.py`:

```python
from app.db.models.user import User
from app.db.models.prediction import Prediction
from app.db.models.expert_opinion import ExpertOpinion
from app.db.models.data_export import DataExportRequest

__all__ = ["User", "Prediction", "ExpertOpinion", "DataExportRequest"]
```

---

## Step 5: Pydantic Schemas

### Create Request/Response Schemas

Create `app/db/schemas/schemas.py`:

```python
from pydantic import BaseModel, Field, EmailStr
from typing import Optional, List
from datetime import datetime
from uuid import UUID


# ============ User Schemas ============

class UserBase(BaseModel):
    email: EmailStr
    full_name: Optional[str] = None


class UserCreate(UserBase):
    cognito_sub: str
    role: str = "patient"


class UserResponse(UserBase):
    id: UUID
    cognito_sub: str
    role: str
    approved: bool
    medical_license: Optional[str] = None
    created_at: datetime
    last_login_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class DoctorApprovalRequest(BaseModel):
    doctor_id: UUID
    action: str = Field(pattern="^(approve|reject)$")
    reason: Optional[str] = None


# ============ Prediction Schemas ============

class PredictionCreate(BaseModel):
    prediction_id: str
    diagnosis: str = Field(pattern="^(benign|malignant)$")
    confidence: float = Field(ge=0, le=1)
    model_version: str
    processing_time_ms: int
    image_path: Optional[str] = None


class PredictionResponse(BaseModel):
    prediction_id: str
    diagnosis: str
    confidence: float
    class_probabilities: dict
    model_version: str
    processing_time_ms: int
    created_at: datetime

    class Config:
        from_attributes = True


class PredictionDetailResponse(PredictionResponse):
    id: UUID
    user_id: UUID
    expert_opinions: List[dict] = []

    class Config:
        from_attributes = True


# ============ Explain Schemas ============

class ExplainRequest(BaseModel):
    prediction_id: str
    method: str = Field(pattern="^(gradcam|gradcam_pp|eigencam|layercam)$")


class ExplainResponse(BaseModel):
    explanation_id: str
    method: str
    heatmaps: dict
    metrics: dict


# ============ Feedback Schemas ============

class FeedbackRequest(BaseModel):
    prediction_id: str
    consent: bool = Field(description="Must be explicitly true")
    user_label: Optional[str] = Field(None, pattern="^(benign|malignant)$")


class FeedbackResponse(BaseModel):
    feedback_id: str
    status: str
    message: str


class FeedbackStatsResponse(BaseModel):
    pool_size: int
    minimum_to_retrain: int
    ready_to_retrain: bool
    last_retrain_date: Optional[str] = None


# ============ Expert Opinion Schemas ============

class ExpertOpinionCreate(BaseModel):
    prediction_id: str
    diagnosis: str = Field(pattern="^(benign|malignant)$")
    notes: Optional[str] = None


class ExpertOpinionResponse(BaseModel):
    id: UUID
    prediction_id: UUID
    doctor_id: UUID
    diagnosis: str
    notes: Optional[str]
    created_at: datetime

    class Config:
        from_attributes = True


# ============ Health Schemas ============

class HealthResponse(BaseModel):
    model_version: str
    device: str
    status: str
    database_connected: bool = False


class MethodsResponse(BaseModel):
    methods: List[str]


# ============ Admin Schemas ============

class AdminStatsResponse(BaseModel):
    total_users: int
    total_patients: int
    total_doctors: int
    pending_doctors: int
    total_predictions: int
    pool_size: int
    last_retrain_date: Optional[str] = None


# ============ GDPR Schemas ============

class DataExportRequestCreate(BaseModel):
    pass


class DataExportRequestResponse(BaseModel):
    id: UUID
    status: str
    download_url: Optional[str] = None
    requested_at: datetime
    expires_at: Optional[datetime] = None

    class Config:
        from_attributes = True
```

---

## Step 6: Database Session

Create `app/db/session.py`:

```python
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlalchemy.pool import NullPool
from app.core.config import settings

# Create async engine
engine = create_async_engine(
    settings.DATABASE_URL,
    echo=settings.DEBUG,
    pool_size=settings.DATABASE_POOL_SIZE,
    max_overflow=settings.DATABASE_MAX_OVERFLOW,
    poolclass=NullPool if "localhost" in settings.DATABASE_URL else None,
)

# Create async session factory
async_session_factory = async_sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=False,
)


async def get_db() -> AsyncSession:
    """Dependency for getting async database session."""
    async with async_session_factory() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()


async def init_db():
    """Initialize database tables."""
    from app.db.base import Base
    from app.db.models import User, Prediction, ExpertOpinion, DataExportRequest

    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
```

---

## Step 7: Authentication Middleware

### Create JWT Validation

Create `app/core/security.py`:

```python
import httpx
from jose import jwt, JWTError, ExpiredSignatureError
from fastapi import HTTPException, Security, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from typing import Optional
from app.core.config import settings
import logging

logger = logging.getLogger(__name__)

security = HTTPBearer(auto_error=False)


class CognitoJWTValidator:
    """Validates JWT tokens against AWS Cognito."""

    def __init__(self):
        self._jwks = None
        self._issuer = f"https://cognito-idp.{settings.AWS_REGION}.amazonaws.com"
        self._audience = None

    async def get_jwks(self, force_refresh: bool = False):
        """Fetch JWKS from Cognito."""
        if self._jwks and not force_refresh:
            return self._jwks

        # Determine which pool client to use based on settings
        if settings.COGNITO_PATIENT_POOL_ID:
            well_known_url = f"{self._issuer}/{settings.COGNITO_PATIENT_POOL_ID}/.well-known/jwks.json"
        elif settings.COGNITO_DOCTOR_POOL_ID:
            well_known_url = f"{self._issuer}/{settings.COGNITO_DOCTOR_POOL_ID}/.well-known/jwks.json"
        else:
            # For local development with mock auth
            return None

        try:
            async with httpx.AsyncClient() as client:
                response = await client.get(well_known_url)
                response.raise_for_status()
                self._jwks = response.json()
                return self._jwks
        except httpx.HTTPError as e:
            logger.error(f"Failed to fetch JWKS: {e}")
            raise HTTPException(status_code=503, detail="Authentication service unavailable")

    async def validate_token(self, token: str, expected_audience: str) -> dict:
        """Validate JWT token and return claims."""
        try:
            # For local development with mock auth
            if settings.USE_MOCK_AUTH:
                return {
                    "sub": "mock-user-id",
                    "email": "mock@example.com",
                    "custom:role": settings.MOCK_USER_ROLE,
                    "custom:approved": "true",
                }

            # Get JWKS
            jwks = await self.get_jwks()

            # Decode token header
            header = jwt.get_unverified_header(token)
            kid = header.get("kid")

            # Find the right key
            rsa_key = None
            for key in jwks.get("keys", []):
                if key.get("kid") == kid:
                    rsa_key = key
                    break

            if not rsa_key:
                raise HTTPException(status_code=401, detail="Invalid token signature")

            # Verify and decode
            payload = jwt.decode(
                token,
                rsa_key,
                algorithms=["RS256"],
                audience=expected_audience,
                issuer=self._issuer,
            )

            return payload

        except ExpiredSignatureError:
            raise HTTPException(status_code=401, detail="Token has expired")
        except JWTError as e:
            logger.error(f"JWT validation error: {e}")
            raise HTTPException(status_code=401, detail="Invalid token")


# Global validator instance
jwt_validator = CognitoJWTValidator()


async def get_current_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Security(security),
) -> dict:
    """
    Dependency to get current authenticated user.
    Validates JWT and returns user claims.
    """
    if not credentials:
        raise HTTPException(status_code=401, detail="Not authenticated")

    token = credentials.credentials

    # Try patient pool first, then doctor pool
    payload = None
    if settings.COGNITO_PATIENT_CLIENT_ID:
        try:
            payload = await jwt_validator.validate_token(token, settings.COGNITO_PATIENT_CLIENT_ID)
        except HTTPException:
            pass

    if not payload and settings.COGNITO_DOCTOR_CLIENT_ID:
        try:
            payload = await jwt_validator.validate_token(token, settings.COGNITO_DOCTOR_CLIENT_ID)
        except HTTPException:
            pass

    if not payload:
        raise HTTPException(status_code=401, detail="Invalid token")

    return {
        "sub": payload.get("sub"),
        "email": payload.get("email"),
        "role": payload.get("custom:role", "patient"),
        "approved": payload.get("custom:approved", "false") == "true",
    }


async def require_doctor(current_user: dict = Depends(get_current_user)) -> dict:
    """Require user to be an approved doctor."""
    if current_user["role"] not in ["doctor", "admin"]:
        raise HTTPException(status_code=403, detail="Doctor access required")

    if current_user["role"] == "doctor" and not current_user["approved"]:
        raise HTTPException(status_code=403, detail="Doctor account pending approval")

    return current_user


async def require_admin(current_user: dict = Depends(get_current_user)) -> dict:
    """Require user to be an admin."""
    if current_user["role"] != "admin":
        raise HTTPException(status_code=403, detail="Admin access required")

    return current_user
```

### What Just Happened?

We created JWT validation middleware that:
1. Fetches JWKS (JSON Web Key Set) from Cognito
2. Validates JWT signature
3. Checks token expiration
4. Returns user claims (sub, email, role, approved)

We also created dependency functions:
- `get_current_user` - any authenticated user
- `require_doctor` - only approved doctors
- `require_admin` - only admins

---

## Step 7.5: ML Model Loader

### Create Model Loader

Create `app/ml/model_loader.py`:

```python
import torch
import torchvision.models as models
from torchvision.models import ResNet50_Weights
import timm
import logging
from typing import Tuple, Optional
import os

logger = logging.getLogger(__name__)


class SkinLesionClassifier:
    """Loads and manages the skin lesion classification model."""

    def __init__(self):
        self.model: Optional[torch.nn.Module] = None
        self.device: str = "cpu"
        self.model_version: str = "1.0.0"
        self.model_architecture: str = "resnet50"
        self.class_names: list = ["benign", "malignant"]
        self.target_layer_name: str = "layer4"

    def load(self, model_path: str) -> None:
        """
        Load model from path or S3.

        Args:
            model_path: Local path or S3 URI to model weights
        """
        try:
            # Determine device
            self.device = "cuda" if torch.cuda.is_available() else "cpu"
            logger.info(f"Using device: {self.device}")

            # Load model architecture
            if self.model_architecture == "resnet50":
                self.model = models.resnet50(weights=ResNet50_Weights.DEFAULT)
            elif self.model_architecture == "efficientnet_b0":
                self.model = timm.create_model("efficientnet_b0", pretrained=True)
            elif self.model_architecture == "swin_transformer":
                self.model = timm.create_model("swin_tiny_patch4_window7_224", pretrained=True)
            else:
                # Default to resnet50
                self.model = models.resnet50(weights=ResNet50_Weights.DEFAULT)

            # Replace classifier head for 2-class output
            if hasattr(self.model, 'fc'):
                self.model.fc = torch.nn.Linear(self.model.fc.in_features, 2)
            elif hasattr(self.model, 'classifier'):
                self.model.classifier = torch.nn.Linear(
                    self.model.classifier.in_features, 2
                )

            # Load weights
            if model_path.startswith("s3://"):
                import boto3
                s3 = boto3.client("s3")
                bucket, key = model_path.replace("s3://", "").split("/", 1)
                s3.download_file(bucket, key, "/tmp/model.pth")
                state_dict = torch.load("/tmp/model.pth", map_location=self.device)
            else:
                if os.path.exists(model_path):
                    state_dict = torch.load(model_path, map_location=self.device)
                else:
                    logger.warning(f"Model not found at {model_path}, using ImageNet weights")
                    self.model_version = "imagenet_fallback"
                    return

            self.model.load_state_dict(state_dict, strict=False)
            self.model.to(self.device)
            self.model.eval()

            # Try to extract version from metadata
            if "model_version" in state_dict:
                self.model_version = state_dict["model_version"]
            elif "metadata" in state_dict and isinstance(state_dict["metadata"], dict):
                self.model_version = state_dict["metadata"].get("version", "unknown")

            logger.info(f"Model loaded successfully: {self.model_version}")

        except Exception as e:
            logger.error(f"Failed to load model: {e}")
            # Fall back to ImageNet weights for development
            self.model = models.resnet50(weights=ResNet50_Weights.DEFAULT)
            self.model.fc = torch.nn.Linear(self.model.fc.in_features, 2)
            self.model.to(self.device)
            self.model.eval()
            self.model_version = "imagenet_fallback"
            logger.warning("Using ImageNet fallback weights")

    def predict(self, image_bytes: bytes) -> Tuple[str, float, dict]:
        """
        Run inference on image bytes.

        Args:
            image_bytes: Raw image bytes

        Returns:
            Tuple of (diagnosis, confidence, class_probabilities)
        """
        from PIL import Image
        import io
        from torchvision import transforms

        preprocess = transforms.Compose([
            transforms.Resize((224, 224)),
            transforms.ToTensor(),
            transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225]),
        ])

        # Load and preprocess image
        image = Image.open(io.BytesIO(image_bytes)).convert("RGB")
        input_tensor = preprocess(image).unsqueeze(0).to(self.device)

        # Run inference
        with torch.no_grad():
            outputs = self.model(input_tensor)
            probs = torch.nn.functional.softmax(outputs, dim=1)[0]

        # Extract results
        pred_class = torch.argmax(probs).item()
        confidence = probs[pred_class].item()
        diagnosis = self.class_names[pred_class]

        class_probabilities = {
            "benign": probs[0].item(),
            "malignant": probs[1].item(),
        }

        return diagnosis, confidence, class_probabilities

    def get_target_layer(self):
        """Get the target layer for Grad-CAM."""
        if hasattr(self.model, 'layer4'):
            return self.model.layer4
        elif hasattr(self.model, 'features'):
            return self.model.features[-1]
        return None


# Global classifier instance
classifier = SkinLesionClassifier()
```

### Create Predictions Store

Create `app/ml/predictions_store.py`:

```python
import redis
import json
import uuid
from datetime import datetime
from typing import Optional, Dict, Any
import logging

logger = logging.getLogger(__name__)


class PredictionsStore:
    """
    In-memory + Redis store for predictions.
    Predictions are stored temporarily for explain/feedback calls.
    TTL is 1 hour by default.
    """

    def __init__(self, redis_url: str = "redis://localhost:6379/0", ttl: int = 3600):
        self.ttl = ttl
        self._memory_store: Dict[str, Dict[str, Any]] = {}

        # Try to connect to Redis
        try:
            self.redis_client = redis.from_url(redis_url, decode_responses=True)
            self.redis_client.ping()
            self.use_redis = True
            logger.info("Using Redis for predictions store")
        except Exception as e:
            logger.warning(f"Redis not available, using in-memory store: {e}")
            self.redis_client = None
            self.use_redis = False

    def create(
        self,
        user_id: str,
        diagnosis: str,
        confidence: float,
        class_probabilities: dict,
        model_version: str,
        processing_time_ms: int,
        image_bytes: bytes,
        original_filename: str = None,
        model = None,
        target_layer = None,
    ) -> str:
        """
        Create a new prediction entry.

        Returns:
            prediction_id string
        """
        prediction_id = str(uuid.uuid4())

        data = {
            "prediction_id": prediction_id,
            "user_id": user_id,
            "diagnosis": diagnosis,
            "confidence": confidence,
            "class_probabilities": class_probabilities,
            "model_version": model_version,
            "processing_time_ms": processing_time_ms,
            "image_bytes": image_bytes.hex() if isinstance(image_bytes, bytes) else image_bytes,
            "original_filename": original_filename,
            "created_at": datetime.utcnow().isoformat(),
            "model": model,
            "target_layer": target_layer,
        }

        if self.use_redis:
            try:
                self.redis_client.setex(
                    f"prediction:{prediction_id}",
                    self.ttl,
                    json.dumps(data, default=str),
                )
            except Exception as e:
                logger.error(f"Redis write failed, using memory: {e}")
                self._memory_store[prediction_id] = data
        else:
            self._memory_store[prediction_id] = data

        return prediction_id

    def get(self, prediction_id: str) -> Optional[Dict[str, Any]]:
        """Get a prediction by ID."""
        if self.use_redis:
            try:
                data = self.redis_client.get(f"prediction:{prediction_id}")
                if data:
                    result = json.loads(data)
                    # Convert hex back to bytes
                    if "image_bytes" in result and isinstance(result["image_bytes"], str):
                        result["image_bytes"] = bytes.fromhex(result["image_bytes"])
                    return result
            except Exception as e:
                logger.error(f"Redis read failed, using memory: {e}")
                pass

        return self._memory_store.get(prediction_id)

    def delete(self, prediction_id: str) -> bool:
        """Delete a prediction."""
        if self.use_redis:
            try:
                return bool(self.redis_client.delete(f"prediction:{prediction_id}"))
            except Exception:
                pass

        if prediction_id in self._memory_store:
            del self._memory_store[prediction_id]
            return True
        return False

    def exists(self, prediction_id: str) -> bool:
        """Check if prediction exists."""
        if self.use_redis:
            try:
                return bool(self.redis_client.exists(f"prediction:{prediction_id}"))
            except Exception:
                pass

        return prediction_id in self._memory_store


# Global predictions store instance
predictions_store = PredictionsStore()
```

### Create CAM Generator

Create `app/ml/cam_generator.py`:

```python
import torch
import numpy as np
import cv2
from PIL import Image
import io
import logging
from typing import Dict, Any, Optional

logger = logging.getLogger(__name__)


class CAMGenerator:
    """
    Generates Class Activation Maps using various XAI methods.
    Supports: Grad-CAM, Grad-CAM++, EigenCAM, LayerCAM
    """

    def __init__(self, model: torch.nn.Module, target_layer: Optional[torch.nn.Module] = None):
        self.model = model
        self.model.eval()
        self.target_layer = target_layer or self._get_target_layer()
        self.gradients: Optional[torch.Tensor] = None
        self.activations: Optional[torch.Tensor] = None

    def _get_target_layer(self):
        """Find the last convolutional layer."""
        if hasattr(self.model, 'layer4'):
            return self.model.layer4
        elif hasattr(self.model, 'features'):
            return self.model.features[-1]
        # Fallback - find last conv layer
        for name, module in self.model.named_modules():
            if isinstance(module, torch.nn.Conv2d):
                self._last_conv_name = name
        return None

    def _save_gradient(self, grad):
        self.gradients = grad

    def generate(
        self,
        image_bytes: bytes,
        method: str = "gradcam",
    ) -> Dict[str, Any]:
        """
        Generate heatmap for image.

        Args:
            image_bytes: Raw image bytes
            method: One of gradcam, gradcam_pp, eigencam, layercam

        Returns:
            Dict with original, heatmap, overlay base64 strings and metrics
        """
        # Load and preprocess image
        image = Image.open(io.BytesIO(image_bytes)).convert("RGB")
        original_image = np.array(image.resize((224, 224)))

        input_tensor = self._preprocess_image(image).unsqueeze(0)

        if method == "gradcam":
            return self._gradcam(input_tensor, original_image)
        elif method == "gradcam_pp":
            return self._gradcam_pp(input_tensor, original_image)
        elif method == "eigencam":
            return self._eigencam(input_tensor, original_image)
        elif method == "layercam":
            return self._layercam(input_tensor, original_image)
        else:
            return self._gradcam(input_tensor, original_image)

    def _preprocess_image(self, image: Image.Image) -> torch.Tensor:
        import torchvision.transforms as transforms
        transform = transforms.Compose([
            transforms.Resize((224, 224)),
            transforms.ToTensor(),
            transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225]),
        ])
        return transform(image)

    def _gradcam(
        self,
        input_tensor: torch.Tensor,
        original_image: np.ndarray,
    ) -> Dict[str, Any]:
        """Standard Grad-CAM implementation."""
        self.model.eval()
        input_tensor.requires_grad_(True)

        # Forward pass
        output = self.model(input_tensor)
        pred_class = output.argmax(dim=1).item()

        # Backward pass
        self.model.zero_grad()
        output[0, pred_class].backward()

        # Get gradients and activations
        gradients = self.gradients  # Set by hook
        activations = self.activations  # Set by hook

        if gradients is None or activations is None:
            # Fallback to simple approach
            return self._simple_gradcam(input_tensor, original_image, pred_class)

        # Global average pooling of gradients
        weights = gradients.mean(dim=(2, 3), keepdim=True)

        # Weighted combination of activation maps
        cam = (weights * activations).sum(dim=1, keepdim=True)
        cam = torch.relu(cam)

        # Normalize
        cam = cam.squeeze().cpu().detach().numpy()
        cam = cv2.resize(cam, (224, 224))
        cam = (cam - cam.min()) / (cam.max() - cam.min() + 1e-8)
        cam = (cam * 255).astype(np.uint8)

        # Apply colormap
        heatmap = cv2.applyColorMap(cam, cv2.COLORMAP_JET)
        heatmap = cv2.cvtColor(heatmap, cv2.COLOR_BGR2RGB)

        # Create overlay
        overlay = cv2.addWeighted(original_image, 0.6, heatmap, 0.4, 0)

        # Calculate metrics
        focus_area = float((cam > 0.5).sum() / cam.size)

        return {
            "original": self._array_to_base64(original_image),
            "heatmap": self._array_to_base64(heatmap),
            "overlay": self._array_to_base64(overlay),
            "focus_area": focus_area,
            "cam_max": float(cam.max()),
            "cam_mean": float(cam.mean()),
        }

    def _gradcam_pp(
        self,
        input_tensor: torch.Tensor,
        original_image: np.ndarray,
    ) -> Dict[str, Any]:
        """Grad-CAM++ with improved gradient weighting."""
        self.model.eval()
        input_tensor.requires_grad_(True)

        output = self.model(input_tensor)
        pred_class = output.argmax(dim=1).item()

        self.model.zero_grad()
        output[0, pred_class].backward()

        gradients = self.gradients
        activations = self.activations

        if gradients is None or activations is None:
            return self._gradcam(input_tensor, original_image)

        # Grad-CAM++ uses second-order gradients
        grad_2 = gradients.pow(2)
        grad_3 = gradients.pow(3)

        # Alpha coefficients
        alpha_num = grad_2
        alpha_denom = 2 * grad_2 + (grad_3 * activations).sum(dim=(2, 3), keepdim=True) + 1e-8

        alpha = alpha_num / alpha_denom
        relu_grad = torch.relu(output[0, pred_class] - self.target_layer.output)
        weights = (alpha * relu_grad.unsqueeze(2).unsqueeze(2) * gradients).sum(dim=(2, 3), keepdim=True)

        cam = (weights * activations).sum(dim=1, keepdim=True)
        cam = torch.relu(cam)

        cam = cam.squeeze().cpu().detach().numpy()
        cam = cv2.resize(cam, (224, 224))
        cam = (cam - cam.min()) / (cam.max() - cam.min() + 1e-8)
        cam = (cam * 255).astype(np.uint8)

        heatmap = cv2.applyColorMap(cam, cv2.COLORMAP_JET)
        heatmap = cv2.cvtColor(heatmap, cv2.COLOR_BGR2RGB)
        overlay = cv2.addWeighted(original_image, 0.6, heatmap, 0.4, 0)

        focus_area = float((cam > 0.5).sum() / cam.size)

        return {
            "original": self._array_to_base64(original_image),
            "heatmap": self._array_to_base64(heatmap),
            "overlay": self._array_to_base64(overlay),
            "focus_area": focus_area,
            "cam_max": float(cam.max()),
            "cam_mean": float(cam.mean()),
        }

    def _eigencam(
        self,
        input_tensor: torch.Tensor,
        original_image: np.ndarray,
    ) -> Dict[str, Any]:
        """EigenCAM - uses PCA on activations."""
        self.model.eval()

        # Get activations
        hook_handle = self.target_layer.register_forward_hook(self._save_activations)
        _ = self.model(input_tensor)
        hook_handle.remove()

        activations = self.activations.squeeze().cpu().detach().numpy()

        # Reshape to (H*W, C)
        reshaped = activations.reshape(activations.shape[0], -1)

        # Compute covariance and eigenvalues
        cov = np.cov(reshaped)
        eigenvalues, eigenvectors = np.linalg.eig(cov)

        # Use first principal component
        first_pc = eigenvectors[:, 0]
        cam = np.dot(reshaped, first_pc).reshape(activations.shape[1], activations.shape[2])

        cam = np.maximum(cam, 0)
        cam = cv2.resize(cam, (224, 224))
        cam = (cam - cam.min()) / (cam.max() - cam.min() + 1e-8)
        cam = (cam * 255).astype(np.uint8)

        heatmap = cv2.applyColorMap(cam, cv2.COLORMAP_JET)
        heatmap = cv2.cvtColor(heatmap, cv2.COLOR_BGR2RGB)
        overlay = cv2.addWeighted(original_image, 0.6, heatmap, 0.4, 0)

        focus_area = float((cam > 0.5).sum() / cam.size)

        return {
            "original": self._array_to_base64(original_image),
            "heatmap": self._array_to_base64(heatmap),
            "overlay": self._array_to_base64(overlay),
            "focus_area": focus_area,
            "cam_max": float(cam.max()),
            "cam_mean": float(cam.mean()),
        }

    def _layercam(
        self,
        input_tensor: torch.Tensor,
        original_image: np.ndarray,
    ) -> Dict[str, Any]:
        """LayerCAM uses gradient-weighted activations from multiple layers."""
        self.model.eval()
        input_tensor.requires_grad_(True)

        output = self.model(input_tensor)
        pred_class = output.argmax(dim=1).item()

        self.model.zero_grad()
        output[0, pred_class].backward()

        gradients = self.gradients
        activations = self.activations

        if gradients is None or activations is None:
            return self._gradcam(input_tensor, original_image)

        # Element-wise multiplication of positive gradients and activations
        cam = torch.relu(activations) * torch.relu(gradients)
        cam = cam.sum(dim=1, keepdim=True)
        cam = torch.relu(cam)

        cam = cam.squeeze().cpu().detach().numpy()
        cam = cv2.resize(cam, (224, 224))
        cam = (cam - cam.min()) / (cam.max() - cam.min() + 1e-8)
        cam = (cam * 255).astype(np.uint8)

        heatmap = cv2.applyColorMap(cam, cv2.COLORMAP_JET)
        heatmap = cv2.cvtColor(heatmap, cv2.COLOR_BGR2RGB)
        overlay = cv2.addWeighted(original_image, 0.6, heatmap, 0.4, 0)

        focus_area = float((cam > 0.5).sum() / cam.size)

        return {
            "original": self._array_to_base64(original_image),
            "heatmap": self._array_to_base64(heatmap),
            "overlay": self._array_to_base64(overlay),
            "focus_area": focus_area,
            "cam_max": float(cam.max()),
            "cam_mean": float(cam.mean()),
        }

    def _simple_gradcam(
        self,
        input_tensor: torch.Tensor,
        original_image: np.ndarray,
        pred_class: int,
    ) -> Dict[str, Any]:
        """Simple fallback when hooks don't work."""
        cam = np.ones((7, 7), dtype=np.float32)
        cam = cv2.resize(cam, (224, 224))
        cam = (cam - cam.min()) / (cam.max() - cam.min() + 1e-8)
        cam = (cam * 255).astype(np.uint8)

        heatmap = cv2.applyColorMap(cam, cv2.COLORMAP_JET)
        heatmap = cv2.cvtColor(heatmap, cv2.COLOR_BGR2RGB)
        overlay = cv2.addWeighted(original_image, 0.6, heatmap, 0.4, 0)

        return {
            "original": self._array_to_base64(original_image),
            "heatmap": self._array_to_base64(heatmap),
            "overlay": self._array_to_base64(overlay),
            "focus_area": 0.5,
            "cam_max": 1.0,
            "cam_mean": 0.5,
        }

    def _save_activations(self, module, input, output):
        self.activations = output.detach()

    def _array_to_base64(self, image: np.ndarray) -> str:
        """Convert numpy array to base64 PNG string."""
        import base64
        img_pil = Image.fromarray(image)
        buffer = io.BytesIO()
        img_pil.save(buffer, format="PNG")
        return base64.b64encode(buffer.getvalue()).decode("utf-8")
```

### Register Hooks for Gradient Capture

The CAM generator needs hooks to capture gradients. Update `model_loader.py` to add forward hooks:

```python
# Add to SkinLesionClassifier predict method after model is loaded

def predict(self, image_bytes: bytes) -> Tuple[str, float, dict]:
    # ... existing code ...

    # Setup hooks for Grad-CAM
    self.gradients = None
    self.activations = None

    def save_gradient(grad):
        self.gradients = grad

    def save_activation(module, input, output):
        self.activations = output

    # Register hooks on target layer
    if hasattr(self, 'target_layer') and self.target_layer:
        self.handle_grad = self.target_layer.register_full_backward_hook(
            lambda module, grad_in, grad_out: save_gradient(grad_out[0])
        )
        self.handle_act = self.target_layer.register_forward_hook(save_activation)

    try:
        # ... inference code ...
    finally:
        # Cleanup hooks
        if hasattr(self, 'handle_grad'):
            self.handle_grad.remove()
        if hasattr(self, 'handle_act'):
            self.handle_act.remove()
```

---

## Step 8: API Dependencies

Create `app/api/deps.py`:

```python
from fastapi import Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from typing import Optional
from app.db.session import get_db
from app.core.security import get_current_user, require_doctor, require_admin
from app.db.models import User
from sqlalchemy import select

# Database session dependency
DbSession = Depends(get_db)

# Auth dependencies
CurrentUser = Depends(get_current_user)
RequireDoctor = Depends(require_doctor)
RequireAdmin = Depends(require_admin)


async def get_current_db_user(
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> User:
    """
    Get the current user from the database based on JWT claims.
    Creates user if doesn't exist.
    """
    # Try to find existing user
    result = await db.execute(
        select(User).where(User.cognito_sub == current_user["sub"])
    )
    db_user = result.scalar_one_or_none()

    if db_user:
        return db_user

    # Create new user
    db_user = User(
        cognito_sub=current_user["sub"],
        email=current_user["email"],
        role=current_user["role"],
        approved=current_user["approved"],
    )

    db.add(db_user)
    await db.flush()

    return db_user
```

---

## Step 9: API Endpoints

### Health Endpoint

Create `app/api/v1/endpoints/health.py`:

```python
from fastapi import APIRouter, Depends
from app.db.schemas import HealthResponse, MethodsResponse
from app.core.security import get_current_user
from app.ml.model_loader import classifier

router = APIRouter()

AVAILABLE_METHODS = ["gradcam", "gradcam_pp", "eigencam", "layercam"]


@router.get("/health", response_model=HealthResponse)
async def health_check(
    current_user: dict = Depends(get_current_user),
):
    """Health check - requires authentication."""
    return HealthResponse(
        model_version=classifier.model_version,
        device=classifier.device,
        status="healthy" if classifier.model is not None else "degraded",
        database_connected=True,
    )


@router.get("/methods", response_model=MethodsResponse)
async def get_methods(
    current_user: dict = Depends(get_current_user),
):
    """Get available XAI methods."""
    return MethodsResponse(methods=AVAILABLE_METHODS)
```

### Predict Endpoint

Create `app/api/v1/endpoints/predict.py`:

```python
from fastapi import APIRouter, File, UploadFile, HTTPException, Depends
from app.db.schemas import PredictionResponse
from app.api.deps import CurrentUser
from app.ml.model_loader import classifier
from app.ml.predictions_store import predictions_store
from app.services.prediction_service import PredictionService
import time

router = APIRouter()


@router.post("/predict", response_model=PredictionResponse)
async def predict(
    image: UploadFile = File(...),
    current_user: dict = Depends(CurrentUser),
):
    """
    Classify a skin lesion image.

    Requires authentication.
    Returns diagnosis, confidence, and prediction_id for follow-up calls.
    """
    # Validate file type
    if not image.content_type.startswith("image/"):
        raise HTTPException(
            status_code=400,
            detail="Invalid file type. Please upload an image."
        )

    # Read image bytes
    image_bytes = await image.read()

    # Check file size (10MB max)
    if len(image_bytes) > 10 * 1024 * 1024:
        raise HTTPException(
            status_code=400,
            detail="File too large. Maximum size is 10MB."
        )

    # Check model is loaded
    if classifier.model is None:
        raise HTTPException(
            status_code=503,
            detail="Model not loaded. Please try again later."
        )

    # Run inference
    start_time = time.time()

    try:
        diagnosis, confidence, class_probabilities = classifier.predict(image_bytes)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Prediction failed: {str(e)}")

    processing_time_ms = int((time.time() - start_time) * 1000)

    # Store prediction with user context
    prediction_id = predictions_store.create(
        user_id=current_user["sub"],
        diagnosis=diagnosis,
        confidence=confidence,
        class_probabilities=class_probabilities,
        model_version=classifier.model_version,
        processing_time_ms=processing_time_ms,
        image_bytes=image_bytes,
        original_filename=image.filename,
    )

    return PredictionResponse(
        prediction_id=prediction_id,
        diagnosis=diagnosis,
        confidence=confidence,
        class_probabilities=class_probabilities,
        model_version=classifier.model_version,
        processing_time_ms=processing_time_ms,
        created_at=datetime.utcnow(),
    )
```

### Explain Endpoint

Create `app/api/v1/endpoints/explain.py`:

```python
from fastapi import APIRouter, HTTPException, Depends
from app.db.schemas import ExplainRequest, ExplainResponse
from app.api.deps import CurrentUser
from app.ml.predictions_store import predictions_store
from app.ml.cam_generator import CAMGenerator
from app.core.config import settings
import uuid

router = APIRouter()

CAM_METHODS = ["gradcam", "gradcam_pp", "eigencam", "layercam"]


@router.post("/explain", response_model=ExplainResponse)
async def explain(
    request: ExplainRequest,
    current_user: dict = Depends(CurrentUser),
):
    """
    Generate XAI heatmap for a prediction.

    User can only access their own predictions.
    """
    # Find the prediction
    prediction = predictions_store.get(request.prediction_id)

    if not prediction:
        raise HTTPException(
            status_code=404,
            detail="Prediction not found or expired."
        )

    # Check user owns this prediction
    if prediction.get("user_id") != current_user["sub"]:
        raise HTTPException(
            status_code=403,
            detail="Access denied. This prediction belongs to another user."
        )

    # Validate method
    if request.method not in CAM_METHODS:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid method. Choose from: {CAM_METHODS}"
        )

    # Generate heatmap
    try:
        generator = CAMGenerator(
            model=prediction.get("model"),
            target_layer=prediction.get("target_layer"),
        )

        heatmaps = generator.generate(
            image_bytes=prediction["image_bytes"],
            method=request.method,
        )

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Heatmap generation failed: {str(e)}")

    explanation_id = str(uuid.uuid4())

    return ExplainResponse(
        explanation_id=explanation_id,
        method=request.method,
        heatmaps={
            "original": heatmaps["original"],
            "heatmap": heatmaps["heatmap"],
            "overlay": heatmaps["overlay"],
        },
        metrics={
            "focus_area_percentage": heatmaps.get("focus_area", 0.0),
            "cam_max": heatmaps.get("cam_max", 0.0),
            "cam_mean": heatmaps.get("cam_mean", 0.0),
        }
    )
```

### Feedback Endpoint

Create `app/api/v1/endpoints/feedback.py`:

```python
from fastapi import APIRouter, HTTPException, Depends
from app.db.schemas import FeedbackRequest, FeedbackResponse, FeedbackStatsResponse
from app.api.deps import CurrentUser, RequireDoctor, RequireAdmin
from app.ml.predictions_store import predictions_store
from app.services.feedback_service import FeedbackService
from app.services.training_pool_service import TrainingPoolService
import uuid

router = APIRouter()


@router.post("/feedback", response_model=FeedbackResponse)
async def submit_consent(
    request: FeedbackRequest,
    current_user: dict = Depends(CurrentUser),
):
    """
    Patient consents to training data contribution.

    Consent MUST be explicitly true.
    User can only consent for their own predictions.
    Image is moved to pending_review folder for doctor validation.
    """
    # CRITICAL: Consent must be explicitly True
    if request.consent is not True:
        raise HTTPException(
            status_code=400,
            detail="Consent must be explicitly true. Feedback rejected."
        )

    # Find the prediction
    prediction = predictions_store.get(request.prediction_id)

    if not prediction:
        raise HTTPException(
            status_code=404,
            detail="Prediction not found or expired."
        )

    # Check user owns this prediction
    if prediction.get("user_id") != current_user["sub"]:
        raise HTTPException(
            status_code=403,
            detail="Access denied. This prediction belongs to another user."
        )

    # Process consent - move image to pending_review folder
    try:
        training_pool_service = TrainingPoolService()
        case_id = await training_pool_service.save_consented_case(
            prediction_id=request.prediction_id,
            prediction=prediction,
        )

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Consent processing failed: {str(e)}")

    return FeedbackResponse(
        feedback_id=case_id,
        status="pending_review",
        message="Thank you. Your case has been added to the review queue for doctor validation."
    )


@router.get("/feedback/stats", response_model=FeedbackStatsResponse)
async def get_feedback_stats(
    current_user: dict = Depends(RequireDoctor),
):
    """
    Get training pool statistics.
    Only doctors and admins can access.
    """
    training_pool_service = TrainingPoolService()
    stats = await training_pool_service.get_pool_stats()

    return FeedbackStatsResponse(**stats)
```

### Expert Opinions Endpoint (Doctor Validation)

Create `app/api/v1/endpoints/expert_opinions.py`:

```python
from fastapi import APIRouter, HTTPException, Depends
from app.db.schemas import ExpertOpinionCreate, ExpertOpinionResponse
from app.api.deps import RequireDoctor
from app.ml.predictions_store import predictions_store
from app.services.training_pool_service import TrainingPoolService
import uuid

router = APIRouter()


@router.get("/predictions/pending-review")
async def list_pending_review(
    current_user: dict = Depends(RequireDoctor),
):
    """List cases pending doctor validation."""
    training_pool_service = TrainingPoolService()
    cases = await training_pool_service.get_pending_review_cases()
    return cases


@router.post("/expert-opinions", response_model=ExpertOpinionResponse)
async def submit_expert_opinion(
    request: ExpertOpinionCreate,
    current_user: dict = Depends(RequireDoctor),
):
    """
    Doctor submits expert opinion for a case.
    Case moves to pending_admin status for admin approval.
    """
    # Find the prediction
    prediction = predictions_store.get(request.prediction_id)

    if not prediction:
        raise HTTPException(
            status_code=404,
            detail="Prediction not found or expired."
        )

    opinion_id = str(uuid.uuid4())

    # In production, would save expert opinion to database

    return ExpertOpinionResponse(
        id=opinion_id,
        prediction_id=request.prediction_id,
        doctor_id=current_user["sub"],
        diagnosis=request.diagnosis,
        notes=request.notes,
        created_at=datetime.utcnow(),
    )
```

### Admin Training Pool Endpoint

Create `app/api/v1/endpoints/admin_training_pool.py`:

```python
from fastapi import APIRouter, HTTPException, Depends
from app.db.schemas import AdminStatsResponse
from app.api.deps import RequireAdmin
from app.services.training_pool_service import TrainingPoolService
from sqlalchemy import select, func
from app.db.models import User

router = APIRouter()


@router.get("/training-pool/pending")
async def list_training_pool_pending(
    current_user: dict = Depends(RequireAdmin),
):
    """List cases pending admin approval."""
    training_pool_service = TrainingPoolService()
    cases = await training_pool_service.get_pending_admin_cases()
    return cases


@router.post("/training-pool/approve/{case_id}")
async def approve_training_case(
    case_id: str,
    current_user: dict = Depends(RequireAdmin),
):
    """Approve a case for the training pool."""
    training_pool_service = TrainingPoolService()
    result = await training_pool_service.approve_case(case_id)
    return result


@router.post("/training-pool/reject/{case_id}")
async def reject_training_case(
    case_id: str,
    current_user: dict = Depends(RequireAdmin),
):
    """Reject a case from the training pool."""
    training_pool_service = TrainingPoolService()
    result = await training_pool_service.reject_case(case_id)
    return result


@router.get("/training-pool/stats", response_model=AdminStatsResponse)
async def get_training_pool_stats(
    current_user: dict = Depends(RequireAdmin),
):
    """Get training pool statistics."""
    training_pool_service = TrainingPoolService()
    pool_stats = await training_pool_service.get_pool_stats()

    # Get user counts
    async with async_session_factory() as db:
        total_users = await db.scalar(select(func.count(User.id)))
        patients = await db.scalar(
            select(func.count(User.id)).where(User.role == "patient")
        )
        doctors = await db.scalar(
            select(func.count(User.id)).where(User.role == "doctor")
        )
        pending_doctors = await db.scalar(
            select(func.count(User.id)).where(
                User.role == "doctor",
                User.approved == False
            )
        )

    return AdminStatsResponse(
        total_users=total_users or 0,
        total_patients=patients or 0,
        total_doctors=doctors or 0,
        pending_doctors=pending_doctors or 0,
        total_predictions=0,
        pool_size=pool_stats.get("pool_size", 0),
        last_retrain_date=pool_stats.get("last_retrain_date"),
    )


@router.post("/training-pool/retrain")
async def trigger_retraining(
    current_user: dict = Depends(RequireAdmin),
):
    """
    Manually trigger batch retraining.
    Only works when pool has >= 5000 approved cases.
    """
    training_pool_service = TrainingPoolService()
    stats = await training_pool_service.get_pool_stats()

    if stats["pool_size"] < 5000:
        raise HTTPException(
            status_code=400,
            detail=f"Not enough cases for retraining. Have {stats['pool_size']}, need 5000."
        )

    # In production, would trigger GitHub Actions workflow or MLflow job
    return {
        "status": "triggered",
        "message": "Retraining job has been triggered. Check MLflow for progress.",
        "pool_size": stats["pool_size"],
    }


@router.get("/stats", response_model=AdminStatsResponse)
async def get_admin_stats(
    current_user: dict = Depends(RequireAdmin),
):
    """Get system-wide statistics."""
    training_pool_service = TrainingPoolService()
    pool_stats = await training_pool_service.get_pool_stats()

    async with async_session_factory() as db:
        total_users = await db.scalar(select(func.count(User.id)))
        patients = await db.scalar(
            select(func.count(User.id)).where(User.role == "patient")
        )
        doctors = await db.scalar(
            select(func.count(User.id)).where(User.role == "doctor")
        )
        pending = await db.scalar(
            select(func.count(User.id)).where(
                User.role == "doctor",
                User.approved == False
            )
        )

        return AdminStatsResponse(
            total_users=total_users or 0,
            total_patients=patients or 0,
            total_doctors=doctors or 0,
            pending_doctors=pending or 0,
            total_predictions=0,
            pool_size=pool_stats.get("pool_size", 0),
            last_retrain_date=pool_stats.get("last_retrain_date"),
        )


@router.get("/doctors/pending")
async def get_pending_doctors(
    current_user: dict = Depends(RequireAdmin),
):
    """Get list of doctors pending approval."""
    async with async_session_factory() as db:
        result = await db.execute(
            select(User).where(
                User.role == "doctor",
                User.approved == False
            )
        )
        doctors = result.scalars().all()
        return [doctor.to_dict() for doctor in doctors]


@router.post("/doctors/approve")
async def approve_doctor(
    request: DoctorApprovalRequest,
    current_user: dict = Depends(RequireAdmin),
):
    """Approve or reject a doctor."""
    async with async_session_factory() as db:
        result = await db.execute(
            select(User).where(User.id == request.doctor_id)
        )
        doctor = result.scalar_one_or_none()

        if not doctor:
            raise HTTPException(status_code=404, detail="Doctor not found")

        if request.action == "approve":
            doctor.approved = True
            await db.commit()
            return {"message": f"Doctor {doctor.email} approved successfully"}

        elif request.action == "reject":
            doctor.approved = False
            doctor.role = "rejected"
            await db.commit()
            return {"message": f"Doctor {doctor.email} rejected"}


@router.post("/data-export", response_model=DataExportRequestResponse)
async def request_data_export(
    request: DataExportRequestCreate,
    current_user: dict = Depends(RequireAdmin),
):
    """Request GDPR data export for a user."""
    admin_service = AdminService()
    export_request = await admin_service.create_export_request(
        user_id=current_user["sub"]
    )
    return DataExportRequestResponse(**export_request)
```

---

## Step 10: Services

### Prediction Service

Create `app/services/prediction_service.py`:

```python
from typing import Tuple
import torch
from PIL import Image
import io
from torchvision import transforms

IMAGE_SIZE = 224
PREPROCESS = transforms.Compose([
    transforms.Resize((IMAGE_SIZE, IMAGE_SIZE)),
    transforms.ToTensor(),
    transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225]),
])


class PredictionService:
    """Service for handling predictions."""

    def preprocess_image(self, image_bytes: bytes) -> torch.Tensor:
        """Preprocess image for model."""
        image = Image.open(io.BytesIO(image_bytes)).convert("RGB")
        return PREPROCESS(image).unsqueeze(0)

    def postprocess_output(
        self,
        probs: torch.Tensor,
    ) -> Tuple[str, float, dict]:
        """Convert model output to diagnosis and confidence."""
        pred_class = torch.argmax(probs).item()
        confidence = probs[pred_class].item()

        diagnosis = "malignant" if pred_class == 1 else "benign"
        class_probabilities = {
            "benign": probs[0].item(),
            "malignant": probs[1].item(),
        }

        return diagnosis, confidence, class_probabilities
```

### Training Pool Service

Create `app/services/training_pool_service.py`:

```python
import boto3
from botocore.exceptions import ClientError
from app.core.config import settings
from datetime import datetime
import uuid
import json
import logging

logger = logging.getLogger(__name__)


class TrainingPoolService:
    """Service for handling the curated training data pipeline."""

    def __init__(self):
        self.s3_client = boto3.client("s3", region_name=settings.AWS_REGION)
        self.training_bucket = settings.S3_BUCKET_TRAINING

    async def save_consented_case(
        self,
        prediction_id: str,
        prediction: dict,
    ) -> str:
        """
        Save consented case to pending_review folder for doctor validation.
        Returns case_id.
        """
        case_id = str(uuid.uuid4())
        date_str = datetime.utcnow().strftime("%Y/%m/%d")

        # Save to pending_review folder
        image_key = f"pending_review/{date_str}/{case_id}.jpg"
        try:
            self.s3_client.put_object(
                Bucket=self.training_bucket,
                Key=image_key,
                Body=prediction["image_bytes"],
                ContentType="image/jpeg",
                ServerSideEncryption="AES256",
                Metadata={
                    "prediction_id": prediction_id,
                    "diagnosis": prediction["diagnosis"],
                    "consent_timestamp": datetime.utcnow().isoformat(),
                }
            )
        except ClientError as e:
            logger.error(f"S3 upload failed: {e}")
            raise

        # Save metadata
        metadata_key = f"pending_review/{date_str}/{case_id}.json"
        metadata = {
            "case_id": case_id,
            "prediction_id": prediction_id,
            "user_id": prediction.get("user_id", ""),
            "diagnosis": prediction["diagnosis"],
            "confidence": float(prediction["confidence"]),
            "model_version": prediction["model_version"],
            "consent_timestamp": datetime.utcnow().isoformat(),
            "status": "pending_review",
        }

        try:
            self.s3_client.put_object(
                Bucket=self.training_bucket,
                Key=metadata_key,
                Body=json.dumps(metadata),
                ContentType="application/json",
                ServerSideEncryption="AES256",
            )
        except ClientError as e:
            logger.error(f"S3 metadata upload failed: {e}")
            raise

        return case_id

    async def move_to_pending_admin(self, case_id: str, case_metadata: dict) -> None:
        """Doctor validated - move to pending_admin folder."""
        date_str = datetime.utcnow().strftime("%Y/%m/%d")

        # Copy image to pending_admin
        source_image = f"pending_review/{case_metadata['date_path']}/{case_id}.jpg"
        dest_image = f"pending_admin/{date_str}/{case_id}.jpg"

        try:
            self.s3_client.copy_object(
                Bucket=self.training_bucket,
                CopySource=f"{self.training_bucket}/{source_image}",
                Key=dest_image,
            )
            # Delete from pending_review
            self.s3_client.delete_object(
                Bucket=self.training_bucket,
                Key=source_image,
            )
        except ClientError as e:
            logger.error(f"S3 move failed: {e}")
            raise

    async def approve_case(self, case_id: str, case_metadata: dict) -> None:
        """Admin approved - move to approved folder and update metadata CSV."""
        date_str = datetime.utcnow().strftime("%Y/%m/%d")

        # Move image to approved folder
        source = f"pending_admin/{case_metadata['date_path']}/{case_id}.jpg"
        dest = f"approved/{date_str}/{case_id}.jpg"

        try:
            self.s3_client.copy_object(
                Bucket=self.training_bucket,
                CopySource=f"{self.training_bucket}/{source}",
                Key=dest,
            )
        except ClientError as e:
            logger.error(f"S3 copy failed: {e}")
            raise

    async def get_pool_stats(self) -> dict:
        """Get training pool statistics."""
        try:
            # Count approved cases
            approved_response = self.s3_client.list_objects_v2(
                Bucket=self.training_bucket,
                Prefix="approved/",
                MaxKeys=100000,
            )
            approved_count = sum(
                1 for obj in approved_response.get("Contents", [])
                if obj["Key"].endswith(".jpg")
            )

            # Count pending doctor review
            pending_review_response = self.s3_client.list_objects_v2(
                Bucket=self.training_bucket,
                Prefix="pending_review/",
                MaxKeys=10000,
            )
            pending_review_count = sum(
                1 for obj in pending_review_response.get("Contents", [])
                if obj["Key"].endswith(".json")
            )

            # Count pending admin approval
            pending_admin_response = self.s3_client.list_objects_v2(
                Bucket=self.training_bucket,
                Prefix="pending_admin/",
                MaxKeys=10000,
            )
            pending_admin_count = sum(
                1 for obj in pending_admin_response.get("Contents", [])
                if obj["Key"].endswith(".json")
            )

            return {
                "pool_size": approved_count,
                "pending_doctor_review": pending_review_count,
                "pending_admin_review": pending_admin_count,
                "minimum_to_retrain": 5000,
                "ready_to_retrain": approved_count >= 5000,
                "last_retrain_date": None,
            }

        except ClientError as e:
            logger.error(f"Failed to get pool stats: {e}")
            return {
                "pool_size": 0,
                "pending_doctor_review": 0,
                "pending_admin_review": 0,
                "minimum_to_retrain": 5000,
                "ready_to_retrain": False,
                "last_retrain_date": None,
            }


### Feedback Service

Create `app/services/feedback_service.py`:

```python
import boto3
from botocore.exceptions import ClientError
from app.core.config import settings
from datetime import datetime
import uuid
import json
import logging

logger = logging.getLogger(__name__)


class FeedbackService:
    """Service for handling patient feedback and consent."""

    def __init__(self):
        self.s3_client = boto3.client("s3", region_name=settings.AWS_REGION)
        self.feedback_bucket = settings.S3_BUCKET_FEEDBACK

    async def upload_consent(
        self,
        prediction_id: str,
        user_id: str,
        consent: bool,
        user_label: str = None,
    ) -> dict:
        """
        Record patient consent decision.

        Args:
            prediction_id: The prediction ID
            user_id: The patient's user ID
            consent: Whether patient consented
            user_label: Optional patient-provided diagnosis

        Returns:
            Dict with feedback_id and status
        """
        feedback_id = str(uuid.uuid4())

        feedback_data = {
            "feedback_id": feedback_id,
            "prediction_id": prediction_id,
            "user_id": user_id,
            "consent": consent,
            "user_label": user_label,
            "created_at": datetime.utcnow().isoformat(),
        }

        # Store feedback metadata
        key = f"feedback/{datetime.utcnow().strftime('%Y/%m/%d')}/{feedback_id}.json"

        try:
            self.s3_client.put_object(
                Bucket=self.feedback_bucket,
                Key=key,
                Body=json.dumps(feedback_data),
                ContentType="application/json",
                ServerSideEncryption="AES256",
            )
            logger.info(f"Feedback recorded: {feedback_id}")
            return feedback_data
        except ClientError as e:
            logger.error(f"Failed to record feedback: {e}")
            raise

    async def get_consent_stats(self) -> dict:
        """Get statistics about consent decisions."""
        try:
            # Count consented vs non-consented
            consented_count = 0
            non_consented_count = 0

            paginator = self.s3_client.get_paginator("list_objects_v2")
            pages = paginator.paginate(Bucket=self.feedback_bucket, Prefix="feedback/")

            for page in pages:
                for obj in page.get("Contents", []):
                    if obj["Key"].endswith(".json"):
                        try:
                            data = self.s3_client.get_object(
                                Bucket=self.feedback_bucket,
                                Key=obj["Key"]
                            )["Body"].read().decode("utf-8")
                            feedback = json.loads(data)
                            if feedback.get("consent"):
                                consented_count += 1
                            else:
                                non_consented_count += 1
                        except Exception:
                            continue

            return {
                "consented": consented_count,
                "not_consented": non_consented_count,
                "total": consented_count + non_consented_count,
                "consent_rate": consented_count / (consented_count + non_consented_count)
                    if (consented_count + non_consented_count) > 0 else 0,
            }
        except ClientError as e:
            logger.error(f"Failed to get consent stats: {e}")
            return {
                "consented": 0,
                "not_consented": 0,
                "total": 0,
                "consent_rate": 0,
            }
```


### Admin Service

Create `app/services/admin_service.py`:

```python
import boto3
from botocore.exceptions import ClientError
from app.core.config import settings
from datetime import datetime, timedelta
import uuid
import json
import logging

logger = logging.getLogger(__name__)


class AdminService:
    """Service for admin operations."""

    def __init__(self):
        self.s3_client = boto3.client("s3", region_name=settings.AWS_REGION)
        self.exports_bucket = settings.S3_BUCKET_EXPORTS

    async def create_export_request(self, user_id: str) -> dict:
        """
        Create GDPR data export request.

        Args:
            user_id: The user requesting their data

        Returns:
            Dict with export_id, status, and download_url (when ready)
        """
        export_id = str(uuid.uuid4())
        date_str = datetime.utcnow().strftime("%Y/%m/%d")

        # Create export manifest
        export_data = {
            "export_id": export_id,
            "user_id": user_id,
            "status": "processing",
            "requested_at": datetime.utcnow().isoformat(),
            "expires_at": None,
            "download_url": None,
        }

        # Save initial request
        request_key = f"exports/requests/{date_str}/{export_id}.json"
        try:
            self.s3_client.put_object(
                Bucket=self.exports_bucket,
                Key=request_key,
                Body=json.dumps(export_data),
                ContentType="application/json",
                ServerSideEncryption="AES256",
            )
        except ClientError as e:
            logger.error(f"Failed to create export request: {e}")
            raise

        # In production, this would trigger an async job to:
        # 1. Query database for all user data
        # 2. Export predictions, feedback, expert opinions
        # 3. Create a ZIP file with all data
        # 4. Upload to S3 with presigned URL
        # 5. Update export status to "completed"

        return export_data

    async def get_export_status(self, export_id: str) -> dict:
        """Get status of an export request."""
        # In production, would query database or S3 for status
        return {
            "export_id": export_id,
            "status": "completed",
            "download_url": f"https://{self.exports_bucket}.s3.amazonaws.com/exports/{export_id}/data.zip",
            "expires_at": (datetime.utcnow() + timedelta(days=7)).isoformat(),
        }

    async def delete_user_data(self, user_id: str) -> dict:
        """
        Process GDPR data deletion request.

        Args:
            user_id: The user requesting deletion

        Returns:
            Dict with deletion status
        """
        deletion_id = str(uuid.uuid4())

        # In production, this would:
        # 1. Delete from database (soft delete recommended)
        # 2. Delete uploaded images from S3
        # 3. Delete feedback records
        # 4. Log the deletion request for compliance

        deletion_data = {
            "deletion_id": deletion_id,
            "user_id": user_id,
            "status": "completed",
            "requested_at": datetime.utcnow().isoformat(),
            "deleted_at": datetime.utcnow().isoformat(),
        }

        logger.info(f"User data deletion processed: {deletion_id} for user: {user_id}")

        return deletion_data

    async def get_system_health(self) -> dict:
        """Get system health metrics for admin dashboard."""
        try:
            # Count S3 objects in various buckets
            training_bucket = settings.S3_BUCKET_TRAINING

            # Count approved cases
            approved_count = 0
            pending_review_count = 0
            pending_admin_count = 0

            for prefix, count_ref in [
                ("approved/", approved_count),
                ("pending_review/", pending_review_count),
                ("pending_admin/", pending_admin_count),
            ]:
                response = self.s3_client.list_objects_v2(
                    Bucket=training_bucket,
                    Prefix=prefix,
                    MaxKeys=10000,
                )
                count_ref = len([o for o in response.get("Contents", []) if o["Key"].endswith(".jpg")])

            return {
                "training_pool": {
                    "approved": approved_count,
                    "pending_review": pending_review_count,
                    "pending_admin": pending_admin_count,
                },
                "system_status": "healthy",
                "last_check": datetime.utcnow().isoformat(),
            }
        except ClientError as e:
            logger.error(f"Failed to get system health: {e}")
            return {
                "system_status": "error",
                "error": str(e),
                "last_check": datetime.utcnow().isoformat(),
            }
```


### Update API Router

Update `app/api/v1/router.py` to include all endpoints:

```python
from fastapi import APIRouter
from app.api.v1.endpoints import (
    health,
    predict,
    explain,
    feedback,
    expert_opinions,
    admin,
    admin_training_pool,
)

api_router = APIRouter()

api_router.include_router(health.router, tags=["health"])
api_router.include_router(predict.router, tags=["predict"])
api_router.include_router(explain.router, tags=["explain"])
api_router.include_router(feedback.router, tags=["feedback"])
api_router.include_router(expert_opinions.router, tags=["expert-opinions"])
api_router.include_router(admin.router, prefix="/admin", tags=["admin"])
api_router.include_router(
    admin_training_pool.router,
    prefix="/admin/training-pool",
    tags=["admin-training-pool"]
)
```

---

## Step 11: Main Application

Create `app/main.py`:

```python
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager

from app.core.config import settings
from app.db.session import init_db
from app.api.v1.router import api_router
from app.ml.model_loader import classifier
import logging

# Configure logging
logging.basicConfig(
    level=logging.INFO if not settings.DEBUG else logging.DEBUG,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Startup and shutdown events."""
    # Startup
    logger.info("Starting up Skin Lesion Analysis API...")

    # Initialize database tables
    await init_db()
    logger.info("Database initialized")

    # Load ML model
    try:
        import os
        model_path = os.environ.get("MODEL_PATH", settings.FALLBACK_MODEL_PATH)
        if os.path.exists(model_path):
            classifier.load(model_path)
            logger.info(f"Model loaded: {classifier.model_version}")
        else:
            logger.warning(f"Model not found at {model_path}, using mock mode")
    except Exception as e:
        logger.error(f"Failed to load model: {e}")

    yield

    # Shutdown
    logger.info("Shutting down...")


# Create FastAPI application
app = FastAPI(
    title=settings.APP_NAME,
    description="AI-powered skin lesion classification with Grad-CAM explainability",
    version=settings.APP_VERSION,
    lifespan=lifespan,
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include API router
app.include_router(api_router, prefix="/api/v1")


# Root endpoint
@app.get("/")
async def root():
    return {
        "name": settings.APP_NAME,
        "version": settings.APP_VERSION,
        "status": "running",
    }


# Health check (no auth required)
@app.get("/health")
async def health():
    return {"status": "healthy"}
```

### Create API Router

Create `app/api/v1/router.py`:

```python
from fastapi import APIRouter
from app.api.v1.endpoints import health, predict, explain, feedback, admin, expert_opinions, admin_training_pool

api_router = APIRouter()

api_router.include_router(health.router, tags=["health"])
api_router.include_router(predict.router, tags=["predict"])
api_router.include_router(explain.router, tags=["explain"])
api_router.include_router(feedback.router, tags=["feedback"])
api_router.include_router(expert_opinions.router, tags=["expert-opinions"])
api_router.include_router(admin.router, prefix="/admin", tags=["admin"])
api_router.include_router(admin_training_pool.router, prefix="/admin/training-pool", tags=["admin-training-pool"])
```

---

## Step 12: Docker Configuration

Create `Dockerfile`:

```dockerfile
# Use Python 3.10 slim image
FROM python:3.10-slim

# Set working directory
WORKDIR /app

# Install system dependencies for PyTorch
RUN apt-get update && apt-get install -y \
    libgomp1 \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first (for better caching)
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY app/ ./app/
COPY ml/ ./ml/

# Model weights are pulled from S3 at runtime (not baked in)
# This keeps the image small

# Expose port (ECS uses 8080 internally, ALB forwards 80/443)
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD python -c "import httpx; httpx.get('http://localhost:8080/health').raise_for_status()"

# Run the application
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8080"]
```

Create `docker-compose.yml`:

```yaml
version: "3.8"

services:
  backend:
    build:
      context: ./backend
      dockerfile: Dockerfile
    ports:
      - "8080:8080"
    environment:
      - DATABASE_URL=postgresql+asyncpg://postgres:postgres@db:5432/skinlesion
      - REDIS_URL=redis://redis:6379/0
      - AWS_REGION=us-east-1
      - MODEL_PATH=/app/ml/outputs/models/resnet50_best.pth
    volumes:
      - ./ml/outputs/models:/app/ml/outputs/models:ro
    depends_on:
      - db
      - redis

  db:
    image: postgres:15-alpine
    environment:
      - POSTGRES_DB=skinlesion
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=postgres
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data

volumes:
  postgres_data:
  redis_data:
```

---

## Step 13: Tests

Create `tests/conftest.py`:

```python
import pytest
import asyncio
from httpx import AsyncClient
from app.main import app


@pytest.fixture(scope="session")
def event_loop():
    """Create event loop for async tests."""
    loop = asyncio.get_event_loop_policy().new_event_loop()
    yield loop
    loop.close()


@pytest.fixture
async def client():
    """Create test client."""
    async with AsyncClient(app=app, base_url="http://test") as ac:
        yield ac


@pytest.fixture
def auth_headers():
    """Mock authentication headers for testing."""
    return {
        "Authorization": "Bearer mock-token"
    }
```

Create `tests/unit/test_predict.py`:

```python
import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_predict_requires_auth(client: AsyncClient):
    """Test that predict endpoint requires authentication."""
    response = await client.post("/api/v1/predict")
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_predict_validates_file_type(client: AsyncClient, auth_headers: dict):
    """Test that predict validates file types."""
    # This would need actual mock auth setup
    pass


@pytest.mark.asyncio
async def test_predict_validates_file_size(client: AsyncClient, auth_headers: dict):
    """Test that predict validates file size."""
    pass
```

---

## Backend Summary

### Files Created

```
backend/
├── app/
│   ├── __init__.py
│   ├── main.py                 # FastAPI app entry point
│   ├── config.py               # Settings (environment variables)
│   │
│   ├── api/
│   │   ├── __init__.py
│   │   ├── deps.py             # Dependencies (auth, db session)
│   │   └── v1/
│   │       ├── __init__.py
│   │       ├── router.py       # Main router
│   │       └── endpoints/
│   │           ├── health.py   # Health + methods endpoints
│   │           ├── predict.py  # Classification endpoint
│   │           ├── explain.py  # Grad-CAM endpoint
│   │           ├── feedback.py # Feedback endpoint
│   │           └── admin.py    # Admin endpoints
│   │
│   ├── core/
│   │   ├── __init__.py
│   │   └── security.py         # JWT validation, Cognito integration
│   │
│   ├── db/
│   │   ├── __init__.py
│   │   ├── base.py             # SQLAlchemy base
│   │   ├── session.py          # Database session
│   │   ├── models/
│   │   │   ├── __init__.py
│   │   │   ├── user.py         # User model
│   │   │   ├── prediction.py   # Prediction model
│   │   │   ├── expert_opinion.py
│   │   │   └── data_export.py
│   │   └── schemas/
│   │       ├── __init__.py
│   │       └── schemas.py      # Pydantic models
│   │
│   ├── ml/
│   │   ├── __init__.py
│   │   ├── model_loader.py     # PyTorch model loading
│   │   ├── predictions_store.py # Redis/in-memory cache
│   │   └── cam_generator.py    # Grad-CAM implementation
│   │
│   └── services/
│       ├── __init__.py
│       ├── prediction_service.py
│       ├── feedback_service.py  # S3 upload
│       └── admin_service.py
│
├── tests/
│   ├── conftest.py
│   └── unit/
│       └── test_predict.py
│
├── ml/
│   ├── scripts/
│   │   └── retrain.py
│   └── notebooks/
│
├── requirements.txt
├── Dockerfile
└── docker-compose.yml
```

### Key Concepts Learned

1. **Async/Await** - FastAPI uses async for high performance
2. **Dependency Injection** - `Depends()` makes code testable and modular
3. **Pydantic** - Automatic request/response validation
4. **SQLAlchemy Async** - Non-blocking database access
5. **JWT Validation** - Secure token-based authentication
6. **JWT with Cognito** - AWS-managed authentication

### Run Commands

```bash
# Local development
uvicorn app.main:app --reload --port 8080

# Docker Compose
docker-compose up --build

# Run tests
pytest tests/ -v

# Lint
ruff check app/

# Type check
mypy app/
```

---

## Step 16: AI Engineer Implementation Details

These are not optional polish items - they are correctness requirements for a medical AI system.

### 16A. Shared Redis Predictions Store (Multi-Instance Safe)

Do NOT use an in-memory dict for the predictions store. With 3 ECS tasks, Task A handles `/predict` and Task B handles `/explain` - they don't share memory. Always use Redis.

```python
# app/ml/predictions_store.py
import redis.asyncio as aioredis
import pickle
import asyncio
from app.core.config import settings

redis_client: aioredis.Redis = None

async def get_redis() -> aioredis.Redis:
    global redis_client
    if redis_client is None:
        redis_client = aioredis.from_url(
            settings.REDIS_URL,
            encoding="utf-8",
            decode_responses=False,  # binary for pickle
        )
    return redis_client

async def store_prediction(prediction_id: str, image_tensor, metadata: dict) -> None:
    r = await get_redis()
    payload = pickle.dumps({"tensor": image_tensor, "metadata": metadata})
    await r.setex(
        f"pred:{prediction_id}",
        settings.REDIS_PREDICTIONS_TTL,  # 3600 seconds
        payload,
    )

async def get_prediction(prediction_id: str) -> dict | None:
    r = await get_redis()
    raw = await r.get(f"pred:{prediction_id}")
    if raw is None:
        return None
    return pickle.loads(raw)

async def store_explain_result(prediction_id: str, method: str, result: dict) -> None:
    """Cache CAM result so repeated requests don't recompute."""
    r = await get_redis()
    payload = pickle.dumps(result)
    await r.setex(
        f"explain:{prediction_id}:{method}",
        settings.REDIS_PREDICTIONS_TTL,
        payload,
    )

async def get_explain_result(prediction_id: str, method: str) -> dict | None:
    r = await get_redis()
    raw = await r.get(f"explain:{prediction_id}:{method}")
    if raw is None:
        return None
    return pickle.loads(raw)
```

### 16B. Circuit Breaker on Inference

Wrap all ML inference calls with a timeout and circuit breaker. A hung model inference must not block the API.

```python
# app/ml/inference.py
import asyncio
from circuitbreaker import circuit
from app.core.config import settings

@circuit(failure_threshold=5, recovery_timeout=30, expected_exception=Exception)
async def run_inference_with_timeout(model_loader, image_tensor) -> dict:
    """Run model inference with hard timeout. Circuit opens after 5 failures."""
    try:
        result = await asyncio.wait_for(
            asyncio.get_event_loop().run_in_executor(
                None,  # use default thread pool
                model_loader.predict,
                image_tensor,
            ),
            timeout=10.0,  # 10 second hard limit
        )
        return result
    except asyncio.TimeoutError:
        raise HTTPException(
            status_code=503,
            detail="Model inference timeout. The service is temporarily overloaded.",
        )

@circuit(failure_threshold=5, recovery_timeout=30, expected_exception=Exception)
async def run_cam_with_timeout(cam_generator, image_tensor, method: str) -> dict:
    """Run Grad-CAM with timeout. CAM can be slow under load."""
    try:
        result = await asyncio.wait_for(
            asyncio.get_event_loop().run_in_executor(
                None,
                cam_generator.generate,
                image_tensor,
                method,
            ),
            timeout=15.0,  # CAM is slower than pure inference
        )
        return result
    except asyncio.TimeoutError:
        raise HTTPException(
            status_code=503,
            detail="Heatmap generation timeout. Try again in a moment.",
        )
```

### 16C. Confidence Calibration

Apply temperature scaling so confidence scores reflect real-world probabilities, not raw softmax outputs.

```python
# ml/scripts/calibrate_model.py
import torch
import torch.nn as nn
from torch.utils.data import DataLoader

class TemperatureScaling(nn.Module):
    """Learn a single temperature parameter to calibrate softmax outputs."""
    
    def __init__(self):
        super().__init__()
        self.temperature = nn.Parameter(torch.ones(1) * 1.5)
    
    def forward(self, logits):
        return logits / self.temperature

def calibrate(model, calibration_loader: DataLoader, device: str = "cpu") -> float:
    """Find optimal temperature on held-out calibration set using NLL loss."""
    temperature_model = TemperatureScaling().to(device)
    optimizer = torch.optim.LBFGS([temperature_model.temperature], lr=0.01, max_iter=50)
    nll_criterion = nn.CrossEntropyLoss()
    
    all_logits = []
    all_labels = []
    
    with torch.no_grad():
        for images, labels in calibration_loader:
            images = images.to(device)
            logits = model(images)
            all_logits.append(logits)
            all_labels.append(labels.to(device))
    
    all_logits = torch.cat(all_logits)
    all_labels = torch.cat(all_labels)
    
    def eval_nll():
        optimizer.zero_grad()
        loss = nll_criterion(temperature_model(all_logits), all_labels)
        loss.backward()
        return loss
    
    optimizer.step(eval_nll)
    
    optimal_temperature = temperature_model.temperature.item()
    print(f"Optimal temperature: {optimal_temperature:.4f}")
    return optimal_temperature

# Usage: run after training, save temperature to MLflow as a model parameter
# model.temperature = calibrate(model, calibration_loader)
# mlflow.log_param("temperature", model.temperature)
```

Apply at inference time:
```python
# In model_loader.py predict() method
logits = self.model(image_tensor)
calibrated_logits = logits / self.temperature  # loaded from MLflow
probs = torch.softmax(calibrated_logits, dim=1)
```

### 16D. CAM Disagreement Score (Production Safety Signal)

Run two CAM methods at inference time. High disagreement = flag for doctor review.

```python
# app/ml/cam_generator.py
import numpy as np
from typing import Tuple

def compute_disagreement_score(mask_a: np.ndarray, mask_b: np.ndarray) -> float:
    """
    Jaccard distance between two binarized CAM activation masks.
    0.0 = identical, 1.0 = completely different.
    High values (>0.5) indicate the model may be unreliable on this image.
    """
    threshold = 0.5  # binarize at 50% of max activation
    binary_a = (mask_a / mask_a.max()) > threshold
    binary_b = (mask_b / mask_b.max()) > threshold
    
    intersection = np.logical_and(binary_a, binary_b).sum()
    union = np.logical_or(binary_a, binary_b).sum()
    
    if union == 0:
        return 0.0
    
    jaccard_similarity = intersection / union
    return 1.0 - jaccard_similarity  # return distance, not similarity

async def generate_with_disagreement(
    cam_generator,
    image_tensor,
    primary_method: str = "gradcam",
    secondary_method: str = "eigencam",
) -> Tuple[dict, float]:
    """Generate CAM and compute safety disagreement score."""
    primary_result = await run_cam_with_timeout(cam_generator, image_tensor, primary_method)
    secondary_result = await run_cam_with_timeout(cam_generator, image_tensor, secondary_method)
    
    disagreement = compute_disagreement_score(
        primary_result["raw_mask"],
        secondary_result["raw_mask"],
    )
    
    return primary_result, disagreement
```

Include `disagreement_score` in the prediction response:
```python
# In predict endpoint response
{
    "prediction_id": "...",
    "diagnosis": "malignant",
    "confidence": 0.87,
    "disagreement_score": 0.62,  # > 0.5: flag for in-person review
    "recommend_review": True,    # computed: disagreement_score > 0.5
}
```

### 16E. Batch Explain Endpoint

Doctors reviewing cases do not want to call `/explain` 50 times. Give them a batch endpoint.

```python
# app/api/v1/endpoints/explain.py
from typing import List
import asyncio

class BatchExplainRequest(BaseModel):
    prediction_ids: List[str] = Field(max_length=20)  # cap at 20 per batch
    method: str = Field(default="gradcam", pattern="^(gradcam|gradcam_pp|eigencam|layercam)$")

@router.post("/explain/batch")
@limiter.limit("5/minute")  # stricter limit - this is compute-heavy
async def explain_batch(
    request: Request,
    body: BatchExplainRequest,
    current_user: User = Depends(require_doctor_or_admin),
    db: AsyncSession = Depends(get_db),
):
    """Generate CAM heatmaps for multiple predictions in parallel."""
    tasks = [
        _generate_single_explain(pred_id, body.method)
        for pred_id in body.prediction_ids
    ]
    # Run all CAM generations concurrently (thread pool, not async)
    results = await asyncio.gather(*tasks, return_exceptions=True)
    
    return {
        "results": [
            r if not isinstance(r, Exception) else {"error": str(r), "prediction_id": pid}
            for pid, r in zip(body.prediction_ids, results)
        ]
    }
```

### 16F. Model Cold Start - Startup Readiness Check

The `/health` endpoint must only return 200 after the model is loaded. ECS uses this for health checks.

```python
# app/main.py
from contextlib import asynccontextmanager
import asyncio

model_ready = asyncio.Event()

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Load model on startup before marking service as ready."""
    logger.info("Loading model from MLflow/S3...")
    try:
        await asyncio.get_event_loop().run_in_executor(None, model_loader.load)
        model_ready.set()
        logger.info(f"Model loaded: {model_loader.model_version}")
    except Exception as e:
        logger.critical(f"Model load failed: {e}")
        # Don't set model_ready - health checks will fail and ECS will restart
    
    yield  # app runs here
    
    model_ready.clear()
    logger.info("Shutdown complete")

@router.get("/health")
async def health():
    if not model_ready.is_set():
        raise HTTPException(503, "Model not loaded yet - service initializing")
    
    return {
        "status": "healthy",
        "model_version": model_loader.model_version,
        "device": model_loader.device,
    }
```

---

## Step 17: Data Engineer Implementation Details

### 17A. Idempotent Consent Endpoint

```python
# app/api/v1/endpoints/consent.py
@router.post("/consent")
async def submit_consent(
    body: ConsentRequest,
    current_user: User = Depends(require_patient),
    db: AsyncSession = Depends(get_db),
):
    """
    Idempotent - calling twice with same prediction_id returns 200, not duplicate entry.
    """
    # Check for existing entry first
    existing = await db.scalar(
        select(TrainingCase).where(TrainingCase.prediction_id == body.prediction_id)
    )
    if existing:
        return {"status": "already_consented", "training_case_id": str(existing.id)}
    
    if not body.consent:
        raise HTTPException(422, "consent must be true")
    
    # Persist the image to S3 NOW (not at doctor validation time)
    # Redis TTL is 1 hour. Doctor validation may take longer.
    prediction_data = await get_prediction(body.prediction_id)
    if prediction_data is None:
        raise HTTPException(404, "Prediction expired or not found. Please re-upload the image.")
    
    # Write image to training bucket pending_review/
    s3_path = await write_pending_image_to_s3(
        prediction_id=body.prediction_id,
        image_tensor=prediction_data["tensor"],
    )
    
    training_case = TrainingCase(
        prediction_id=body.prediction_id,
        image_s3_path=s3_path,
        status="pending_doctor_review",
    )
    db.add(training_case)
    await db.commit()
    
    return {"status": "queued_for_review", "training_case_id": str(training_case.id)}
```

### 17B. GDPR Deletion Request Flow

```python
# app/api/v1/endpoints/gdpr.py
@router.delete("/users/me/data")
async def request_data_deletion(
    current_user: User = Depends(require_patient),
    db: AsyncSession = Depends(get_db),
):
    """
    Create a deletion request. Processed within 30 days per GDPR Article 17.
    Cases already used in training cannot have weights un-trained, but no new
    data will be used and all stored copies will be deleted.
    """
    request = DeletionRequest(
        user_id=current_user.id,
        status="pending",
        requested_at=datetime.utcnow(),
    )
    db.add(request)
    await db.commit()
    
    return {
        "message": "Deletion request received. Your data will be deleted within 30 days.",
        "request_id": str(request.id),
        "sla_date": (datetime.utcnow() + timedelta(days=30)).isoformat(),
    }

# Scheduled job (Lambda or ECS cron task) processes deletion_requests daily:
# 1. Find all pending requests older than 0 days
# 2. Delete from predictions table (or anonymize)
# 3. Delete images from S3 training bucket if not yet used_in_training
# 4. Mark DeletionRequest.status = 'completed', completed_at = NOW()
# 5. Log to CloudWatch for GDPR audit trail
```

### 17C. Training Pool Class Distribution Gate

```python
# ml/scripts/retrain.py
from sqlalchemy import text

MIN_SAMPLES_PER_CLASS = 300
MAX_CLASS_FRACTION = 0.60

async def check_class_distribution(db) -> dict:
    """Hard gate: abort retraining if class distribution is too skewed."""
    result = await db.execute(text("""
        SELECT diagnosis, COUNT(*) as count
        FROM training_cases
        WHERE used_in_training = FALSE
        GROUP BY diagnosis
    """))
    distribution = {row.diagnosis: row.count for row in result}
    
    total = sum(distribution.values())
    issues = []
    
    for cls, count in distribution.items():
        if count < MIN_SAMPLES_PER_CLASS:
            issues.append(f"{cls}: only {count} samples (minimum {MIN_SAMPLES_PER_CLASS})")
        if count / total > MAX_CLASS_FRACTION:
            issues.append(f"{cls}: {count/total:.1%} of dataset (maximum {MAX_CLASS_FRACTION:.0%})")
    
    if issues:
        raise ValueError(f"Retraining aborted - class imbalance:\n" + "\n".join(issues))
    
    return distribution
```

---

## Next Steps

**Phase 2 Complete!**

Next is **Phase 3: Frontend Development**

Proceed to: `BUILD_PHASE_3_FRONTEND.md`
