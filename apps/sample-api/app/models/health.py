from enum import Enum
from typing import List, Optional

from pydantic import BaseModel, Field


class HealthStatus(str, Enum):

    OK = "ok"
    ERROR = "error"


class ComponentHealth(BaseModel):

    name: str
    status: HealthStatus
    details: Optional[str] = None


class HealthCheck(BaseModel):

    status: HealthStatus
    components: List[ComponentHealth] = Field(default_factory=list)


class ReadinessCheck(BaseModel):

    status: HealthStatus
    components: List[ComponentHealth] = Field(default_factory=list)
