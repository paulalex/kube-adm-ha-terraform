data "aws_ami" "nat" {
  filter {
    name   = "name"
    values = ["amzn-ami-vpc-nat-hvm-*-x86_64-ebs"]
  }

  most_recent = true
  owners      = ["amazon"]
}

resource "aws_instance" "nat" {
  ami                    = data.aws_ami.nat.id
  instance_type          = "t2.micro"
  subnet_id              = module.vpc.public_subnets[0]
  source_dest_check      = false
  key_name               = var.ec2_key_name
  vpc_security_group_ids = [aws_security_group.nat.id]
  tags = {
    Name = format("%s%s", var.stack_identifier, "-nat")
  }
}

data "external" "myipaddr" {
  program = ["bash", "-c", "curl -s 'https://api.ipify.org?format=json'"]
}

resource "aws_security_group" "nat" {
  name        = format("%s%s", var.stack_identifier, "-sg-nat")
  description = "SG for nat instance"
  vpc_id      = module.vpc.vpc_id
}

resource "aws_security_group_rule" "ssh_in_nat" {
  type      = "ingress"
  from_port = 22
  to_port   = 22
  protocol  = "tcp"
  // Opening to 0.0.0.0/0 can lead to security vulnerabilities.
  cidr_blocks = [format("%s/%s", data.external.myipaddr.result.ip, "32")]

  security_group_id = aws_security_group.nat.id
}

resource "aws_security_group_rule" "priv_in_nat" {
  type        = "ingress"
  from_port   = 0
  to_port     = 0
  protocol    = -1
  cidr_blocks = module.vpc.private_subnets_cidr_blocks

  security_group_id = aws_security_group.nat.id
}

resource "aws_security_group_rule" "egress_all_nat" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.nat.id
}


resource "aws_route" "r" {
  count                  = length(module.vpc.private_route_table_ids)
  route_table_id         = module.vpc.private_route_table_ids[count.index]
  destination_cidr_block = "0.0.0.0/0"
  instance_id            = aws_instance.nat.id
}





