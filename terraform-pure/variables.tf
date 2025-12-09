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
  default     = "1.34"
}

variable "vpc_cidr" {
  description = "CIDR range for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "cluster_public_access_cidrs" {
  description = "CIDR blocks that can access the EKS public endpoint (tighten for best security)"
  type        = list(string)
  default     = []
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

variable "node_instance_types" {
  description = "EC2 instance types for the managed node group"
  type        = list(string)
  default     = ["t3.medium"]
}