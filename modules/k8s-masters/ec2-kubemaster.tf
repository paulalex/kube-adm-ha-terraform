resource "aws_instance" "kubemaster" {
  count                  = "3"
  ami                    = var.ami
  iam_instance_profile   = "${aws_iam_instance_profile.kubemaster-instance-profile.id}"
  instance_type          = "t2.medium"
  key_name               = "${var.key_name}"
  subnet_id              = var.private_subnets_ids[count.index]
  source_dest_check      = false
  vpc_security_group_ids = [aws_security_group.kubemaster.id, var.bgp_security_group_id]
  tags = {
    Name                                          = "${var.stackname}-kubemaster${count.index}"
    Kuberole                                      = "master"
    "kubernetes.io/cluster/kube-${var.stackname}" = "owned"
  }
  user_data = <<EOF
${local.master_user_data}

%{if count.index == 0}
${local.k8s-init-master-sh}
%{else}
${local.k8s-join-controlplane-sh}
%{endif}
EOF
  lifecycle {
    create_before_destroy = true
    ignore_changes        = ["user_data"]
  }
}


locals {
  master_user_data = <<USERDATA
#!/usr/bin/env bash

# Install AWSCLI
yum -y install python3-pip
pip3 install awscli
cat << EOF >> ~/.bash_profile
PATH=$${PATH}:/usr/local/bin
export PATH
EOF


# turn off swap
swapoff -a
 
# comment out swap line from fstab
sed -i.bak 's/\(.*swap.*\)/#\1/' /etc/fstab
 
# set up kubernetes repo file
cat << 'EOF' > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF
 
# set up k8s sysctl config
cat << 'EOF' > /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
 
# setup docker repo, install
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
yum -y install docker
 
# change deafult logging to json file
sed -i.bak 's/--log-driver=.\+\ /--log-driver=json-file\ /g'  /etc/sysconfig/docker
 
# enable and start docker
systemctl enable docker
systemctl restart docker
 
# configure selinux to be permissive
setenforce 0 && sed -i.bak 's/^SELINUX=.*/SELINUX=permissive/g' /etc/selinux/config
 
# update sysctl settings
sysctl --system
 
# install kubernetes components
yum -y install kubectl-${var.k8s_version} kubeadm-${var.k8s_version} kubelet-${var.k8s_version} kubernetes-cni
systemctl enable kubelet

cat << 'EOF' > /usr/lib/systemd/system/kubelet.service.d/10-kubeadm.conf
# Note: This dropin only works with kubeadm and kubelet v1.11+
[Service]
Environment="KUBELET_KUBECONFIG_ARGS=--bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf --kubeconfig=/etc/kubernetes/kubelet.conf --cloud-provider=aws"
Environment="KUBELET_CONFIG_ARGS=--config=/var/lib/kubelet/config.yaml"
# This is a file that "kubeadm init" and "kubeadm join" generates at runtime, populating the KUBELET_KUBEADM_ARGS variable dynamically
EnvironmentFile=-/var/lib/kubelet/kubeadm-flags.env
# This is a file that the user can use for overrides of the kubelet args as a last resort. Preferably, the user should use
# the .NodeRegistration.KubeletExtraArgs object in the configuration files instead. KUBELET_EXTRA_ARGS should be sourced from this file.
EnvironmentFile=-/etc/sysconfig/kubelet
ExecStart=
ExecStart=/usr/bin/kubelet $KUBELET_KUBECONFIG_ARGS $KUBELET_CONFIG_ARGS $KUBELET_KUBEADM_ARGS $KUBELET_EXTRA_ARGS
EOF
 
cat << 'EOF' > /usr/lib/systemd/system/kubelet.service.d/11-cgroups.conf
[Service]
CPUAccounting=true
MemoryAccounting=true
EOF

systemctl daemon-reload
systemctl restart kubelet

USERDATA


}


resource "aws_security_group" "kubemaster" {
  name        = join("", [var.stackname, "-sg-kubemaster"])
  description = "Security Group for kubemaster instances"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group_rule" "ssh" {
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  source_security_group_id = var.nat_security_group_id
  security_group_id        = aws_security_group.kubemaster.id
}

resource "aws_security_group_rule" "api_1" {
  type                     = "ingress"
  from_port                = 6443
  to_port                  = 6443
  protocol                 = "tcp"
  source_security_group_id = var.nat_security_group_id
  security_group_id        = aws_security_group.kubemaster.id
}

resource "aws_security_group_rule" "api_2" {
  type              = "ingress"
  from_port         = 6443
  to_port           = 6443
  protocol          = "tcp"
  security_group_id = aws_security_group.kubemaster.id
  cidr_blocks       = var.private_subnets_cidr_blocks
}

resource "aws_security_group_rule" "self" {
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = -1
  security_group_id = aws_security_group.kubemaster.id
  self              = true
}



