output "argocd_capability_name" {
  description = "Managed Amazon EKS Argo CD capability name"
  value       = aws_eks_capability.argocd.capability_name
}

output "argocd_capability_arn" {
  description = "Managed Amazon EKS Argo CD capability ARN"
  value       = aws_eks_capability.argocd.arn
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
