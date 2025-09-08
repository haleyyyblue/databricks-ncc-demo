output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "VPC CIDR block"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_id" {
  description = "Public subnet ID for EC2"
  value       = aws_subnet.public.id
}

output "private_rds_subnet_ids" {
  description = "Private subnet IDs for RDS"
  value       = [aws_subnet.private_rds_1.id, aws_subnet.private_rds_2.id]
}

output "private_nlb_subnet_id" {
  description = "Private subnet ID for NLB"
  value       = aws_subnet.private_nlb.id
}

output "ec2_instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.web.id
}

output "ec2_public_ip" {
  description = "EC2 instance public IP (only available if public IP is assigned)"
  value       = var.assign_public_ip_to_ec2 ? aws_instance.web.public_ip : null
}

output "ec2_public_dns" {
  description = "EC2 instance public DNS (only available if public IP is assigned)"
  value       = var.assign_public_ip_to_ec2 ? aws_instance.web.public_dns : null
}

output "ec2_private_ip" {
  description = "EC2 instance private IP"
  value       = aws_instance.web.private_ip
}

output "ec2_subnet_info" {
  description = "EC2 instance subnet information"
  value = {
    subnet_type     = (var.assign_public_ip_to_ec2 ? "public" : "private")
    subnet_id       = (var.assign_public_ip_to_ec2 ? aws_subnet.public.id : aws_subnet.private_nlb.id)
    subnet_cidr     = (var.assign_public_ip_to_ec2 ? aws_subnet.public.cidr_block : aws_subnet.private_nlb.cidr_block)
    has_public_ip   = var.assign_public_ip_to_ec2
    access_type     = (var.assign_public_ip_to_ec2 ? 
      "Public subnet + public IP (internet accessible)" : 
      "Private subnet + private IP only (VPC internal)")
    internet_access = (var.assign_public_ip_to_ec2 ? 
      "Direct via IGW" : 
      (var.enable_nat_gateway ? "Via NAT Gateway" : "No internet access"))
  }
}

output "rds_endpoint" {
  description = "RDS MySQL endpoint"
  value       = aws_db_instance.mysql.endpoint
  sensitive   = true
}

output "rds_port" {
  description = "RDS MySQL port"
  value       = aws_db_instance.mysql.port
}

output "rds_db_name" {
  description = "RDS database name"
  value       = aws_db_instance.mysql.db_name
}

output "ec2_security_group_id" {
  description = "EC2 security group ID"
  value       = aws_security_group.ec2.id
}

output "rds_security_group_id" {
  description = "RDS security group ID"
  value       = aws_security_group.rds.id
}

output "database_connection_command" {
  description = "Command to connect to the MySQL database from EC2"
  value       = "mysql -h ${aws_db_instance.mysql.endpoint} -P ${aws_db_instance.mysql.port} -u ${var.rds_admin_username} -p${var.rds_admin_password}"
  sensitive   = true
}

output "test_database_info" {
  description = "Information about the test database and sample data"
  value = {
    database_name = "test"
    table_name    = "hr"
    sample_query  = "SELECT * FROM test.hr LIMIT 5;"
    total_records = "10 sample employee records"
    initialization_method = (var.assign_public_ip_to_ec2 ? 
      "Terraform provisioner (remote-exec from local machine)" : 
      "EC2 user_data script (executed during boot)")
    initialization_status = (var.assign_public_ip_to_ec2 ? 
      "Check Terraform output for initialization status" : 
      "Check EC2 logs: /var/log/db_init.log and /var/log/setup.log")
    verification_command = "mysql -h [RDS_ENDPOINT] -u admin -p[PASSWORD] -e 'SELECT COUNT(*) FROM test.hr;'"
    ssh_log_check = (var.assign_public_ip_to_ec2 ? 
      null : 
      "ssh ec2-user@[EC2_IP] 'cat /var/log/db_init.log'")
  }
}

