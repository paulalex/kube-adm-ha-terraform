resource "aws_launch_template" "k8s_worker" {
  name_prefix   = "k8s_worker"
  instance_type = "${var.instance-type}"

  vpc_security_group_ids = var.security_groups
  image_id               = var.ami
  key_name               = var.key_name
  user_data              = base64encode(join("\n", [local.node_user_data, local.k8s-join-cluster-sh]))
  iam_instance_profile {
    name = "${var.instance_profile}"
  }
  tag_specifications {
    resource_type = "instance"

    tags = {
      Name                         = "${var.stackname}-kubenode-${var.label}"
      Kuberole                     = "node"
      "kubernetes.io/cluster/kube" = "owned"
    }
  }
}

resource "aws_autoscaling_group" "asg" {
  name                = format("%s-asg", var.label)
  desired_capacity    = var.node_count
  max_size            = var.node_count + 1
  min_size            = var.node_count
  vpc_zone_identifier = var.private_subnets_ids
  target_group_arns   = ["${var.target_group_arn}"]
  health_check_type   = "EC2"
  launch_template {
    id      = aws_launch_template.k8s_worker.id
    version = "$Latest"
  }
}


locals {
  node_user_data = <<USERDATA
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

  k8s-join-cluster-sh = <<JOINCLUSTER
#!/bin/bash

# Wait for API server to be ready
while true
do
  curl -k https://${var.apiserver_address}:6443 --connect-timeout 10 && break
  sleep 5
done

# Fetch the join script
while true
do
  aws s3 cp ${var.cluster_join_script} /usr/local/bin/w-join.sh && break
  sleep 5
done
chmod u+x /usr/local/bin/w-join.sh

# set up the kubelet extra args
KUBELET_EXTRA_ARGS='--cloud-provider=aws --healthz-bind-address=0.0.0.0 --kube-reserved=memory=500Mi --system-reserved=memory=500Mi --enforce-node-allocatable=pods${var.node_labels != "" ? " --node-labels=${var.node_labels}" : ""}${var.taints != "" ? " --register-with-taints=${var.taints}" : ""}${var.feature_gates != "" ? " --feature-gates=${var.feature_gates}" : ""}'

cat << EOF > /etc/sysconfig/kubelet
KUBELET_EXTRA_ARGS='$${KUBELET_EXTRA_ARGS}'
EOF

# Join!
/usr/local/bin/w-join.sh

JOINCLUSTER

}


