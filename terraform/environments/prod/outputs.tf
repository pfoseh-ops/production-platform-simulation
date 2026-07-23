output "cluster_name" {
  value = module.eks.cluster_name
}

output "storage_bucket" {
  value = module.storage.bucket_name
}

output "kubectl_config_command" {
  value = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

output "grafana_command" {
  value = "kubectl -n observability port-forward svc/prometheus-grafana 3000:80"
}
