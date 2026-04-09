data "aws_ssoadmin_instances" "current" {}

locals {
  argocd_identity_center_instance_arn = coalesce(
    var.argocd_identity_center_instance_arn,
    try(data.aws_ssoadmin_instances.current.arns[0], null)
  )

  argocd_identity_center_region = coalesce(
    var.argocd_identity_center_region,
    var.aws_region
  )

  argocd_rbac_role_mappings = concat(
    length(var.argocd_admin_group_ids) > 0 ? [
      {
        role = "ADMIN"
        identities = [
          for group_id in var.argocd_admin_group_ids : {
            id   = group_id
            type = "SSO_GROUP"
          }
        ]
      }
    ] : [],
    length(var.argocd_editor_group_ids) > 0 ? [
      {
        role = "EDITOR"
        identities = [
          for group_id in var.argocd_editor_group_ids : {
            id   = group_id
            type = "SSO_GROUP"
          }
        ]
      }
    ] : [],
    length(var.argocd_viewer_group_ids) > 0 ? [
      {
        role = "VIEWER"
        identities = [
          for group_id in var.argocd_viewer_group_ids : {
            id   = group_id
            type = "SSO_GROUP"
          }
        ]
      }
    ] : []
  )
}

resource "aws_eks_capability" "argocd" {
  count = var.argocd_enable_managed_capability ? 1 : 0

  cluster_name    = module.eks.cluster_name
  capability_name = var.argocd_capability_name
  type            = "ARGOCD"
  role_arn        = aws_iam_role.argocd_capability[0].arn

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
            for_each = rbac_role_mapping.value.identities
            content {
              id   = identity.value.id
              type = identity.value.type
            }
          }
        }
      }
    }
  }

  lifecycle {
    precondition {
      condition     = local.argocd_identity_center_instance_arn != null
      error_message = "Managed Argo CD requires an AWS Identity Center instance ARN. Set argocd_identity_center_instance_arn or ensure one is discoverable via aws_ssoadmin_instances."
    }
  }

  depends_on = [module.eks]
}

resource "kubernetes_secret_v1" "argocd_local_cluster" {
  count = var.argocd_enable_managed_capability ? 1 : 0

  metadata {
    name      = "in-cluster"
    namespace = var.argocd_namespace
    labels = {
      "argocd.argoproj.io/secret-type" = "cluster"
    }
  }

  data = {
    name    = "in-cluster"
    project = "default"
    server  = module.eks.cluster_arn
  }

  type = "Opaque"

  depends_on = [aws_eks_capability.argocd]
}
