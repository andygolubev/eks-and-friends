locals {
  inputs = {
    aws_region         = "us-west-2"
    project            = "eks-demo"
    environment        = "dev"
    cluster_name       = "eks-demo"
    kubernetes_version = "1.36"
    vpc_cidr           = "10.0.0.0/16"

    frontend_domain           = "front.eks-demo-cluster.online"
    frontend_hosted_zone_name = "eks-demo-cluster.online"

    # Populate at least one group before apply, unless your account supplies
    # access through another IAM Identity Center mapping.
    argocd_admin_group_ids = []
  }
}
