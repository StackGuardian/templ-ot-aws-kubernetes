variable "name_prefix" {
  description = "Prefix for all resource names"
  type        = string
  default     = "demo"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,15}$", var.name_prefix))
    error_message = "Use 2-16 lowercase letters, digits or hyphens, starting with a letter."
  }
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

variable "tags" {
  description = "Additional tags for all resources"
  type        = map(string)
  default     = {}
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "Must be a valid IPv4 CIDR block."
  }
}

variable "kubernetes_version" {
  description = "Kubernetes version of the cluster. Null uses the current EKS default."
  type        = string
  default     = null
}

variable "allowed_api_cidrs" {
  description = "IPv4 CIDRs allowed to reach the public Kubernetes API endpoint"
  type        = list(string)

  validation {
    condition     = length(var.allowed_api_cidrs) > 0 && alltrue([for c in var.allowed_api_cidrs : can(cidrnetmask(c))])
    error_message = "Set at least one valid IPv4 CIDR block."
  }

  validation {
    condition     = !anytrue([for c in var.allowed_api_cidrs : endswith(c, "/0")])
    error_message = "Open-to-the-internet CIDRs like 0.0.0.0/0 are not allowed."
  }
}

variable "node_instance_types" {
  description = "Instance types of the managed node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_desired_size" {
  description = "Desired number of nodes"
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Minimum number of nodes"
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum number of nodes"
  type        = number
  default     = 3
}

variable "node_disk_size" {
  description = "Root volume size of the nodes in GiB"
  type        = number
  default     = 20
}

variable "log_retention_days" {
  description = "Retention of control plane and flow logs in CloudWatch"
  type        = number
  default     = 90
}
