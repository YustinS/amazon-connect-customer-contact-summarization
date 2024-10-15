resource "aws_api_gateway_rest_api" "summary_api" {
  name        = local.api_gateway_name
  description = "Rest API for ${var.resource_shortname} Contact Summarization in ${var.environment}"
  tags        = var.tags

  body = local.apigw_body_content

  # Determine the API type
  endpoint_configuration {
    types            = ["REGIONAL"]
    vpc_endpoint_ids = null
  }
}

resource "aws_api_gateway_deployment" "summary_api" {
  rest_api_id = aws_api_gateway_rest_api.summary_api.id

  triggers = {
    redeployment = sha1(aws_api_gateway_rest_api.summary_api.body)
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [aws_api_gateway_rest_api.summary_api]
}

resource "aws_api_gateway_stage" "summary_api" {
  deployment_id        = aws_api_gateway_deployment.summary_api.id
  rest_api_id          = aws_api_gateway_rest_api.summary_api.id
  stage_name           = var.environment
  xray_tracing_enabled = false
  access_log_settings {
    # Always created, even if Logging is disabled
    destination_arn = aws_cloudwatch_log_group.summary_api_logs.arn
    format = jsonencode({
      "requestId"      = "$context.requestId",
      "extRequestId"   = "$context.extendedRequestId",
      "ip"             = "$context.identity.sourceIp",
      "requestTime"    = "$context.requestTime",
      "epochTime"      = "$context.requestTimeEpoch",
      "httpMethod"     = "$context.httpMethod",
      "resourcePath"   = "$context.resourcePath",
      "status"         = "$context.status",
      "protocol"       = "$context.protocol",
      "responseLength" = "$context.responseLength",
      "errorMessage"   = "$context.error.messageString",
    })
  }
}

resource "aws_api_gateway_method_settings" "summary_api" {
  rest_api_id = aws_api_gateway_rest_api.summary_api.id
  stage_name  = aws_api_gateway_stage.summary_api.stage_name
  method_path = "*/*"

  settings {
    metrics_enabled    = false
    logging_level      = "INFO"
    data_trace_enabled = false

    throttling_burst_limit = 100
    throttling_rate_limit  = 200

    caching_enabled      = false
    cache_data_encrypted = true
  }
}


resource "aws_api_gateway_usage_plan" "summary_api_usage_plan" {
  name = "${var.resource_shortname}-summary-api-usage-plan-${var.environment}"

  api_stages {
    api_id = aws_api_gateway_rest_api.summary_api.id
    stage  = aws_api_gateway_stage.summary_api.stage_name
  }
}

resource "aws_api_gateway_api_key" "summary_api_key" {
  name = "${var.resource_shortname}-summary-api-key${var.environment}"
}

resource "aws_api_gateway_usage_plan_key" "main" {
  key_id        = aws_api_gateway_api_key.summary_api_key.id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.summary_api_usage_plan.id
}

resource "aws_cloudwatch_log_group" "summary_api_logs" {
  name = "/aws/apigateway/${aws_api_gateway_rest_api.summary_api.id}/${var.environment}"
  # retention_in_days = var.log_retention_days
  kms_key_id = local.kms_key_id
}

data "aws_api_gateway_domain_name" "api_custom_domain" {
  count       = local.api_gateway_custom_url ? 1 : 0
  domain_name = var.apigw_domain_settings.api_gateway_url
}

resource "aws_api_gateway_base_path_mapping" "base_path_mapping" {
  count       = local.api_gateway_custom_url ? 1 : 0
  api_id      = aws_api_gateway_rest_api.summary_api.id
  stage_name  = aws_api_gateway_stage.summary_api.stage_name
  domain_name = data.aws_api_gateway_domain_name.api_custom_domain[0].domain_name
  base_path   = var.apigw_domain_settings.api_gateway_base_path
}