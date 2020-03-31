# https://github.com/terraform-providers/terraform-provider-aws/releases
provider "aws" {
  version = "~> 2.50.0"
  region  = var.aws_region
}

# https://github.com/terraform-providers/terraform-provider-external/releases
provider "external" {
  version = "~> 1.2.0"
}



# https://github.com/terraform-providers/terraform-provider-template/releases
provider "template" {
  version = "~> 2.1.2"
}
