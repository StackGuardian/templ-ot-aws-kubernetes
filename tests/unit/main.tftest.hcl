# Unit tests: plan only, providers are mocked. No cloud account, no cost.
# Run: tofu test -test-directory=tests/unit
# Test case catalog: tests/README.md

mock_provider "aws" {
  mock_data "aws_availability_zones" {
    defaults = {
      names = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
    }
  }

  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
      arn        = "arn:aws:sts::123456789012:assumed-role/deployer/session"
    }
  }

  mock_data "aws_iam_session_context" {
    defaults = {
      issuer_arn = "arn:aws:iam::123456789012:role/deployer"
    }
  }

  # Some arguments are validated as ARNs, so mocked values must look like ARNs.
  mock_resource "aws_cloudwatch_log_group" {
    defaults = {
      arn = "arn:aws:logs:eu-central-1:123456789012:log-group:mock"
    }
  }

  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::123456789012:role/mock"
    }
  }

  mock_resource "aws_kms_key" {
    defaults = {
      arn = "arn:aws:kms:eu-central-1:123456789012:key/mock"
    }
  }

  mock_resource "aws_launch_template" {
    defaults = {
      id             = "lt-0123456789abcdef0"
      latest_version = 1
    }
  }
}

variables {
  allowed_api_cidrs = ["203.0.113.0/24"]
}

# U-01
run "defaults_are_valid" {
  command = plan

  assert {
    condition = (
      local.tags["Environment"] == "demo" &&
      local.tags["ManagedBy"] == "opentofu" &&
      local.tags["Project"] == var.name_prefix &&
      local.tags["Repository"] != ""
    )
    error_message = "Default tags are missing or wrong."
  }
}

# U-02
run "invalid_name_prefix_is_rejected" {
  command = plan

  variables {
    name_prefix = "Invalid_Prefix"
  }

  expect_failures = [var.name_prefix]
}

# U-03
run "custom_tags_are_merged" {
  command = plan

  variables {
    tags = {
      Owner = "tester"
    }
  }

  assert {
    condition     = local.tags["Owner"] == "tester" && local.tags["ManagedBy"] == "opentofu"
    error_message = "Custom tags are not merged with the default tags."
  }
}

# U-04
run "api_endpoint_is_restricted" {
  command = apply

  assert {
    condition = (
      one(aws_eks_cluster.this.vpc_config).public_access_cidrs == toset(["203.0.113.0/24"]) &&
      one(aws_eks_cluster.this.vpc_config).endpoint_private_access
    )
    error_message = "The public API endpoint must be limited to allowed_api_cidrs, private access must be on."
  }
}

# U-05
run "open_api_cidr_is_rejected" {
  command = plan

  variables {
    allowed_api_cidrs = ["0.0.0.0/0"]
  }

  expect_failures = [var.allowed_api_cidrs]
}

# U-06
run "secrets_are_encrypted_with_kms" {
  command = apply

  assert {
    condition = (
      one(one(aws_eks_cluster.this.encryption_config).provider).key_arn == aws_kms_key.eks.arn &&
      contains(one(aws_eks_cluster.this.encryption_config).resources, "secrets")
    )
    error_message = "Kubernetes secrets must be encrypted with the KMS key."
  }

  assert {
    condition     = aws_kms_key.eks.enable_key_rotation
    error_message = "KMS key rotation must be enabled."
  }
}

# U-07
run "control_plane_logging_is_enabled" {
  command = apply

  assert {
    condition     = length(setsubtract(["api", "audit", "authenticator"], aws_eks_cluster.this.enabled_cluster_log_types)) == 0
    error_message = "api, audit and authenticator logs must be enabled."
  }

  assert {
    condition     = aws_cloudwatch_log_group.eks.name == "/aws/eks/${aws_eks_cluster.this.name}/cluster"
    error_message = "The log group must match the cluster so its retention applies."
  }
}

# U-08
run "nodes_are_private" {
  command = apply

  assert {
    condition = (
      aws_eks_node_group.this.subnet_ids == toset(aws_subnet.private[*].id) &&
      alltrue([for s in aws_subnet.private : !s.map_public_ip_on_launch])
    )
    error_message = "Nodes must run in the private subnets only."
  }
}

# U-09
run "access_entries_are_used" {
  command = apply

  assert {
    condition = (
      one(aws_eks_cluster.this.access_config).authentication_mode == "API" &&
      !one(aws_eks_cluster.this.access_config).bootstrap_cluster_creator_admin_permissions
    )
    error_message = "The cluster must use access entries only."
  }

  assert {
    condition = (
      aws_eks_access_entry.deployer.principal_arn == "arn:aws:iam::123456789012:role/deployer" &&
      aws_eks_access_policy_association.deployer.policy_arn == "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
    )
    error_message = "The deploying IAM role must get cluster admin through an access entry."
  }
}

# U-10
run "node_hardening" {
  command = apply

  assert {
    condition     = one(aws_launch_template.node.metadata_options).http_tokens == "required"
    error_message = "IMDSv2 must be enforced on the nodes."
  }

  assert {
    condition     = one(one(aws_launch_template.node.block_device_mappings).ebs).encrypted == "true"
    error_message = "Node volumes must be encrypted."
  }

  assert {
    condition     = one(aws_eks_node_group.this.launch_template).id == aws_launch_template.node.id
    error_message = "The node group must use the hardened launch template."
  }
}

# U-11
run "pod_identity_and_flow_logs" {
  command = apply

  assert {
    condition     = aws_eks_addon.pod_identity.addon_name == "eks-pod-identity-agent"
    error_message = "The Pod Identity agent add-on must be installed."
  }

  assert {
    condition     = aws_flow_log.this.traffic_type == "ALL"
    error_message = "VPC flow logs must capture all traffic."
  }
}

# U-12
run "broad_api_cidr_is_rejected" {
  command = plan

  variables {
    allowed_api_cidrs = ["128.0.0.0/1"]
  }

  expect_failures = [var.allowed_api_cidrs]
}

# U-13
run "node_sizes_must_be_ordered" {
  command = plan

  variables {
    node_min_size     = 3
    node_desired_size = 2
  }

  expect_failures = [aws_eks_node_group.this]
}
