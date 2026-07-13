module "cognito" {
  count  = var.enable_cognito ? 1 : 0
  source = "./modules/cognito"

  project_name = var.project_name
  environment  = var.environment
}
