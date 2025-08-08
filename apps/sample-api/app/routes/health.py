from typing import Dict

import psutil
from fastapi import APIRouter, Response, status

from app.config import settings
from app.models.health import (ComponentHealth, HealthCheck, HealthStatus,
                               ReadinessCheck)

router = APIRouter()


@router.get("/live", response_model=HealthCheck)
async def liveness():
    """
    Kubernetes liveness probe endpoint.
    Returns 200 if the application is alive.
    """
    return HealthCheck(status=HealthStatus.OK)


@router.get("/ready", response_model=ReadinessCheck)
async def readiness(response: Response):
    """
    Kubernetes readiness probe endpoint.
    Checks if the application is ready to serve traffic.
    """
    checks = {
        "memory": check_memory(),
        "disk": check_disk(),
        "config": check_configuration(),
    }

    # If any check fails, return 503
    if not all(check["healthy"] for check in checks.values()):
        response.status_code = status.HTTP_503_SERVICE_UNAVAILABLE

    is_ready = all(check["healthy"] for check in checks.values())
    overall_status = HealthStatus.OK if is_ready else HealthStatus.ERROR

    if not is_ready:
        response.status_code = status.HTTP_503_SERVICE_UNAVAILABLE

    component_healths = [
        ComponentHealth(
            name=name,
            status=HealthStatus.OK if check["healthy"] else HealthStatus.ERROR,
            details=check["message"],
        )
        for name, check in checks.items()
    ]

    return ReadinessCheck(status=overall_status, components=component_healths)


@router.get("/startup", response_model=HealthCheck)
async def startup():
    """
    Kubernetes startup probe endpoint.
    Used for slow-starting containers.
    """
    # Add any startup checks here
    return HealthCheck(status=HealthStatus.OK)


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
            "percent": memory.percent,
        },
    }


def check_disk() -> Dict[str, any]:
    """Check if disk usage is within acceptable limits"""
    disk = psutil.disk_usage("/")
    healthy = disk.percent < 90
    return {
        "healthy": healthy,
        "message": f"Disk usage: {disk.percent}%",
        "details": {"total": disk.total, "free": disk.free, "percent": disk.percent},
    }


def check_configuration() -> Dict[str, any]:
    """Check if required configuration is present"""
    required_vars = ["APP_NAME", "APP_ENV", "VERSION"]
    missing = [var for var in required_vars if not getattr(settings, var, None)]
    healthy = len(missing) == 0
    return {
        "healthy": healthy,
        "message": "Configuration OK" if healthy else f"Missing: {missing}",
        "details": {"app_env": settings.APP_ENV, "debug": settings.DEBUG},
    }
