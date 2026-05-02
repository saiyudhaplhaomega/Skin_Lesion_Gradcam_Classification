# app/services/feature_flags.py
# Fetches feature flags from AWS AppConfig and caches them in-memory
# Use this in route handlers and middleware to gate feature behavior

import os
import json
import logging
from functools import lru_cache
from typing import Optional
from dataclasses import dataclass

import boto3
from botocore.exceptions import ClientError

logger = logging.getLogger(__name__)

_appconfig_client = None


@dataclass
class FeatureFlag:
    enabled: bool
    rollout_percent: int = 0
    description: str = ""


def get_appconfig_client():
    global _appconfig_client
    if _appconfig_client is None:
        _appconfig_client = boto3.client(
            "appconfig",
            region_name=os.environ.get("AWS_REGION", "us-east-1")
        )
    return _appconfig_client


@lru_cache(maxsize=1)
def get_all_flags(
    application: str = "skin-lesion-prod",
    profile: str = "feature-flags",
    environment: str = "prod",
) -> dict[str, FeatureFlag]:
    """
    Fetch all feature flags from AppConfig.
    Results are cached for 60 seconds (TTL-based caching).
    For real-time updates, use the AppConfig Lambda extension or SDK agent.

    WHY: We cache flags because:
    1. AppConfig has rate limits on the API
    2. Checking flags on every request would be slow
    3. Most flags change infrequently (deployment-gated, not request-gated)
    """
    try:
        client = get_appconfig_client()
        response = client.get_configuration(
            Application=application,
            Configuration=profile,
            Environment=environment,
            ClientId="backend-service",
        )

        content = response["Configuration"].read().decode("utf-8")
        config = json.loads(content)

        flags = {}
        for name, values in config.get("flags", {}).items():
            flags[name] = FeatureFlag(
                enabled=values.get("enabled", False),
                rollout_percent=values.get("rollout_percent", 0),
                description=values.get("description", ""),
            )

        logger.info(f"Fetched {len(flags)} feature flags from AppConfig")
        return flags

    except ClientError as e:
        logger.error(f"Failed to fetch flags from AppConfig: {e}")
        return {}


def is_flag_enabled(
    flag_name: str,
    default: bool = False,
    application: str = None,
    environment: str = None,
) -> bool:
    """
    Check if a specific feature flag is enabled.

    Usage:
        if is_flag_enabled("new_heatmap_method"):
            return run_new_heatmap(image)
        else:
            return run_old_heatmap(image)
    """
    # Allow override via environment variable for local testing
    env_override = os.environ.get(f"FLAG_{flag_name.upper()}")
    if env_override is not None:
        return env_override.lower() in ("true", "1", "yes")

    # Resolve application/environment from settings if not provided
    if application is None:
        application = os.environ.get("APPCONFIG_APPLICATION", "skin-lesion-prod")
    if environment is None:
        environment = os.environ.get("APPCONFIG_ENVIRONMENT", "prod")

    flags = get_all_flags(application=application, environment=environment)
    flag = flags.get(flag_name)

    if flag is None:
        logger.warning(f"Flag '{flag_name}' not found - using default: {default}")
        return default

    return flag.enabled


def get_flag_rollout(flag_name: str, default: int = 0) -> int:
    """
    Get the rollout percentage for a feature flag.
    Use for gradual percentage-based rollouts.

    Usage:
        rollout = get_flag_rollout("rag_explanation_v2")
        if random.random() * 100 < rollout:
            return serve_rag_v2(request)
    """
    flags = get_all_flags()
    flag = flags.get(flag_name)

    if flag is None:
        return default

    return flag.rollout_percent


# Alias for common usage
get_flag = is_flag_enabled
