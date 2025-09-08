# Data source for getting Amazon Linux 2 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# Security Group for EC2
resource "aws_security_group" "ec2" {
  name_prefix = "${var.project_name}-${var.environment}-ec2-"
  vpc_id      = aws_vpc.main.id
  description = "Security group for EC2 instance"

  depends_on = [aws_vpc.main]

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ec2_ssh_allowed_cidrs
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.ec2_web_allowed_cidrs
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.ec2_web_allowed_cidrs
  }

  # Conditional MySQL proxy port (only if enabled)
  dynamic "ingress" {
    for_each = var.enable_mysql_proxy ? [1] : []
    content {
      description = "MySQL Proxy"
      from_port   = 3306
      to_port     = 3306
      protocol    = "tcp"
      cidr_blocks = var.mysql_proxy_allowed_cidrs
    }
  }

  # Conditional MySQL proxy access from NLB subnet (only if both MySQL proxy and NLB are enabled)
  dynamic "ingress" {
    for_each = var.enable_mysql_proxy && var.enable_nlb ? [1] : []
    content {
      description = "MySQL Proxy from NLB Subnet"
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
    Name = "${local.prefix}-ec2-sg"
  })
}

# EC2 Instance
resource "aws_instance" "web" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.ec2_instance_type
  # Choose subnet based on user preference
  subnet_id              = var.assign_public_ip_to_ec2 ? aws_subnet.public.id : aws_subnet.private_nlb.id
  vpc_security_group_ids = [aws_security_group.ec2.id]
  key_name               = aws_key_pair.ec2_key_pair.key_name
  
  # Assign public IP only when in public subnet
  associate_public_ip_address = var.assign_public_ip_to_ec2

  depends_on = [
    aws_subnet.public,
    aws_subnet.private_nlb,  # Need private subnet as option
    aws_security_group.ec2,
    aws_internet_gateway.main,
    aws_db_instance.mysql,
    aws_key_pair.ec2_key_pair
  ]

  user_data = base64encode(<<-EOF
              #!/bin/bash
              yum update -y
              
              # Install web server and MySQL client
              yum install -y httpd mysql
              
              # Install tools for MySQL proxy (conditional)
              ${var.enable_mysql_proxy ? "yum install -y socat nmap-ncat" : "# MySQL proxy tools not installed (MySQL proxy disabled)"}
              
              # Start and enable Apache
              systemctl start httpd
              systemctl enable httpd
              
              # Create a simple web page with database info
              cat > /var/www/html/index.html << 'HTML'
<!DOCTYPE html>
<html>
<head>
    <title>AWS Infrastructure Test</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .container { max-width: 800px; margin: 0 auto; }
        .header { background: #f0f0f0; padding: 20px; border-radius: 5px; }
        .section { margin: 20px 0; padding: 15px; border: 1px solid #ddd; border-radius: 5px; }
        .code { background: #f8f8f8; padding: 10px; font-family: monospace; border-radius: 3px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚀 AWS Infrastructure Test Page</h1>
            <p>Infrastructure successfully deployed with Terraform!</p>
        </div>
        
        <div class="section">
            <h2>📊 Database Connection Test</h2>
            <p>To test the MySQL database connection:</p>
            <div class="code">
                mysql -h [RDS_ENDPOINT] -P 3306 -u admin -p<br/>
                USE test;<br/>
                SELECT * FROM hr LIMIT 5;
            </div>
        </div>
        
        <div class="section">
            <h2>🏗️ Infrastructure Components</h2>
            <ul>
                <li>✅ VPC with public and private subnets</li>
                <li>✅ EC2 instance with web server</li>
                <li>✅ RDS MySQL with test database</li>
                <li>✅ Security groups with controlled access</li>
            </ul>
        </div>
        
        <div class="section">
            <h2>👨‍💼 Sample HR Data</h2>
            <p>The database includes a 'test.hr' table with 10 sample employee records for testing purposes.</p>
        </div>
    </div>
</body>
</html>
HTML
              
              ${var.enable_mysql_proxy ? <<-PROXY
              # Setup MySQL Proxy (forwards EC2:3306 to RDS:3306)
              echo "Setting up MySQL proxy to RDS..." >> /var/log/setup.log
              
              # Wait for RDS to be fully available
              echo "Waiting for RDS to be ready..."
              while ! nc -z ${aws_db_instance.mysql.address} ${aws_db_instance.mysql.port}; do
                echo "Waiting for RDS connection..."
                sleep 10
              done
              
              # Start MySQL proxy using socat
              echo "Starting MySQL proxy: EC2:3306 -> RDS:${aws_db_instance.mysql.address}:${aws_db_instance.mysql.port}"
              nohup socat TCP-LISTEN:3306,fork TCP:${aws_db_instance.mysql.address}:${aws_db_instance.mysql.port} > /var/log/mysql-proxy.log 2>&1 &
              
              # Save proxy PID for management
              echo $! > /var/run/mysql-proxy.pid
              
              # Create proxy management script
              cat > /usr/local/bin/mysql-proxy-status.sh << 'SCRIPT'
              #!/bin/bash
              if [ -f /var/run/mysql-proxy.pid ]; then
                PID=$(cat /var/run/mysql-proxy.pid)
                if ps -p $PID > /dev/null; then
                  echo "MySQL Proxy is running (PID: $PID)"
                  echo "Forwarding EC2:3306 -> RDS:${aws_db_instance.mysql.address}:${aws_db_instance.mysql.port}"
                else
                  echo "MySQL Proxy is not running"
                fi
              else
                echo "MySQL Proxy PID file not found"
              fi
              SCRIPT
              chmod +x /usr/local/bin/mysql-proxy-status.sh
              
              echo "MySQL proxy setup completed at $(date)" >> /var/log/setup.log
              PROXY
              : ""}
              
              # Database initialization (for private subnet only)
              ${!var.assign_public_ip_to_ec2 ? <<-DB_INIT
              echo "Initializing database from EC2 (private subnet mode) at $(date)" >> /var/log/setup.log
              
              # Create SQL initialization script
              cat > /tmp/init_db.sql << 'SQL'
              CREATE DATABASE IF NOT EXISTS test;
              USE test;
              
              CREATE TABLE IF NOT EXISTS hr (
                  id INT AUTO_INCREMENT PRIMARY KEY,
                  name VARCHAR(100) NOT NULL,
                  department VARCHAR(50) NOT NULL,
                  position VARCHAR(50) NOT NULL,
                  salary DECIMAL(10, 2),
                  hire_date DATE,
                  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
              );
              
              INSERT IGNORE INTO hr (id, name, department, position, salary, hire_date) VALUES
              (1, 'Alice Johnson', 'Engineering', 'Senior Developer', 95000.00, '2022-01-15'),
              (2, 'Bob Smith', 'Engineering', 'DevOps Engineer', 87000.00, '2022-02-01'),
              (3, 'Carol Davis', 'Data Science', 'Data Scientist', 92000.00, '2022-02-15'),
              (4, 'David Wilson', 'Data Science', 'ML Engineer', 89000.00, '2022-03-01'),
              (5, 'Emma Brown', 'Product', 'Product Manager', 105000.00, '2021-12-01'),
              (6, 'Frank Miller', 'Engineering', 'Frontend Developer', 78000.00, '2022-03-15'),
              (7, 'Grace Lee', 'Data Science', 'Analytics Engineer', 85000.00, '2022-04-01'),
              (8, 'Henry Taylor', 'Engineering', 'Backend Developer', 82000.00, '2022-04-15'),
              (9, 'Ivy Chen', 'Product', 'UX Designer', 75000.00, '2022-05-01'),
              (10, 'Jack Anderson', 'Engineering', 'QA Engineer', 72000.00, '2022-05-15');
              SQL
              
              # Wait for RDS to be ready (longer wait for private subnet)
              echo "Waiting for RDS to be ready..." >> /var/log/setup.log
              sleep 120
              
              # Create MySQL config file for authentication
              cat > /tmp/mysql.cnf << 'MYSQL_CFG'
              [client]
              host=${aws_db_instance.mysql.address}
              port=${aws_db_instance.mysql.port}
              user=${var.rds_admin_username}
              password=${var.rds_admin_password}
              MYSQL_CFG
              chmod 600 /tmp/mysql.cnf
              
              # Test connection and initialize database
              DB_INIT_LOG="/var/log/db_init.log"
              echo "=== Database Initialization Started at $(date) ===" >> $DB_INIT_LOG
              
              # Test connectivity
              if command -v nc >/dev/null 2>&1; then
                if nc -z ${aws_db_instance.mysql.address} ${aws_db_instance.mysql.port}; then
                  echo "✅ RDS port is reachable" >> $DB_INIT_LOG
                else
                  echo "❌ RDS port is not reachable" >> $DB_INIT_LOG
                fi
              fi
              
              # Test MySQL connection
              if mysql --defaults-file=/tmp/mysql.cnf -e 'SELECT VERSION();' >> $DB_INIT_LOG 2>&1; then
                echo "✅ MySQL connection successful" >> $DB_INIT_LOG
                
                # Execute SQL script
                if mysql --defaults-file=/tmp/mysql.cnf < /tmp/init_db.sql >> $DB_INIT_LOG 2>&1; then
                  echo "✅ SQL script executed successfully" >> $DB_INIT_LOG
                  
                  # Verify results
                  RECORD_COUNT=$(mysql --defaults-file=/tmp/mysql.cnf -sN -e 'SELECT COUNT(*) FROM test.hr;' 2>/dev/null || echo '0')
                  echo "Records found: $RECORD_COUNT" >> $DB_INIT_LOG
                  
                  if [ "$RECORD_COUNT" -eq "10" ]; then
                    echo "✅ Database initialization completed successfully! (10 records)" >> $DB_INIT_LOG
                  else
                    echo "⚠️ Partial success: Expected 10 records, found: $RECORD_COUNT" >> $DB_INIT_LOG
                  fi
                else
                  echo "❌ SQL script execution failed" >> $DB_INIT_LOG
                fi
              else
                echo "❌ MySQL connection failed" >> $DB_INIT_LOG
              fi
              
              # Cleanup sensitive files
              rm -f /tmp/mysql.cnf
              
              echo "=== Database Initialization Completed at $(date) ===" >> $DB_INIT_LOG
              echo "Database initialization completed (check /var/log/db_init.log for details)" >> /var/log/setup.log
              DB_INIT
              : "# Database initialization skipped (public subnet - handled by null_resource)"}
              
              # Log installation completion
              echo "EC2 instance setup completed at $(date)" >> /var/log/setup.log
              EOF
  )

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(local.common_tags, {
    Name = "${local.prefix}-web"
  })
}
