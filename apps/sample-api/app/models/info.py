from pydantic import BaseModel
from typing import Optional

class VersionInfo(BaseModel):
    version: str
    build_number: Optional[str] = None
    git_commit: Optional[str] = None
    git_branch: Optional[str] = None
    environment: Optional[str] = None

class AppInfo(BaseModel):
    app_name: str
    version: VersionInfo
    description: Optional[str] = None