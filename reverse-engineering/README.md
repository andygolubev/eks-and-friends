## Reverse-engineering from state

This folder was generated from the **working** `eks-module/terraform.tfstate` and recreates the same AWS resources **without modules**, using the same parameters found in state.

### How to use

1. Make sure you are authenticated to the same AWS account as the working state (**account `766198264464`**, region **`us-east-1`**).
2. From this folder:

```bash
terraform init
bash import.sh
terraform plan
```

### Notes / limitations

- This does **not** “copy” resources into another AWS account. It’s meant to **adopt/import** the *existing* resources that were created by the module-based project.
- If any `aws_security_group_rule` imports fail (provider differences), switch those to `aws_vpc_security_group_ingress_rule` / `aws_vpc_security_group_egress_rule` and re-import using the `sgr-...` IDs from state.

