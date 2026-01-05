resource "aws_cloudwatch_log_group" "eks_cluster" {
  name              = "/aws/eks/${local.cluster_name}/cluster"
  retention_in_days = 90

  tags = {
    Name = "/aws/eks/${local.cluster_name}/cluster"
  }
}

resource "aws_eks_cluster" "this" {
  name     = local.cluster_name
  role_arn = aws_iam_role.eks_cluster.arn
  version  = "1.32"

  enabled_cluster_log_types = ["api", "audit", "authenticator"]

  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = false
  }

  vpc_config {
    endpoint_public_access  = true
    endpoint_private_access = true
    public_access_cidrs     = ["0.0.0.0/0"]

    security_group_ids = [aws_security_group.eks_cluster.id]
    subnet_ids = [
      aws_subnet.private_us_east_1a.id,
      aws_subnet.private_us_east_1b.id,
      aws_subnet.private_us_east_1c.id,
    ]
  }

  encryption_config {
    provider {
      key_arn = aws_kms_key.cluster.arn
    }

    resources = ["secrets"]
  }

  kubernetes_network_config {
    ip_family         = "ipv4"
    service_ipv4_cidr = "172.20.0.0/16"
  }

  upgrade_policy {
    support_type = "STANDARD"
  }

  tags = {
    "terraform-aws-modules" = "eks"
  }

  depends_on = [
    aws_cloudwatch_log_group.eks_cluster,
    aws_iam_role_policy_attachment.eks_cluster_AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.eks_cluster_AmazonEKSVPCResourceController,
    aws_iam_role_policy_attachment.eks_cluster_custom,
    aws_iam_role_policy_attachment.eks_cluster_encryption,
  ]
}

resource "aws_iam_openid_connect_provider" "eks" {
  url = "oidc.eks.us-east-1.amazonaws.com/id/6C9403A3377FCCC6BD0EE057059B1A97"

  client_id_list = ["sts.amazonaws.com"]
  thumbprint_list = ["06b25927c42a721631c1efd9431e648fa62e1e39"]

  tags = {
    Name = "${local.cluster_name}-eks-irsa"
  }
}