output "mysql_proxy_info" {
  description = "MySQL proxy connection information (only if enabled)"
  value = var.enable_mysql_proxy ? {
    proxy_enabled    = true
    has_public_ip    = var.assign_public_ip_to_ec2
    proxy_endpoint   = var.assign_public_ip_to_ec2 ? "${aws_instance.web.public_ip}:3306" : "${aws_instance.web.private_ip}:3306"
    target_rds       = "${aws_db_instance.mysql.address}:${aws_db_instance.mysql.port}"
    connection_cmd   = var.assign_public_ip_to_ec2 ? "mysql -h ${aws_instance.web.public_ip} -P 3306 -u ${var.rds_admin_username} -p${var.rds_admin_password}" : "mysql -h ${aws_instance.web.private_ip} -P 3306 -u ${var.rds_admin_username} -p${var.rds_admin_password}"
    status_check_cmd = var.assign_public_ip_to_ec2 ? "ssh -i your-key.pem ec2-user@${aws_instance.web.public_ip} 'sudo /usr/local/bin/mysql-proxy-status.sh'" : "ssh -i your-key.pem ec2-user@${aws_instance.web.private_ip} 'sudo /usr/local/bin/mysql-proxy-status.sh'"
    access_note     = var.assign_public_ip_to_ec2 ? "Direct internet access available" : "VPC internal access only - use bastion host, VPN, or NLB"
  } : {
    proxy_enabled = false
    message       = "MySQL proxy is disabled. Set enable_mysql_proxy = true to enable."
  }
  sensitive = true
}

output "nlb_info" {
  description = "Network Load Balancer information (only if enabled)"
  value = var.enable_mysql_proxy && var.enable_nlb ? {
    nlb_enabled       = true
    nlb_dns_name      = aws_lb.mysql_nlb[0].dns_name
    nlb_zone_id       = aws_lb.mysql_nlb[0].zone_id
    nlb_internal_ip   = aws_lb.mysql_nlb[0].dns_name  # NLB internal DNS
    target_group_arn  = aws_lb_target_group.mysql_proxy[0].arn
    connection_cmd    = "mysql -h ${aws_lb.mysql_nlb[0].dns_name} -P 3306 -u ${var.rds_admin_username} -p${var.rds_admin_password}"
    health_check_url  = "Check target group health in AWS Console"
    access_pattern    = "VPC Internal → NLB:3306 → EC2:3306 → RDS:3306"
  } : {
    nlb_enabled = false
    message     = var.enable_mysql_proxy ? "NLB is disabled. Set enable_nlb = true to enable." : "Enable mysql_proxy first, then set enable_nlb = true."
  }
  sensitive = true
}

# SSH Key Information
output "ssh_key_info" {
  description = "SSH key information for EC2 access"
  value = {
    key_name           = aws_key_pair.ec2_key_pair.key_name
    private_key_file   = local_file.private_key.filename
    key_fingerprint    = aws_key_pair.ec2_key_pair.fingerprint
    ssh_command        = (var.assign_public_ip_to_ec2 ? 
      "ssh -i ${local_file.private_key.filename} ec2-user@${aws_instance.web.public_ip}" : 
      "ssh -i ${local_file.private_key.filename} ec2-user@${aws_instance.web.private_ip}")
    note              = "Private key file has been automatically generated and saved locally"
  }
}

