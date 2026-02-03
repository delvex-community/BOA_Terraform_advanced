terraform {
required_version = "~> 1.13.4"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "6.27.0"
    }
  }
}

provider "aws" {
  # Configuration options
}