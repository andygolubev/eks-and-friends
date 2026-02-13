output "argocd_url" {
  description = "ArgoCD web UI URL"
  value       = "https://${var.argocd_domain}"
}

output "argocd_password_command" {
  description = "Command to retrieve the ArgoCD admin password"
  value       = "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d"
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
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "argocd_bootstrap_command" {
  description = "Command to deploy the App of Apps"
  value       = "kubectl apply -f https://raw.githubusercontent.com/andygolubev/eks-and-friends/main/argocd-apps/root-app.yaml"
}
