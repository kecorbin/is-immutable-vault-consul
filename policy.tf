resource "aws_iam_instance_profile" "instance_profile" {
  name_prefix = "${var.name_prefix}-vault"
  role        = aws_iam_role.instance_role.name
}

resource "aws_iam_role" "instance_role" {
  name_prefix        = "${var.name_prefix}-vault"
  assume_role_policy = data.aws_iam_policy_document.instance_role.json
}

data "aws_iam_policy_document" "instance_role" {
  statement {
    effect = "Allow"
    actions = [
      "sts:AssumeRole",
    ]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "cluster_discovery_health" {
  name   = "${var.name_prefix}-vault-cluster_discovery_health"
  role   = aws_iam_role.instance_role.id
  policy = data.aws_iam_policy_document.cluster_discovery_health.json
}

data "aws_iam_policy_document" "cluster_discovery_health" {
  statement {
    effect = "Allow"

    actions = [
      "ec2:DescribeInstances",
      "autoscaling:CompleteLifecycleAction",
      "ec2:DescribeTags"
    ]

    resources = ["*"]
  }

  statement {
    actions = [
      "kms:DescribeKey",
      "kms:Encrypt",
      "kms:Decrypt",
    ]

    resources = [
      "${aws_kms_key.vault.arn}",
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = [
      "arn:aws:s3:::${var.name_prefix}-consul-data/*"
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "s3:ListBucketVersions",
      "s3:ListBucket",
    ]
    resources = [
      "arn:aws:s3:::${var.name_prefix}-consul-data"
    ]
  }

}