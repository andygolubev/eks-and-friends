# EKS Infrastructure with Terraform/OpenTofu

This directory contains Terraform/OpenTofu configuration to provision a complete EKS cluster with networking, IAM, node groups, and essential addons (metrics-server, cluster-autoscaler, AWS Load Balancer Controller, cert-manager).

Based on: https://github.com/antonputra/tutorials/tree/main/lessons/196

## Prerequisites

- OpenTofu >= 1.5.0 (tested with 1.11.2)
- AWS CLI configured with appropriate credentials
- kubectl installed
- Helm provider 3.1.1+ (see bug section below)

## Known Issue: Helm Provider 3.x "Inconsistent Final Plan" Bug

### The Bug

When provisioning **fresh infrastructure** (first-time apply), you may encounter this error:

```
Error: Provider produced inconsistent final plan

When expanding the plan for helm_release.metrics_server to include new values
learned so far during apply, provider "registry.opentofu.org/hashicorp/helm"
produced an invalid new value for .status: was null, but now
cty.StringVal("deployed").
```

**Root Cause:**
- Helm provider 3.x migrated to Terraform Plugin Framework
- During fresh applies, computed attributes (`id`, `status`, `metadata`) start as `null` in the plan
- When the Helm provider actually creates the release, these become known values
- OpenTofu's strict plan validation detects this change and fails with "inconsistent plan"
- This is a provider-level bug affecting Helm provider 3.0.0+ with OpenTofu

**Affected Resources:**
- `helm_release.metrics_server`
- `helm_release.cluster_autoscaler`
- `helm_release.aws_lbc`
- `helm_release.cert_manager`

**Why It Happens:**
The Helm provider cannot determine computed values until:
1. The EKS cluster exists and is accessible
2. The Kubernetes API is reachable
3. Helm can actually install the chart

On a fresh apply, all resources are planned simultaneously, so Helm resources are planned before the cluster is fully ready, causing the computed attribute mismatch.

### Workaround: Split Apply Strategy

The only reliable workaround without downgrading the Helm provider is to split the apply into two stages:

**Stage 1:** Create the EKS cluster and all AWS resources (but skip Helm releases)
**Stage 2:** Create Helm releases after the cluster is ready

## Provisioning Fresh Infrastructure

### Step 1: Initialize Terraform

```bash
tofu init
```

### Step 2: First Apply - Create Cluster (Skip Helm Releases)

```bash
tofu apply -target=aws_eks_addon.ebs_csi_driver --auto-approve
```

This command:
- Creates all AWS resources (VPC, subnets, security groups, IAM roles, EKS cluster, node groups, EBS CSI driver addon)
- **Skips** all `helm_release.*` resources
- Takes approximately 10-15 minutes

**What gets created:**
- VPC, subnets, NAT gateway, internet gateway
- EKS cluster
- Node groups (ARM64 and AMD64)
- EBS CSI driver addon
- Pod identity associations
- IAM roles and policies
- Access entries

**What gets skipped:**
- `helm_release.metrics_server`
- `helm_release.cluster_autoscaler`
- `helm_release.aws_lbc`
- `helm_release.cert_manager`

### Step 3: Second Apply - Install Helm Releases

```bash
tofu apply --auto-approve
```

This command:
- Plans only the remaining Helm releases
- The EKS cluster now exists, so Helm provider can properly compute attributes
- No "inconsistent plan" error occurs
- Takes approximately 2-3 minutes

**What gets created:**
- Metrics Server (Helm chart)
- Cluster Autoscaler (Helm chart)
- AWS Load Balancer Controller (Helm chart)
- Cert Manager (Helm chart)

### Complete Fresh Provisioning Script

```bash
#!/bin/bash
set -e

echo "Step 1: Initializing Terraform..."
tofu init

echo "Step 2: Creating EKS cluster and AWS resources..."
tofu apply -target=aws_eks_addon.ebs_csi_driver --auto-approve

echo "Step 3: Installing Helm releases..."
tofu apply --auto-approve

echo "Provisioning complete!"
```

## Normal Operations (After Initial Provisioning)

Once the infrastructure is provisioned, you can use normal Terraform commands:

```bash
# Plan changes
tofu plan

# Apply changes
tofu apply

# Destroy everything
tofu destroy
```

**Note:** The split-apply workaround is only needed for **fresh infrastructure**. Subsequent applies work normally because the cluster already exists and Helm provider can read its state.

## Alternative Solutions (Not Recommended)

### Option 1: Downgrade Helm Provider to 2.x
```hcl
helm = {
  source  = "hashicorp/helm"
  version = "~> 2.17"
}
```
**Downside:** Loses Helm provider 3.x features and improvements

### Option 2: Use Terraform Instead of OpenTofu
**Downside:** Terraform has different licensing and may have similar issues

### Option 3: Wait for Provider Fix
The bug is tracked upstream. Monitor:
- https://github.com/hashicorp/terraform-provider-helm/issues
- Helm provider releases for fixes

## Troubleshooting

### Error: "Provider produced inconsistent final plan"
- **Cause:** Running full `tofu apply` on fresh infrastructure
- **Solution:** Use the split-apply strategy described above

### Error: "Could not connect to registry.opentofu.org"
- **Cause:** Network/TLS certificate issues
- **Solution:** Run with `required_permissions: ['all']` or check network connectivity

### Helm releases fail to install
- **Cause:** Cluster not ready, RBAC issues, or chart repository problems
- **Solution:** 
  - Verify cluster is ready: `kubectl get nodes`
  - Check Helm release logs: `kubectl logs -n kube-system -l app.kubernetes.io/name=metrics-server`
  - Verify chart repositories are accessible

## Project Structure

```
terraform-pure/
├── 01-networking.tf          # VPC, subnets, NAT gateway, security groups
├── 02-eks.tf                # EKS cluster configuration
├── 03-nodes.tf              # Node groups (ARM64 and AMD64)
├── 04-users-and-roles.tf    # IAM users, roles, and access entries
├── 05-helm-provider.tf      # Helm provider configuration
├── 06-metric-server.tf      # Metrics Server Helm release
├── 07-pod-Identity-addon.tf # EKS Pod Identity addon
├── 08-cluster-autoscaler.tf # Cluster Autoscaler Helm release
├── 09-cert-manager.tf       # Cert Manager Helm release
├── 10-ebs-sci-driver.tf     # EBS CSI driver addon
├── 11-openid-provide.tf     # OIDC provider for IRSA
├── providers.tf             # AWS provider configuration
├── variables.tf             # Input variables
├── versions.tf              # Provider version constraints
└── values/
    └── metrics-server.yaml  # Metrics Server Helm values
```

## Variables

Key variables (see `variables.tf` for full list):

- `aws_region`: AWS region (default: `us-east-1`)
- `project`: Project name tag (default: `eks-demo`)
- `environment`: Environment tag (default: `dev`)
- `cluster_name`: EKS cluster name (default: `eks-demo`)
- `kubernetes_version`: Kubernetes version (default: `1.34`)
- `vpc_cidr`: VPC CIDR block (default: `10.0.0.0/16`)

## Outputs

After provisioning, you can access:

- EKS cluster endpoint
- Cluster name
- VPC ID
- Subnet IDs
- IAM role ARNs

## References

- [Original Tutorial](https://github.com/antonputra/tutorials/tree/main/lessons/196)
- [Helm Provider Documentation](https://registry.terraform.io/providers/hashicorp/helm/latest/docs)
- [OpenTofu Documentation](https://opentofu.org/docs)
- [EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
