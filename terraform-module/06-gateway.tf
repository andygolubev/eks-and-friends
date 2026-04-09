# ---------------------------------------------------------------------------
# Gateway API CRDs
# ---------------------------------------------------------------------------

data "http" "gateway_api_standard_install" {
  url = "https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.5.0/standard-install.yaml"
}

data "http" "aws_lbc_gateway_crds" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.17.0/config/crd/gateway/gateway-crds.yaml"
}

locals {
  gateway_api_documents = [
    for doc in split("\n---\n", data.http.gateway_api_standard_install.response_body) : try(yamldecode(doc), null)
  ]

  gateway_api_crd_manifests = {
    for doc in local.gateway_api_documents : doc.metadata.name => doc
    if doc != null && try(doc.kind, "") == "CustomResourceDefinition"
  }

  aws_lbc_gateway_documents = [
    for doc in split("\n---\n", data.http.aws_lbc_gateway_crds.response_body) : try(yamldecode(doc), null)
  ]

  aws_lbc_gateway_crd_manifests = {
    for doc in local.aws_lbc_gateway_documents : doc.metadata.name => doc
    if doc != null && try(doc.kind, "") == "CustomResourceDefinition"
  }
}

resource "kubernetes_manifest" "gateway_api_crds" {
  for_each = local.gateway_api_crd_manifests
  manifest = {
    for key, value in each.value : key => value
    if key != "status"
  }

  depends_on = [helm_release.aws_lbc]
}

resource "kubernetes_manifest" "aws_lbc_gateway_crds" {
  for_each = local.aws_lbc_gateway_crd_manifests
  manifest = {
    for key, value in each.value : key => value
    if key != "status"
  }

  depends_on = [helm_release.aws_lbc]
}

# ---------------------------------------------------------------------------
# Gateway bootstrap chart — GatewayClass + Gateway
# ---------------------------------------------------------------------------

resource "helm_release" "gateway_bootstrap" {
  name             = "gateway-bootstrap"
  chart            = "${path.module}/charts/gateway-bootstrap"
  namespace        = var.argocd_namespace
  create_namespace = true

  timeout = 300
  wait    = false

  values = [
    yamlencode({
      gatewayClass = {
        name           = "aws-alb"
        controllerName = "gateway.k8s.aws/alb"
      }
      gateway = {
        name            = "argocd-gateway"
        certificateArns = [aws_acm_certificate_validation.frontend.certificate_arn]
      }
    })
  ]

  depends_on = [
    kubernetes_manifest.gateway_api_crds,
    kubernetes_manifest.aws_lbc_gateway_crds,
  ]
}
