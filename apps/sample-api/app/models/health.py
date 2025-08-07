from enum import Enum
from pydantic import BaseModel, Field
from typing import List, Optional

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