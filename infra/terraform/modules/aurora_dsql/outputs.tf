output "cluster_id" {
  description = "Aurora DSQL cluster identifier"
  value       = aws_dsql_cluster.main.id
}

output "cluster_arn" {
  description = "Aurora DSQL cluster ARN"
  value       = aws_dsql_cluster.main.arn
}

output "endpoint" {
  description = "Aurora DSQL cluster endpoint (hostname:5432)"
  value       = aws_dsql_cluster.main.endpoint
}

output "ssm_endpoint_parameter" {
  description = "SSM parameter path storing the cluster endpoint"
  value       = aws_ssm_parameter.dsql_endpoint.name
}

output "connect_policy_arn" {
  description = "IAM policy ARN to attach to EKS node/pod roles for DSQL access"
  value       = aws_iam_policy.dsql_connect.arn
}
