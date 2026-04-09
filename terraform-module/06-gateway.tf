# ---------------------------------------------------------------------------
# Gateway API CRDs — installed via kubectl after cluster is ready
# (kubernetes_manifest requires a live API server at plan time, so we use
#  local-exec instead to avoid chicken-and-egg issues on fresh clusters)
# ---------------------------------------------------------------------------

resource "null_resource" "gateway_api_crds" {
  triggers = {
    cluster_name = module.eks.cluster_name
    crd_version  = "v1.5.0"
  }

  provisioner "local-exec" {
    command = <<-EOF
      aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}
      kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.5.0/standard-install.yaml
    EOF
  }

  depends_on = [helm_release.aws_lbc]
}

resource "null_resource" "aws_lbc_gateway_crds" {
  triggers = {
    cluster_name = module.eks.cluster_name
    lbc_version  = "v2.17.0"
  }

  provisioner "local-exec" {
    command = <<-EOF
      aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}
      kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.17.0/config/crd/gateway/gateway-crds.yaml
    EOF
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
    null_resource.gateway_api_crds,
    null_resource.aws_lbc_gateway_crds,
  ]
}
