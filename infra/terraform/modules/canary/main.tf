# Canary ALB Module
# Creates two target groups (baseline/canary) with weighted routing.
# Baseline receives 100% traffic initially. Canary receives 0%.
# As the canary passes checks, weight is shifted: 5% -> 25% -> 50% -> 100%
# Once canary is at 100%, it becomes the new baseline and old baseline is destroyed.

variable "environment" {}
variable "alb_arn" {}
variable "vpc_id" {}
variable "app_subnet_ids" {}
variable "ecs_security_group_id" {}

resource "aws_lb_target_group" "baseline" {
  name     = "skin-lesion-tg-${var.environment}-baseline"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/health"
    matcher             = "200"
  }

  tags = {
    Environment = var.environment
    Slot        = "baseline"
  }
}

resource "aws_lb_target_group" "canary" {
  name     = "skin-lesion-tg-${var.environment}-canary"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/health"
    matcher             = "200"
  }

  tags = {
    Environment = var.environment
    Slot        = "canary"
  }
}

# Canary listener rule - weights are managed via AWS CLI after terraform apply
resource "aws_lb_listener_rule" "canary" {
  listener_arn = var.alb_arn

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.baseline.arn
  }

  condition {
    path_pattern {
      values = ["*"]
    }
  }

  tags = {
    Environment = var.environment
  }
}

# SSM parameters to track canary weight (0-100)
resource "aws_ssm_parameter" "canary_weight" {
  name  = "/skin-lesion/${var.environment}/canary-weight"
  type  = "String"
  value = "0"  # 0 = no traffic to canary, 100 = all traffic to canary

  tags = {
    Environment = var.environment
  }
}

resource "aws_ssm_parameter" "baseline_tg_arn" {
  name  = "/skin-lesion/${var.environment}/baseline-tg-arn"
  type  = "String"
  value = aws_lb_target_group.baseline.arn
}

resource "aws_ssm_parameter" "canary_tg_arn" {
  name  = "/skin-lesion/${var.environment}/canary-tg-arn"
  type  = "String"
  value = aws_lb_target_group.canary.arn
}

output "baseline_tg_arn" {
  value = aws_lb_target_group.baseline.arn
}

output "canary_tg_arn" {
  value = aws_lb_target_group.canary.arn
}

output "canary_weight" {
  value = aws_ssm_parameter.canary_weight.value
}
