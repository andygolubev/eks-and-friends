terraform {
  source = "../../../../../modules/eks"
}

include "root" {
  path = find_in_parent_folders()
}

include "common" {
  path = find_in_parent_folders("_common.hcl")
}

dependency "vpc" {
  config_path = "../../networking/vpc"
}

inputs = {
  cluster_name       = "eks"
  vpc_id             = dependency.vpc.outputs.vpc_id
  private_subnet_ids = dependency.vpc.outputs.private_subnet_ids
  tags               = local.common_tags
}


