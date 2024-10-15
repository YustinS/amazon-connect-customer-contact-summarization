##################
# Webhook Function Function
##################
resource "aws_iam_role" "call_summarization_function_lambda_role" {
  name               = "${local.call_summarization_function_name}-role"
  assume_role_policy = data.aws_iam_policy_document.python_lambda_assume_role.json
}

data "aws_iam_policy_document" "call_summarization_function_lambda_logging" {
  #tfsec:ignore:AWS099 - Requires wildcarded at the given ARN location
  statement {
    sid = "AllowCWAccess"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["${aws_cloudwatch_log_group.call_summarization_function_logs.arn}:*"]
  }
}

resource "aws_iam_role_policy" "call_summarization_function_lambda_logging" {
  name   = "${local.call_summarization_function_name}-lambda-logging"
  role   = aws_iam_role.call_summarization_function_lambda_role.name
  policy = data.aws_iam_policy_document.call_summarization_function_lambda_logging.json
}

# KMS read access
resource "aws_iam_role_policy_attachment" "call_summarization_function_kms_write" {
  count      = local.use_kms_key ? 1 : 0
  role       = aws_iam_role.call_summarization_function_lambda_role.name
  policy_arn = aws_iam_policy.kms_write_access[0].arn
}

# Connect Access
data "aws_iam_policy_document" "call_summarization_function_lambda_connect" {
  statement {
    sid = "AllowConnectAccess"
    actions = [
      "connect:ListRealtimeContactAnalysisSegments",
      "connect:ListRealtimeContactAnalysisSegmentsV2"
    ]
    resources = [
      "${data.aws_connect_instance.connect_instance.arn}/contact/*"
    ]
  }

}

resource "aws_iam_role_policy" "call_summarization_function_lambda_ddb" {
  name   = "${local.call_summarization_function_name}-lambda-connect-access"
  role   = aws_iam_role.call_summarization_function_lambda_role.name
  policy = data.aws_iam_policy_document.call_summarization_function_lambda_connect.json
}

# S3 Access
data "aws_iam_policy_document" "call_summarization_function_lambda_s3" {
  statement {
    sid = "AllowS3Access"
    actions = [
      "s3:PutObject"
    ]
    resources = [
      "${aws_s3_bucket.transcript_data.arn}/*"
    ]
  }

}

resource "aws_iam_role_policy" "call_summarization_function_lambda_s3" {
  name   = "${local.call_summarization_function_name}-lambda-s3-access"
  role   = aws_iam_role.call_summarization_function_lambda_role.name
  policy = data.aws_iam_policy_document.call_summarization_function_lambda_s3.json
}

# Comprehend Access
data "aws_iam_policy_document" "call_summarization_function_lambda_comprehend" {
  statement {
    sid = "AllowComprehendAccess"
    actions = [
      "comprehend:DetectPiiEntities"
    ]
    resources = [
      "*"
    ]
  }

}

resource "aws_iam_role_policy" "call_summarization_function_lambda_comprehend" {
  name   = "${local.call_summarization_function_name}-lambda-comprehend-access"
  role   = aws_iam_role.call_summarization_function_lambda_role.name
  policy = data.aws_iam_policy_document.call_summarization_function_lambda_comprehend.json
}

# Bedrock Access
data "aws_iam_policy_document" "call_summarization_function_lambda_bedrock" {
  statement {
    sid = "AllowBedrockAccess"
    actions = [
      "bedrock:InvokeModel"
    ]
    resources = [
      "arn:aws:bedrock:${var.aws_region}::foundation-model/${var.bedrock_model}"
    ]
  }

}

resource "aws_iam_role_policy" "call_summarization_function_lambda_bedrock" {
  name   = "${local.call_summarization_function_name}-lambda-bedrock-access"
  role   = aws_iam_role.call_summarization_function_lambda_role.name
  policy = data.aws_iam_policy_document.call_summarization_function_lambda_bedrock.json
}