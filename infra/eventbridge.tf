resource "aws_cloudwatch_event_rule" "inbound_voice_events_rule" {
  name        = local.eventbridge_rule_name
  description = "Inbound Voice Disconnects - ${var.aws_connect_instance_alias}"

  event_bus_name = data.aws_cloudwatch_event_bus.default_event_bus.name

  event_pattern = local.event_pattern
  state         = "ENABLED"
}

resource "aws_cloudwatch_event_target" "inbound_voice_events_rule_log" {
  rule      = aws_cloudwatch_event_rule.inbound_voice_events_rule.name
  target_id = "${var.aws_connect_instance_alias}-inbound-voice-disconnects-${var.environment}"
  arn       = aws_cloudwatch_log_group.inbound_voice_events_logs.arn

}

resource "aws_cloudwatch_event_target" "inbound_voice_events_transcript_function" {
  rule      = aws_cloudwatch_event_rule.inbound_voice_events_rule.name
  target_id = "${var.aws_connect_instance_alias}-call-summarization-${var.environment}"
  arn       = aws_lambda_function.call_summarization.arn

  input_transformer {
    input_paths = {
      contact_id   = "$.detail.contactId",
      instance_arn = "$.detail.instanceArn"
    }
    input_template = <<EOF
{
  "body": "{\"contactId\": \"<contact_id>\", \"instanceArn\": \"<instance_arn>\"}"
}
EOF
  }
}


data "aws_cloudwatch_event_bus" "default_event_bus" {
  name = "default"
}

resource "aws_cloudwatch_log_group" "inbound_voice_events_logs" {
  name = "/aws/events/${var.aws_connect_instance_alias}-disconnect-events"
  # retention_in_days = var.log_retention_days
  kms_key_id = local.kms_key_id
}