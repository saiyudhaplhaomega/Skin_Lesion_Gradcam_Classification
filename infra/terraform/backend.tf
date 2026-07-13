terraform {
  backend "s3" {
    bucket       = "skin-lesion-tf-state-dev-version1a-0-526404916929"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}

# State keys are intentionally supplied as partial backend configuration so each
# environment has isolated state. Reconfigure before changing environments:
# terraform init -backend-config=env/backend-<env>.hcl -reconfigure
