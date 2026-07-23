resource "aws_iam_role" "cluster" {
  name               = "${var.name}-cluster"
  assume_role_policy = data.aws_iam_policy_document.cluster_assume.json
  tags               = var.tags
}

data "aws_iam_policy_document" "cluster_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "cluster" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "aws_kms_key" "cluster" {
  description             = "Encrypts ${var.name} Kubernetes secrets and control-plane logs"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.cluster_kms.json
  tags                    = var.tags
}

data "aws_iam_policy_document" "cluster_kms" {
  #checkov:skip=CKV_AWS_109:KMS key policies require Resource "*" and permissions remain restricted by explicit account-root and CloudWatch Logs principals.
  #checkov:skip=CKV_AWS_111:KMS key policies require Resource "*" and write access remains restricted by explicit account-root and CloudWatch Logs principals.
  #checkov:skip=CKV_AWS_356:KMS key policies require Resource "*" because the key ARN is not available while defining its policy.
  statement {
    sid     = "AccountAdministrationAndEKSUse"
    effect  = "Allow"
    actions = ["kms:*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    resources = ["*"]
  }

  statement {
    sid    = "CloudWatchLogs"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:Encrypt",
      "kms:GenerateDataKey",
      "kms:ReEncryptFrom",
      "kms:ReEncryptTo"
    ]
    principals {
      type        = "Service"
      identifiers = ["logs.${data.aws_region.current.name}.amazonaws.com"]
    }
    resources = ["*"]
    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = ["arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/eks/${var.name}/cluster"]
    }
  }
}

resource "aws_cloudwatch_log_group" "cluster" {
  name              = "/aws/eks/${var.name}/cluster"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.cluster.arn
  tags              = var.tags
}

resource "aws_eks_cluster" "this" {
  #checkov:skip=CKV_AWS_39:GitHub-hosted runners require the public endpoint; access remains limited to explicit trusted CIDRs.
  #checkov:skip=CKV_AWS_38:The production variable validation prohibits 0.0.0.0/0 and requires at least one explicit trusted CIDR.
  name     = var.name
  role_arn = aws_iam_role.cluster.arn
  version  = var.kubernetes_version

  enabled_cluster_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler"
  ]

  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  encryption_config {
    provider {
      key_arn = aws_kms_key.cluster.arn
    }
    resources = ["secrets"]
  }

  vpc_config {
    subnet_ids              = var.private_subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = var.public_access_cidrs
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster,
    aws_cloudwatch_log_group.cluster
  ]

  tags = var.tags
}

resource "aws_iam_role" "nodes" {
  name               = "${var.name}-nodes"
  assume_role_policy = data.aws_iam_policy_document.nodes_assume.json
  tags               = var.tags
}

data "aws_iam_policy_document" "nodes_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "nodes" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  ])

  role       = aws_iam_role.nodes.name
  policy_arn = each.value
}

resource "aws_eks_node_group" "this" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "system"
  node_role_arn   = aws_iam_role.nodes.arn
  subnet_ids      = var.private_subnet_ids
  instance_types  = var.node_instance_types
  capacity_type   = "ON_DEMAND"

  scaling_config {
    min_size     = var.node_min_size
    desired_size = var.node_desired_size
    max_size     = var.node_max_size
  }

  update_config {
    max_unavailable_percentage = 33
  }

  labels = {
    workload = "general"
  }

  depends_on = [aws_iam_role_policy_attachment.nodes]
  tags       = var.tags
}

resource "aws_iam_role" "ebs_csi" {
  name               = "${var.name}-ebs-csi"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_assume.json
  tags               = var.tags
}

data "aws_iam_policy_document" "pod_identity_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole", "sts:TagSession"]
    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  role       = aws_iam_role.ebs_csi.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

resource "aws_eks_addon" "pod_identity" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "eks-pod-identity-agent"
  resolve_conflicts_on_update = "PRESERVE"

  depends_on = [aws_eks_node_group.this]
  tags       = var.tags
}

resource "aws_eks_addon" "ebs_csi" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "aws-ebs-csi-driver"
  resolve_conflicts_on_update = "PRESERVE"

  pod_identity_association {
    role_arn        = aws_iam_role.ebs_csi.arn
    service_account = "ebs-csi-controller-sa"
  }

  depends_on = [
    aws_eks_addon.pod_identity,
    aws_iam_role_policy_attachment.ebs_csi
  ]

  tags = var.tags
}
