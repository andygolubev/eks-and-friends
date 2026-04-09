provider "helm" {
  repository_cache = "${path.module}/.terraform-helm-repository-cache"

  kubernetes = {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

# ---------------------------------------------------------------------------
# AWS Load Balancer Controller
# ---------------------------------------------------------------------------

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
      controllerConfig = {
        featureGates = {
          ALBGatewayAPI = true
        }
      }
    })
  ]

  depends_on = [aws_eks_pod_identity_association.aws_lbc]
}

# ---------------------------------------------------------------------------
# ACM certificate — Frontend
# ---------------------------------------------------------------------------

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

data "aws_route53_zone" "frontend" {
  name         = var.frontend_hosted_zone_name
  private_zone = false
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

# ---------------------------------------------------------------------------
# gp3 StorageClass — EBS gp3 default class (applied via kubectl)
# ---------------------------------------------------------------------------

resource "null_resource" "gp3_storage_class" {
  triggers = {
    cluster_name = module.eks.cluster_name
  }

  provisioner "local-exec" {
    command = <<-EOF
      aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}
      kubectl apply -f - <<YAML
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp3
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: ebs.csi.aws.com
reclaimPolicy: Retain
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
parameters:
  type: gp3
  encrypted: "true"
YAML
    EOF
  }

  depends_on = [helm_release.aws_lbc]
}
