# Security Group for RDS
resource "aws_security_group" "rds" {
  name_prefix = "${var.project_name}-${var.environment}-rds-"
  vpc_id      = aws_vpc.main.id
  description = "Security group for RDS MySQL"

  depends_on = [aws_vpc.main, aws_security_group.ec2]

  ingress {
    description     = "MySQL from EC2"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2.id]
  }

  # Additional ingress rule for private subnet CIDR (when EC2 is in private subnet)
  dynamic "ingress" {
    for_each = var.enable_mysql_proxy ? [1] : []
    content {
      description = "MySQL from Private NLB Subnet (CIDR-based)"
      from_port   = 3306
      to_port     = 3306
      protocol    = "tcp"
      cidr_blocks = [var.private_subnet_nlb_cidr]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(local.common_tags, {
    Name = "${local.prefix}-rds-sg"
  })
}

# RDS Subnet Group
resource "aws_db_subnet_group" "rds" {
  name       = "${var.project_name}-${var.environment}-rds-subnet-group"
  subnet_ids = [aws_subnet.private_rds_1.id, aws_subnet.private_rds_2.id]

  depends_on = [aws_subnet.private_rds_1, aws_subnet.private_rds_2]

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(local.common_tags, {
    Name = "${local.prefix}-rds-subnet-group"
  })
}

# RDS MySQL Instance
resource "aws_db_instance" "mysql" {
  identifier     = "${var.project_name}-${var.environment}-mysql"
  engine         = "mysql"
  engine_version = "8.0"
  instance_class = var.rds_instance_class
  
  allocated_storage     = var.rds_allocated_storage
  max_allocated_storage = 100
  storage_type          = "gp2"
  storage_encrypted     = true

  db_name  = "mydb"
  username = var.rds_admin_username
  password = var.rds_admin_password

  db_subnet_group_name   = aws_db_subnet_group.rds.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  
  publicly_accessible = false
  multi_az            = false

  depends_on = [
    aws_db_subnet_group.rds,
    aws_security_group.rds
  ]

  backup_retention_period = 7
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"

  skip_final_snapshot       = true
  delete_automated_backups  = true
  deletion_protection      = false

  lifecycle {
    prevent_destroy = false
    ignore_changes  = [password]
  }

  tags = merge(local.common_tags, {
    Name = "${local.prefix}-mysql"
  })
}

# Database initialization after RDS is ready
# Only works when EC2 is in public subnet (SSH accessible)
resource "null_resource" "db_initialization" {
  count = var.assign_public_ip_to_ec2 ? 1 : 0  # Only for public subnet

  depends_on = [
    aws_db_instance.mysql,
    aws_instance.web
  ]

  # Copy SQL file to EC2 instance
  provisioner "file" {
    source      = "init_db.sql"
    destination = "/tmp/init_db.sql"

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = tls_private_key.ec2_key.private_key_pem
      host        = var.assign_public_ip_to_ec2 ? aws_instance.web.public_ip : aws_instance.web.private_ip
      timeout     = "10m"
    }
  }

  # Initialize database from EC2 instance  
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "ec2-user" 
      private_key = tls_private_key.ec2_key.private_key_pem
      host        = var.assign_public_ip_to_ec2 ? aws_instance.web.public_ip : aws_instance.web.private_ip
      timeout     = "10m"
    }

    inline = [
      "#!/bin/bash",
      "set -x",  # Enable detailed logging
      "LOG_FILE=\"/tmp/terraform_db_init_$(date +%s).log\"",
      "exec > >(tee -a $LOG_FILE) 2>&1",
      "echo '=== Database Initialization Started from EC2 at $(date) ==='",
      "echo 'Log file: '$LOG_FILE",
      "echo 'RDS Address: ${aws_db_instance.mysql.address}'",
      "echo 'RDS Port: ${aws_db_instance.mysql.port}'", 
      "echo 'Username: ${var.rds_admin_username}'",
      "# Create MySQL config file with credentials (more reliable than MYSQL_PWD)",
      "cat > /tmp/mysql.cnf << 'EOF'",
      "[client]",
      "host=${aws_db_instance.mysql.address}",
      "port=${aws_db_instance.mysql.port}",
      "user=${var.rds_admin_username}",
      "password=${var.rds_admin_password}",
      "EOF",
      "chmod 600 /tmp/mysql.cnf",
      "echo '✅ Created MySQL config file'",
      "# Wait for RDS to be ready",
      "echo 'Waiting 60 seconds for RDS to be fully ready...'",
      "sleep 60",
      "# Test basic connectivity first",
      "echo '=== Testing network connectivity ==='",
      "if command -v nc >/dev/null 2>&1; then",
      "  if nc -z ${aws_db_instance.mysql.address} ${aws_db_instance.mysql.port}; then",
      "    echo '✅ Port ${aws_db_instance.mysql.port} is reachable'",
      "  else",
      "    echo '❌ Port ${aws_db_instance.mysql.port} is NOT reachable'",
      "    exit 1",
      "  fi",
      "else",
      "  echo '⚠️ nc command not available, skipping port test'",
      "fi",
      "# Test MySQL connection",
      "echo '=== Testing MySQL connection ==='",
      "if mysql --defaults-file=/tmp/mysql.cnf -e 'SELECT VERSION();' 2>>$LOG_FILE; then",
      "  echo '✅ MySQL connection successful'",
      "  mysql --defaults-file=/tmp/mysql.cnf -e 'SELECT VERSION();'",
      "else",
      "  echo '❌ MySQL connection failed - see full error:'",
      "  mysql --defaults-file=/tmp/mysql.cnf -e 'SELECT VERSION();'",
      "  echo 'Connection failed, exiting...'",
      "  exit 1",
      "fi",
      "# Check if SQL file exists and show content", 
      "echo '=== Checking SQL file ==='",
      "if [ -f '/tmp/init_db.sql' ]; then",
      "  echo '✅ SQL file exists'",
      "  echo \"File size: $(wc -l < /tmp/init_db.sql) lines\"",
      "  echo 'First 10 lines of SQL file:'",
      "  head -10 /tmp/init_db.sql",
      "else",
      "  echo '❌ SQL file not found'",
      "  ls -la /tmp/",
      "  exit 1", 
      "fi",
      "# Execute SQL script",
      "echo '=== Executing SQL script ==='",
      "if mysql --defaults-file=/tmp/mysql.cnf < /tmp/init_db.sql 2>>$LOG_FILE; then",
      "  echo '✅ SQL script executed successfully'",
      "else",
      "  echo '❌ SQL script execution failed - see full error:'",
      "  mysql --defaults-file=/tmp/mysql.cnf < /tmp/init_db.sql",
      "  echo 'Script execution failed, but continuing to check results...'",
      "fi", 
      "# Check what databases exist",
      "echo '=== Checking databases ==='",
      "mysql --defaults-file=/tmp/mysql.cnf -e 'SHOW DATABASES;'",
      "# Check if test database exists",
      "echo '=== Checking test database ==='",
      "if mysql --defaults-file=/tmp/mysql.cnf -e 'USE test; SHOW TABLES;' 2>/dev/null; then",
      "  echo '✅ Test database exists'",
      "  mysql --defaults-file=/tmp/mysql.cnf -e 'USE test; SHOW TABLES;'",
      "else",
      "  echo '❌ Test database does not exist'",
      "  exit 1",
      "fi",
      "# Verify record count",
      "echo '=== Verifying record count ==='",
      "RECORD_COUNT=$(mysql --defaults-file=/tmp/mysql.cnf -sN -e 'SELECT COUNT(*) FROM test.hr;' 2>/dev/null || echo '0')",
      "echo \"Records found: $RECORD_COUNT\"",
      "if [ \"$RECORD_COUNT\" -eq \"10\" ]; then",
      "  echo '✅ Database initialization completely successful! (10 records)'",
      "elif [ \"$RECORD_COUNT\" -gt \"0\" ]; then",
      "  echo '⚠️ Partial success: Expected 10 records, found: '$RECORD_COUNT",
      "  mysql --defaults-file=/tmp/mysql.cnf -e 'SELECT * FROM test.hr LIMIT 3;'",
      "else",
      "  echo '❌ No records found in hr table'",
      "  mysql --defaults-file=/tmp/mysql.cnf -e 'DESCRIBE test.hr;' 2>/dev/null || echo 'hr table does not exist'",
      "fi",
      "# Clean up sensitive files",
      "rm -f /tmp/mysql.cnf",
      "echo '🗑️ Cleaned up config file'",
      "echo '=== Database Initialization Completed at $(date) ==='",
      "echo '📋 Full log saved to: '$LOG_FILE",
      "echo '📋 To view log: cat '$LOG_FILE"
    ]
  }

  # Trigger re-initialization if SQL file changes
  triggers = {
    sql_file_hash = filemd5("init_db.sql")
    rds_endpoint  = aws_db_instance.mysql.endpoint
  }

  lifecycle {
    create_before_destroy = true
  }
}
