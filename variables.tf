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
    condition     = alltrue([for c in var.allowed_api_cidrs : try(tonumber(split("/", c)[1]) >= 8, false)])
    error_message = "CIDRs broader than /8, such as 0.0.0.0/0, are not allowed."
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

  validation {
    condition     = var.node_min_size >= 1
    error_message = "At least one node is needed."
  }
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

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.log_retention_days)
    error_message = "CloudWatch Logs accepts only fixed retention values, for example 30, 90 or 365."
  }
}
