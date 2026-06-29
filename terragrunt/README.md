# Terragrunt EKS example

This deployment uses the same canonical EKS platform as `terraform-module`, with
the VPC isolated as a Terragrunt dependency. State is local to each unit.

1. Confirm the `eks-demo-cluster.online` Route 53 hosted zone and values in
   `common.hcl`.
2. Run `terragrunt run --all plan` from `terragrunt/live`.
3. Run `terragrunt run --all apply` after reviewing the plan. Terragrunt applies
   the VPC before EKS and destroys EKS before the VPC.

The managed EKS Argo CD capability bootstraps the existing applications from
`argocd-apps/apps`; it does not install separate example workloads.
