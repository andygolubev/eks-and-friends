# ---------------------------------------------------------------------------
# Gateway API CRDs — installed via kubectl after cluster is ready
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
# Gateway bootstrap — GatewayClass + Gateway (includes ArgoCD cert for TLS)
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
        name = "argocd-gateway"
        certificateArns = [
          aws_acm_certificate_validation.frontend.certificate_arn,
          aws_acm_certificate_validation.argocd.certificate_arn,
        ]
      }
    })
  ]

  depends_on = [
    null_resource.gateway_api_crds,
    null_resource.aws_lbc_gateway_crds,
    aws_acm_certificate_validation.argocd,
  ]
}

# ---------------------------------------------------------------------------
# Wait for Gateway ALB to be provisioned by the LBC
# ---------------------------------------------------------------------------

resource "null_resource" "wait_for_gateway_alb" {
  triggers = {
    cluster_name = module.eks.cluster_name
  }

  provisioner "local-exec" {
    command = <<-EOF
      set -euo pipefail
      for attempt in $(seq 1 40); do
        arn=$(aws resourcegroupstaggingapi get-resources \
          --region "${var.aws_region}" \
          --resource-type-filters "elasticloadbalancing:loadbalancer" \
          --tag-filters \
            Key=elbv2.k8s.aws/cluster,Values=${module.eks.cluster_name} \
            Key=gateway.k8s.aws.alb/resource,Values=LoadBalancer \
            Key=gateway.k8s.aws.alb/stack,Values=argocd/argocd-gateway \
          --query 'ResourceTagMappingList[0].ResourceARN' \
          --output text 2>/dev/null || true)
        if [ -n "$${arn}" ] && [ "$${arn}" != "None" ]; then
          echo "Gateway ALB found: $${arn}"
          exit 0
        fi
        echo "Attempt $${attempt}/40: waiting for Gateway ALB..."
        sleep 15
      done
      echo "Timed out waiting for Gateway ALB" >&2
      exit 1
    EOF
  }

  depends_on = [helm_release.gateway_bootstrap]
}

# ---------------------------------------------------------------------------
# Look up the Gateway ALB (used for Route53 records)
# ---------------------------------------------------------------------------

data "aws_lb" "gateway" {
  tags = {
    "elbv2.k8s.aws/cluster"        = module.eks.cluster_name
    "gateway.k8s.aws.alb/resource" = "LoadBalancer"
    "gateway.k8s.aws.alb/stack"    = "argocd/argocd-gateway"
  }

  depends_on = [null_resource.wait_for_gateway_alb]
}
