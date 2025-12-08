terraform {
  source = "../../../../../modules/argo/bootstrap"
}

include "root" {
  path = find_in_parent_folders("root.hcl")
}

dependency "eks" {
  config_path = "../../eks/cluster"

  # Allow planning before EKS is applied by providing mock outputs
  mock_outputs = {
    cluster_name      = "eks"
    cluster_endpoint  = "https://mock-eks-endpoint"
    oidc_provider_arn = "arn:aws:iam::111111111111:oidc-provider/mock"
  }
  mock_outputs_allowed_terraform_commands = ["init", "plan"]
}

inputs = {
  cluster_name       = dependency.eks.outputs.cluster_name
  cluster_endpoint   = dependency.eks.outputs.cluster_endpoint
  oidc_provider_arn  = dependency.eks.outputs.oidc_provider_arn

  namespace     = "argocd"
  repo_url      = "https://github.com/andygolubev/eks-argo-terraform"
  repo_path     = "argocd/app-of-apps"
  repo_revision = "main"
}


