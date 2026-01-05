terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      # Working state used aws provider 5.x (from the lock file).
      version = ">= 5.61, < 6.0"
    }
  }
}

