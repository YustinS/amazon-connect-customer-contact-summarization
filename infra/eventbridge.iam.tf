data "aws_iam_policy_document" "eventbridge_cloudwatch_log_policy" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogStream"
    ]

    resources = [
      "*"
    ]

    principals {
      type = "Service"
      identifiers = [
        "events.amazonaws.com",
        "delivery.logs.amazonaws.com"
      ]
    }
  }
  statement {
    effect = "Allow"
    actions = [
      "logs:PutLogEvents"
    ]

    resources = [
      "*"
    ]

    principals {
      type = "Service"
      identifiers = [
        "events.amazonaws.com",
        "delivery.logs.amazonaws.com"
      ]
    }
  }
}

resource "aws_cloudwatch_log_resource_policy" "eventbridge_cloudwatch_log_policy" {
  policy_document = data.aws_iam_policy_document.eventbridge_cloudwatch_log_policy.json
  policy_name     = "eventbridge-cloudwatch-log-policy-${var.environment}"
}