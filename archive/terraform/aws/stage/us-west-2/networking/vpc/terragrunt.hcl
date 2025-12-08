terraform {
  source = "../../../../../modules/vpc"
}

include "root" {
  path = find_in_parent_folders()
}

include "common" {
  path = find_in_parent_folders("_common.hcl")
}

inputs = {
  name = "vpc"
  tags = local.common_tags
}


