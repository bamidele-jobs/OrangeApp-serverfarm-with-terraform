terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  #access_key = "my-access-key" . #Rather than hardcoding my user IAM credentials, I signed into the organization AWS Account via the AWS CLI.
  #secret_key = "my-secret-key"
  region = "eu-west-2"
}
