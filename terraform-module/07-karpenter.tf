locals {
  default_karpenter_pools = {
    for arch_key, config in var.node_group_arch_and_instance_types :
    "general-${arch_key == "arm_64" ? "arm64" : "amd64"}" => {
      instance_types  = config.instance_types
      kubernetes_arch = arch_key == "arm_64" ? "arm64" : "amd64"
      capacity_types  = ["on-demand"]
      labels          = {}
      taints          = []
      limits          = {}
      weight          = arch_key == "arm_64" ? 100 : 50
    }
  }

  karpenter_pools = {
    for pool_name, pool in(
      var.karpenter_pools == null ? local.default_karpenter_pools : var.karpenter_pools
      ) : pool_name => merge({
        capacity_types = ["on-demand"]
        labels         = {}
        taints         = []
        limits         = {}
        weight         = null
    }, pool)
  }
}

resource "aws_sqs_queue" "karpenter_interruption" {
  name                      = "${var.cluster_name}-karpenter"
  message_retention_seconds = 300
  sqs_managed_sse_enabled   = true
}

resource "aws_sqs_queue_policy" "karpenter_interruption" {
  queue_url = aws_sqs_queue.karpenter_interruption.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = [
            "events.amazonaws.com",
            "sqs.amazonaws.com"
          ]
        }
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.karpenter_interruption.arn
      },
      {
        Sid       = "DenyHTTP"
        Effect    = "Deny"
        Principal = "*"
        Action    = "sqs:*"
        Resource  = aws_sqs_queue.karpenter_interruption.arn
        Condition = {
          Bool = {
            "aws:SecureTransport" = false
          }
        }
      }
    ]
  })
}

resource "aws_cloudwatch_event_rule" "karpenter_scheduled_change" {
  name = "${var.cluster_name}-karpenter-scheduled-change"

  event_pattern = jsonencode({
    source      = ["aws.health"]
    detail-type = ["AWS Health Event"]
  })
}

resource "aws_cloudwatch_event_target" "karpenter_scheduled_change" {
  rule      = aws_cloudwatch_event_rule.karpenter_scheduled_change.name
  target_id = "KarpenterInterruptionQueueTarget"
  arn       = aws_sqs_queue.karpenter_interruption.arn
}

resource "aws_cloudwatch_event_rule" "karpenter_spot_interruption" {
  name = "${var.cluster_name}-karpenter-spot-interruption"

  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Spot Instance Interruption Warning"]
  })
}

resource "aws_cloudwatch_event_target" "karpenter_spot_interruption" {
  rule      = aws_cloudwatch_event_rule.karpenter_spot_interruption.name
  target_id = "KarpenterInterruptionQueueTarget"
  arn       = aws_sqs_queue.karpenter_interruption.arn
}

resource "aws_cloudwatch_event_rule" "karpenter_rebalance" {
  name = "${var.cluster_name}-karpenter-rebalance"

  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Instance Rebalance Recommendation"]
  })
}

resource "aws_cloudwatch_event_target" "karpenter_rebalance" {
  rule      = aws_cloudwatch_event_rule.karpenter_rebalance.name
  target_id = "KarpenterInterruptionQueueTarget"
  arn       = aws_sqs_queue.karpenter_interruption.arn
}

resource "aws_cloudwatch_event_rule" "karpenter_instance_state_change" {
  name = "${var.cluster_name}-karpenter-instance-state-change"

  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Instance State-change Notification"]
  })
}

resource "aws_cloudwatch_event_target" "karpenter_instance_state_change" {
  rule      = aws_cloudwatch_event_rule.karpenter_instance_state_change.name
  target_id = "KarpenterInterruptionQueueTarget"
  arn       = aws_sqs_queue.karpenter_interruption.arn
}

resource "aws_ec2_tag" "karpenter_subnet_discovery" {
  for_each = toset(module.vpc.private_subnets)

  resource_id = each.value
  key         = "karpenter.sh/discovery"
  value       = module.eks.cluster_name
}

resource "aws_ec2_tag" "karpenter_node_security_group_discovery" {
  resource_id = module.eks.node_security_group_id
  key         = "karpenter.sh/discovery"
  value       = module.eks.cluster_name
}

resource "aws_ec2_tag" "karpenter_cluster_security_group_discovery" {
  resource_id = module.eks.cluster_primary_security_group_id
  key         = "karpenter.sh/discovery"
  value       = module.eks.cluster_name
}

resource "helm_release" "karpenter" {
  name = "karpenter"

  repository       = "oci://public.ecr.aws/karpenter"
  chart            = "karpenter"
  namespace        = var.karpenter_namespace
  create_namespace = true
  version          = var.karpenter_chart_version

  timeout = 600
  wait    = true

  values = [
    yamlencode({
      serviceAccount = {
        create = true
        name   = "karpenter"
      }
      settings = {
        clusterName       = module.eks.cluster_name
        clusterEndpoint   = module.eks.cluster_endpoint
        interruptionQueue = aws_sqs_queue.karpenter_interruption.name
      }
      controller = {
        resources = {
          requests = {
            cpu    = "500m"
            memory = "512Mi"
          }
          limits = {
            cpu    = "1"
            memory = "1Gi"
          }
        }
      }
    })
  ]

  depends_on = [
    aws_eks_pod_identity_association.karpenter,
    aws_ec2_tag.karpenter_subnet_discovery,
    aws_ec2_tag.karpenter_node_security_group_discovery,
    aws_ec2_tag.karpenter_cluster_security_group_discovery
  ]
}

resource "helm_release" "karpenter_bootstrap" {
  name             = "karpenter-bootstrap"
  chart            = "${path.module}/charts/karpenter-bootstrap"
  namespace        = var.karpenter_namespace
  create_namespace = false

  timeout = 300
  wait    = false

  values = [
    yamlencode({
      clusterName = module.eks.cluster_name
      nodeRole    = aws_iam_role.karpenter_node.name
      pools       = local.karpenter_pools
    })
  ]

  depends_on = [helm_release.karpenter]
}
