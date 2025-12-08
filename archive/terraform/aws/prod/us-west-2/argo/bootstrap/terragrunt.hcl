terraform {
  source = "../../../../../modules/argo/bootstrap"
}

include "root" {
  path = find_in_parent_folders("root.hcl")
}

dependency "eks" {
  config_path = "../../eks/cluster"
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


