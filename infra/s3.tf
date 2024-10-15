resource "aws_s3_bucket" "transcript_data" {
  bucket = local.s3_bucket_name

  tags = {
    "Name"        = local.s3_bucket_name,
    "Application" = "contact_summarization"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "transcript_data" {
  bucket = aws_s3_bucket.transcript_data.id
  rule {
    id = "transition"

    filter {
      prefix = "transcripts/"
    }

    status = "Enabled"

    expiration {
      days = 7
    }

    noncurrent_version_expiration {
      noncurrent_days = 7
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "transcript_data" {
  bucket = aws_s3_bucket.transcript_data.id

  rule {
    bucket_key_enabled = true

    apply_server_side_encryption_by_default {
      sse_algorithm     = local.use_kms_key ? "aws:kms" : "AES256"
      kms_master_key_id = local.use_kms_key ? local.kms_key_id : null
    }
  }
}

resource "aws_s3_bucket_versioning" "transcript_data" {
  bucket = aws_s3_bucket.transcript_data.id

  versioning_configuration {
    mfa_delete = "Disabled"
    status     = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "transcript_data" {
  bucket                  = aws_s3_bucket.transcript_data.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "transcript_data" {
  bucket = aws_s3_bucket.transcript_data.id
  policy = data.aws_iam_policy_document.transcript_data.json
}


data "aws_iam_policy_document" "transcript_data" {

  statement {
    sid    = "BlockNonSSL"
    effect = "Deny"
    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = [
      "s3:*",
    ]

    resources = [
      aws_s3_bucket.transcript_data.arn,
      "${aws_s3_bucket.transcript_data.arn}/*"
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"

      values = [
        "false"
      ]
    }
  }
}
