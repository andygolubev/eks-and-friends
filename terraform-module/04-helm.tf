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
