variable "ami" {}
variable "key_name" {}
variable "vpc_id" {}
variable "nat_security_group_id" {}
variable stackname {}
variable k8s_version {}
variable private_subnets_cidr_blocks {
  type = list
}
variable private_subnets_ids {
  type = list
}

data "aws_region" "current" {}

variable domain {}

variable ingress_port {}

variable feature_gates {}

variable bgp_security_group_id {}
