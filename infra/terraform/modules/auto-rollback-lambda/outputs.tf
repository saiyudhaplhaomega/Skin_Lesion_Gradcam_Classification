output "lambda_arn" {
  value = aws_lambda_function.auto_rollback.arn
}

output "lambda_role_arn" {
  value = aws_iam_role.rollback_lambda_role.arn
}
