# Databricks Network Connectivity Configuration (NCC)
# Only created when Databricks NCC is enabled and VPC Endpoint Service exists

resource "databricks_mws_network_connectivity_config" "ncc" {
  count = var.enable_databricks_ncc && var.enable_mysql_proxy && var.enable_nlb && var.enable_endpoint_service ? 1 : 0

  provider = databricks.account
  name     = "ncc-for-${local.prefix}"
  region   = var.aws_region

  depends_on = [
    aws_vpc_endpoint_service.mysql_privatelink
  ]

  lifecycle {
    create_before_destroy = true
  }
}

# NCC Private Endpoint Rule for MySQL VPC Endpoint Service
resource "databricks_mws_ncc_private_endpoint_rule" "mysql_vpce" {
  count = var.enable_databricks_ncc && var.enable_mysql_proxy && var.enable_nlb && var.enable_endpoint_service ? 1 : 0

  provider                       = databricks.account
  network_connectivity_config_id = databricks_mws_network_connectivity_config.ncc[0].network_connectivity_config_id
  endpoint_service               = aws_vpc_endpoint_service.mysql_privatelink[0].service_name
  domain_names                   = [aws_db_instance.mysql.address]

  depends_on = [
    databricks_mws_network_connectivity_config.ncc,
    aws_vpc_endpoint_service.mysql_privatelink,
    aws_db_instance.mysql
  ]

  lifecycle {
    create_before_destroy = true
  }
}
