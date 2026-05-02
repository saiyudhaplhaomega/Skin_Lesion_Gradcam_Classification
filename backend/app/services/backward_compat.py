# app/services/backward_compat.py
# Response transformers that convert between API versions
# Used when serving old v1 response shapes to v1 clients

from typing import Any


def transform_analysis_response_v1(response: dict[str, Any]) -> dict[str, Any]:
    """
    Transform a v2 analysis response into a v1 response shape.
    Used when a v1 client calls a v2 endpoint.

    v2 response:
    {
        "analysis_id": "...",
        "prediction": {
            "class": "nv",
            "class_name": "Melanocytic nevi",
            "confidence": 0.87,
            "differential": [{"class": "bkl", "confidence": 0.05}]
        },
        "model_opinions": {...},
        "reliability": {...},
        "safety_flags": [...],
        "gradcam_enabled": true
    }

    v1 response (flat):
    {
        "analysis_id": "...",
        "diagnosis": "nv",
        "diagnosis_name": "Melanocytic nevi",
        "confidence": 0.87,
        "reliability_score": 0.85,
        "safety_flag": false
    }
    """
    return {
        "analysis_id": response.get("analysis_id", ""),
        "diagnosis": response.get("prediction", {}).get("class", ""),
        "diagnosis_name": response.get("prediction", {}).get("class_name", ""),
        "confidence": response.get("prediction", {}).get("confidence", 0.0),
        "reliability_score": response.get("reliability", {}).get("overall_score", 0.0),
        "safety_flag": len(response.get("safety_flags", [])) > 0,
    }


def transform_heatmap_response_v1(response: dict[str, Any]) -> dict[str, Any]:
    """
    Transform v2 heatmap response to v1 shape.

    v2: {"heatmaps": {"original": "base64...", "overlay": "base64..."}, "method": "gradcam"}
    v1: {"heatmap": "base64...", "method": "gradcam"}
    """
    return {
        "heatmap": response.get("heatmaps", {}).get("original", ""),
        "method": response.get("method", "gradcam"),
    }
