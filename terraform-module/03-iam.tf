data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

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

# ---------------------------------------------------------------------------
# AWS Load Balancer Controller
# ---------------------------------------------------------------------------

resource "aws_iam_policy" "aws_lbc" {
  policy = file("${path.module}/iam/AWSLoadBalancerController.json")
  name   = "AWSLoadBalancerController"
}

resource "aws_iam_role" "aws_lbc" {
  name = "${var.cluster_name}-aws-lbc"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "pods.eks.amazonaws.com"
        }
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "aws_lbc_policy" {
  role       = aws_iam_role.aws_lbc.name
  policy_arn = aws_iam_policy.aws_lbc.arn
}

# ---------------------------------------------------------------------------
# EBS CSI Driver
# ---------------------------------------------------------------------------

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

resource "aws_iam_role" "ebs_csi_driver" {
  name = "${var.cluster_name}-ebs-csi-driver"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "pods.eks.amazonaws.com"
        }
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ebs_csi_driver_policy" {
  role       = aws_iam_role.ebs_csi_driver.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

resource "aws_iam_role_policy_attachment" "ebs_csi_driver_encryption_policy" {
  role       = aws_iam_role.ebs_csi_driver.name
  policy_arn = aws_iam_policy.ebs_csi_driver_encryption.arn
}

# ---------------------------------------------------------------------------
# Karpenter
# ---------------------------------------------------------------------------

resource "aws_iam_role" "karpenter_node" {
  name = "${var.cluster_name}-karpenter-node"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.${data.aws_partition.current.dns_suffix}"
        }
        Action = [
          "sts:AssumeRole"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "karpenter_node_worker" {
  role       = aws_iam_role.karpenter_node.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "karpenter_node_cni" {
  role       = aws_iam_role.karpenter_node.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "karpenter_node_ecr" {
  role       = aws_iam_role.karpenter_node.name
  policy_arn = local.ecr_read_only_policy_arn
}

resource "aws_iam_role_policy_attachment" "karpenter_node_ssm" {
  role       = aws_iam_role.karpenter_node.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_policy" "karpenter_controller" {
  name = "${var.cluster_name}-karpenter-controller"

  policy = templatefile("${path.module}/iam/KarpenterController.json.tftpl", {
    account_id    = data.aws_caller_identity.current.account_id
    cluster_name  = module.eks.cluster_name
    node_role_arn = aws_iam_role.karpenter_node.arn
    partition     = data.aws_partition.current.partition
    region        = data.aws_region.current.name
    queue_arn     = aws_sqs_queue.karpenter_interruption.arn
  })
}

resource "aws_iam_role" "karpenter_controller" {
  name = "${var.cluster_name}-karpenter-controller"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "pods.eks.amazonaws.com"
        }
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "karpenter_controller_policy" {
  role       = aws_iam_role.karpenter_controller.name
  policy_arn = aws_iam_policy.karpenter_controller.arn
}

# ---------------------------------------------------------------------------
# Managed Argo CD capability
# ---------------------------------------------------------------------------

resource "aws_iam_role" "argocd_capability" {
  count = var.argocd_enable_managed_capability ? 1 : 0

  name = "${var.cluster_name}-argocd-capability"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "capabilities.eks.amazonaws.com"
        }
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "argocd_capability_secrets_manager" {
  count = var.argocd_enable_managed_capability && var.argocd_enable_secrets_manager_access ? 1 : 0

  role       = aws_iam_role.argocd_capability[0].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AWSSecretsManagerClientReadOnlyAccess"
}

