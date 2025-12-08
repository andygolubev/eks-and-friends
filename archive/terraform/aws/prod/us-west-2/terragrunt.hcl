include "root" {
  path = find_in_parent_folders("root.hcl")
}

generate "provider_region" {
  path      = "provider_region.tf"
  if_exists = "overwrite"
  contents  = <<EOP
provider "aws" {
  region = "us-west-2"
}
EOP
}
