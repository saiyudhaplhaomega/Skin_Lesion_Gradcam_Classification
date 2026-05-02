# auto_rollback.py - Lambda handler for automatic rollback
# Triggered by CloudWatch alarm via SNS
# Reverses ALB listener to the inactive target group

import json
import os
import boto3
from botocore.exceptions import ClientError

ssm = boto3.client("ssm")
elb = boto3.client("elbv2")
sns = boto3.client("sns")

BLUE_TG_ARN = os.environ["BLUE_TG_ARN"]
GREEN_TG_ARN = os.environ["GREEN_TG_ARN"]
ACTIVE_SLOT_SSM = os.environ["ACTIVE_SLOT_SSM"]
ENVIRONMENT = os.environ["ENVIRONMENT"]


def lambda_handler(event, context):
    print(f"Auto-rollback triggered: {json.dumps(event, default=str)}")

    message = json.loads(event["Records"][0]["Sns"]["Message"])
    alarm_name = message.get("AlarmName", "unknown")
    alarm_reason = message.get("AlarmDescription", "")

    print(f"Alarm: {alarm_name} - {alarm_reason}")

    # Read current active slot from SSM
    try:
        response = ssm.get_parameter(Name=ACTIVE_SLOT_SSM)
        active_slot = response["Parameter"]["Value"]
    except ClientError:
        active_slot = "blue"

    print(f"Current active slot: {active_slot}")

    # Determine which TG to switch TO (the inactive one)
    inactive_slot = "green" if active_slot == "blue" else "blue"
    inactive_tg_arn = GREEN_TG_ARN if inactive_slot == "green" else BLUE_TG_ARN

    print(f"Rolling back to: {inactive_slot} (TG: {inactive_tg_arn})")

    try:
        # Describe listeners to find HTTP:80
        listeners = elb.describe_listeners(
            LoadBalancerArn=os.environ.get("ALB_ARN", "")
        )

        http_listener = None
        for listener in listeners["Listeners"]:
            if listener["Port"] == 80:
                http_listener = listener
                break

        if not http_listener:
            print("No HTTP:80 listener found")
            return {"statusCode": 404, "body": "Listener not found"}

        listener_arn = http_listener["ListenerArn"]

        # Update the default action to forward to the inactive TG
        elb.modify_listener(
            ListenerArn=listener_arn,
            DefaultActions=[
                {
                    "Type": "forward",
                    "TargetGroupArn": inactive_tg_arn
                }
            ]
        )

        # Update the SSM parameter to reflect the new active slot
        ssm.put_parameter(
            Name=ACTIVE_SLOT_SSM,
            Value=inactive_slot,
            Overwrite=True,
            Type="String"
        )

        print(f"Rollback complete: ALB now forwarding to {inactive_slot}")

        # Send notification
        try:
            sns.publish(
                TopicArn=os.environ.get("SNS_TOPIC_ARN", ""),
                Subject=f"[ALERT] Auto-rollback executed for {ENVIRONMENT}",
                Message=(
                    f"Auto-rollback executed for {ENVIRONMENT}\n"
                    f"Alarm: {alarm_name}\n"
                    f"Switched ALB to: {inactive_slot}"
                )
            )
        except Exception:
            pass

        return {"statusCode": 200, "body": f"Rollback to {inactive_slot} complete"}

    except ClientError as e:
        print(f"Rollback failed: {e}")
        return {"statusCode": 500, "body": f"Rollback failed: {e}"}
