# Terragrunt EKS example

This deployment uses the same canonical EKS platform as `terraform-module`, with
the VPC isolated as a Terragrunt dependency. State is local to each unit.

1. Confirm the `eks-demo-cluster.online` Route 53 hosted zone is available and
   add IAM Identity Center group IDs in `common.hcl`.
2. Run `terragrunt run --all plan` from `terragrunt/live`.
3. Run `terragrunt run --all apply` after reviewing the plan.

The managed EKS Argo CD capability bootstraps the existing applications from
`argocd-apps/apps`; it does not install separate example workloads.
