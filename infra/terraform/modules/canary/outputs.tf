output "baseline_target_group_arn" {
  value = aws_lb_target_group.baseline.arn
}

output "canary_target_group_arn" {
  value = aws_lb_target_group.canary.arn
}

output "canary_weight_ssm_param" {
  value = aws_ssm_parameter.canary_weight.name
}

output "baseline_tg_name" {
  value = aws_lb_target_group.baseline.name
}

output "canary_tg_name" {
  value = aws_lb_target_group.canary.name
}
