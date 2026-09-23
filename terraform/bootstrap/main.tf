# =============================================================================
# BOOTSTRAP STACK — persistent identity infrastructure
# -----------------------------------------------------------------------------
# This stack is applied ONCE and never destroyed with the ephemeral cluster.
# It holds the GitHub Actions OIDC role, which the pipeline needs even when no
# cluster exists. Separating persistent identity from ephemeral workload infra
# means `terraform destroy` on the cluster never removes the CI auth role.
#
# Its own state key (bootstrap.tfstate) keeps it fully independent of the
# cluster's state (ai-vibecode-lab/terraform.tfstate).
# =============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "securestack-tfstate-761584754677"
    key            = "ai-vibecode-lab/bootstrap.tfstate"
    region         = "eu-west-2"
    encrypt        = true
    dynamodb_table = "securestack-tflock"
  }
}

provider "aws" {
  region = "eu-west-2"

  default_tags {
    tags = {
      Project   = "ai-vibecode-lab"
      Stack     = "bootstrap"
      ManagedBy = "terraform"
    }
  }
}

# Reference the account-wide GitHub OIDC provider (one per account).
data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

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
    Name = "github-actions-ai-vibecode-lab"
  }
}

resource "aws_iam_role_policy_attachment" "github_actions_readonly" {
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

output "github_actions_role_arn" {
  description = "ARN of the role ai-vibecode-lab's pipeline assumes"
  value       = aws_iam_role.github_actions.arn
}
