---
name: python-fastapi
description: Use this skill for FastAPI backend development — async route design, Pydantic v2 models, PostgreSQL with asyncpg/SQLAlchemy, JWT authentication, background tasks, middleware, Docker deployment, and production patterns. Activate when building Python APIs or diagnosing FastAPI performance issues.
---

# Python FastAPI

## Project Structure

```
app/
├── main.py              # FastAPI app, lifespan, middleware
├── config.py            # Settings via pydantic-settings
├── database.py          # async engine, session factory
├── models/              # SQLAlchemy ORM models
│   └── user.py
├── schemas/             # Pydantic request/response models
│   └── user.py
├── routers/             # Route handlers grouped by domain
│   ├── auth.py
│   └── users.py
├── dependencies/        # Shared deps (get_db, get_current_user)
│   └── auth.py
└── services/            # Business logic (no DB calls in routers)
    └── user_service.py
```

## App Setup + Lifespan

```python
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from .database import engine, Base
from .routers import auth, users

@asynccontextmanager
async def lifespan(app: FastAPI):
    # startup
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield
    # shutdown
    await engine.dispose()

app = FastAPI(title="My API", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["https://myapp.example.com"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router, prefix="/auth", tags=["auth"])
app.include_router(users.router, prefix="/users", tags=["users"])
```

## Config (pydantic-settings)

```python
# config.py
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    database_url: str
    secret_key: str
    access_token_expire_minutes: int = 30
    environment: str = "production"

    class Config:
        env_file = ".env"

settings = Settings()
```

## Database (async SQLAlchemy + asyncpg)

```python
# database.py
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlalchemy.orm import DeclarativeBase

engine = create_async_engine(
    settings.database_url.replace("postgresql://", "postgresql+asyncpg://"),
    pool_size=10,
    max_overflow=20,
    echo=False,
)
AsyncSessionLocal = async_sessionmaker(engine, expire_on_commit=False)

class Base(DeclarativeBase):
    pass

async def get_db():
    async with AsyncSessionLocal() as session:
        yield session
```

**Model:**
```python
# models/user.py
from sqlalchemy import String, DateTime, func
from sqlalchemy.orm import Mapped, mapped_column
from ..database import Base
import uuid

class User(Base):
    __tablename__ = "users"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    email: Mapped[str] = mapped_column(String, unique=True, index=True)
    password_hash: Mapped[str] = mapped_column(String)
    created_at: Mapped[DateTime] = mapped_column(DateTime, server_default=func.now())
```

## Pydantic Schemas (v2)

```python
# schemas/user.py
from pydantic import BaseModel, EmailStr, field_validator
from datetime import datetime

class UserCreate(BaseModel):
    email: EmailStr
    password: str

    @field_validator("password")
    @classmethod
    def password_strength(cls, v: str) -> str:
        if len(v) < 8:
            raise ValueError("Password must be at least 8 characters")
        return v

class UserResponse(BaseModel):
    id: str
    email: str
    created_at: datetime

    model_config = {"from_attributes": True}   # replaces orm_mode=True in v1
```

## JWT Authentication

```python
# dependencies/auth.py
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
import jwt
from datetime import datetime, timedelta, timezone

security = HTTPBearer()

def create_access_token(user_id: str) -> str:
    expire = datetime.now(timezone.utc) + timedelta(minutes=settings.access_token_expire_minutes)
    return jwt.encode({"sub": user_id, "exp": expire}, settings.secret_key, algorithm="HS256")

async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: AsyncSession = Depends(get_db),
) -> User:
    try:
        payload = jwt.decode(credentials.credentials, settings.secret_key, algorithms=["HS256"])
        user_id = payload["sub"]
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token expired")
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=401, detail="Invalid token")

    user = await db.get(User, user_id)
    if not user:
        raise HTTPException(status_code=401, detail="User not found")
    return user
```

## Routers

