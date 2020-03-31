module "kubemasters" {
  source                      = "./modules/k8s-masters"
  ami                         = data.aws_ami.centos.id
  vpc_id                      = module.vpc.vpc_id
  key_name                    = var.ec2_key_name
  stackname                   = var.stack_identifier
  nat_security_group_id       = aws_security_group.nat.id
  k8s_version                 = var.k8s_version
  private_subnets_cidr_blocks = module.vpc.private_subnets_cidr_blocks
  private_subnets_ids         = module.vpc.private_subnets
  domain                      = var.domain
  ingress_port                = var.ingress_port
  feature_gates               = var.feature_gates
  bgp_security_group_id       = aws_security_group.bgp_security_group.id
}

resource "aws_security_group" "bgp_security_group" {
  name        = join("", [var.stack_identifier, "-sg-bgp"])
  description = "Security Group for BGP between nodes"
  vpc_id      = module.vpc.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group_rule" "bgp_self" {
  type              = "ingress"
  from_port         = 179
  to_port           = 179
  protocol          = "tcp"
  self              = true
  security_group_id = aws_security_group.bgp_security_group.id
}

