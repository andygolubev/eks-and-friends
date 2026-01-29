locals {
  name_prefix = "${var.project}-${var.environment}"
  azs         = slice(data.aws_availability_zones.available.names, 0, 3)

  public_subnet_cidrs = [
    for idx, az in local.azs : cidrsubnet(var.vpc_cidr, 4, idx)
  ]
  private_subnet_cidrs = [
    for idx, az in local.azs : cidrsubnet(var.vpc_cidr, 4, idx + length(local.azs))
  ]
}

data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.6"

  name = "${local.name_prefix}-vpc"
  cidr = var.vpc_cidr
  azs  = local.azs

  public_subnets  = local.public_subnet_cidrs
  private_subnets = local.private_subnet_cidrs

  enable_dns_support   = true
  enable_dns_hostnames = true

  enable_nat_gateway = true
  single_nat_gateway = true

  map_public_ip_on_launch = true

  public_subnet_names = [
    for az in local.azs : "${local.name_prefix}-public-${az}"
  ]
  private_subnet_names = [
    for az in local.azs : "${local.name_prefix}-private-${az}"
  ]

  public_subnet_tags = {
    Tier                                = "public"
    "kubernetes.io/role/elb"            = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
  private_subnet_tags = {
    Tier                                        = "private"
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}
