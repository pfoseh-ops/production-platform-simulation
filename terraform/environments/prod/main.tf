data "aws_caller_identity" "current" {}

locals {
  name = "${var.project_name}-${var.environment}"
  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

module "network" {
  source = "../../modules/network"

  name               = local.name
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
  tags               = local.tags
}

module "eks" {
  source = "../../modules/eks"

  name                = local.name
  kubernetes_version  = var.kubernetes_version
  private_subnet_ids  = module.network.private_subnet_ids
  public_access_cidrs = var.public_access_cidrs
  node_instance_types = var.node_instance_types
  node_min_size       = var.node_min_size
  node_desired_size   = var.node_desired_size
  node_max_size       = var.node_max_size
  tags                = local.tags
}

module "storage" {
  source = "../../modules/storage"

  name = "${local.name}-${data.aws_caller_identity.current.account_id}"
  tags = local.tags
}

resource "helm_release" "storage_class" {
  name      = "storage-prerequisites"
  namespace = "kube-system"
  chart     = "${path.root}/../../../deploy/storage-chart"
  atomic    = true
  timeout   = 300

  depends_on = [module.eks]
}

resource "helm_release" "metrics_server" {
  name             = "metrics-server"
  namespace        = "metrics-server"
  create_namespace = true
  repository       = "https://kubernetes-sigs.github.io/metrics-server/"
  chart            = "metrics-server"
  version          = "3.12.2"
  atomic           = true
  timeout          = 600

  depends_on = [module.eks]
}

resource "helm_release" "monitoring" {
  name             = "prometheus"
  namespace        = "observability"
  create_namespace = true
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  version          = "69.8.2"
  atomic           = true
  timeout          = 900

  values = [
    templatefile("${path.module}/monitoring-values.yaml.tftpl", {
      grafana_admin_password = var.grafana_admin_password
    })
  ]

  depends_on = [helm_release.storage_class]
}

resource "helm_release" "application" {
  name             = "production-simulation"
  namespace        = "production-simulation"
  create_namespace = true
  chart            = "${path.root}/../../../deploy/chart"
  atomic           = true
  timeout          = 600

  set {
    name  = "image.repository"
    value = var.image_repository
  }

  set {
    name  = "image.tag"
    value = var.image_tag
  }

  depends_on = [
    helm_release.metrics_server,
    helm_release.monitoring
  ]
}
