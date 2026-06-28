variable "aws_region" {
  description = "AWS region to deploy resources into"
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Project tag/name"
  type        = string
  default     = "eks-demo"
}

variable "environment" {
  description = "Environment tag/name"
  type        = string
  default     = "dev"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "eks-demo"
}

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS control plane"
  type        = string
  default     = "1.36"
}

variable "vpc_cidr" {
  description = "CIDR range for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "create_vpc" {
  description = "Create the VPC in this stack"
  type        = bool
  default     = true
}

variable "existing_vpc_id" {
  description = "Existing VPC ID when create_vpc is false"
  type        = string
  default     = null
  nullable    = true
}

variable "existing_private_subnet_ids" {
  description = "Existing private subnet IDs when create_vpc is false"
  type        = list(string)
  default     = []
}

variable "cluster_public_access_cidrs" {
  description = "CIDR blocks that can access the EKS public endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# ---------------------------------------------------------------------------
# Node groups
# ---------------------------------------------------------------------------

variable "node_min_size" {
  description = "Minimum number of nodes per managed node group"
  type        = number
  default     = 1
}

variable "node_desired_size" {
  description = "Desired number of nodes per managed node group"
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Maximum number of nodes per managed node group"
  type        = number
  default     = 3
}

variable "node_group_arch_and_instance_types" {
  description = "Managed node group presets keyed by architecture"
  type = map(object({
    ami_type       = string
    instance_types = list(string)
  }))
  default = {
    x86_64 = {
      ami_type       = "BOTTLEROCKET_x86_64"
      instance_types = ["t3.medium"]
    }
    arm_64 = {
      ami_type       = "BOTTLEROCKET_ARM_64"
      instance_types = ["t4g.medium"]
    }
  }
}

# ---------------------------------------------------------------------------
# Karpenter
# ---------------------------------------------------------------------------

variable "karpenter_namespace" {
  description = "Namespace for the Karpenter controller"
  type        = string
  default     = "karpenter"
}

variable "karpenter_chart_version" {
  description = "Karpenter Helm chart version"
  type        = string
  default     = "1.9.0"
}

variable "karpenter_pools" {
  description = "Optional explicit Karpenter NodePool definitions. When null, the module derives one on-demand general pool per architecture from node_group_arch_and_instance_types."
  type = map(object({
    kubernetes_arch = string
    instance_types  = list(string)
    capacity_types  = optional(list(string), ["on-demand"])
    labels          = optional(map(string), {})
    taints = optional(list(object({
      key    = string
      value  = optional(string)
      effect = string
    })), [])
    limits = optional(map(string), {})
    weight = optional(number)
  }))
  default  = null
  nullable = true
}

# ---------------------------------------------------------------------------
# EKS add-ons
# ---------------------------------------------------------------------------

variable "enable_metrics_server" {
  description = "Install Metrics Server as an Amazon EKS add-on"
  type        = bool
  default     = true
}

variable "enable_cert_manager" {
  description = "Install cert-manager as an Amazon EKS community add-on"
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------
# DNS / Certificates
# ---------------------------------------------------------------------------

variable "frontend_domain" {
  description = "Domain name for frontend ingress"
  type        = string
  default     = "front.eks-demo-cluster.online"
}

variable "frontend_hosted_zone_name" {
  description = "Route 53 hosted zone name used for frontend DNS validation"
  type        = string
  default     = "eks-demo-cluster.online"
}

# ---------------------------------------------------------------------------
# ArgoCD (Managed Capability)
# ---------------------------------------------------------------------------

variable "argocd_namespace" {
  description = "Namespace for ArgoCD"
  type        = string
  default     = "argocd"
}

variable "argocd_capability_name" {
  description = "Name of the Amazon EKS Argo CD capability"
  type        = string
  default     = "argocd"
}

variable "argocd_identity_center_instance_arn" {
  description = "IAM Identity Center instance ARN; discovered automatically when null"
  type        = string
  default     = null
  nullable    = true
}

variable "argocd_identity_center_region" {
  description = "IAM Identity Center region; defaults to aws_region"
  type        = string
  default     = null
  nullable    = true
}

variable "argocd_admin_group_ids" {
  description = "IAM Identity Center group IDs granted Argo CD ADMIN access"
  type        = list(string)
  default     = []
}

variable "argocd_editor_group_ids" {
  description = "IAM Identity Center group IDs granted Argo CD EDITOR access"
  type        = list(string)
  default     = []
}

variable "argocd_viewer_group_ids" {
  description = "IAM Identity Center group IDs granted Argo CD VIEWER access"
  type        = list(string)
  default     = []
}

variable "argocd_gitops_repo_url" {
  description = "Repository watched by the Argo CD root Application"
  type        = string
  default     = "https://github.com/andygolubev/eks-and-friends.git"
}

variable "argocd_gitops_target_revision" {
  description = "Git revision watched by the Argo CD root Application"
  type        = string
  default     = "main"
}

variable "argocd_gitops_source_path" {
  description = "Repository path watched by the Argo CD root Application"
  type        = string
  default     = "argocd-apps/apps"
}
