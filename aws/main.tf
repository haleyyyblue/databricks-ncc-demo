terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
    databricks = {
      source  = "databricks/databricks"
      version = "~> 1.40"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Databricks provider for account-level resources
provider "databricks" {
  alias           = "account"
  host            = "https://accounts.cloud.databricks.com"
  account_id      = var.databricks_account_id
  client_id       = var.databricks_client_id
  client_secret   = var.databricks_client_secret
}

# Common tags for all resources (corporate compliance)
locals {
  prefix = "${var.project_name}-${var.environment}"

  common_tags = {
    Owner       = "${var.user_name}@${var.company_domain}"
    Environment = var.environment
    RemoveAfter = var.remove_after
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }

  # Configuration validation checks
  validate_private_subnet_configuration = !var.assign_public_ip_to_ec2 && !var.enable_nat_gateway && var.enable_mysql_proxy ? (
    file("ERROR: EC2 in private subnet without NAT Gateway cannot install required packages (mysql, socat). Set enable_nat_gateway=true or assign_public_ip_to_ec2=true.")
  ) : null

  validate_privatelink_prerequisites = var.enable_endpoint_service && (!var.enable_mysql_proxy || !var.enable_nlb) ? (
    file("ERROR: PrivateLink (VPC Endpoint Service) requires both MySQL proxy and NLB to be enabled. Set enable_mysql_proxy=true and enable_nlb=true.")
  ) : null

  validate_nlb_prerequisites = var.enable_nlb && !var.enable_mysql_proxy ? (
    file("ERROR: NLB requires MySQL proxy to be enabled. Set enable_mysql_proxy=true.")
  ) : null

  validate_databricks_ncc_prerequisites = var.enable_databricks_ncc && (!var.enable_mysql_proxy || !var.enable_nlb || !var.enable_endpoint_service) ? (
    file("ERROR: Databricks NCC requires MySQL proxy, NLB, and VPC Endpoint Service. Set enable_mysql_proxy=true, enable_nlb=true, and enable_endpoint_service=true.")
  ) : null

  validate_databricks_account_id = var.enable_databricks_ncc && var.databricks_account_id == "" ? (
    file("ERROR: Databricks NCC requires a valid account ID. Set databricks_account_id in terraform.tfvars.")
  ) : null

  validate_databricks_credentials = var.enable_databricks_ncc && (var.databricks_client_id == "" || var.databricks_client_secret == "") ? (
    file("ERROR: Databricks NCC requires client credentials for authentication. Set databricks_client_id and databricks_client_secret in terraform.tfvars.")
  ) : null
}