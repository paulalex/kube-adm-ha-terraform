module "kubeworkers_1" {
  source              = "./modules/k8s-workers"
  ami                 = data.aws_ami.centos.id
  key_name            = var.ec2_key_name
  stackname           = var.stack_identifier
  k8s_version         = var.k8s_version
  private_subnets_ids = module.vpc.private_subnets
  instance-type       = "t2.medium"
  label               = "workers_1"
  security_groups     = [aws_security_group.kubeworker.id, aws_security_group.bgp_security_group.id]
  node_count          = 1
  node_labels         = format("%s/ingress=true", var.domain)
  instance_profile    = aws_iam_instance_profile.kubenode-instance-profile.id
  cluster_join_script = module.kubemasters.cluster_join_script
  apiserver_address   = module.kubemasters.apiserver_address
  target_group_arn    = aws_alb_target_group.ingress.arn
  feature_gates       = var.feature_gates
}

resource "aws_security_group" "kubeworker" {
  name        = join("", [var.stack_identifier, "-sg-kubeworker"])
  description = "Security Group for kube worker instances"
  vpc_id      = module.vpc.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group_rule" "ssh_from_nat" {
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.nat.id
  security_group_id        = aws_security_group.kubeworker.id
}

resource "aws_security_group_rule" "nodeport_from_lb" {
  type                     = "ingress"
  from_port                = var.ingress_port
  to_port                  = var.ingress_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.lb-ext.id
  security_group_id        = aws_security_group.kubeworker.id
}

resource "aws_security_group_rule" "kubelet_from_control_plane" {
  type                     = "ingress"
  from_port                = 10250
  to_port                  = 10250
  protocol                 = "tcp"
  source_security_group_id = module.kubemasters.control_plane_security_group
  security_group_id        = aws_security_group.kubeworker.id
}


resource "aws_iam_role" "kubenode-instance-role" {
  name               = format("%s-kubenode-instance-role", var.stack_identifier)
  path               = "/"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_instance_profile" "kubenode-instance-profile" {
  name = format("%s-kubenode-instance-profile", var.stack_identifier)
  path = "/"
  role = "${aws_iam_role.kubenode-instance-role.name}"
}

resource "aws_iam_role_policy_attachment" "kubenode-instance-role-attachment1" {
  role       = "${aws_iam_role.kubenode-instance-role.name}"
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

resource "aws_iam_policy" "kubenode" {
  name        = format("%s-kubenode-policy", var.stack_identifier)
  path        = "/"
  description = "Policy for kubenode"
  policy      = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "autoscaling:DescribeAutoScalingGroups",
                "autoscaling:DescribeLaunchConfigurations",
                "autoscaling:DescribeTags",
                "ec2:DescribeInstances",
                "ec2:DescribeRegions",
                "ec2:DescribeRouteTables",
                "ec2:DescribeSecurityGroups",
                "ec2:DescribeSubnets",
                "ec2:DescribeVolumes",
                "ec2:CreateSecurityGroup",
                "ec2:CreateTags",
                "ec2:CreateVolume",
                "ec2:ModifyInstanceAttribute",
                "ec2:ModifyVolume",
                "ec2:AttachVolume",
                "ec2:AuthorizeSecurityGroupIngress",
                "ec2:CreateRoute",
                "ec2:DeleteRoute",
                "ec2:DeleteSecurityGroup",
                "ec2:DeleteVolume",
                "ec2:DetachVolume",
                "ec2:RevokeSecurityGroupIngress",
                "ec2:DescribeVpcs",
                "iam:CreateServiceLinkedRole",
                "kms:DescribeKey",
                "ecr:GetAuthorizationToken",
                "ecr:BatchCheckLayerAvailability",
                "ecr:GetDownloadUrlForLayer",
                "ecr:GetRepositoryPolicy",
                "ecr:DescribeRepositories",
                "ecr:ListImages",
                "ecr:BatchGetImage"
            ],
            "Resource": [
                "*"
            ]
        },        {
            "Effect": "Allow",
            "Action": ["s3:GetObject"],
            "Resource": "${module.kubemasters.scripts_bucket_arn}/w-join*"
        }

    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "kubenode-instance-role-attachment2" {
  role       = "${aws_iam_role.kubenode-instance-role.name}"
  policy_arn = "${aws_iam_policy.kubenode.arn}"
}

