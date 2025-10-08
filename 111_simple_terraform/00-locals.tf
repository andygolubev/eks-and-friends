data "aws_availability_zones" "available" {
  state = "available"
}
locals {
  env         = "dev"
  region      = "us-east-1"
  first_3_azs = slice(data.aws_availability_zones.available.names, 0, 3)
  eks_name    = "myeks"
  eks_version = "1.33"
}