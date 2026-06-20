output "kms_key_arn" {
  description = "ARN of the main KMS key"
  value       = aws_kms_key.main.arn
}

output "kms_alias_name" {
  description = "Name of the KMS alias"
  value       = aws_kms_alias.main.name
}

output "upload_bucket_name" {
  description = "Name of the S3 upload bucket"
  value       = aws_s3_bucket.uploads.id
}

output "training_bucket_name" {
  description = "Name of the S3 training bucket"
  value       = aws_s3_bucket.training.id
}

output "log_bucket_name" {
  description = "Name of the S3 log bucket"
  value       = aws_s3_bucket.logs.id
}

output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = aws_ecr_repository.backend.repository_url
}

output "db_password_secret_arn" {
  description = "ARN of the database password secret"
  value       = aws_secretsmanager_secret.db_password.arn
}

output "jwt_secret_arn" {
  description = "ARN of the JWT secret"
  value       = aws_secretsmanager_secret.jwt_secret.arn
}

output "eks_cluster_name" {
  description = "Name of the EKS cluster created in guide 08"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "API endpoint of the EKS cluster created in guide 08"
  value       = module.eks.cluster_endpoint
}

output "notifications_topic_arn" {
  description = "SNS topic used by staging notifications and alarms"
  value       = aws_sns_topic.notifications.arn
}

output "training_queue_url" {
  description = "SQS FIFO queue URL for training workflow events"
  value       = aws_sqs_queue.training_workflow.url
}

output "training_dlq_url" {
  description = "SQS FIFO dead-letter queue URL for failed training workflow messages"
  value       = aws_sqs_queue.training_workflow_dlq.url
}

output "training_events_bus_name" {
  description = "EventBridge bus for training workflow events"
  value       = aws_cloudwatch_event_bus.training.name
}
