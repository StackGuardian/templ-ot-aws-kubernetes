# Tests

Tests use the built-in OpenTofu test framework (`tofu test`, OpenTofu 1.9 or later).

| Level | Folder | What it does | Cost | When it runs |
|---|---|---|---|---|
| Unit | `tests/unit` | Plan only with mocked providers. Checks configuration and security settings. | None | Merge requests into `development` or `main`, and tags |
| Integration | `tests/integration` | Deploys real resources, checks them, destroys them. | Cloud cost while running | Tags, when cloud credentials are set (`integration-tests` job) |

## Run locally

```bash
tofu init
tofu test -test-directory=tests/unit
tofu test -test-directory=tests/integration   # needs cloud credentials
```

## Test cases

| ID | Level | Description | Status |
|---|---|---|---|
| U-01 | Unit | Default variables produce a valid plan with all default tags | done |
| U-02 | Unit | Invalid `name_prefix` is rejected | done |
| U-03 | Unit | Custom `advanced_settings.tags` are merged with the default tags | done |
| U-04 | Unit | Public API endpoint is limited to `allowed_api_cidrs`, private endpoint access is on | done |
| U-05 | Unit | `allowed_api_cidrs` containing `0.0.0.0/0` is rejected | done |
| U-06 | Unit | Kubernetes secrets are encrypted with the KMS key, key rotation is on | done |
| U-07 | Unit | Control plane logging (api, audit, authenticator) is on and the log group matches the cluster | done |
| U-08 | Unit | Node group uses only private subnets | done |
| U-09 | Unit | Authentication mode `API`, no creator admin, deploying IAM role gets cluster admin via access entry | done |
| U-10 | Unit | Launch template enforces IMDSv2 and encrypted volumes, node group uses it | done |
| U-11 | Unit | Pod Identity agent add-on is installed, VPC flow logs capture all traffic | done |
| U-12 | Unit | `allowed_api_cidrs` broader than `/8` (for example `128.0.0.0/1`) is rejected | done |
| U-13 | Unit | Node sizes with `advanced_settings.node_min_size` above `node_desired_size` are rejected | done |
| I-01 | Integration | Cluster status is `ACTIVE` | done |
| I-02 | Integration | Node group status is `ACTIVE` with the desired size | done |
| I-03 | Integration | Cluster endpoint and version outputs are set | done |

Integration tests are written but have not run against a real cloud account yet.
