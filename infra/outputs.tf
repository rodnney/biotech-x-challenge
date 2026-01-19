output "github_actions_role_arn" {
  description = "ARN da IAM Role para GitHub Actions (usar como AWS_ROLE_ARN no GitHub Secrets)"
  value       = aws_iam_role.github_actions_role.arn
}

output "eks_cluster_name" {
  description = "Nome do cluster EKS"
  value       = aws_eks_cluster.main.name
}

output "eks_cluster_endpoint" {
  description = "Endpoint do cluster EKS"
  value       = aws_eks_cluster.main.endpoint
}
