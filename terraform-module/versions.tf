terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.25"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 3.1.1, < 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5"
    }
    http = {
      source  = "hashicorp/http"
      version = ">= 3.4"
    }
  }
}
