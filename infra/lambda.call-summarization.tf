resource "aws_lambda_function" "call_summarization" {
  depends_on = [
    aws_cloudwatch_log_group.call_summarization_function_logs
  ]

  filename         = "${path.module}/../code/call-summarization/call-summarization.zip"
  source_code_hash = filebase64sha256("${path.module}/../code/call-summarization/call-summarization.zip")

  function_name = local.call_summarization_function_name
  role          = aws_iam_role.call_summarization_function_lambda_role.arn
  handler       = "src/app.lambda_handler"
  runtime       = "nodejs20.x"
  memory_size   = 128
  timeout       = 90
  kms_key_arn   = local.kms_key_id


  tags = {
    "Name"        = local.call_summarization_function_name,
    "Application" = "contact_summarization"
  }

  environment {
    variables = {
      ENVIRONMENT       = var.environment
      S3_BUCKET         = aws_s3_bucket.transcript_data.bucket
      INSTANCE_ARN      = data.aws_connect_instance.connect_instance.arn
      CORS_DOMAIN       = local.api_cors_config
      REDACTION_ENABLED = "true"
      RUN_SUMMARY       = var.enable_summarization
      BEDROCK_MODEL     = var.bedrock_model
      loggingLevel      = var.environment == "prod" ? "INFO" : "DEBUG"
    }
  }
}

resource "aws_cloudwatch_log_group" "call_summarization_function_logs" {
  name = "/aws/lambda/${local.call_summarization_function_name}"
  # retention_in_days = var.log_retention_days
  kms_key_id = local.kms_key_id
}

resource "aws_lambda_permission" "call_summarization_function_invoke_permission" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.call_summarization.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.inbound_voice_events_rule.arn
}

resource "aws_lambda_permission" "framework_api_resource_policy" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.call_summarization.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.summary_api.execution_arn}/*/*"
}