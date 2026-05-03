# app/middleware/api_version.py
# Handles API version negotiation for backward compatibility
# Returns deprecation headers for older API versions

from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response
from starlette.datastructures import MUTABLE_HEADERS


class APIVersionMiddleware(BaseHTTPMiddleware):
    """
    Handles API versioning and backward compatibility.

    Clients declare their API version via:
    - Header: X-API-Version: v1
    - Query param: ?api_version=v1

    Servers announce deprecation via headers:
    - X-API-Deprecation: true
    - X-API-Sunset-Date: 2026-12-31
    - X-API-Successor-Version: v2

    Response shape is determined by the client's declared version.
    """

    CURRENT_VERSION = "v2"
    DEPRECATED_VERSIONS = ["v1"]

    SUNSET_DATES = {
        "v1": "2026-12-31",
    }

    SUCCESSOR_VERSIONS = {
        "v1": "v2",
    }

    async def dispatch(self, request: Request, call_next) -> Response:
        # Get client-declared version
        client_version = request.headers.get("X-API-Version")
        if not client_version:
            client_version = request.query_params.get("api_version", self.CURRENT_VERSION)

        # Normalize version
        client_version = client_version.lower().strip()
        if not client_version.startswith("v"):
            client_version = f"v{client_version}"

        # Store version in request state
        request.state.api_version = client_version

        # Check if client is using deprecated version
        is_deprecated = client_version in self.DEPRECATED_VERSIONS

        # Call the route handler
        response = await call_next(request)

        # Add deprecation headers
        headers = MUTABLE_HEADERS(response.headers)
        headers.append(("X-API-Version", client_version))

        if is_deprecated:
            headers.append(("X-API-Deprecation", "true"))
            headers.append(("X-API-Sunset-Date", self.SUNSET_DATES.get(client_version, "")))
            headers.append(("X-API-Successor-Version", self.SUCCESSOR_VERSIONS.get(client_version, self.CURRENT_VERSION)))

        return response
