output "application_id" {
  value = aws_appconfig_application.main.id
}

output "configuration_profile_id" {
  value = aws_appconfig_configuration_profile.flags.id
}

output "environment_id" {
  value = aws_appconfig_environment.main.id
}
