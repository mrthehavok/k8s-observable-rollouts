import os
from datetime import datetime
from typing import Dict

import psutil
from fastapi import APIRouter, Response, status

from app.config import settings
from app.models.health import HealthCheck, HealthStatus, ReadinessCheck

router = APIRouter()

@router.get("/live", response_model=HealthStatus)
async def liveness():
    """
    Kubernetes liveness probe endpoint.
    Returns 200 if the application is alive.
    """
    return HealthStatus(
        status="healthy",
        timestamp=datetime.utcnow().isoformat(),
        version=settings.VERSION
    )

@router.get("/ready", response_model=ReadinessCheck)
async def readiness(response: Response):
    """
    Kubernetes readiness probe endpoint.
    Checks if the application is ready to serve traffic.
    """
    checks = {
        "memory": check_memory(),
        "disk": check_disk(),
        "config": check_configuration()
    }

    # If any check fails, return 503
    if not all(check["healthy"] for check in checks.values()):
        response.status_code = status.HTTP_503_SERVICE_UNAVAILABLE

    return ReadinessCheck(
        status="ready" if response.status_code == 200 else "not_ready",
        timestamp=datetime.utcnow().isoformat(),
        version=settings.VERSION,
        checks=checks
    )

@router.get("/startup", response_model=HealthStatus)
async def startup():
    """
    Kubernetes startup probe endpoint.
    Used for slow-starting containers.
    """
    # Add any startup checks here
    return HealthStatus(
        status="started",
        timestamp=datetime.utcnow().isoformat(),
        version=settings.VERSION
    )

def check_memory() -> Dict[str, any]:
    """Check if memory usage is within acceptable limits"""
    memory = psutil.virtual_memory()
    healthy = memory.percent < 90
    return {
        "healthy": healthy,
        "message": f"Memory usage: {memory.percent}%",
        "details": {
            "total": memory.total,
            "available": memory.available,
            "percent": memory.percent
        }
    }

def check_disk() -> Dict[str, any]:
    """Check if disk usage is within acceptable limits"""
    disk = psutil.disk_usage('/')
    healthy = disk.percent < 90
    return {
        "healthy": healthy,
        "message": f"Disk usage: {disk.percent}%",
        "details": {
            "total": disk.total,
            "free": disk.free,
            "percent": disk.percent
        }
    }

def check_configuration() -> Dict[str, any]:
    """Check if required configuration is present"""
    required_vars = ["APP_NAME", "APP_ENV", "VERSION"]
    missing = [var for var in required_vars if not getattr(settings, var, None)]
    healthy = len(missing) == 0
    return {
        "healthy": healthy,
        "message": "Configuration OK" if healthy else f"Missing: {missing}",
        "details": {
            "app_env": settings.APP_ENV,
            "debug": settings.DEBUG
        }
    }