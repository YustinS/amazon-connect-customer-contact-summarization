# versions.tf
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      version = ">= 4.61.0"
      source  = "hashicorp/aws"
    }
    random = {
      version = ">= 3.5.1"
      source  = "hashicorp/random"
    }
  }

  backend "s3" {
    bucket  = "state-storage-bucket"
    key     = "connect-contact-summarization/terraform.tfstate"
    region  = "ap-southeast-2"
    profile = "my-profile"
  }
}
