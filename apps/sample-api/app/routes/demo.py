import asyncio
import random
from typing import Optional

from fastapi import APIRouter, HTTPException, Query

from app.config import settings
from app.metrics import metrics_registry

router = APIRouter()


@router.get("/slow")
async def slow_endpoint(
    delay: Optional[int] = Query(None, ge=0, le=30, description="Delay in seconds")
):
    """
    Simulate a slow endpoint for testing timeouts and performance.
    """
    if not settings.ENABLE_SLOW_ENDPOINT:
        raise HTTPException(status_code=404, detail="Slow endpoint is disabled")

    actual_delay = delay if delay is not None else settings.SLOW_ENDPOINT_DELAY

    # Track slow request
    metrics_registry.business_operations.labels(
        operation="slow_request", status="started"
    ).inc()

    await asyncio.sleep(actual_delay)

    metrics_registry.business_operations.labels(
        operation="slow_request", status="completed"
    ).inc()

    return {"message": f"Response after {actual_delay} seconds", "delay": actual_delay}


@router.get("/error")
async def error_endpoint(
    rate: Optional[float] = Query(
        None, ge=0, le=100, description="Error rate percentage"
    )
):
    """
    Simulate errors based on configured or provided error rate.
    """
    error_rate = rate if rate is not None else settings.ERROR_RATE

    if random.random() * 100 < error_rate:
        metrics_registry.track_error("simulated_error")
        raise HTTPException(
            status_code=500, detail=f"Simulated error (rate: {error_rate}%)"
        )

    return {"message": "Success", "error_rate": error_rate}


@router.get("/cpu")
async def cpu_intensive(
    duration: int = Query(
        1, ge=1, le=10, description="CPU intensive duration in seconds"
    )
):
    """
    Simulate CPU intensive operation for testing auto-scaling.
    """
    import time

    start = time.time()

    # CPU intensive operation
    while time.time() - start < duration:
        _ = sum(i * i for i in range(1000000))

    return {"message": "CPU intensive operation completed", "duration": duration}


@router.get("/memory")
async def memory_intensive(
    size_mb: int = Query(10, ge=1, le=100, description="Memory to allocate in MB")
):
    """
    Simulate memory intensive operation for testing memory limits.
    """
    # Allocate memory
    data = bytearray(size_mb * 1024 * 1024)

    # Do something with the data to prevent optimization
    data[0] = 1
    data[-1] = 1

    return {"message": f"Allocated {size_mb}MB of memory", "size_mb": size_mb}
