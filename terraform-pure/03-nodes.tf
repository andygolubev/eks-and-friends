resource "aws_iam_role" "eks_node_role" {
  name = "eks-node-role-${var.cluster_name}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = ["sts:AssumeRole"]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "eks_ec2_container_registry_read_only" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_eks_node_group" "eks_node_group_main_arm64" {
  cluster_name    = aws_eks_cluster.eks_cluster.name
  version         = var.kubernetes_version
  node_group_name = "group-main-arm64"

  node_role_arn  = aws_iam_role.eks_node_role.arn
  subnet_ids     = values(aws_subnet.private)[*].id
  capacity_type  = "ON_DEMAND"
  ami_type       = var.node_group_arch_and_instance_types.arm_64.ami_type
  instance_types = var.node_group_arch_and_instance_types.arm_64.instance_types

  scaling_config {
    desired_size = var.node_desired_size
    max_size     = var.node_max_size
    min_size     = var.node_min_size
  }

  update_config {
    max_unavailable = 1
  }

  labels = {
    role = "main"
    arch = "arm64"
  }

  tags = {
    Name = "eks-node-group-main-arm64"
  }

  lifecycle {
    ignore_changes = [
      scaling_config[0].desired_size
    ]
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_ec2_container_registry_read_only,
  ]

}

resource "aws_eks_node_group" "eks_node_group_secondary_amd64" {
  cluster_name    = aws_eks_cluster.eks_cluster.name
  version         = var.kubernetes_version
  node_group_name = "group-secondary-amd64"

  node_role_arn  = aws_iam_role.eks_node_role.arn
  subnet_ids     = values(aws_subnet.private)[*].id
  capacity_type  = "ON_DEMAND"
  ami_type       = var.node_group_arch_and_instance_types.x86_64.ami_type
  instance_types = var.node_group_arch_and_instance_types.x86_64.instance_types

  scaling_config {
    desired_size = var.node_desired_size
    max_size     = var.node_max_size
    min_size     = var.node_min_size
  }

  update_config {
    max_unavailable = 1
  }

  labels = {
    role = "secondary"
    arch = "amd64"
  }

  tags = {
    Name = "eks-node-group-secondary-amd64"
  }

  lifecycle {
    ignore_changes = [
      scaling_config[0].desired_size
    ]
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_ec2_container_registry_read_only,
  ]

}