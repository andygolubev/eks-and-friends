include "root" {
  path = find_in_parent_folders("root.hcl")
}

dependency "vpc" {
  config_path = "../vpc"
  mock_outputs = {
    vpc_id          = "vpc-00000000000000000"
    private_subnets = ["subnet-00000000000000001", "subnet-00000000000000002"]
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

terraform {
  source = "../../../terraform-module"

  extra_arguments "isolated_helm_cache" {
    commands = ["init", "validate", "plan", "apply", "destroy"]
    env_vars = {
      HELM_CONFIG_HOME = "${get_terragrunt_dir()}/.helm/config"
      HELM_CACHE_HOME  = "${get_terragrunt_dir()}/.helm/cache"
    }
  }
}

inputs = {
  create_vpc                  = false
  existing_vpc_id             = dependency.vpc.outputs.vpc_id
  existing_private_subnet_ids = dependency.vpc.outputs.private_subnets
}
