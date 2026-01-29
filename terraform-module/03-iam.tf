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
          "eks:DescribeNode"
        ]
        Resource = "*"
      }
    ]
  })
}

module "eks_admin_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version = "~> 5.0"

  create_role       = true
  role_name         = "eks-admin"
  trusted_role_arns = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
  custom_role_policy_arns = [
    aws_iam_policy.eks_admin.arn
  ]
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
        Resource = module.eks_admin_role.iam_role_arn
      }
    ]
  })
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

resource "aws_iam_policy" "cluster_autoscaler" {
  name = "${var.cluster_name}-cluster-autoscaler"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances",
          "autoscaling:DescribeLaunchConfigurations",
          "autoscaling:DescribeScalingActivities",
          "autoscaling:DescribeTags",
          "ec2:DescribeImages",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeLaunchTemplateVersions",
          "ec2:GetInstanceTypesFromInstanceRequirements",
          "eks:DescribeNodegroup"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "autoscaling:SetDesiredCapacity",
          "autoscaling:TerminateInstanceInAutoScalingGroup"
        ]
        Resource = "*"
      }
    ]
  })
}

module "cluster_autoscaler_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version = "~> 5.0"

  create_role           = true
  role_name             = "${var.cluster_name}-cluster-autoscaler"
  trusted_role_services = ["pods.eks.amazonaws.com"]
  custom_role_policy_arns = [
    aws_iam_policy.cluster_autoscaler.arn
  ]
}

resource "aws_iam_policy" "aws_lbc" {
  policy = file("${path.module}/../terraform-pure/iam/AWSLoadBalancerController.json")
  name   = "AWSLoadBalancerController"
}

module "aws_lbc_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version = "~> 5.0"

  create_role           = true
  role_name             = "${var.cluster_name}-aws-lbc"
  trusted_role_services = ["pods.eks.amazonaws.com"]
  custom_role_policy_arns = [
    aws_iam_policy.aws_lbc.arn
  ]
}

resource "aws_iam_policy" "ebs_csi_driver_encryption" {
  name = "${var.cluster_name}-ebs-csi-driver-encryption"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKeyWithoutPlaintext",
          "kms:CreateGrant"
        ]
        Resource = "*"
      }
    ]
  })
}

module "ebs_csi_driver_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version = "~> 5.0"

  create_role           = true
  role_name             = "${var.cluster_name}-ebs-csi-driver"
  trusted_role_services = ["pods.eks.amazonaws.com"]
  custom_role_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy",
    aws_iam_policy.ebs_csi_driver_encryption.arn
  ]
}
