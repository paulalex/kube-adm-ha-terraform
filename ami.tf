data "aws_ami" "centos" {
  most_recent = true
  name_regex  = "CentOS Linux 7 x86_64 HVM EBS ENA 1901_01*"
  owners      = ["aws-marketplace"]

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}