# auto_heal.py - Lambda handler for automatic healing
# Triggered by CloudWatch ECS/ALB alarms
# Remediation: scale up, restart failed tasks, notify oncall

import json
import os
import boto3
from datetime import datetime
from botocore.exceptions import ClientError

ecs = boto3.client("ecs")
sns = boto3.client("sns")

ECS_CLUSTER = os.environ["ECS_CLUSTER_NAME"]
ECS_SERVICE = os.environ["ECS_SERVICE_NAME"]
SNS_TOPIC = os.environ["SNS_TOPIC_ARN"]
ENVIRONMENT = os.environ["ENVIRONMENT"]


def lambda_handler(event, context):
    print(f"Auto-heal triggered: {json.dumps(event, default=str)}")

    try:
        message = json.loads(event["Records"][0]["Sns"]["Message"])
        alarm_name = message.get("AlarmName", "unknown")
        state = message.get("NewState", "UNKNOWN")
    except (KeyError, json.JSONDecodeError):
        state = "UNKNOWN"

    if state != "ALARM":
        return {"statusCode": 200, "body": f"Ignored {state} transition"}

    # Determine remediation based on alarm name
    if "memory" in alarm_name.lower():
        result = handle_memory()
    elif "cpu" in alarm_name.lower():
        result = handle_cpu()
    elif "health" in alarm_name.lower() or "healthy" in alarm_name.lower():
        result = handle_health()
    elif "latency" in alarm_name.lower():
        result = handle_latency()
    else:
        result = {"action": "notify_only", "message": f"No automated remediation for: {alarm_name}"}

    # Send notification
    try:
        sns.publish(
            TopicArn=SNS_TOPIC,
            Subject=f"[AUTO-HEAL] {alarm_name} - {result.get('action', 'unknown')}",
            Message=(
                f"Auto-heal action taken for {ENVIRONMENT}\n"
                f"Alarm: {alarm_name}\n"
                f"Action: {result.get('action', 'unknown')}\n"
                f"Details: {json.dumps(result, default=str)}"
            )
        )
    except Exception:
        pass

    return {"statusCode": 200, "body": json.dumps(result)}


def handle_memory():
    try:
        service = ecs.describe_services(cluster=ECS_CLUSTER, services=[ECS_SERVICE])["services"][0]
        current = service["desiredCount"]
        new = min(current + 1, 6)

        if new > current:
            ecs.update_service(cluster=ECS_CLUSTER, service=ECS_SERVICE, desiredCount=new)
            return {"action": "scaled_up", "previous": current, "new": new}

        return {"action": "at_max", "desired": current}
    except ClientError as e:
        return {"action": "failed", "error": str(e)}


def handle_cpu():
    return handle_memory()  # Same remediation


def handle_health():
    try:
        ecs.update_service(cluster=ECS_CLUSTER, service=ECS_SERVICE, forceNewDeployment=True)
        return {"action": "force_redeployment", "reason": "Health check failures"}
    except ClientError as e:
        return {"action": "failed", "error": str(e)}


def handle_latency():
    try:
        tasks = ecs.list_tasks(cluster=ECS_CLUSTER, serviceName=ECS_SERVICE, desiredStatus="RUNNING")["taskArns"]
        if tasks:
            ecs.stop_task(cluster=ECS_CLUSTER, task=tasks[0], reason="High latency auto-heal")
            return {"action": "restarted_task", "task": tasks[0]}
        return {"action": "no_tasks"}
    except ClientError as e:
        return {"action": "failed", "error": str(e)}
