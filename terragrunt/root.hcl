locals {
  common = read_terragrunt_config(find_in_parent_folders("common.hcl"))
}

inputs = local.common.locals.inputs

generate "tofu_version" {
  path      = "zz_terragrunt_tofu.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  required_version = ">= 1.10, < 2.0"
}
EOF
}
