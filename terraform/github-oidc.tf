# =============================================================================
# GitHub Actions OIDC — keyless CI-to-AWS auth for ai-vibecode-lab
# -----------------------------------------------------------------------------
# The OIDC PROVIDER is a one-per-account shared foundation (already created in
# this AWS account). We REFERENCE it here rather than creating it again.
# We create our OWN role, scoped to THIS repo only, with read-only access.
# =============================================================================

# Reference the existing account-wide GitHub OIDC provider (do not re-create).
data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

# Role that ai-vibecode-lab's pipeline assumes. Trust scoped to THIS repo only.
data "aws_iam_policy_document" "github_actions_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Only workflows in baks7101/ai-vibecode-lab can assume this role.
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:baks7101/ai-vibecode-lab:*"]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = "github-actions-ai-vibecode-lab"
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume.json

  tags = {
    Name        = "github-actions-ai-vibecode-lab"
    Environment = var.environment
  }
}

# Read-only is enough for `terraform plan` (plan only READS AWS). Least privilege.
resource "aws_iam_role_policy_attachment" "github_actions_readonly" {
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

output "github_actions_role_arn" {
  description = "ARN of the role ai-vibecode-lab's pipeline assumes"
  value       = aws_iam_role.github_actions.arn
}
