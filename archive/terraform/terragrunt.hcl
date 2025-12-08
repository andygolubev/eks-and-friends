locals {
  repo_name = "eks-argo-terraform"
  env_tags  = { repo = local.repo_name }
}

remote_state {
  backend = "s3"
  config = {
    bucket    = get_env("TF_STATE_BUCKET", "eks-argo-terraform-tf-state-bucket")
    key       = "${path_relative_to_include()}/terraform.tfstate"
    region    = get_env("TF_STATE_REGION", "us-east-1")
    encrypt   = true
    use_lockfile = true
  }
}

generate "providers" {
  path      = "providers.tf"
  if_exists = "overwrite"
  contents  = <<EOP
terraform {
  required_version = ">= 1.13"
  required_providers {
    aws        = { source = "hashicorp/aws",        version = ">= 6.13" }
    helm       = { source = "hashicorp/helm",       version = ">= 3.0" }
    kubernetes = { source = "hashicorp/kubernetes", version = ">= 2.38" }
  }
}

provider "aws" {
  region = "${get_env("AWS_REGION", "us-east-1")}"
}
EOP
}
