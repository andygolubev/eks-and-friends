resource "aws_security_group" "eks_cluster" {
  name        = "guru-eks-U1solEVW-cluster-20251231122516327200000011"
  description = "EKS cluster security group"
  vpc_id      = aws_vpc.this.id

  tags = {
    Name = "guru-eks-U1solEVW-cluster"
  }
}

resource "aws_security_group" "eks_node_shared" {
  name        = "guru-eks-U1solEVW-node-20251231122516109000000010"
  description = "EKS node shared security group"
  vpc_id      = aws_vpc.this.id

  tags = {
    Name                                     = "guru-eks-U1solEVW-node"
    "kubernetes.io/cluster/${local.cluster_name}" = "owned"
  }
}

resource "aws_security_group_rule" "cluster_ingress_nodes_443" {
  type                     = "ingress"
  description              = "Node groups to cluster API"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_cluster.id
  source_security_group_id = aws_security_group.eks_node_shared.id
}

resource "aws_security_group_rule" "node_egress_all" {
  type              = "egress"
  description       = "Allow all egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.eks_node_shared.id
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "node_ingress_cluster_443" {
  type                     = "ingress"
  description              = "Cluster API to node groups"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_node_shared.id
  source_security_group_id = aws_security_group.eks_cluster.id
}

resource "aws_security_group_rule" "node_ingress_cluster_4443_webhook" {
  type                     = "ingress"
  description              = "Cluster API to node 4443/tcp webhook"
  from_port                = 4443
  to_port                  = 4443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_node_shared.id
  source_security_group_id = aws_security_group.eks_cluster.id
}

resource "aws_security_group_rule" "node_ingress_cluster_6443_webhook" {
  type                     = "ingress"
  description              = "Cluster API to node 6443/tcp webhook"
  from_port                = 6443
  to_port                  = 6443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_node_shared.id
  source_security_group_id = aws_security_group.eks_cluster.id
}

resource "aws_security_group_rule" "node_ingress_cluster_8443_webhook" {
  type                     = "ingress"
  description              = "Cluster API to node 8443/tcp webhook"
  from_port                = 8443
  to_port                  = 8443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_node_shared.id
  source_security_group_id = aws_security_group.eks_cluster.id
}

resource "aws_security_group_rule" "node_ingress_cluster_9443_webhook" {
  type                     = "ingress"
  description              = "Cluster API to node 9443/tcp webhook"
  from_port                = 9443
  to_port                  = 9443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_node_shared.id
  source_security_group_id = aws_security_group.eks_cluster.id
}

resource "aws_security_group_rule" "node_ingress_cluster_kubelet" {
  type                     = "ingress"
  description              = "Cluster API to node kubelets"
  from_port                = 10250
  to_port                  = 10250
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_node_shared.id
  source_security_group_id = aws_security_group.eks_cluster.id
}

resource "aws_security_group_rule" "node_ingress_nodes_ephemeral" {
  type              = "ingress"
  description       = "Node to node ingress on ephemeral ports"
  from_port         = 1025
  to_port           = 65535
  protocol          = "tcp"
  security_group_id = aws_security_group.eks_node_shared.id
  self              = true
}

resource "aws_security_group_rule" "node_ingress_self_coredns_tcp" {
  type              = "ingress"
  description       = "Node to node CoreDNS"
  from_port         = 53
  to_port           = 53
  protocol          = "tcp"
  security_group_id = aws_security_group.eks_node_shared.id
  self              = true
}

resource "aws_security_group_rule" "node_ingress_self_coredns_udp" {
  type              = "ingress"
  description       = "Node to node CoreDNS UDP"
  from_port         = 53
  to_port           = 53
  protocol          = "udp"
  security_group_id = aws_security_group.eks_node_shared.id
  self              = true
}

