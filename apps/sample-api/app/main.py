from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import Response
from fastapi.staticfiles import StaticFiles
from contextlib import asynccontextmanager
import uvicorn
import os

from app.config import settings
from app.middleware import RequestMetricsMiddleware
from app.metrics import metrics_registry
from app.routes import health, info, demo, root
from app.version import version_info

# Lifespan context manager for startup/shutdown
@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    print(f"Starting {settings.APP_NAME} v{version_info.version}")
    metrics_registry.initialize()
    yield
    # Shutdown
    print("Shutting down...")

# Create FastAPI app
app = FastAPI(
    title=settings.APP_NAME,
    description="Sample API for K8s Observable Rollouts Demo",
    version=version_info.version,
    docs_url="/docs",
    redoc_url="/redoc",
    openapi_url="/openapi.json",
    lifespan=lifespan
)

# Add middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
app.add_middleware(RequestMetricsMiddleware)

# Mount static files
static_dir = os.path.join(os.path.dirname(__file__), "static")
app.mount("/static", StaticFiles(directory=static_dir), name="static")

# Include routers
app.include_router(root.router)
app.include_router(health.router, prefix="/health", tags=["health"])
app.include_router(info.router, prefix="/api", tags=["info"])
app.include_router(demo.router, prefix="/demo", tags=["demo"])

@app.get("/metrics")
async def metrics():
    return Response(media_type="text/plain", content=metrics_registry.get_metrics())

if __name__ == "__main__":
    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",
        port=settings.PORT,
        reload=settings.DEBUG,
        log_level=settings.LOG_LEVEL.lower()
    )