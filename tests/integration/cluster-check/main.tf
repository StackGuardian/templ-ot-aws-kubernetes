# Helper for the integration test: reads the live state of the cluster and the node group.
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

variable "cluster_name" {
  type = string
}

variable "node_group_name" {
  type = string
}

data "aws_eks_cluster" "this" {
  name = var.cluster_name
}

data "aws_eks_node_group" "this" {
  cluster_name    = var.cluster_name
  node_group_name = var.node_group_name
}

output "cluster_status" {
  value = data.aws_eks_cluster.this.status
}

output "node_group_status" {
  value = data.aws_eks_node_group.this.status
}

output "node_desired_size" {
  value = one(data.aws_eks_node_group.this.scaling_config).desired_size
}
