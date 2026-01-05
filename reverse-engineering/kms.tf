resource "aws_kms_key" "cluster" {
  description         = "${local.cluster_name} cluster encryption key"
  enable_key_rotation = true

  # Exact policy captured from the working state
  policy = file("${path.module}/policies/kms_key_policy.json")

  tags = {
    "terraform-aws-modules" = "eks"
  }
}

resource "aws_kms_alias" "cluster" {
  name          = "alias/eks/${local.cluster_name}"
  target_key_id = aws_kms_key.cluster.key_id
}

