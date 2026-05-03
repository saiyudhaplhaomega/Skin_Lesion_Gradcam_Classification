# app/middleware/feature_flag.py
# FastAPI middleware that injects feature flags into each request
# Makes flags available via request.state.flags

import time
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response
from starlette.types import ASGIApp

from app.services.feature_flags import get_all_flags, FeatureFlag


class FeatureFlagMiddleware(BaseHTTPMiddleware):
    """
    Injects feature flags into every request via request.state.flags.

    Usage in route handlers:
        flags = request.state.flags
        if flags.is_enabled("new_heatmap_method"):
            ...
    """

    def __init__(self, app: ASGIApp, cache_ttl_seconds: int = 60):
        super().__init__(app)
        self.cache_ttl_seconds = cache_ttl_seconds
        self._last_fetch = 0
        self._cached_flags: dict[str, FeatureFlag] = {}

    def _fetch_flags_if_stale(self):
        """Re-fetch flags if cache has expired."""
        now = time.time()
        if now - self._last_fetch > self.cache_ttl_seconds:
            self._cached_flags = get_all_flags()
            self._last_fetch = now

    async def dispatch(self, request: Request, call_next) -> Response:
        self._fetch_flags_if_stale()

        # Inject flags into request state
        request.state.flags = FeatureFlagProxy(self._cached_flags)

        return await call_next(request)


class FeatureFlagProxy:
    """
    Proxy object that provides a clean interface to feature flags
    from within a request context.
    """

    def __init__(self, flags: dict[str, FeatureFlag]):
        self._flags = flags

    def is_enabled(self, flag_name: str) -> bool:
        """Check if a flag is enabled."""
        flag = self._flags.get(flag_name)
        return flag.enabled if flag else False

    def get_rollout(self, flag_name: str) -> int:
        """Get rollout percentage for a flag."""
        flag = self._flags.get(flag_name)
        return flag.rollout_percent if flag else 0

    def is_flag_active(self, flag_name: str, user_id: str = None) -> bool:
        """
        Check if a flag is active for a specific user.
        Uses rollout_percent to deterministically hash users.

        This ensures consistent behavior: the same user always gets
        the same flag state (no flapping).
        """
        flag = self._flags.get(flag_name)
        if not flag or not flag.enabled:
            return False

        if flag.rollout_percent >= 100:
            return True
        if flag.rollout_percent <= 0:
            return False

        # Deterministic hash - same user always gets same result
        if user_id:
            hash_value = hash(f"{flag_name}:{user_id}") % 100
            return hash_value < flag.rollout_percent

        return False
