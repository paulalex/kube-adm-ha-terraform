# TERRAFORM-KUBEADM-HA

This is a Terraform repo for building a Highly Available K8S cluster in AWS using kubeadm

## Building Infrastructure
    
* Update backend config in backends/example.hcl
* Update variables in tfvars/example.tfvars
* Initialize Terraform

        terraform init -backend-config=backends/example.hcl
* Apply terraform

        terraform apply -var-file=tfvars/example.tfvars
        
The cluster will take around 5 minutes to build

## Accessing the HA Control Plane

* ssh to the NAT server ensuring the authentication is forwarded (-A)

        ssh -A ec2-user@[NAT Public Address]
* From the NAT server ssh to a control plane node again ensuring that the authentication is forwarded (-A)

        ssh -A centos@[kubemaster private address]

