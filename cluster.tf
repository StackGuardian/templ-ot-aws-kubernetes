locals {
  cluster_name = "${var.name_prefix}-eks"
}

data "aws_caller_identity" "current" {}

# Resolves an assumed-role session to its IAM role ARN for the access entry.
data "aws_iam_session_context" "current" {
  arn = data.aws_caller_identity.current.arn
}

# Envelope encryption of Kubernetes secrets
resource "aws_kms_key" "eks" {
  description             = "${local.cluster_name} secrets encryption"
  enable_key_rotation     = true
  deletion_window_in_days = 7

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AccountAdmin"
      Effect    = "Allow"
      Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
      Action    = "kms:*"
      Resource  = "*"
    }]
  })
}

resource "aws_kms_alias" "eks" {
  name          = "alias/${local.cluster_name}"
  target_key_id = aws_kms_key.eks.key_id
}

# Created up front so the retention applies to the control plane logs.
resource "aws_cloudwatch_log_group" "eks" {
  #checkov:skip=CKV_AWS_338:Demo template, retention is configurable via advanced_settings.log_retention_days
  #checkov:skip=CKV_AWS_158:Encrypted with AWS-managed keys, customer-managed KMS is out of scope for the demo
  name              = "/aws/eks/${local.cluster_name}/cluster"
  retention_in_days = var.advanced_settings.log_retention_days
}

resource "aws_iam_role" "cluster" {
  name = "${local.cluster_name}-cluster"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
      Action    = ["sts:AssumeRole", "sts:TagSession"]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "cluster" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# The cluster role encrypts and decrypts secrets with the key.
resource "aws_iam_role_policy" "cluster_kms" {
  name = "secrets-encryption"
  role = aws_iam_role.cluster.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["kms:Encrypt", "kms:Decrypt", "kms:DescribeKey", "kms:CreateGrant"]
      Resource = aws_kms_key.eks.arn
    }]
  })
}

resource "aws_eks_cluster" "this" {
  #checkov:skip=CKV_AWS_38:Public access is limited to allowed_api_cidrs, a validation rejects 0.0.0.0/0
  #checkov:skip=CKV_AWS_39:The public endpoint is needed to use kubectl from outside the VPC, it is limited to allowed_api_cidrs
  #checkov:skip=CKV_AWS_339:Versions 1.34 to 1.37 are in EKS standard support, the version list built into checkov ends at 1.35
  name     = local.cluster_name
  version  = var.advanced_settings.kubernetes_version
  role_arn = aws_iam_role.cluster.arn

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  access_config {
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = false
  }

  vpc_config {
    subnet_ids              = aws_subnet.private[*].id
    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = var.allowed_api_cidrs
  }

  encryption_config {
    resources = ["secrets"]

    provider {
      key_arn = aws_kms_key.eks.arn
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster,
    aws_iam_role_policy.cluster_kms,
    aws_cloudwatch_log_group.eks,
  ]
}

# Cluster admin for the identity that runs OpenTofu
resource "aws_eks_access_entry" "deployer" {
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = data.aws_iam_session_context.current.issuer_arn
}

resource "aws_eks_access_policy_association" "deployer" {
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = aws_eks_access_entry.deployer.principal_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}

resource "aws_eks_addon" "pod_identity" {
  cluster_name = aws_eks_cluster.this.name
  addon_name   = "eks-pod-identity-agent"

  depends_on = [aws_eks_node_group.this]
}
