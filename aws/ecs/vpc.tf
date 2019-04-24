variable "limit_availability_zones" {
  type        = "string"
  description = "Whether we should limit the number of AZs in use to 2"
  default     = "true"
}

variable "availability_zones" {
  type        = "list"
  description = "List of Availability Zones"
  default     = []
}

locals {
  name = "${var.region}"
}

module "vpc" {
  source     = "git::https://github.com/cloudposse/terraform-aws-vpc.git?ref=tags/0.3.4"
  namespace  = "${var.namespace}"
  stage      = "${var.stage}"
  name       = "${local.name}"
  cidr_block = "172.16.0.0/16"
}

data "aws_availability_zones" "available" {}

locals {
  availability_zones       = "${length(var.availability_zones) > 0 ? var.availability_zones : data.aws_availability_zones.available.names}"
  max_availability_zones   = "${var.limit_availability_zones == "true" ? 2 : length(local.availability_zones)}"
  availability_zones_final = "${slice(local.availability_zones, 0, local.max_availability_zones)}"
}

module "subnets" {
  source              = "git::https://github.com/cloudposse/terraform-aws-dynamic-subnets.git?ref=tags/0.8.0"
  availability_zones  = "${local.availability_zones_final}"
  max_subnet_count    = "${local.max_availability_zones}"
  namespace           = "${var.namespace}"
  stage               = "${var.stage}"
  name                = "${local.name}"
  region              = "${var.region}"
  vpc_id              = "${module.vpc.vpc_id}"
  igw_id              = "${module.vpc.igw_id}"
  cidr_block          = "${module.vpc.vpc_cidr_block}"
  nat_gateway_enabled = "true"
}