```python
# routers/auth.py
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from ..database import get_db
from ..schemas.user import UserCreate, UserResponse, TokenResponse
from ..services.user_service import create_user, authenticate_user
from ..dependencies.auth import create_access_token

router = APIRouter()

@router.post("/register", response_model=UserResponse, status_code=201)
async def register(body: UserCreate, db: AsyncSession = Depends(get_db)):
    return await create_user(db, body)

@router.post("/login", response_model=TokenResponse)
async def login(body: UserCreate, db: AsyncSession = Depends(get_db)):
    user = await authenticate_user(db, body.email, body.password)
    if not user:
        raise HTTPException(status_code=401, detail="Invalid credentials")
    return {"access_token": create_access_token(user.id), "token_type": "bearer"}
```

## Background Tasks

```python
from fastapi import BackgroundTasks

async def send_welcome_email(email: str):
    # async email sending
    await email_client.send(to=email, subject="Welcome")

@router.post("/register")
async def register(body: UserCreate, background_tasks: BackgroundTasks, db=Depends(get_db)):
    user = await create_user(db, body)
    background_tasks.add_task(send_welcome_email, user.email)
    return user
```

For heavy/long-running tasks use Celery + Redis or ARQ (async Redis Queue) instead.

## Error Handling

```python
from fastapi import Request
from fastapi.responses import JSONResponse

@app.exception_handler(ValueError)
async def value_error_handler(request: Request, exc: ValueError):
    return JSONResponse(status_code=400, content={"detail": str(exc)})

# Custom exception
class NotFoundError(Exception):
    def __init__(self, resource: str, id: str):
        self.message = f"{resource} {id} not found"

@app.exception_handler(NotFoundError)
async def not_found_handler(request: Request, exc: NotFoundError):
    return JSONResponse(status_code=404, content={"detail": exc.message})
```

## Docker Deployment

```dockerfile
# Dockerfile
FROM python:3.13-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "2"]
```

**Production uvicorn config:**
```bash
# Single process (let K8s/Swarm handle scaling)
uvicorn app.main:app --host 0.0.0.0 --port 8000 --workers 1

# Or gunicorn + uvicorn workers
gunicorn app.main:app -w 4 -k uvicorn.workers.UvicornWorker --bind 0.0.0.0:8000
```

**K3s Deployment:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
spec:
  replicas: 2
  template:
    spec:
      containers:
        - name: api
          image: registry.example.com:5000/api:latest
          ports: [{containerPort: 8000}]
          envFrom:
            - secretRef:
                name: api-secret
          readinessProbe:
            httpGet:
              path: /health
              port: 8000
            initialDelaySeconds: 5
```

## Performance Patterns

```python
# Connection pool tuning for high traffic
engine = create_async_engine(url, pool_size=20, max_overflow=40, pool_timeout=30)

# Select only needed columns (avoid SELECT *)
from sqlalchemy import select
result = await db.execute(select(User.id, User.email).where(User.active == True))
users = result.all()

# Bulk insert
await db.execute(User.__table__.insert(), [{"email": e, ...} for e in emails])
await db.commit()

# Cache expensive queries (in-memory, TTL)
from functools import lru_cache
import asyncio
_cache = {}

async def get_cached(key: str, ttl: int, fetch_fn):
    if key in _cache:
        value, ts = _cache[key]
        if asyncio.get_event_loop().time() - ts < ttl:
            return value
    value = await fetch_fn()
    _cache[key] = (value, asyncio.get_event_loop().time())
    return value
```

## Common Issues

| Problem | Fix |
|---|---|
| `greenlet_spawn` error | Missing `async` on DB call, or using sync SQLAlchemy with async engine |
| CORS blocked | Check `allow_origins`, exact domain match, trailing slash matters |
| Pydantic `orm_mode` not recognized | v2 uses `model_config = {"from_attributes": True}` |
| DB connection pool exhausted | Increase `pool_size`, ensure sessions are closed (use `async with`) |
| Startup slow | Move DB init to lifespan, not module level |
| 422 Unprocessable Entity | Request body doesn't match Pydantic schema — check error detail |
