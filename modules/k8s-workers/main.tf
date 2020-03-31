variable "instance-type" {}

variable "label" {}
variable "node_count" {}

variable "stackname" {}

variable "security_groups" {
  type = "list"
}

variable private_subnets_ids {
  type = list
}

variable "ami" {}

variable "instance_profile" {}

variable "k8s_version" {}

variable "target_group_arn" {
  default = ""
}

variable "taints" {
  default = ""
}

variable "node_labels" {
  default = ""
}

variable key_name {}

variable cluster_join_script {}

variable apiserver_address {}

variable feature_gates {
  default = ""
}




