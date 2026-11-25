# ─────────────────────────────────────────────
# IRSA: IAM role ESO uses to read the MediTriage app secret
# ─────────────────────────────────────────────
# ESO syncs secrets FROM Secrets Manager INTO k8s. This role is assumed on
# behalf of ONE namespace (meditriage), through a namespace-scoped
# SecretStore and a dedicated service account, and can read exactly ONE
# secret: the app secret.
#
# Previously this role was tied to ESO's own controller service account and
# used through a ClusterSecretStore, so ANY namespace could create an
# ExternalSecret and have ESO fetch the app secret, or the OpenSearch master
# password, on its behalf (a "confused deputy"). Now each app gets its own
# reader role, scoped to its own secret. Another app or namespace that needs
# a secret gets its own SecretStore, service account and role.
#
# Resource and output names are kept as "eso" so existing references work;
# only the role's AWS name changes.

resource "aws_iam_role" "eso" {
  name = "${var.project_name}-meditriage-secrets-reader"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = var.oidc_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          # Only the meditriage-secrets-reader service account in the
          # meditriage namespace may assume this role. ESO requests a
          # short-lived token for it; no pod runs as this account.
          "${local.oidc_host}:sub" = "system:serviceaccount:meditriage:meditriage-secrets-reader"
          "${local.oidc_host}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = {
    Name        = "${var.project_name}-meditriage-secrets-reader"
    Environment = var.environment
  }
}

# Read-only, and scoped to exactly ONE secret: the app secret.
resource "aws_iam_role_policy" "eso_read_secrets" {
  name = "${var.project_name}-meditriage-read-app-secret"
  role = aws_iam_role.eso.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ]
      Resource = [aws_secretsmanager_secret.app.arn]
      }, {
      # The app secret is encrypted with the customer-managed CMK, so ESO
      # needs kms:Decrypt on that key to read it (not just GetSecretValue).
      Effect   = "Allow"
      Action   = ["kms:Decrypt"]
      Resource = [aws_kms_key.secrets.arn]
    }]
  })
}

output "eso_role_arn" {
  description = "IAM role ARN to annotate on the meditriage-secrets-reader service account"
  value       = aws_iam_role.eso.arn
}
