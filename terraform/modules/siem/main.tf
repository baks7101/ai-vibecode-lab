# =============================================================================
# SIEM CENTRALISATION — ship CloudTrail + GuardDuty into OpenSearch
# -----------------------------------------------------------------------------
# Turns OpenSearch into a single pane of glass: CloudTrail (AWS API activity)
# and GuardDuty (threat findings) land in the same searchable place as the
# app + Falco logs (which Fluent Bit already ships). An investigator searches
# one system instead of three.
#
#   CloudTrail -> S3 -> (S3 event) -> Lambda -> OpenSearch  (index: cloudtrail)
#   GuardDuty -> EventBridge -> Lambda -> OpenSearch          (index: guardduty)
#
# Both Lambdas authenticate to OpenSearch with the master creds from Secrets
# Manager (pragmatic for a single-node lab; a larger setup would map a scoped
# FGAC backend role for least privilege).
# =============================================================================

# ---- package the two shipper scripts ----
data "archive_file" "cloudtrail_shipper" {
  type        = "zip"
  source_file = "${path.module}/src/cloudtrail_shipper.py"
  output_path = "${path.module}/build/cloudtrail_shipper.zip"
}

data "archive_file" "guardduty_shipper" {
  type        = "zip"
  source_file = "${path.module}/src/guardduty_shipper.py"
  output_path = "${path.module}/build/guardduty_shipper.zip"
}

# ---- IAM role shared by both shipper Lambdas ----
data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "shipper" {
  name               = "${var.name_prefix}-siem-shipper"
  assume_role_policy = data.aws_iam_policy_document.assume.json
  tags               = var.tags
}

data "aws_iam_policy_document" "shipper" {
  # CloudWatch logs for the Lambdas themselves.
  statement {
    sid       = "Logs"
    effect    = "Allow"
    actions   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["arn:aws:logs:*:*:*"]
  }
  # Read CloudTrail log files from the S3 bucket.
  statement {
    sid       = "ReadCloudTrailBucket"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${var.cloudtrail_bucket_arn}/*"]
  }
  # Read the OpenSearch master creds.
  statement {
    sid       = "ReadOpenSearchSecret"
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [var.opensearch_secret_arn]
  }
  # Decrypt the CMK the secret is encrypted with.
  statement {
    sid       = "DecryptSecret"
    effect    = "Allow"
    actions   = ["kms:Decrypt"]
    resources = [var.secrets_kms_key_arn]
  }
}

resource "aws_iam_role_policy" "shipper" {
  name   = "${var.name_prefix}-siem-shipper"
  role   = aws_iam_role.shipper.id
  policy = data.aws_iam_policy_document.shipper.json
}

# ---- CloudTrail shipper Lambda ----
resource "aws_lambda_function" "cloudtrail" {
  # checkov:skip=CKV_AWS_117:Reaches S3 + OpenSearch public endpoint + Secrets Manager; in-VPC would need NAT/endpoints, disproportionate for this lab.
  # checkov:skip=CKV_AWS_116:No DLQ — failures surface via CloudWatch logs; over-engineering for a lab shipper.
  # checkov:skip=CKV_AWS_272:Code-signing needs a Signer profile; disproportionate here.
  # checkov:skip=CKV_AWS_173:Env vars hold endpoint + secret id (identifiers, not secrets).
  # checkov:skip=CKV_AWS_115:Reserved concurrency starves this low-limit account's pool (< AWS min 10); would set in prod.
  function_name    = "${var.name_prefix}-siem-cloudtrail-shipper"
  role             = aws_iam_role.shipper.arn
  runtime          = "python3.12"
  handler          = "cloudtrail_shipper.handler"
  filename         = data.archive_file.cloudtrail_shipper.output_path
  source_code_hash = data.archive_file.cloudtrail_shipper.output_base64sha256
  timeout          = 60
  memory_size      = 256

  tracing_config {
    mode = "Active"
  }

  environment {
    variables = {
      OPENSEARCH_ENDPOINT  = var.opensearch_endpoint
      OPENSEARCH_SECRET_ID = var.opensearch_secret_id
      OPENSEARCH_INDEX     = "cloudtrail"
    }
  }
  tags = var.tags
}

resource "aws_cloudwatch_log_group" "cloudtrail" {
  # checkov:skip=CKV_AWS_158:Operational Lambda logs, not secrets; CMK disproportionate for lab.
  # checkov:skip=CKV_AWS_338:7-day retention is a deliberate lab cost decision.
  name              = "/aws/lambda/${aws_lambda_function.cloudtrail.function_name}"
  retention_in_days = 7
  tags              = var.tags
}

# ---- GuardDuty shipper Lambda ----
resource "aws_lambda_function" "guardduty" {
  # checkov:skip=CKV_AWS_117:See cloudtrail shipper — public-endpoint reach, lab.
  # checkov:skip=CKV_AWS_116:No DLQ — CloudWatch logs suffice for a lab.
  # checkov:skip=CKV_AWS_272:Code-signing disproportionate.
  # checkov:skip=CKV_AWS_173:Env vars are identifiers not secrets.
  # checkov:skip=CKV_AWS_115:Reserved concurrency starves low-limit account pool.
  function_name    = "${var.name_prefix}-siem-guardduty-shipper"
  role             = aws_iam_role.shipper.arn
  runtime          = "python3.12"
  handler          = "guardduty_shipper.handler"
  filename         = data.archive_file.guardduty_shipper.output_path
  source_code_hash = data.archive_file.guardduty_shipper.output_base64sha256
  timeout          = 30
  memory_size      = 128

  tracing_config {
    mode = "Active"
  }

  environment {
    variables = {
      OPENSEARCH_ENDPOINT  = var.opensearch_endpoint
      OPENSEARCH_SECRET_ID = var.opensearch_secret_id
      OPENSEARCH_INDEX     = "guardduty"
    }
  }
  tags = var.tags
}

resource "aws_cloudwatch_log_group" "guardduty" {
  # checkov:skip=CKV_AWS_158:Operational Lambda logs, not secrets.
  # checkov:skip=CKV_AWS_338:7-day retention is a lab cost decision.
  name              = "/aws/lambda/${aws_lambda_function.guardduty.function_name}"
  retention_in_days = 7
  tags              = var.tags
}

# ---- S3 -> CloudTrail Lambda trigger ----
resource "aws_lambda_permission" "s3_invoke" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cloudtrail.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = var.cloudtrail_bucket_arn
}

resource "aws_s3_bucket_notification" "cloudtrail" {
  bucket = var.cloudtrail_bucket_id

  lambda_function {
    lambda_function_arn = aws_lambda_function.cloudtrail.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "AWSLogs/"
    filter_suffix       = ".json.gz"
  }

  depends_on = [aws_lambda_permission.s3_invoke]
}

# ---- EventBridge -> GuardDuty Lambda trigger ----
resource "aws_cloudwatch_event_rule" "guardduty_to_siem" {
  name        = "${var.name_prefix}-guardduty-to-siem"
  description = "Route GuardDuty findings to the SIEM shipper Lambda"

  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
  })
  tags = var.tags
}

resource "aws_cloudwatch_event_target" "guardduty_to_siem" {
  rule      = aws_cloudwatch_event_rule.guardduty_to_siem.name
  target_id = "siem-guardduty-shipper"
  arn       = aws_lambda_function.guardduty.arn
}

resource "aws_lambda_permission" "eventbridge_invoke" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.guardduty.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.guardduty_to_siem.arn
}
