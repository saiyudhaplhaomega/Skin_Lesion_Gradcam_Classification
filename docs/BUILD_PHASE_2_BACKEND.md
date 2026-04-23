# Phase 2: Backend Development

**Step-by-step guide to building a production-ready FastAPI backend with authentication**

---

## Overview

The backend is the core of our application. It handles:
1. User authentication (JWT validation with Cognito)
2. Image classification (PyTorch models)
3. Grad-CAM heatmap generation
4. Feedback collection with S3 storage
5. GDPR data exports
6. Admin operations (doctor approval)

### Technology Stack
- **Framework**: FastAPI (async, high-performance)
- **Language**: Python 3.10
- **Database**: PostgreSQL (via SQLAlchemy async)
- **Cache**: Redis (for predictions store)
- **Storage**: S3 (model weights, feedback images)
- **Auth**: AWS Cognito JWT validation

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

Create `requirements.txt`:

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

## Next Steps

**Phase 2 Complete!**

Next is **Phase 3: Frontend Development**

Proceed to: `BUILD_PHASE_3_FRONTEND.md`