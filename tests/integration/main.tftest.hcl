# Integration tests: deploy real resources, check them, then destroy them.
# This costs money and needs cloud credentials.
# Run: tofu test -test-directory=tests/integration
# Test case catalog: tests/README.md

variables {
  name_prefix = "itest"
  # Documentation range, nobody can reach the API. The test only reads the AWS API.
  allowed_api_cidrs = ["203.0.113.0/24"]
  advanced_settings = {
    tags = {
      Purpose = "integration-test"
    }
  }
}

# I-03
run "deploy" {
  command = apply

  assert {
    condition     = startswith(output.cluster_endpoint, "https://") && output.cluster_version != ""
    error_message = "Cluster endpoint and version outputs must be set."
  }
}

# I-01, I-02
run "cluster_and_nodes_are_active" {
  module {
    source = "./tests/integration/cluster-check"
  }

  variables {
    cluster_name    = run.deploy.cluster_name
    node_group_name = run.deploy.node_group_name
  }

  assert {
    condition     = output.cluster_status == "ACTIVE"
    error_message = "The cluster is not ACTIVE."
  }

  assert {
    condition     = output.node_group_status == "ACTIVE" && output.node_desired_size == 2
    error_message = "The node group is not ACTIVE with the desired size."
  }
}
