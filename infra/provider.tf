provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
  ignore_tags {
    key_prefixes = ["AutoTag_"]
  }
  default_tags {
    tags = merge({
      Environment = var.environment
      Owner       = "CyberCX"
      Managed_By  = "OpenTofu"
      },
      var.tags
    )
  }
}
