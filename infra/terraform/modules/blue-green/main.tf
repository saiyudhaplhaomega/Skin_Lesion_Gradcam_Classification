# Blue-Green ALB Module
# Creates two target groups (blue/green) and a listener with a rule that can flip between them.
# The "active" target group receives 100% traffic. The "inactive" receives 0%.
# On deployment, we deploy to inactive, validate, then flip the active TG in the listener rule.

variable "environment" {}
variable "alb_arn" {}
variable "vpc_id" {}
variable "app_subnet_ids" {}
variable "ecs_security_group_id" {}

resource "aws_lb_target_group" "blue" {
  name     = "skin-lesion-tg-${var.environment}-blue"
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
    Slot        = "blue"
  }
}

resource "aws_lb_target_group" "green" {
  name     = "skin-lesion-tg-${var.environment}-green"
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
    Slot        = "green"
  }
}

# Listener rule that forwards to the active target group
# We use a fixed-rule listener (not rule-based) for blue-green
# because blue-green switches the entire target group, not path-based
resource "aws_lb_listener" "main" {
  load_balancer_arn = var.alb_arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.blue.arn  # Blue is active by default
  }
}

# We track active slot via SSM parameter so Lambda and GitHub Actions can read it
resource "aws_ssm_parameter" "active_slot" {
  name  = "/skin-lesion/${var.environment}/active-slot"
  type  = "String"
  value = "blue"  # Valid values: "blue" or "green"

  tags = {
    Environment = var.environment
  }
}

resource "aws_ssm_parameter" "blue_tg_arn" {
  name  = "/skin-lesion/${var.environment}/blue-tg-arn"
  type  = "String"
  value = aws_lb_target_group.blue.arn

  tags = {
    Environment = var.environment
  }
}

resource "aws_ssm_parameter" "green_tg_arn" {
  name  = "/skin-lesion/${var.environment}/green-tg-arn"
  type  = "String"
  value = aws_lb_target_group.green.arn

  tags = {
    Environment = var.environment
  }
}

output "blue_tg_arn" {
  value = aws_lb_target_group.blue.arn
}

output "green_tg_arn" {
  value = aws_lb_target_group.green.arn
}

output "blue_tg_name" {
  value = aws_lb_target_group.blue.name
}

output "green_tg_name" {
  value = aws_lb_target_group.green.name
}

output "listener_arn" {
  value = aws_lb_listener.main.arn
}

output "active_slot" {
  value = aws_ssm_parameter.active_slot.value
}
