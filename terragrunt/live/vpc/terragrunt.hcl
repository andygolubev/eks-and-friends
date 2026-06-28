include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  common = read_terragrunt_config(find_in_parent_folders("common.hcl"))
  name   = "${local.common.locals.inputs.project}-${local.common.locals.inputs.environment}"
}

terraform {
  source = "tfr:///terraform-aws-modules/vpc/aws?version=6.6.0"
}

generate "aws_provider" {
  path      = "zz_terragrunt_provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  region = "${local.common.locals.inputs.aws_region}"
  default_tags {
    tags = {
      Project     = "${local.common.locals.inputs.project}"
      Environment = "${local.common.locals.inputs.environment}"
      ManagedBy   = "terragrunt"
    }
  }
}
EOF
}

inputs = {
  name = "${local.name}-vpc"
  cidr = local.common.locals.inputs.vpc_cidr
  azs  = ["${local.common.locals.inputs.aws_region}a", "${local.common.locals.inputs.aws_region}b", "${local.common.locals.inputs.aws_region}c"]

  public_subnets  = [cidrsubnet(local.common.locals.inputs.vpc_cidr, 4, 0), cidrsubnet(local.common.locals.inputs.vpc_cidr, 4, 1), cidrsubnet(local.common.locals.inputs.vpc_cidr, 4, 2)]
  private_subnets = [cidrsubnet(local.common.locals.inputs.vpc_cidr, 4, 3), cidrsubnet(local.common.locals.inputs.vpc_cidr, 4, 4), cidrsubnet(local.common.locals.inputs.vpc_cidr, 4, 5)]

  enable_dns_support      = true
  enable_dns_hostnames    = true
  enable_nat_gateway      = true
  single_nat_gateway      = true
  map_public_ip_on_launch = true
  public_subnet_tags = {
    "kubernetes.io/role/elb"                                           = "1"
    "kubernetes.io/cluster/${local.common.locals.inputs.cluster_name}" = "shared"
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"                                  = "1"
    "kubernetes.io/cluster/${local.common.locals.inputs.cluster_name}" = "shared"
    "karpenter.sh/discovery"                                           = local.common.locals.inputs.cluster_name
  }
}
