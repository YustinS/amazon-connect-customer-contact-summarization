aws_region  = "ap-southeast-2"
environment = "dev"
aws_profile = "my-profile"

resource_shortname         = "contact-summary"
log_retention_days         = 30
aws_connect_instance_alias = "my-instance-alias"
enable_summarization       = true

encryption_configuration = {
  use_cmk = false
  cmk_id  = null
}

tags = {}