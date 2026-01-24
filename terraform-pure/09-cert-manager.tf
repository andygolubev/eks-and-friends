resource "helm_release" "cert_manager" {
  name = "cert-manager"

  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  namespace        = "cert-manager"
  create_namespace = true
  version          = "v1.19.2"
  values = [
    yamlencode({
      installCRDs = true
    })
  ]

  depends_on = [helm_release.aws_lbc]
}