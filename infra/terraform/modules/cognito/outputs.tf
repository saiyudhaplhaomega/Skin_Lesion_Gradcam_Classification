output "user_pool_id" {
  description = "Cognito user pool ID"
  value       = aws_cognito_user_pool.main.id
}

output "user_pool_client_id" {
  description = "Public Cognito user pool client ID for the backend application"
  value       = aws_cognito_user_pool_client.backend.id
}
