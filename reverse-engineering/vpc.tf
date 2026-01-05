resource "aws_vpc" "this" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "guru-vpc"
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "guru-vpc"
  }
}

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "guru-vpc-us-east-1a"
  }
}

resource "aws_subnet" "private_us_east_1a" {
  vpc_id            = aws_vpc.this.id
  availability_zone = "us-east-1a"
  cidr_block        = "10.0.1.0/24"

  tags = {
    Name                                     = "guru-vpc-private-us-east-1a"
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"        = "1"
  }
}

resource "aws_subnet" "private_us_east_1b" {
  vpc_id            = aws_vpc.this.id
  availability_zone = "us-east-1b"
  cidr_block        = "10.0.2.0/24"

  tags = {
    Name                                     = "guru-vpc-private-us-east-1b"
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"        = "1"
  }
}

resource "aws_subnet" "private_us_east_1c" {
  vpc_id            = aws_vpc.this.id
  availability_zone = "us-east-1c"
  cidr_block        = "10.0.3.0/24"

  tags = {
    Name                                     = "guru-vpc-private-us-east-1c"
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"        = "1"
  }
}

resource "aws_subnet" "public_us_east_1a" {
  vpc_id            = aws_vpc.this.id
  availability_zone = "us-east-1a"
  cidr_block        = "10.0.4.0/24"

  tags = {
    Name                                     = "guru-vpc-public-us-east-1a"
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                 = "1"
  }
}

resource "aws_subnet" "public_us_east_1b" {
  vpc_id            = aws_vpc.this.id
  availability_zone = "us-east-1b"
  cidr_block        = "10.0.5.0/24"

  tags = {
    Name                                     = "guru-vpc-public-us-east-1b"
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                 = "1"
  }
}

resource "aws_subnet" "public_us_east_1c" {
  vpc_id            = aws_vpc.this.id
  availability_zone = "us-east-1c"
  cidr_block        = "10.0.6.0/24"

  tags = {
    Name                                     = "guru-vpc-public-us-east-1c"
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                 = "1"
  }
}

resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_us_east_1a.id

  tags = {
    Name = "guru-vpc-us-east-1a"
  }

  depends_on = [aws_internet_gateway.this]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "guru-vpc-public"
  }
}

resource "aws_route" "public_internet_gateway" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public_us_east_1a" {
  subnet_id      = aws_subnet.public_us_east_1a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_us_east_1b" {
  subnet_id      = aws_subnet.public_us_east_1b.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_us_east_1c" {
  subnet_id      = aws_subnet.public_us_east_1c.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "guru-vpc-private"
  }
}

resource "aws_route" "private_nat_gateway" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this.id
}

resource "aws_route_table_association" "private_us_east_1a" {
  subnet_id      = aws_subnet.private_us_east_1a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_us_east_1b" {
  subnet_id      = aws_subnet.private_us_east_1b.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_us_east_1c" {
  subnet_id      = aws_subnet.private_us_east_1c.id
  route_table_id = aws_route_table.private.id
}

# Default VPC resources (these are real AWS resources; we import them by ID).
resource "aws_default_network_acl" "default" {
  default_network_acl_id = aws_vpc.this.default_network_acl_id

  ingress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  ingress {
    protocol         = "-1"
    rule_no          = 101
    action           = "allow"
    ipv6_cidr_block  = "::/0"
    from_port        = 0
    to_port          = 0
  }

  egress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  egress {
    protocol         = "-1"
    rule_no          = 101
    action           = "allow"
    ipv6_cidr_block  = "::/0"
    from_port        = 0
    to_port          = 0
  }

  subnet_ids = [
    aws_subnet.public_us_east_1a.id,
    aws_subnet.public_us_east_1b.id,
    aws_subnet.public_us_east_1c.id,
    aws_subnet.private_us_east_1a.id,
  ]

  tags = {
    Name = "guru-vpc-default"
  }
}

resource "aws_default_route_table" "default" {
  default_route_table_id = aws_vpc.this.default_route_table_id

  tags = {
    Name = "guru-vpc-default"
  }
}

resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "guru-vpc-default"
  }
}

