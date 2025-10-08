resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "main-${local.env}"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "igw-${local.env}"
  }
}

resource "aws_subnet" "private_subnet" {
  for_each          = toset(local.first_3_azs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 4, index(local.first_3_azs, each.value))
  availability_zone = each.value

  tags = {
    "Name"                                                 = "${local.env}-private-${each.value}"
    "kubernetes.io/role/internal-elb"                      = "1"
    "kubernetes.io/cluster/${local.env}-${local.eks_name}" = "owned"
  }
}

resource "aws_subnet" "public_subnet" {
  for_each          = toset(local.first_3_azs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 4, index(local.first_3_azs, each.value) + 3)
  availability_zone = each.value

  tags = {
    "Name"                                                 = "${local.env}-public-${each.value}"
    "kubernetes.io/role/elb"                              = "1"
    "kubernetes.io/cluster/${local.env}-${local.eks_name}" = "owned"
  }
}