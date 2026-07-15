# General-purpose IRSA role for the backend ServiceAccount. This role always
# exists because the backend needs S3 and KMS access regardless of optional
# infrastructure features such as Aurora DSQL.
data "aws_iam_policy_document" "backend_workload_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.oidc_issuer_url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.oidc_issuer_url, "https://", "")}:sub"
      values = [
        "system:serviceaccount:skin-lesion-dev:skin-lesion-backend",
        "system:serviceaccount:skin-lesion-staging:skin-lesion-backend",
        "system:serviceaccount:skin-lesion-prod:skin-lesion-backend",
      ]
    }
  }
}

resource "aws_iam_role" "backend_workload" {
  name               = "${var.project_name}-${var.environment}-backend-workload"
  assume_role_policy = data.aws_iam_policy_document.backend_workload_assume_role.json

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Purpose     = "backend-irsa"
  }
}

data "aws_iam_policy_document" "backend_workload_storage" {
  statement {
    sid = "ListBackendBuckets"

    actions = ["s3:ListBucket"]
    resources = [
      aws_s3_bucket.uploads.arn,
      aws_s3_bucket.lab_results.arn,
    ]
  }

  statement {
    sid = "ManageBackendObjects"

    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject",
    ]
    resources = [
      "${aws_s3_bucket.uploads.arn}/*",
      "${aws_s3_bucket.lab_results.arn}/*",
    ]
  }

  statement {
    sid = "UseBackendStorageKey"

    actions = [
      "kms:GenerateDataKey",
      "kms:Decrypt",
    ]
    resources = [aws_kms_key.main.arn]
  }
}

resource "aws_iam_role_policy" "backend_workload_storage" {
  name   = "${var.project_name}-${var.environment}-backend-storage"
  role   = aws_iam_role.backend_workload.id
  policy = data.aws_iam_policy_document.backend_workload_storage.json
}
