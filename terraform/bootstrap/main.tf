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

    # Only the two kinds of run that need AWS: pull requests and pushes to
    # main. Previously "repo:baks7101/ai-vibecode-lab:*" let ANY workflow on
    # ANY branch assume this role, with no PR or review. StringEquals means
    # exact matches, no wildcards. PRs from forks never receive OIDC tokens.
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:baks7101/ai-vibecode-lab:pull_request",
        "repo:baks7101/ai-vibecode-lab:ref:refs/heads/main",
      ]
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

# Exactly what the pipeline's OPA stage needs for `terraform plan
# -refresh=false`. Its data sources: aws_caller_identity (no permission
# needed), aws_region and aws_iam_policy_document (no API call), and
# aws_availability_zones (the one action below).
# Replaces the AWS-managed ReadOnlyAccess, which could read every S3 object,
# including Terraform state holding a generated password (proven with
# `aws iam simulate-principal-policy`: s3:GetObject on the state = allowed).
resource "aws_iam_role_policy" "github_actions_plan" {
  name = "terraform-plan-minimal"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "TerraformPlanDataSources"
      Effect   = "Allow"
      Action   = ["ec2:DescribeAvailabilityZones"]
      Resource = "*"
    }]
  })
}

output "github_actions_role_arn" {
  description = "ARN of the role ai-vibecode-lab's pipeline assumes"
  value       = aws_iam_role.github_actions.arn
}
