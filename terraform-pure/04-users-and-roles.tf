data "aws_caller_identity" "current" {}


resource "aws_iam_user" "eks_developer" {
  name = "eks-developer"
  tags = {
    Name = "eks-developer"
  }
}

resource "aws_iam_user_policy" "eks_developer_policy" {
  name = "eks-developer-policy"
  user = aws_iam_user.eks_developer.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "eks:ListClusters",
          "eks:DescribeCluster",
          "eks:ListNodegroups",
          "eks:DescribeNodegroup",
          "eks:ListNodes",
          "eks:DescribeNode",
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_eks_access_entry" "eks_developer_access_entry" {
  cluster_name      = aws_eks_cluster.eks_cluster.name
  principal_arn     = aws_iam_user.eks_developer.arn
  kubernetes_groups = ["eks-viewer"]
}


resource "aws_iam_role" "eks_admin" {
  name = "eks-admin"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "eks_admin" {
  name = "AmazonEKSAdminPolicy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "eks:*"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = "*"
        Condition = {
          StringEquals = {
            "iam:PassedToService" = "eks.amazonaws.com"
          }
        }
      }
    ]
  })
}

resource "aws_iam_policy" "eks_assume_admin" {
  name = "AmazonEKSAssumeAdminPolicy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sts:AssumeRole"
        ]
        Resource = aws_iam_role.eks_admin.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_admin" {
  role       = aws_iam_role.eks_admin.name
  policy_arn = aws_iam_policy.eks_admin.arn
}

resource "aws_iam_user" "eks_admin" {
  name = "eks-admin"
  tags = {
    Name = "eks-admin"
  }
}

resource "aws_iam_user_policy_attachment" "eks_admin_policy_attachment" {
  user       = aws_iam_user.eks_admin.name
  policy_arn = aws_iam_policy.eks_assume_admin.arn
}

# Best practice: use IAM roles due to temporary credentials
resource "aws_eks_access_entry" "eks_admin" {
  cluster_name      = aws_eks_cluster.eks_cluster.name
  principal_arn     = aws_iam_role.eks_admin.arn
  kubernetes_groups = ["eks-admin"]
}