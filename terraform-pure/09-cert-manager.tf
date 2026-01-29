resource "helm_release" "cert_manager" {
  name = "cert-manager"

  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  namespace        = "cert-manager"
  create_namespace = true
  version          = "v1.19.2"

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

  values = [
    yamlencode({
      installCRDs = true
    })
  ]

  depends_on = [helm_release.aws_lbc]
}