data "aws_eks_cluster_auth" "eks" {
  name = module.eks.cluster_name

  depends_on = [module.eks]
}

provider "helm" {
  kubernetes = {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.eks.token
  }
}

resource "helm_release" "metrics_server" {
  name = "metrics-server"

  repository       = "https://kubernetes-sigs.github.io/metrics-server/"
  chart            = "metrics-server"
  namespace        = "kube-system"
  create_namespace = false
  version          = "3.13.0"

  timeout = 300
  wait    = true

  values = [
    yamlencode({
      defaultArgs = [
        "--cert-dir=/tmp",
        "--kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname",
        "--kubelet-use-node-status-port",
        "--metric-resolution=15s",
        "--secure-port=10250"
      ]
    })
  ]

  depends_on = [module.eks]
}

resource "helm_release" "cluster_autoscaler" {
  name = "autoscaler"

  repository       = "https://kubernetes.github.io/autoscaler"
  chart            = "cluster-autoscaler"
  namespace        = "kube-system"
  create_namespace = false
  version          = "9.54.1"

  timeout = 300
  wait    = true

  values = [
    yamlencode({
      rbac = {
        serviceAccount = {
          name = "cluster-autoscaler"
        }
      }
      autoDiscovery = {
        clusterName = module.eks.cluster_name
      }
      awsRegion = var.aws_region
    })
  ]

  depends_on = [helm_release.metrics_server]
}

resource "helm_release" "aws_lbc" {
  name = "aws-load-balancer-controller"

  repository       = "https://aws.github.io/eks-charts"
  chart            = "aws-load-balancer-controller"
  namespace        = "kube-system"
  create_namespace = false
  version          = "1.17.0"

  timeout = 300
  wait    = true

  values = [
    yamlencode({
      clusterName = module.eks.cluster_name
      serviceAccount = {
        name = "aws-load-balancer-controller"
      }
      vpcId = module.vpc.vpc_id
    })
  ]

  depends_on = [helm_release.cluster_autoscaler]
}

resource "helm_release" "cert_manager" {
  name = "cert-manager"

  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  namespace        = "cert-manager"
  create_namespace = true
  version          = "v1.19.2"

  timeout = 300
  wait    = true

  values = [
    yamlencode({
      installCRDs = true
    })
  ]

  depends_on = [helm_release.aws_lbc]
}

# ---------------------------------------------------------------------------
# ArgoCD
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

resource "aws_acm_certificate" "frontend" {
  domain_name       = var.frontend_domain
  validation_method = "DNS"

  tags = {
    Name = var.frontend_domain
  }

  lifecycle {
    create_before_destroy = true
  }
}

data "aws_route53_zone" "argocd" {
  name         = var.argocd_hosted_zone_name
  private_zone = false
}

data "aws_route53_zone" "frontend" {
  name         = var.frontend_hosted_zone_name
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

resource "aws_route53_record" "frontend_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.frontend.domain_validation_options : dvo.domain_name => {
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
  zone_id         = data.aws_route53_zone.frontend.zone_id
}

resource "aws_acm_certificate_validation" "frontend" {
  certificate_arn         = aws_acm_certificate.frontend.arn
  validation_record_fqdns = [for record in aws_route53_record.frontend_cert_validation : record.fqdn]
}

resource "helm_release" "argocd" {
  name = "argocd"

  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true
  version          = "9.4.1"

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
            "alb.ingress.kubernetes.io/scheme"         = "internet-facing"
            "alb.ingress.kubernetes.io/target-type"     = "ip"
            "alb.ingress.kubernetes.io/certificate-arn" = aws_acm_certificate_validation.argocd.certificate_arn
            "alb.ingress.kubernetes.io/listen-ports"    = jsonencode([{ "HTTPS" = 443 }, { "HTTP" = 80 }])
            "alb.ingress.kubernetes.io/ssl-redirect"    = "443"
          }
          hostname = var.argocd_domain
          aws = {
            backendProtocolVersion = "GRPC"
            serviceType            = "ClusterIP"
          }
        }
      }
    })
  ]

  depends_on = [helm_release.cert_manager]
}

# Look up the ALB created by the AWS Load Balancer Controller for ArgoCD ingress
data "aws_lb" "argocd" {
  tags = {
    "elbv2.k8s.aws/cluster"    = module.eks.cluster_name
    "ingress.k8s.aws/resource" = "LoadBalancer"
    "ingress.k8s.aws/stack"    = "argocd/argocd-server"
  }

  depends_on = [helm_release.argocd]
}

# Create Route 53 alias record pointing to the ALB
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
