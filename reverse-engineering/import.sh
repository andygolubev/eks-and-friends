#!/usr/bin/env bash
set -euo pipefail

# Run from reverse-engineering/

terraform init

# VPC + networking
terraform import aws_vpc.this vpc-01753b8ce9deabbf7
terraform import aws_internet_gateway.this igw-0d5ac7b42f48de15f
terraform import aws_eip.nat eipalloc-0361f147b6fd73c20
terraform import aws_subnet.private_us_east_1a subnet-0cb5274e8c2d5ea8e
terraform import aws_subnet.private_us_east_1b subnet-00a2c929840f7e6e9
terraform import aws_subnet.private_us_east_1c subnet-0659e105cdc82395e
terraform import aws_subnet.public_us_east_1a subnet-01c0640515c98c092
terraform import aws_subnet.public_us_east_1b subnet-099ec92e890969d46
terraform import aws_subnet.public_us_east_1c subnet-08a303bd3053da997
terraform import aws_nat_gateway.this nat-0fbd2c783d19abdf1
terraform import aws_route_table.public rtb-023deb974d4ea0dba
terraform import aws_route_table.private rtb-00db21dd6a8bb2ac4

# Routes: route_table_id_destination
terraform import aws_route.public_internet_gateway rtb-023deb974d4ea0dba_0.0.0.0/0
terraform import aws_route.private_nat_gateway rtb-00db21dd6a8bb2ac4_0.0.0.0/0

# Route table associations
terraform import aws_route_table_association.public_us_east_1a rtbassoc-0c211175abcd905d6
terraform import aws_route_table_association.public_us_east_1b rtbassoc-08abd621468697905
terraform import aws_route_table_association.public_us_east_1c rtbassoc-065fedda23edef5ff
terraform import aws_route_table_association.private_us_east_1a rtbassoc-0769453e2974466f0
terraform import aws_route_table_association.private_us_east_1b rtbassoc-070c894007d514e3b
terraform import aws_route_table_association.private_us_east_1c rtbassoc-0de5b81fba4daee29

# Default VPC resources
terraform import aws_default_network_acl.default acl-07977f305207b3167
terraform import aws_default_route_table.default rtb-02d42449e9123a7bb
terraform import aws_default_security_group.default sg-02032dd4bd90c405e

# KMS
terraform import aws_kms_key.cluster 9e76b81c-5b08-44e6-af93-290bddcca91b
terraform import aws_kms_alias.cluster alias/eks/guru-eks-U1solEVW

# IAM
terraform import aws_iam_role.eks_cluster guru-eks-U1solEVW-cluster-20251231122500371400000001
terraform import aws_iam_policy.eks_cluster_custom arn:aws:iam::766198264464:policy/guru-eks-U1solEVW-cluster-20251231122500373100000004
terraform import aws_iam_policy.eks_cluster_encryption arn:aws:iam::766198264464:policy/guru-eks-U1solEVW-cluster-ClusterEncryption20251231122527474500000013
terraform import aws_iam_role_policy_attachment.eks_cluster_AmazonEKSClusterPolicy guru-eks-U1solEVW-cluster-20251231122500371400000001/arn:aws:iam::aws:policy/AmazonEKSClusterPolicy
terraform import aws_iam_role_policy_attachment.eks_cluster_AmazonEKSVPCResourceController guru-eks-U1solEVW-cluster-20251231122500371400000001/arn:aws:iam::aws:policy/AmazonEKSVPCResourceController
terraform import aws_iam_role_policy_attachment.eks_cluster_custom guru-eks-U1solEVW-cluster-20251231122500371400000001/arn:aws:iam::766198264464:policy/guru-eks-U1solEVW-cluster-20251231122500373100000004
terraform import aws_iam_role_policy_attachment.eks_cluster_encryption guru-eks-U1solEVW-cluster-20251231122500371400000001/arn:aws:iam::766198264464:policy/guru-eks-U1solEVW-cluster-ClusterEncryption20251231122527474500000013

terraform import aws_iam_role.node_group_1 node-group-1-eks-node-group-20251231122500372900000003
terraform import aws_iam_role_policy_attachment.node_group_1_AmazonEC2ContainerRegistryReadOnly node-group-1-eks-node-group-20251231122500372900000003/arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly
terraform import aws_iam_role_policy_attachment.node_group_1_AmazonEKSWorkerNodePolicy node-group-1-eks-node-group-20251231122500372900000003/arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy
terraform import aws_iam_role_policy_attachment.node_group_1_AmazonEKS_CNI_Policy node-group-1-eks-node-group-20251231122500372900000003/arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy

terraform import aws_iam_role.node_group_2 node-group-2-eks-node-group-20251231122500372400000002
terraform import aws_iam_role_policy_attachment.node_group_2_AmazonEC2ContainerRegistryReadOnly node-group-2-eks-node-group-20251231122500372400000002/arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly
terraform import aws_iam_role_policy_attachment.node_group_2_AmazonEKSWorkerNodePolicy node-group-2-eks-node-group-20251231122500372400000002/arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy
terraform import aws_iam_role_policy_attachment.node_group_2_AmazonEKS_CNI_Policy node-group-2-eks-node-group-20251231122500372400000002/arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy

# Security groups + rules
terraform import aws_security_group.eks_cluster sg-0009af5c8354484af
terraform import aws_security_group.eks_node_shared sg-03e429719a9ca322a

# NOTE: aws_security_group_rule import IDs are provider-specific. These are the AWS rule IDs from state.
# If import fails, switch these resources to aws_vpc_security_group_ingress_rule/egress_rule and re-import by sgr-... IDs.
terraform import aws_security_group_rule.cluster_ingress_nodes_443 sgr-0f9194d5c5e0a3ea6
terraform import aws_security_group_rule.node_egress_all sgr-08b9b0d0c1686cc33
terraform import aws_security_group_rule.node_ingress_cluster_443 sgr-05afd9573e2d5ecd8
terraform import aws_security_group_rule.node_ingress_cluster_4443_webhook sgr-09a3e2c88d476babb
terraform import aws_security_group_rule.node_ingress_cluster_6443_webhook sgr-08aa080bf55b2029d
terraform import aws_security_group_rule.node_ingress_cluster_8443_webhook sgr-0cb20af3beffb806a
terraform import aws_security_group_rule.node_ingress_cluster_9443_webhook sgr-014fe55aee138c8b9
terraform import aws_security_group_rule.node_ingress_cluster_kubelet sgr-0768faf7ba0af328d
terraform import aws_security_group_rule.node_ingress_nodes_ephemeral sgr-0fbf64bca646c0cc1
terraform import aws_security_group_rule.node_ingress_self_coredns_tcp sgr-027322ceb1774a426
terraform import aws_security_group_rule.node_ingress_self_coredns_udp sgr-05e75b663cf195715

# EKS
terraform import aws_cloudwatch_log_group.eks_cluster /aws/eks/guru-eks-U1solEVW/cluster
terraform import aws_eks_cluster.this guru-eks-U1solEVW
terraform import aws_iam_openid_connect_provider.eks arn:aws:iam::766198264464:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/6C9403A3377FCCC6BD0EE057059B1A97

# Launch templates + node groups
terraform import aws_launch_template.node_group_1 lt-0b9c808ecf9ed5c1a
terraform import aws_launch_template.node_group_2 lt-09fdc8aa2aba6dbd3
terraform import aws_eks_node_group.one guru-eks-U1solEVW:node-group-1-2025123112365627460000001b
terraform import aws_eks_node_group.two guru-eks-U1solEVW:node-group-2-20251231123656274600000019

echo "Done. Now run: terraform plan"
