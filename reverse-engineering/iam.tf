resource "aws_iam_role" "eks_cluster" {
  name               = "guru-eks-U1solEVW-cluster-20251231122500371400000001"
  assume_role_policy = "{\"Statement\":[{\"Action\":[\"sts:TagSession\",\"sts:AssumeRole\"],\"Effect\":\"Allow\",\"Principal\":{\"Service\":\"eks.amazonaws.com\"},\"Sid\":\"EKSClusterAssumeRole\"}],\"Version\":\"2012-10-17\"}"

  force_detach_policies = true
  max_session_duration  = 3600
  path                  = "/"
}

resource "aws_iam_policy" "eks_cluster_custom" {
  name        = "guru-eks-U1solEVW-cluster-20251231122500373100000004"
  description = ""
  path        = "/"

  policy = file("${path.module}/policies/cluster_custom.json")
}

resource "aws_iam_policy" "eks_cluster_encryption" {
  name        = "guru-eks-U1solEVW-cluster-ClusterEncryption20251231122527474500000013"
  description = "Cluster encryption policy to allow cluster role to utilize CMK provided"
  path        = "/"

  policy = file("${path.module}/policies/cluster_encryption.json")
}

resource "aws_iam_role_policy_attachment" "eks_cluster_AmazonEKSClusterPolicy" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy_attachment" "eks_cluster_AmazonEKSVPCResourceController" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
}

resource "aws_iam_role_policy_attachment" "eks_cluster_custom" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = aws_iam_policy.eks_cluster_custom.arn
}

resource "aws_iam_role_policy_attachment" "eks_cluster_encryption" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = aws_iam_policy.eks_cluster_encryption.arn
}

resource "aws_iam_role" "node_group_1" {
  name               = "node-group-1-eks-node-group-20251231122500372900000003"
  assume_role_policy = "{\"Statement\":[{\"Action\":\"sts:AssumeRole\",\"Effect\":\"Allow\",\"Principal\":{\"Service\":\"ec2.amazonaws.com\"},\"Sid\":\"EKSNodeAssumeRole\"}],\"Version\":\"2012-10-17\"}"
  force_detach_policies = true
  max_session_duration  = 3600
  path                  = "/"
}

resource "aws_iam_role_policy_attachment" "node_group_1_AmazonEC2ContainerRegistryReadOnly" {
  role       = aws_iam_role.node_group_1.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "node_group_1_AmazonEKSWorkerNodePolicy" {
  role       = aws_iam_role.node_group_1.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "node_group_1_AmazonEKS_CNI_Policy" {
  role       = aws_iam_role.node_group_1.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role" "node_group_2" {
  name               = "node-group-2-eks-node-group-20251231122500372400000002"
  assume_role_policy = "{\"Statement\":[{\"Action\":\"sts:AssumeRole\",\"Effect\":\"Allow\",\"Principal\":{\"Service\":\"ec2.amazonaws.com\"},\"Sid\":\"EKSNodeAssumeRole\"}],\"Version\":\"2012-10-17\"}"
  force_detach_policies = true
  max_session_duration  = 3600
  path                  = "/"
}

resource "aws_iam_role_policy_attachment" "node_group_2_AmazonEC2ContainerRegistryReadOnly" {
  role       = aws_iam_role.node_group_2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "node_group_2_AmazonEKSWorkerNodePolicy" {
  role       = aws_iam_role.node_group_2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "node_group_2_AmazonEKS_CNI_Policy" {
  role       = aws_iam_role.node_group_2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

