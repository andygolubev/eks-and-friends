output "argocd_url" {
  description = "Self-managed Argo CD URL. Null when the managed Amazon EKS capability is enabled."
  value       = var.argocd_enable_managed_capability ? null : "https://${var.argocd_domain}"
}

output "argocd_capability_name" {
  description = "Managed Amazon EKS Argo CD capability name"
  value       = var.argocd_enable_managed_capability ? var.argocd_capability_name : null
}

output "argocd_capability_role_arn" {
  description = "IAM role ARN used by the managed Amazon EKS Argo CD capability"
  value       = try(aws_iam_role.argocd_capability[0].arn, null)
}

output "kubeconfig_command" {
  description = "Command to configure kubectl for the EKS cluster"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = module.eks.cluster_endpoint
}

output "frontend_url" {
  description = "Frontend URL"
  value       = "https://${var.frontend_domain}"
}

output "frontend_certificate_arn" {
  description = "ACM certificate ARN for the frontend ingress"
  value       = aws_acm_certificate_validation.frontend.certificate_arn
}
