resource "aws_iam_role" "cluster_autoscaler" {
  name = "${aws_eks_cluster.eks_cluster.name}-cluster-autoscaler"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
        Principal = {
          Service = "pods.eks.amazonaws.com"
        }
      }
    ]
  })
}


resource "aws_iam_policy" "cluster_autoscaler" {
  name = "${aws_eks_cluster.eks_cluster.name}-cluster-autoscaler"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances",
          "autoscaling:DescribeLaunchConfigurations",
          "autoscaling:DescribeScalingActivities",
          "autoscaling:DescribeTags",
          "ec2:DescribeImages",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeLaunchTemplateVersions",
          "ec2:GetInstanceTypesFromInstanceRequirements",
          "eks:DescribeNodegroup"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "autoscaling:SetDesiredCapacity",
          "autoscaling:TerminateInstanceInAutoScalingGroup"
        ]
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cluster_autoscaler" {
  policy_arn = aws_iam_policy.cluster_autoscaler.arn
  role       = aws_iam_role.cluster_autoscaler.name
}

resource "aws_eks_pod_identity_association" "cluster_autoscaler" {
  cluster_name    = aws_eks_cluster.eks_cluster.name
  namespace       = "kube-system"
  service_account = "cluster-autoscaler"
  role_arn        = aws_iam_role.cluster_autoscaler.arn
}

resource "helm_release" "cluster_autoscaler" {
  name = "autoscaler"

  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  namespace  = "kube-system"
  create_namespace = false
  version    = "9.54.1"

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

  # MUST be updated to match your region
  values = [
    yamlencode({
      rbac = {
        serviceAccount = {
          name = "cluster-autoscaler"
        }
      }
      autoDiscovery = {
        clusterName = aws_eks_cluster.eks_cluster.name
      }
      awsRegion = var.aws_region
    })
  ]

  depends_on = [helm_release.metrics_server]
}


data "aws_iam_policy_document" "aws_lbc" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }

    actions = [
      "sts:AssumeRole",
      "sts:TagSession"
    ]
  }
}

resource "aws_iam_role" "aws_lbc" {
  name               = "${aws_eks_cluster.eks_cluster.name}-aws-lbc"
  assume_role_policy = data.aws_iam_policy_document.aws_lbc.json
}

resource "aws_iam_policy" "aws_lbc" {
  policy = file("./iam/AWSLoadBalancerController.json")
  name   = "AWSLoadBalancerController"
}

resource "aws_iam_role_policy_attachment" "aws_lbc" {
  policy_arn = aws_iam_policy.aws_lbc.arn
  role       = aws_iam_role.aws_lbc.name
}

resource "aws_eks_pod_identity_association" "aws_lbc" {
  cluster_name    = aws_eks_cluster.eks_cluster.name
  namespace       = "kube-system"
  service_account = "aws-load-balancer-controller"
  role_arn        = aws_iam_role.aws_lbc.arn
}

resource "helm_release" "aws_lbc" {
  name = "aws-load-balancer-controller"

  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  create_namespace = false
  version    = "1.17.0"

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
      clusterName = aws_eks_cluster.eks_cluster.name
      serviceAccount = {
        name = "aws-load-balancer-controller"
      }
      vpcId = aws_vpc.main.id
    })
  ]

  depends_on = [helm_release.cluster_autoscaler]
}