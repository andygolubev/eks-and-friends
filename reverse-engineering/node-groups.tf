resource "aws_launch_template" "node_group_1" {
  name        = "one-20251231123648874100000015"
  description = "Custom launch template for node-group-1 EKS managed node group"

  update_default_version = true

  vpc_security_group_ids = [aws_security_group.eks_node_shared.id]

  metadata_options {
    http_endpoint               = "enabled"
    http_put_response_hop_limit = 2
    http_tokens                 = "required"
  }

  monitoring {
    enabled = true
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "node-group-1"
    }
  }

  tag_specifications {
    resource_type = "network-interface"
    tags = {
      Name = "node-group-1"
    }
  }

  tag_specifications {
    resource_type = "volume"
    tags = {
      Name = "node-group-1"
    }
  }
}

resource "aws_launch_template" "node_group_2" {
  name        = "two-20251231123648874200000016"
  description = "Custom launch template for node-group-2 EKS managed node group"

  update_default_version = true

  vpc_security_group_ids = [aws_security_group.eks_node_shared.id]

  metadata_options {
    http_endpoint               = "enabled"
    http_put_response_hop_limit = 2
    http_tokens                 = "required"
  }

  monitoring {
    enabled = true
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "node-group-2"
    }
  }

  tag_specifications {
    resource_type = "network-interface"
    tags = {
      Name = "node-group-2"
    }
  }

  tag_specifications {
    resource_type = "volume"
    tags = {
      Name = "node-group-2"
    }
  }
}

resource "aws_eks_node_group" "one" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "node-group-1-2025123112365627460000001b"
  node_role_arn   = aws_iam_role.node_group_1.arn

  subnet_ids = [
    aws_subnet.private_us_east_1a.id,
    aws_subnet.private_us_east_1b.id,
    aws_subnet.private_us_east_1c.id,
  ]

  ami_type       = "AL2023_x86_64_STANDARD"
  capacity_type  = "ON_DEMAND"
  instance_types = ["t3.small"]
  version        = "1.32"

  scaling_config {
    min_size     = 1
    max_size     = 3
    desired_size = 2
  }

  update_config {
    max_unavailable_percentage = 33
  }

  launch_template {
    id      = aws_launch_template.node_group_1.id
    version = "1"
  }

  tags = {
    Name = "node-group-1"
  }
}

resource "aws_eks_node_group" "two" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "node-group-2-20251231123656274600000019"
  node_role_arn   = aws_iam_role.node_group_2.arn

  subnet_ids = [
    aws_subnet.private_us_east_1a.id,
    aws_subnet.private_us_east_1b.id,
    aws_subnet.private_us_east_1c.id,
  ]

  ami_type       = "AL2023_x86_64_STANDARD"
  capacity_type  = "ON_DEMAND"
  instance_types = ["t3.small"]
  version        = "1.32"

  scaling_config {
    min_size     = 1
    max_size     = 2
    desired_size = 1
  }

  update_config {
    max_unavailable_percentage = 33
  }

  launch_template {
    id      = aws_launch_template.node_group_2.id
    version = "1"
  }

  tags = {
    Name = "node-group-2"
  }
}

