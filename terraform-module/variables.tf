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
  description = "EKS cluster name (suffix will be added for uniqueness)"
  type        = string
  default     = "eks-demo"
}

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS control plane"
  type        = string
  default     = "1.35"
}

variable "vpc_cidr" {
  description = "CIDR range for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "cluster_public_access_cidrs" {
  description = "CIDR blocks that can access the EKS public endpoint (tighten for best security)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "node_min_size" {
  description = "Minimum number of nodes in the managed node group"
  type        = number
  default     = 1
}

variable "node_desired_size" {
  description = "Desired number of nodes in the managed node group"
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Maximum number of nodes in the managed node group"
  type        = number
  default     = 3
}

variable "argocd_domain" {
  description = "Domain name for ArgoCD server"
  type        = string
  default     = "argocd.064083568243.realhandsonlabs.net"
}

variable "argocd_hosted_zone_name" {
  description = "Route 53 hosted zone name used for ArgoCD DNS validation and alias record"
  type        = string
  default     = "064083568243.realhandsonlabs.net"
}

variable "frontend_domain" {
  description = "Domain name for frontend ingress"
  type        = string
  default     = "front.064083568243.realhandsonlabs.net"
}

variable "frontend_hosted_zone_name" {
  description = "Route 53 hosted zone name used for frontend DNS validation"
  type        = string
  default     = "064083568243.realhandsonlabs.net"
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
