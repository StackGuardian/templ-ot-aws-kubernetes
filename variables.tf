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

# Grouped so the StackGuardian form can show them in one "Advanced Settings" section.
variable "advanced_settings" {
  description = "Settings most deployments keep at their defaults"
  type = object({
    vpc_cidr            = optional(string, "10.0.0.0/16")       # CIDR block of the VPC
    kubernetes_version  = optional(string, "1.37")              # Kubernetes minor version; EKS picks the latest patch
    node_instance_types = optional(list(string), ["t3.medium"]) # Instance types of the managed node group
    node_desired_size   = optional(number, 2)                   # Desired number of nodes
    node_min_size       = optional(number, 1)                   # Minimum number of nodes
    node_max_size       = optional(number, 3)                   # Maximum number of nodes
    node_disk_size      = optional(number, 20)                  # Root volume size of the nodes in GiB
    log_retention_days  = optional(number, 90)                  # Retention of control plane and flow logs in CloudWatch
    tags                = optional(map(string), {})             # Additional tags for all resources
  })
  default  = {}
  nullable = false

  validation {
    condition     = can(cidrnetmask(var.advanced_settings.vpc_cidr))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block."
  }

  validation {
    condition = alltrue([
      for n in [var.advanced_settings.node_min_size, var.advanced_settings.node_desired_size, var.advanced_settings.node_max_size] : n >= 1 && n <= 20
    ])
    error_message = "node_min_size, node_desired_size and node_max_size must each be between 1 and 20."
  }

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.advanced_settings.log_retention_days)
    error_message = "CloudWatch Logs accepts only fixed retention values, for example 30, 90 or 365."
  }
}
