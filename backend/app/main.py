"""FastAPI Application Entry Point for EASE."""

import time
import uuid
from contextlib import asynccontextmanager
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from backend.app.api.v1 import (
    auth,
    meetings,
    memory,
    notifications,
    projects,
    reports,
    tasks
)
from backend.app.config import get_settings
from backend.app.database import Base, engine


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Initialize SQLite database schema
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield
    await engine.dispose()


settings = get_settings()

app = FastAPI(
    title=settings.APP_NAME,
    description="EASE: In-person project discussion capture, speaker diarization, cross-discussion memory, and team collaboration backend.",
    version="1.0.0",
    lifespan=lifespan
)

# CORS Middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.middleware("http")
async def request_observability_middleware(request: Request, call_next):
    """Adds X-Request-ID and measures execution latency."""
    request_id = request.headers.get("X-Request-ID") or str(uuid.uuid4())
    start_time = time.perf_counter()

    response = await call_next(request)

    latency_ms = (time.perf_counter() - start_time) * 1000.0
    response.headers["X-Request-ID"] = request_id
    response.headers["X-Process-Time-Ms"] = f"{latency_ms:.2f}"

    return response


# Include Routers
app.include_router(auth.router, prefix="/api/v1")
app.include_router(projects.router, prefix="/api/v1")
app.include_router(meetings.router, prefix="/api/v1")
app.include_router(memory.router, prefix="/api/v1")
app.include_router(tasks.router, prefix="/api/v1")
app.include_router(reports.router, prefix="/api/v1")
app.include_router(notifications.router, prefix="/api/v1")


@app.get("/health", tags=["Health"])
async def health_check():
    return {
        "status": "healthy",
        "app": settings.APP_NAME,
        "env": settings.APP_ENV,
        "database": "connected"
    }
