terraform {
  required_version = ">= 0.11.2"
  backend          "s3"             {}
}

provider "aws" {
  assume_role {
    role_arn = "${var.aws_assume_role_arn}"
  }
}

module "kops_metadata" {
  source       = "git::https://github.com/cloudposse/terraform-aws-kops-data-iam.git?ref=tags/0.1.0"
  cluster_name = "${var.cluster_name}"
}

module "kops_vpc" {
  source       = "git::https://github.com/cloudposse/terraform-aws-kops-data-network.git?ref=tags/0.1.1"
  cluster_name = "${var.cluster_name}"
  vpc_id       = "${var.vpc_id}"
}

data "aws_route53_zone" "default" {
  name = "${var.zone_name == "" ? var.cluster_name : var.zone_name}"
}

locals {
  zone_id    = "${data.aws_route53_zone.default.zone_id}"
  subnet_ids = ["${slice(module.kops_vpc.private_subnet_ids, 0, min(2, length(module.kops_vpc.private_subnet_ids)))}"]
}

locals {
  role_arns = {
    masters = ["${module.kops_metadata.masters_role_arn}"]
    nodes   = ["${module.kops_metadata.nodes_role_arn}"]
    both    = ["${module.kops_metadata.masters_role_arn}", "${module.kops_metadata.nodes_role_arn}"]
    any     = ["*"]
    none    = []
  }

  security_groups = {
    masters = ["${module.kops_vpc.masters_security_group_id}"]
    nodes   = ["${module.kops_vpc.nodes_security_group_id}"]
    both    = ["${module.kops_vpc.masters_security_group_id}", "${module.kops_vpc.nodes_security_group_id}"]
    any     = ["${module.kops_vpc.masters_security_group_id}", "${module.kops_vpc.nodes_security_group_id}"]
    none    = []
  }

  option_keys = {
    masters = "masters"
    nodes   = "nodes"
    both    = "both"
    any     = "any"
  }
}

module "elasticsearch" {
  source                          = "git::https://github.com/cloudposse/terraform-aws-elasticsearch.git?ref=tags/0.3.0"
  namespace                       = "${var.namespace}"
  stage                           = "${var.stage}"
  name                            = "${var.elasticsearch_name}"
  dns_zone_id                     = "${local.zone_id}"
  security_groups                 = ["${local.security_groups[var.elasticsearch_network_permitted_nodes]}"]
  vpc_id                          = "${module.kops_vpc.vpc_id}"
  subnet_ids                      = "${local.subnet_ids}"
  zone_awareness_enabled          = "${length(module.kops_vpc.private_subnet_ids) > 1 ? "true" : "false"}"
  elasticsearch_version           = "${var.elasticsearch_version}"
  instance_type                   = "${var.elasticsearch_instance_type}"
  instance_count                  = "${var.elasticsearch_instance_count}"
  iam_role_arns                   = ["${local.role_arns[var.elasticsearch_iam_permitted_nodes]}"]
  iam_authorizing_role_arns       = "${coalescelist(local.role_arns[lookup(local.option_keys, var.elasticsearch_iam_authorizing_role_arn, "none")], list(var.elasticsearch_iam_authorizing_role_arn))}"
  iam_actions                     = ["${var.elasticsearch_iam_actions}"]
  kibana_subdomain_name           = "kibana-elasticsearch"
  ebs_volume_size                 = "${var.elasticsearch_ebs_volume_size}"
  encrypt_at_rest_enabled         = "${var.elasticsearch_encrypt_at_rest_enabled}"
  node_to_node_encryption_enabled = "${var.elasticsearch_node_to_node_encryption_enabled}"
  enabled                         = "${var.elasticsearch_enabled}"

  advanced_options {
    "rest.action.multi.allow_explicit_index" = "true"
  }
}

output "elasticsearch_security_group_id" {
  value       = "${module.elasticsearch.security_group_id}"
  description = "Security Group ID to control access to the Elasticsearch domain"
}

output "elasticsearch_domain_arn" {
  value       = "${module.elasticsearch.domain_arn}"
  description = "ARN of the Elasticsearch domain"
}

output "elasticsearch_domain_id" {
  value       = "${module.elasticsearch.domain_id}"
  description = "Unique identifier for the Elasticsearch domain"
}

output "elasticsearch_domain_endpoint" {
  value       = "${module.elasticsearch.domain_endpoint}"
  description = "Domain-specific endpoint used to submit index, search, and data upload requests"
}

output "elasticsearch_kibana_endpoint" {
  value       = "${module.elasticsearch.kibana_endpoint}"
  description = "Domain-specific endpoint for Kibana without https scheme"
}

output "elasticsearch_domain_hostname" {
  value       = "${module.elasticsearch.domain_hostname}"
  description = "Elasticsearch domain hostname to submit index, search, and data upload requests"
}

output "elasticsearch_kibana_hostname" {
  value       = "${module.elasticsearch.kibana_hostname}"
  description = "Kibana hostname"
}

output "elasticsearch_user_iam_role_name" {
  value       = "${module.elasticsearch.elasticsearch_user_iam_role_name}"
  description = "IAM name of role for Elasticsearch users"
}

output "elasticsearch_user_iam_role_arn" {
  value       = "${module.elasticsearch.elasticsearch_user_iam_role_arn}"
  description = "IAM ARN of role for Elasticsearch users"
}

module "elasticsearch_log_cleanup" {
  source    = "git::https://github.com/cloudposse/terraform-aws-lambda-elasticsearch-cleanup.git?ref=tags/0.2.0"
  enabled   = "${var.elasticsearch_enabled == "true" ? var.elasticsearch_log_cleanup_enabled : "false"}"
  namespace = "${var.namespace}"
  stage     = "${var.stage}"
  name      = "${var.elasticsearch_name}"

  es_endpoint          = "${module.elasticsearch.domain_endpoint}"
  es_domain_arn        = "${module.elasticsearch.domain_arn}"
  es_security_group_id = "${module.elasticsearch.security_group_id}"
  vpc_id               = "${module.kops_vpc.vpc_id}"
  subnet_ids           = "${local.subnet_ids}"

  index        = "${var.elasticsearch_log_index_name}"
  delete_after = "${var.elasticsearch_log_retention_days}"
}
