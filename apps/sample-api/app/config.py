from pydantic_settings import BaseSettings
from typing import Optional
import os

class Settings(BaseSettings):
    # Application settings
    APP_NAME: str = "Sample API"
    APP_ENV: str = "development"
    DEBUG: bool = False
    PORT: int = 8000
    LOG_LEVEL: str = "INFO"

    # Version information
    VERSION: str = "1.0.0"
    BUILD_NUMBER: Optional[str] = None
    GIT_COMMIT: Optional[str] = None

    # Feature flags
    ENABLE_SLOW_ENDPOINT: bool = True
    SLOW_ENDPOINT_DELAY: int = 5
    ERROR_RATE: float = 0.0  # Percentage of requests to fail (0-100)

    # Monitoring
    METRICS_PATH: str = "/metrics"

    # Database (for future use)
    DATABASE_URL: Optional[str] = None

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"
        case_sensitive = True

settings = Settings()