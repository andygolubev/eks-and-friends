resource "aws_iam_role" "eks_role" {

    name = "EKS-cluster-role-${var.cluster_name}"
    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
        {
            Effect = "Allow"
            Principal = {
            Service = "eks.amazonaws.com"
            }
            Action = ["sts:AssumeRole", "sts:TagSession"]
        }
        ]
    })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_role.name
}

resource "aws_eks_cluster" "eks_cluster" {
  name = var.cluster_name

  access_config {
    authentication_mode = "API"
    bootstrap_cluster_creator_admin_permissions = true
  }

  role_arn = aws_iam_role.eks_role.arn
  version  = var.kubernetes_version

  vpc_config {
    endpoint_public_access = true
    endpoint_private_access = false

    security_group_ids = [aws_security_group.eks_cluster.id]
    subnet_ids = values(aws_subnet.private)[*].id
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
  ]
}