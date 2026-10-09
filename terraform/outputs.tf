

output "cluster_name" {
  value = aws_eks_cluster.main.name
}


output "cluster_endpoint" {
  value = aws_eks_cluster.main.endpoint
}


output "aws_region" {
  value = var.aws_region
}


output "connect_command" {
  value = "aws eks update-kubeconfig --name ${aws_eks_cluster.main.name} --region ${var.aws_region}"
}

