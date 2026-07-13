# GitHub's OIDC provider is account-global. Staging owns it so the isolated
# dev/prod states do not attempt to create the same IAM provider a second time.
# Apply staging once before using the deploy role in any environment.
data "tls_certificate" "github_actions" {
  url = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_openid_connect_provider" "github_actions" {
  count = var.environment == "staging" ? 1 : 0

  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github_actions.certificates[0].sha1_fingerprint]

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Purpose     = "github-actions-oidc"
  }
}

locals {
  github_actions_oidc_provider_arn = "arn:aws:iam::${var.aws_account_id}:oidc-provider/token.actions.githubusercontent.com"
  github_actions_subjects = var.environment == "prod" ? [
    "repo:saiyudhaplhaomega/Skin_Lesion_Classification_backend:ref:refs/heads/main",
    "repo:saiyudhaplhaomega/Skin_Lesion_Classification_backend:environment:production",
    ] : var.environment == "staging" ? [
    "repo:saiyudhaplhaomega/Skin_Lesion_Classification_backend:ref:refs/heads/main",
    "repo:saiyudhaplhaomega/Skin_Lesion_Classification_backend:environment:staging",
    ] : [
    "repo:saiyudhaplhaomega/Skin_Lesion_Classification_backend:ref:refs/heads/main",
  ]
}

data "aws_iam_policy_document" "github_actions_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.github_actions_oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = local.github_actions_subjects
    }
  }
}

resource "aws_iam_role" "github_actions_deploy" {
  name               = "${var.project_name}-github-actions-deploy-${var.environment}"
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role.json

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Purpose     = "github-actions-deployment"
  }
}

data "aws_iam_policy_document" "github_actions_deploy" {
  statement {
    sid       = "EcrAuthorization"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid    = "BackendRepositoryPushPull"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:DescribeImages",
      "ecr:DescribeRepositories",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:ListImages",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
    ]
    resources = [aws_ecr_repository.backend.arn]
  }
}

resource "aws_iam_role_policy" "github_actions_deploy" {
  name   = "${var.project_name}-github-actions-ecr-${var.environment}"
  role   = aws_iam_role.github_actions_deploy.id
  policy = data.aws_iam_policy_document.github_actions_deploy.json
}

resource "aws_eks_access_entry" "github_actions_deploy" {
  cluster_name  = module.eks.cluster_name
  principal_arn = aws_iam_role.github_actions_deploy.arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "github_actions_deploy" {
  cluster_name  = module.eks.cluster_name
  principal_arn = aws_iam_role.github_actions_deploy.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy"

  access_scope {
    type       = "namespace"
    namespaces = ["skin-lesion-${var.environment}"]
  }

  depends_on = [aws_eks_access_entry.github_actions_deploy]
}
