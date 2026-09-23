variable "name_prefix" {
  description = "Prefix for SIEM resource names"
  type        = string
  default     = "securestack"
}

variable "cloudtrail_bucket_id" {
  description = "The CloudTrail S3 bucket name (id) to attach the notification to"
  type        = string
}

variable "cloudtrail_bucket_arn" {
  description = "The CloudTrail S3 bucket ARN (for read permission + notification source)"
  type        = string
}

variable "opensearch_endpoint" {
  description = "OpenSearch domain endpoint (host only, no scheme)"
  type        = string
}

variable "opensearch_secret_id" {
  description = "Secrets Manager id holding the OpenSearch master creds"
  type        = string
}

variable "opensearch_secret_arn" {
  description = "Secrets Manager ARN of the OpenSearch master creds (for IAM)"
  type        = string
}

variable "secrets_kms_key_arn" {
  description = "ARN of the KMS key the OpenSearch secret is encrypted with"
  type        = string
}

variable "tags" {
  description = "Tags applied to SIEM resources"
  type        = map(string)
  default     = {}
}
