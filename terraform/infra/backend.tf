terraform {
  backend "s3" {
    bucket       = "k8s-from-scratch-tfstate-954028443875"
    key          = "infra/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
