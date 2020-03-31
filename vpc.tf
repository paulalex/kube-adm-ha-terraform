module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "2.25.0"

  name = format("%s%s", var.stack_identifier, "-vpc")
  cidr = var.vpc_cidr

  azs             = data.aws_availability_zones.available.names
  private_subnets = "${length(local.private_subnets) > 2 ? slice(local.private_subnets, 0, 3) : local.private_subnets}"
  public_subnets  = "${length(local.public_subnets) > 2 ? slice(local.public_subnets, 0, 3) : local.public_subnets}"

  enable_nat_gateway = false
  enable_vpn_gateway = false

  enable_dns_hostnames = true

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  private_subnets = [
    for i, entry in data.aws_availability_zones.available.names :
    cidrsubnet(var.vpc_cidr, 8, i)
  ]
  public_subnets = [
    for i, entry in data.aws_availability_zones.available.names :
    cidrsubnet(var.vpc_cidr, 8, 100 + i)
  ]
}

