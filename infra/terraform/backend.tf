terraform {
  backend "s3" {
    bucket       = "skin-lesion-tf-state-dev-version1a-0-526404916929"
    key          = "dev/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}