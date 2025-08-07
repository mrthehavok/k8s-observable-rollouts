import time

from starlette.middleware.base import (BaseHTTPMiddleware,
                                       RequestResponseEndpoint)
from starlette.requests import Request
from starlette.responses import Response
from starlette.routing import Match

from app.metrics import metrics_registry


class RequestMetricsMiddleware(BaseHTTPMiddleware):
    async def dispatch(
        self, request: Request, call_next: RequestResponseEndpoint
    ) -> Response:
        start_time = time.time()
        metrics_registry.active_requests.inc()

        # Get endpoint path template
        endpoint = "unknown"
        for route in request.app.routes:
            match, _ = route.matches(request.scope)
            if match == Match.FULL:
                endpoint = route.path
                break

        response = await call_next(request)

        duration = time.time() - start_time
        request_size = int(request.headers.get("content-length", 0))
        response_size = int(response.headers.get("content-length", 0))

        metrics_registry.track_request(
            method=request.method,
            endpoint=endpoint,
            status=response.status_code,
            duration=duration,
            request_size=request_size,
            response_size=response_size,
        )
        metrics_registry.active_requests.dec()

        return response
