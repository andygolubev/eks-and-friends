locals {
  ecr_read_only_policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.15"

  name               = var.cluster_name
  kubernetes_version = var.kubernetes_version
  authentication_mode = "API"

  endpoint_public_access       = true
  endpoint_private_access      = false
  endpoint_public_access_cidrs = var.cluster_public_access_cidrs

  enable_irsa                            = true
  enable_cluster_creator_admin_permissions = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  security_group_additional_rules = {
    api_from_vpc = {
      description = "Allow cluster API from VPC"
      protocol    = "tcp"
      from_port   = 443
      to_port     = 443
      type        = "ingress"
      cidr_blocks = [var.vpc_cidr]
    }
  }

  node_security_group_additional_rules = {
    node_to_node_all = {
      description = "Allow node to node"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }
    api_to_nodes = {
      description = "Allow cluster API to nodes"
      protocol    = "tcp"
      from_port   = 1025
      to_port     = 65535
      type        = "ingress"
      cidr_blocks = [var.vpc_cidr]
    }
  }

  access_entries = {
    eks_developer = {
      principal_arn     = aws_iam_user.eks_developer.arn
      kubernetes_groups = ["eks-viewer"]
    }
    eks_admin = {
      principal_arn     = module.eks_admin_role.iam_role_arn
      kubernetes_groups = ["eks-admin"]
    }
  }

  addons = {
    "eks-pod-identity-agent" = {
      addon_version = "v1.3.10-eksbuild.2"
    }
    "aws-ebs-csi-driver" = {
      addon_version = "v1.54.0-eksbuild.1"
    }
    "vpc-cni" = {
      most_recent    = true
      before_compute = true
    }
    "coredns" = {
      most_recent    = true
      before_compute = true
    }
    "kube-proxy" = {
      most_recent    = true
      before_compute = true
    }
  }

  eks_managed_node_groups = {
    main_arm64 = {
      name           = "group-main-arm64"
      ami_type       = var.node_group_arch_and_instance_types.arm_64.ami_type
      instance_types = var.node_group_arch_and_instance_types.arm_64.instance_types
      capacity_type  = "ON_DEMAND"

      min_size     = var.node_min_size
      max_size     = var.node_max_size
      desired_size = var.node_desired_size

      update_config = {
        max_unavailable = 1
      }

      labels = {
        role = "main"
        arch = "arm64"
      }

      iam_role_attach_cni_policy = true
      iam_role_additional_policies = {
        ecr_read_only = local.ecr_read_only_policy_arn
      }

      tags = {
        Name = "eks-node-group-main-arm64"
      }
    }
    secondary_amd64 = {
      name           = "group-secondary-amd64"
      ami_type       = var.node_group_arch_and_instance_types.x86_64.ami_type
      instance_types = var.node_group_arch_and_instance_types.x86_64.instance_types
      capacity_type  = "ON_DEMAND"

      min_size     = var.node_min_size
      max_size     = var.node_max_size
      desired_size = var.node_desired_size

      update_config = {
        max_unavailable = 1
      }

      labels = {
        role = "secondary"
        arch = "amd64"
      }

      iam_role_attach_cni_policy = true
      iam_role_additional_policies = {
        ecr_read_only = local.ecr_read_only_policy_arn
      }

      tags = {
        Name = "eks-node-group-secondary-amd64"
      }
    }
  }
}
