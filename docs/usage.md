# AWS Kubernetes Cluster (EKS)

Creates an Amazon EKS cluster with a managed group of worker nodes in private subnets. No application is deployed, so the cluster is ready for your own workloads.

Use it to show a hardened Kubernetes setup on AWS or to get a cluster for tests.

## What gets created

- A VPC across two availability zones, with private subnets for the nodes and public subnets for the NAT gateway and internet-facing load balancers
- One NAT gateway for outbound traffic
- The EKS cluster with control plane logging and encryption of Kubernetes secrets (KMS)
- A managed node group
- The EKS Pod Identity add-on
- Cluster admin access for the identity that runs the deployment
- VPC flow logs

## Before you start

- A workflow with an AWS cloud connector for the target account
- Permissions to create VPC, EKS, EC2, IAM, KMS and CloudWatch Logs resources
- The public IP range you work from, for **Allowed API CIDRs**
- To use the cluster: the AWS CLI and `kubectl`

## Form fields

| Field | What it does | Default |
|---|---|---|
| Allowed API CIDRs | **Required.** IP ranges that may reach the Kubernetes API, for example your office or VPN address. `0.0.0.0/0` is rejected | none |
| Name prefix | Prefix for all resource names. 2 to 16 lowercase letters, digits or hyphens, starting with a letter | `demo` |
| Region | AWS region | `eu-central-1` |

### Advanced settings

These appear after you tick "Show advanced settings". Most deployments keep the defaults.

| Field | What it does | Default |
|---|---|---|
| VPC CIDR | IP range of the new network | `10.0.0.0/16` |
| Kubernetes version | Kubernetes minor version. EKS picks the latest patch | `1.37` |
| Node instance types | Instance types of the nodes. Pick one or more from the list (x86 only) | `t3.medium` |
| Node desired size | Number of nodes, 1 to 20 | `2` |
| Node min size | Smallest number of nodes, 1 to 20. Must not exceed the desired size | `1` |
| Node max size | Largest number of nodes, 1 to 20. Must not be below the desired size | `3` |
| Node disk size | Disk size per node in GiB | `20` |
| Log retention days | How long control plane logs and flow logs are kept | `90` |
| Tags | Extra tags added to all resources | none |

The version list contains the EKS versions in standard support. A new version may not be available in every region yet. If the run fails for that reason, pick the next lower version.

## After the run

The workflow outputs show:

- `cluster_name`, `cluster_endpoint` and `cluster_version`
- `kubeconfig_command`: run it, then `kubectl get nodes`

The identity that ran the deployment is cluster admin. To give other people access, add EKS access entries for their IAM roles. Creating the cluster takes about 15 minutes.

## Security defaults

- Nodes have no public IPs
- The API is reachable only from the allowed IP ranges and from inside the VPC
- Kubernetes secrets are encrypted with a customer-managed KMS key with rotation
- Access is managed with EKS access entries only. Control plane and audit logs are on
- Nodes require IMDSv2 and have encrypted disks. Pods get AWS permissions through Pod Identity, not from the node

## Cost and cleanup

The EKS control plane, the NAT gateway and the nodes are billed per hour, also when idle. Destroy the resources from the workflow when the demo is over.

## Limits

- One NAT gateway, so outbound traffic is not highly available
- No sample workload and no ingress controller
