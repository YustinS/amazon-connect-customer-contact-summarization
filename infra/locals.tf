locals {
  account_id = data.aws_caller_identity.current.account_id

  api_gateway_name = "${var.resource_shortname}-summarization-api-${var.environment}"

  api_gateway_custom_url = var.apigw_domain_settings.use_custom_domain && var.apigw_domain_settings.api_gateway_url != null && var.apigw_domain_settings.api_gateway_base_path != null

  s3_bucket_name = "${var.aws_connect_instance_alias}-summarization-storage-${var.environment}"

  call_summarization_function_name = "${var.aws_connect_instance_alias}-call-summarization-${var.environment}"

  eventbridge_rule_name = "${var.aws_connect_instance_alias}-inbound-voice-disconnects-${var.environment}"

  use_kms_key = var.encryption_configuration.use_cmk && var.encryption_configuration.cmk_id != null ? true : false
  kms_key_id  = var.encryption_configuration.use_cmk && var.encryption_configuration.cmk_id != null ? data.aws_kms_key.custom_key[0].arn : null

  api_cors_config = "*"

  apigw_body_content = templatefile(
    "${path.module}/templates/summary-api.yaml",
    {
      "cors_allowed_domain"        = local.api_cors_config,
      "summarization_function_arn" = aws_lambda_function.call_summarization.invoke_arn
    }
  )

  event_pattern = jsonencode({
    "detail-type" = [
      "Amazon Connect Contact Event"
    ]
    "source" = ["aws.connect"]
    "detail" = {
      "eventType"        = ["DISCONNECTED"]
      "channel"          = ["VOICE"]
      "initiationMethod" = ["INBOUND"]
      "instanceArn"      = ["${data.aws_connect_instance.connect_instance.arn}"]
      "agentInfo" = {
        "agentArn" = [{ "exists" : true }]
      }
      "contactLens" = {
        "conversationalAnalytics" = {
          "configuration" = {
            "enabled" = [true]
            "channelConfiguration" = {
              "analyticsModes" = [
                "RealTime"
              ]
            }
          }
        }
      }
    }
  })
}

data "aws_kms_key" "custom_key" {
  count  = var.encryption_configuration.use_cmk ? 1 : 0
  key_id = var.encryption_configuration.cmk_id
}

data "aws_connect_instance" "connect_instance" {
  instance_alias = var.aws_connect_instance_alias
}

data "aws_caller_identity" "current" {}

# data "aws_partition" "current" {}
