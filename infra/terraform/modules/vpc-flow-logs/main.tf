# VPC Flow Logs to CloudWatch
# Implements Tier 2 defensive controls

variable "environment" {}
variable "vpc_id" {}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/aws/vpc/flow-logs-${var.environment}"
  retention_in_days = 30

  tags = {
    Environment = var.environment
  }
}

# VPC Flow Logs
resource "aws_flow_log" "main" {
  log_destination_type = "cloud-watch-logs"
  log_destination      = aws_cloudwatch_log_group.vpc_flow_logs.arn
  log_format         = "$${version} $${resource-type} $${account-id} $${action} $${srcaddr} $${dstaddr} $${srcport} $${dstport} $${pkt-srcaddr} $${pkt-dstaddr} $${protocol} $${bytes} $${packets} $${start} $${end} $${action} $${log-status} $${vpc-id} $${subnet-id} $${instance-id} $${interface-id} $${region} $${type} $${pkt-src-aws-service} $${pkt-dst-aws-service} $${aws-service}"
  traffic_type       = "ALL"
  vpc_id            = var.vpc_id

  tags = {
    Environment = var.environment
  }
}

output "log_group_name" {
  value = aws_cloudwatch_log_group.vpc_flow_logs.name
}
