output "github_actions_role_arn" {
  description = "ARN da IAM Role para GitHub Actions (usar como AWS_ROLE_ARN no GitHub Secrets)"
  value       = aws_iam_role.github_actions_role.arn
}

output "ecr_repository_backend" {
  description = "Nome do repositório ECR do backend"
  value       = aws_ecr_repository.backend.name
}

output "ecr_repository_frontend" {
  description = "Nome do repositório ECR do frontend"
  value       = aws_ecr_repository.frontend.name
}

output "eks_cluster_name" {
  description = "Nome do cluster EKS"
  value       = aws_eks_cluster.main.name
}

output "eks_cluster_endpoint" {
  description = "Endpoint do cluster EKS"
  value       = aws_eks_cluster.main.endpoint
}
