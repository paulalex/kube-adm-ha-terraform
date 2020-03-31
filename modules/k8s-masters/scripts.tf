locals {
  k8s-init-master-sh = <<MASTERINIHA
#!/bin/bash

# create master node locally including aws provider
kubeadm init ${local.kubeadm_flags[split(".", var.k8s_version)[1]][0]} --config <(cat << EOF
---
apiVersion: kubeadm.k8s.io/v1beta1
kind: ClusterConfiguration
kubernetesVersion: v${var.k8s_version}
controlPlaneEndpoint: "${aws_alb.control_plane.dns_name}:6443"
apiServer:
  extraArgs:
    cloud-provider: aws
    feature-gates: "ExpandPersistentVolumes=true${var.feature_gates != "" ? ",${var.feature_gates}" : ""}"
controllerManager:
  extraArgs:
    cloud-provider: aws
    configure-cloud-routes: "false"
networking:
  podSubnet: 192.168.0.0/16
---
apiVersion: kubeadm.k8s.io/v1beta1
kind: InitConfiguration
nodeRegistration:
  kubeletExtraArgs:
    cloud-provider: aws
EOF
)

mkdir -p ~/.kube
cp -p /etc/kubernetes/admin.conf ~/.kube/config

# set up the admin config in the bash profile and current environment
export KUBECONFIG=/etc/kubernetes/admin.conf
cat << 'EOF' >> /root/.bash_profile
export KUBECONFIG=/etc/kubernetes/admin.conf
EOF

. /root/.bash_profile

# Lets do 3 passes at setting up some addons - sometimes first pass will fail due to a potential timing issue
# No problems doing multiple passes as its declarative 
for i in 0 1 2
do
  # install calico
  kubectl apply -f https://docs.projectcalico.org/v3.9/manifests/calico.yaml

  # install aws storage class
  kubectl apply -f https://raw.githubusercontent.com/kubernetes/kubernetes/master/cluster/addons/storage-class/aws/default.yaml

  # install Ingress in cluster
  cat << EOF | kubectl apply -f -
${local.ingress_manifests}
EOF
  sleep 5
done

# check node status for the cluster
kubectl get nodes



certificatekey=$(kubeadm init phase upload-certs ${local.kubeadm_flags[split(".", var.k8s_version)[1]][0]} | tail -1)
cat << EOF > /tmp/cp-join.sh
$(kubeadm token create --print-join-command) ${local.kubeadm_flags[split(".", var.k8s_version)[1]][1]} --certificate-key $certificatekey
EOF
aws s3 cp /tmp/cp-join.sh s3://${aws_s3_bucket.scripts.id}/scripts/cp-join-${random_uuid.join.result}.sh

cat << EOF > /tmp/w-join.sh
$(kubeadm token create --print-join-command)
EOF
aws s3 cp /tmp/w-join.sh s3://${aws_s3_bucket.scripts.id}/scripts/w-join-${random_uuid.join.result}.sh

MASTERINIHA

  k8s-join-controlplane-sh = <<JOINCONTROLPLANE
#!/bin/bash

# Wait for API server to be ready
while true
do
  curl -k https://${aws_alb.control_plane.dns_name}:6443 --connect-timeout 10 && break
  sleep 5
done

# Fetch the join script
while true
do
  aws s3 cp s3://${aws_s3_bucket.scripts.id}/scripts/cp-join-${random_uuid.join.result}.sh /usr/local/bin/cp-join.sh && break
  sleep 5
done
chmod u+x /usr/local/bin/cp-join.sh

# Join!
/usr/local/bin/cp-join.sh

JOINCONTROLPLANE

}

locals {
  kubeadm_flags = {
    "14" = ["--experimental-upload-certs", "--experimental-control-plane"]
    "15" = ["--upload-certs", "--control-plane"]
    "16" = ["--upload-certs", "--control-plane"]
    "17" = ["--upload-certs", "--control-plane"]
    "18" = ["--upload-certs", "--control-plane"]
  }
}

resource "random_uuid" "join" {}