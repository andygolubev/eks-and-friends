data "aws_ssoadmin_instances" "current" {}

locals {
  argocd_identity_center_instance_arn = coalesce(
    var.argocd_identity_center_instance_arn,
    try(data.aws_ssoadmin_instances.current.arns[0], null)
  )
  argocd_identity_center_region = coalesce(var.argocd_identity_center_region, var.aws_region)
  argocd_rbac_role_mappings = concat(
    length(var.argocd_admin_group_ids) > 0 ? [{ role = "ADMIN", ids = var.argocd_admin_group_ids }] : [],
    length(var.argocd_editor_group_ids) > 0 ? [{ role = "EDITOR", ids = var.argocd_editor_group_ids }] : [],
    length(var.argocd_viewer_group_ids) > 0 ? [{ role = "VIEWER", ids = var.argocd_viewer_group_ids }] : []
  )
}

resource "aws_eks_capability" "argocd" {
  cluster_name              = module.eks.cluster_name
  capability_name           = var.argocd_capability_name
  type                      = "ARGOCD"
  role_arn                  = aws_iam_role.argocd_capability.arn
  delete_propagation_policy = "RETAIN"

  configuration {
    argo_cd {
      namespace = var.argocd_namespace
      aws_idc {
        idc_instance_arn = local.argocd_identity_center_instance_arn
        idc_region       = local.argocd_identity_center_region
      }
      dynamic "rbac_role_mapping" {
        for_each = local.argocd_rbac_role_mappings
        content {
          role = rbac_role_mapping.value.role
          dynamic "identity" {
            for_each = rbac_role_mapping.value.ids
            content {
              id   = identity.value
              type = "SSO_GROUP"
            }
          }
        }
      }
    }
  }

  lifecycle {
    precondition {
      condition     = local.argocd_identity_center_instance_arn != null
      error_message = "Managed Argo CD requires an IAM Identity Center instance ARN."
    }
  }
}

resource "aws_eks_access_policy_association" "argocd_cluster_admin" {
  cluster_name  = module.eks.cluster_name
  principal_arn = aws_iam_role.argocd_capability.arn
  policy_arn    = "arn:${data.aws_partition.current.partition}:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  access_scope { type = "cluster" }
  depends_on = [aws_eks_capability.argocd]
}

# EKS Managed Argo CD runs outside the cluster and cannot use the usual
# in-cluster Kubernetes service destination. Register this EKS cluster
# explicitly using its ARN, then target it by its Argo CD cluster name so
# Application manifests do not embed the AWS account-specific ARN.
resource "kubernetes_secret_v1" "argocd_local_cluster" {
  metadata {
    name      = "in-cluster"
    namespace = var.argocd_namespace
    labels = {
      "argocd.argoproj.io/secret-type" = "cluster"
    }
  }

  data = {
    name    = "in-cluster"
    server  = module.eks.cluster_arn
    project = "default"
  }

  type = "Opaque"

  depends_on = [
    aws_eks_capability.argocd,
    aws_eks_access_policy_association.argocd_cluster_admin,
  ]
}

resource "null_resource" "argocd_gitops_bootstrap" {
  triggers = {
    cluster_name = module.eks.cluster_name
    repo_url     = var.argocd_gitops_repo_url
    revision     = var.argocd_gitops_target_revision
    source_path  = var.argocd_gitops_source_path
  }

  provisioner "local-exec" {
    command = <<-EOF
      set -euo pipefail
      aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}
      for attempt in $(seq 1 60); do
        kubectl get crd applications.argoproj.io >/dev/null 2>&1 && break
        sleep 10
      done
      kubectl apply -f - <<'YAML'
      apiVersion: argoproj.io/v1alpha1
      kind: Application
      metadata:
        name: root
        namespace: ${var.argocd_namespace}
        finalizers:
          - resources-finalizer.argocd.argoproj.io
      spec:
        project: default
        source:
          repoURL: ${var.argocd_gitops_repo_url}
          targetRevision: ${var.argocd_gitops_target_revision}
          path: ${var.argocd_gitops_source_path}
        destination:
          name: in-cluster
          namespace: ${var.argocd_namespace}
        syncPolicy:
          automated:
            prune: true
            selfHeal: true
      YAML
    EOF
  }

  depends_on = [kubernetes_secret_v1.argocd_local_cluster]
}
