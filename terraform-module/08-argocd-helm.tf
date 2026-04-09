# ---------------------------------------------------------------------------
# ACM certificate — ArgoCD
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
# ArgoCD — Helm chart with ALB ingress
# ---------------------------------------------------------------------------

resource "helm_release" "argocd" {
  name = "argocd"

  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
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

      server = {
        ingress = {
          enabled          = true
          controller       = "aws"
          ingressClassName = "alb"
          annotations = {
            "alb.ingress.kubernetes.io/scheme"          = "internet-facing"
            "alb.ingress.kubernetes.io/target-type"     = "ip"
            "alb.ingress.kubernetes.io/certificate-arn" = aws_acm_certificate_validation.argocd.certificate_arn
            "alb.ingress.kubernetes.io/listen-ports"    = jsonencode([{ "HTTPS" = 443 }, { "HTTP" = 80 }])
            "alb.ingress.kubernetes.io/ssl-redirect"    = "443"
            "alb.ingress.kubernetes.io/backend-protocol-version" = "GRPC"
          }
          hostname = var.argocd_domain
        }
      }
    })
  ]

  depends_on = [helm_release.aws_lbc]
}

# ---------------------------------------------------------------------------
# Route53 alias record — ArgoCD ALB
# ---------------------------------------------------------------------------

data "aws_lb" "argocd" {
  tags = {
    "elbv2.k8s.aws/cluster"    = module.eks.cluster_name
    "ingress.k8s.aws/resource" = "LoadBalancer"
    "ingress.k8s.aws/stack"    = "argocd/argocd-server"
  }

  depends_on = [helm_release.argocd]
}

resource "aws_route53_record" "argocd" {
  zone_id = data.aws_route53_zone.argocd.zone_id
  name    = var.argocd_domain
  type    = "A"

  alias {
    name                   = data.aws_lb.argocd.dns_name
    zone_id                = data.aws_lb.argocd.zone_id
    evaluate_target_health = true
  }
}
