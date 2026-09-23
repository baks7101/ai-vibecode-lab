output "ecr_api_url" {
  description = "ECR repository URL for API image"
  value       = aws_ecr_repository.api.repository_url
}

output "ecr_frontend_url" {
  description = "ECR repository URL for Frontend image"
  value       = aws_ecr_repository.frontend.repository_url
}

output "cloudtrail_bucket" {
  description = "S3 bucket name for CloudTrail logs"
  value       = aws_s3_bucket.cloudtrail.id
}

output "guardduty_detector_id" {
  description = "GuardDuty detector ID"
  value       = aws_guardduty_detector.main.id
}

output "sns_security_alerts_arn" {
  description = "SNS topic ARN for security alerts"
  value       = aws_sns_topic.security_alerts.arn
}

output "db_secret_arn" {
  description = "ARN of the database credentials secret"
  value       = aws_secretsmanager_secret.db_credentials.arn
}

output "jwt_secret_arn" {
  description = "ARN of the JWT secret"
  value       = aws_secretsmanager_secret.jwt_secret.arn
}

output "cloudtrail_bucket_arn" {
  description = "ARN of the CloudTrail S3 bucket"
  value       = aws_s3_bucket.cloudtrail.arn
}

output "opensearch_secret_id" {
  description = "Secrets Manager id of the OpenSearch master creds"
  value       = aws_secretsmanager_secret.opensearch_master.id
}

output "opensearch_secret_arn" {
  description = "Secrets Manager ARN of the OpenSearch master creds"
  value       = aws_secretsmanager_secret.opensearch_master.arn
}

output "secrets_kms_key_arn" {
  description = "ARN of the CMK the secrets are encrypted with"
  value       = aws_kms_key.secrets.arn
}
