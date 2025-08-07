from fastapi import APIRouter
from fastapi.responses import HTMLResponse
from datetime import datetime
import json

from app.models.info import VersionInfo, AppInfo
from app.config import settings
from app.version import version_info, changelog

router = APIRouter()

@router.get("/version", response_model=VersionInfo)
async def get_version():
    """Return application version information"""
    return VersionInfo(
        version=version_info.version,
        build_number=version_info.build_number,
        git_commit=version_info.git_commit,
        git_branch=version_info.git_branch,
        environment=settings.APP_ENV
    )

@router.get("/info", response_model=AppInfo)
async def get_info():
    """Return comprehensive application information"""
    return AppInfo(
        name=settings.APP_NAME,
        version=version_info.version,
        environment=settings.APP_ENV,
        uptime=get_uptime(),
        features={
            "slow_endpoint": settings.ENABLE_SLOW_ENDPOINT,
            "metrics": True,
            "health_checks": True
        },
        links={
            "health": "/health/ready",
            "metrics": settings.METRICS_PATH,
            "docs": "/docs",
            "version_page": "/html"
        }
    )

@router.get("/changelog")
async def get_changelog():
    """Return application changelog"""
    return {
        "version": version_info.version,
        "changes": changelog.get_changes(version_info.version)
    }

def get_uptime() -> str:
    """Calculate application uptime"""
    from app.main import app
    if hasattr(app, 'startup_time'):
        delta = datetime.utcnow() - app.startup_time
        return str(delta)
    return "unknown"