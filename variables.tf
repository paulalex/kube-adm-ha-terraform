variable aws_region {}

variable ec2_key_name {}

variable vpc_cidr {}

variable stack_identifier {}


variable k8s_version {}

variable ingress_port {
  default = "80"
}

variable domain {}

variable feature_gates {
  default = ""
}