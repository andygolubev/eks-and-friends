resource "helm_release" "metrics_server" {
  name = "metrics-server"

  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  namespace  = "kube-system"
  version    = "3.13.0"

  atomic                     = false
  cleanup_on_fail            = false
  dependency_update          = false
  disable_crd_hooks          = false
  disable_openapi_validation = false
  disable_webhooks           = false
  force_update               = false
  lint                       = false
  max_history                = 0
  pass_credentials           = false
  recreate_pods              = false
  render_subchart_notes      = true
  replace                    = false
  reset_values               = false
  reuse_values               = false
  skip_crds                  = false
  take_ownership             = false
  timeout                    = 300
  upgrade_install            = false
  verify                     = false
  wait                       = true
  wait_for_jobs              = false

  values = [file("${path.module}/values/metrics-server.yaml")]

  depends_on = [aws_eks_node_group.eks_node_group_main_arm64]
}