# ---------------------------------------------------------------------------
# ACM certificate — ArgoCD domain
# ---------------------------------------------------------------------------

resource "aws_acm_certificate" "argocd" {
  domain_name       = var.argocd_domain
  validation_method = "DNS"

  tags = {
    Name = var.argocd_domain
  }

  lifecycle {
    create_before_destroy = true
  }
}

data "aws_route53_zone" "argocd" {
  name         = var.argocd_hosted_zone_name
  private_zone = false
}

resource "aws_route53_record" "argocd_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.argocd.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.argocd.zone_id
}

resource "aws_acm_certificate_validation" "argocd" {
  certificate_arn         = aws_acm_certificate.argocd.arn
  validation_record_fqdns = [for record in aws_route53_record.argocd_cert_validation : record.fqdn]
}

# ---------------------------------------------------------------------------
# ArgoCD — Helm (no Ingress; exposed via Gateway API HTTPRoute below)
# ---------------------------------------------------------------------------

resource "helm_release" "argocd" {
  name = "argocd"

  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = var.argocd_namespace
  create_namespace = true
  version          = "7.8.23"

  timeout = 600
  wait    = true

  values = [
    yamlencode({
      global = {
        domain = var.argocd_domain
      }
      configs = {
        params = {
          "server.insecure" = true
        }
      }
    })
  ]

  depends_on = [helm_release.gateway_bootstrap]
}

# ---------------------------------------------------------------------------
# TargetGroupConfiguration — IP mode for argocd-server (avoids Instance default)
# ---------------------------------------------------------------------------

resource "null_resource" "argocd_target_group_config" {
  triggers = {
    cluster_name = module.eks.cluster_name
  }

  provisioner "local-exec" {
    command = <<-EOF
      aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}
      kubectl apply -f - <<YAML
apiVersion: gateway.k8s.aws/v1beta1
kind: TargetGroupConfiguration
metadata:
  name: argocd-server-tgc
  namespace: ${var.argocd_namespace}
spec:
  targetReference:
    name: argocd-server
    kind: Service
  defaultConfiguration:
    targetType: ip
    protocol: HTTP
    protocolVersion: HTTP1
    healthCheckConfig:
      healthCheckPath: /healthz
      healthCheckProtocol: HTTP
      healthCheckPort: "8080"
YAML
    EOF
  }

  depends_on = [helm_release.argocd]
}

# ---------------------------------------------------------------------------
# HTTPRoute — route argocd.domain → argocd-server via the shared Gateway
# ---------------------------------------------------------------------------

resource "null_resource" "argocd_httproute" {
  triggers = {
    cluster_name = module.eks.cluster_name
    argocd_domain = var.argocd_domain
  }

  provisioner "local-exec" {
    command = <<-EOF
      aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}
      kubectl apply -f - <<YAML
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: argocd
  namespace: ${var.argocd_namespace}
spec:
  parentRefs:
    - name: argocd-gateway
      namespace: ${var.argocd_namespace}
  hostnames:
    - "${var.argocd_domain}"
  rules:
    - backendRefs:
        - name: argocd-server
          port: 80
YAML
    EOF
  }

  depends_on = [
    helm_release.argocd,
    null_resource.wait_for_gateway_alb,
  ]
}

# ---------------------------------------------------------------------------
# Route53 alias — ArgoCD domain → same Gateway ALB as frontend
# ---------------------------------------------------------------------------

resource "aws_route53_record" "argocd" {
  zone_id = data.aws_route53_zone.argocd.zone_id
  name    = var.argocd_domain
  type    = "A"

  alias {
    name                   = data.aws_lb.gateway.dns_name
    zone_id                = data.aws_lb.gateway.zone_id
    evaluate_target_health = true
  }
}