# VPC Endpoint Service Information
output "endpoint_service_info" {
  description = "VPC Endpoint Service information for PrivateLink access"
  value = var.enable_mysql_proxy && var.enable_nlb && var.enable_endpoint_service ? {
    endpoint_service_enabled = true
    service_name            = aws_vpc_endpoint_service.mysql_privatelink[0].service_name
    service_id              = aws_vpc_endpoint_service.mysql_privatelink[0].id
    service_type            = aws_vpc_endpoint_service.mysql_privatelink[0].service_type
    acceptance_required     = aws_vpc_endpoint_service.mysql_privatelink[0].acceptance_required
    allowed_principals      = var.endpoint_service_allowed_principals
    base_endpoint_dns_names = aws_vpc_endpoint_service.mysql_privatelink[0].base_endpoint_dns_names
    connection_guide        = "Create VPC endpoint in target account/VPC using service name above"
    access_pattern          = "Target VPC → VPC Endpoint → PrivateLink → NLB:3306 → EC2:3306 → RDS:3306"
    message                 = "VPC Endpoint Service is active and ready for connections"
  } : {
    endpoint_service_enabled = false
    service_name            = null
    service_id              = null
    service_type            = null
    acceptance_required     = null
    allowed_principals      = null
    base_endpoint_dns_names = null
    connection_guide        = null
    access_pattern          = null
    message                 = (var.enable_mysql_proxy && var.enable_nlb ? 
      "Endpoint Service is disabled. Set enable_endpoint_service = true to enable PrivateLink." : 
      "Enable mysql_proxy and nlb first, then set enable_endpoint_service = true.")
  }
}

# Database Connection Information  
output "database_endpoint" {
  description = "RDS MySQL endpoint with port (sensitive)"
  value       = aws_db_instance.mysql.endpoint
  sensitive   = true
}

output "database_address" {
  description = "RDS MySQL address only (without port, for debugging)"
  value       = aws_db_instance.mysql.address  
  sensitive   = true
}

output "database_port" {
  description = "RDS MySQL port"
  value       = aws_db_instance.mysql.port
}

# Databricks Network Connectivity Configuration Information
output "databricks_ncc_info" {
  description = "Databricks Network Connectivity Configuration information"
  value = var.enable_databricks_ncc && var.enable_mysql_proxy && var.enable_nlb && var.enable_endpoint_service ? {
    ncc_enabled                  = true
    ncc_id                      = databricks_mws_network_connectivity_config.ncc[0].network_connectivity_config_id
    ncc_name                    = databricks_mws_network_connectivity_config.ncc[0].name
    ncc_region                  = databricks_mws_network_connectivity_config.ncc[0].region
    ncc_creation_time           = databricks_mws_network_connectivity_config.ncc[0].creation_time
    vpc_endpoint_service_name   = aws_vpc_endpoint_service.mysql_privatelink[0].service_name
    mysql_endpoint_rule_created = true
    mysql_domain_name          = aws_db_instance.mysql.address
    databricks_account_id       = var.databricks_account_id
    authentication_method       = "OAuth Client Credentials"
    usage_guide                 = "Use this NCC in Databricks workspace creation for private MySQL connectivity"
    mysql_connection_pattern    = "Databricks → NCC → PrivateLink → NLB:3306 → EC2:3306 → RDS:3306"
    message                     = null
  } : {
    ncc_enabled                  = false
    ncc_id                      = null
    ncc_name                    = null
    ncc_region                  = null
    ncc_creation_time           = null
    vpc_endpoint_service_name   = null
    mysql_endpoint_rule_created = false
    mysql_domain_name          = null
    databricks_account_id       = null
    authentication_method       = null
    usage_guide                 = null
    mysql_connection_pattern    = null
    message                     = (var.enable_databricks_ncc ? 
      (var.enable_mysql_proxy && var.enable_nlb && var.enable_endpoint_service ? 
        "Enable all prerequisites: mysql_proxy, nlb, and endpoint_service" : 
        "Set databricks_account_id in terraform.tfvars and enable_databricks_ncc = true") : 
      "Set enable_databricks_ncc = true to enable Databricks NCC")
    prerequisites = [
      "enable_mysql_proxy = true",
      "enable_nlb = true", 
      "enable_endpoint_service = true",
      "Set valid databricks_account_id in terraform.tfvars",
      "Set databricks_client_id and databricks_client_secret for OAuth authentication"
    ]
  }
}
