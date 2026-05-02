output "notifications_topic_arn" {
  value = aws_sns_topic.notifications.arn
}

output "notifications_topic_name" {
  value = aws_sns_topic.notifications.name
}
