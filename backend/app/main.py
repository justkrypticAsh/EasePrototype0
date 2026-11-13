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
from backend.app.database import Base, engine, AsyncSessionLocal
from backend.app.services.demo_seeder import seed_demo_data_if_needed, reset_demo_data


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Initialize SQLite database schema
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    # Seed demo data for "Product Launch" if not present
    async with AsyncSessionLocal() as session:
        try:
            await seed_demo_data_if_needed(session)
        except Exception as e:
            print(f"Warning: Demo seeder notice: {e}")

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


@app.post("/api/v1/demo/reset", tags=["Demo"])
async def reset_demo_endpoint():
    async with AsyncSessionLocal() as session:
        await reset_demo_data(session)
    return {"status": "success", "message": "Product Launch demo dataset reset successfully"}
