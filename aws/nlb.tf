# Security Group for Network Load Balancer
resource "aws_security_group" "nlb" {
  count = var.enable_mysql_proxy && var.enable_nlb ? 1 : 0
  
  name_prefix = "${var.project_name}-${var.environment}-nlb-"
  vpc_id      = aws_vpc.main.id
  description = "Security group for MySQL NLB"

  ingress {
    description = "MySQL via NLB"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = var.nlb_allowed_cidrs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  depends_on = [aws_vpc.main]

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(local.common_tags, {
    Name = "${local.prefix}-nlb-sg"
  })
}

# Target Group for MySQL Proxy
resource "aws_lb_target_group" "mysql_proxy" {
  count = var.enable_mysql_proxy && var.enable_nlb ? 1 : 0

  name     = "${var.project_name}-${var.environment}-mysql-tg"
  port     = 3306
  protocol = "TCP"
  vpc_id   = aws_vpc.main.id

  # Health check configuration
  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    port                = "3306"
    protocol            = "TCP"
    timeout             = 6
    unhealthy_threshold = 2
  }

  # Deregistration delay
  deregistration_delay = 30

  depends_on = [aws_vpc.main]

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(local.common_tags, {
    Name = "${local.prefix}-mysql-tg"
  })
}

# Target Group Attachment - EC2 Instance
resource "aws_lb_target_group_attachment" "mysql_proxy" {
  count = var.enable_mysql_proxy && var.enable_nlb ? 1 : 0

  target_group_arn = aws_lb_target_group.mysql_proxy[0].arn
  target_id        = aws_instance.web.id
  port             = 3306

  depends_on = [
    aws_instance.web,
    aws_lb_target_group.mysql_proxy
  ]
}

# Network Load Balancer
resource "aws_lb" "mysql_nlb" {
  count = var.enable_mysql_proxy && var.enable_nlb ? 1 : 0

  name               = "${var.project_name}-${var.environment}-mysql-nlb"
  internal           = true
  load_balancer_type = "network"
  ip_address_type    = "ipv4"

  # Use the NLB private subnet
  subnets = [aws_subnet.private_nlb.id]

  # Enable security groups for NLB (newer feature)
  security_groups                   = [aws_security_group.nlb[0].id]
  enforce_security_group_inbound_rules_on_private_link_traffic = "off"

  enable_deletion_protection = false

  depends_on = [
    aws_subnet.private_nlb,
    aws_security_group.nlb,
    aws_instance.web  # Wait for EC2 to be ready
  ]

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(local.common_tags, {
    Name = "${local.prefix}-mysql-nlb"
  })
}

# NLB Listener - TCP 3306
resource "aws_lb_listener" "mysql_tcp" {
  count = var.enable_mysql_proxy && var.enable_nlb ? 1 : 0

  load_balancer_arn = aws_lb.mysql_nlb[0].arn
  port              = "3306"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.mysql_proxy[0].arn
  }

  depends_on = [
    aws_lb.mysql_nlb,
    aws_lb_target_group.mysql_proxy
  ]

  # Note: ALB/NLB listeners don't support tags in Terraform
  # The tags block here may cause errors and should be removed
}

# VPC Endpoint Service (PrivateLink) for cross-account/cross-VPC access
resource "aws_vpc_endpoint_service" "mysql_privatelink" {
  count = var.enable_mysql_proxy && var.enable_nlb && var.enable_endpoint_service ? 1 : 0

  network_load_balancer_arns   = [aws_lb.mysql_nlb[0].arn]
  acceptance_required          = true    # Require acceptance for endpoint connections
  supported_ip_address_types   = ["ipv4"] # IPv4 support only
  
  depends_on = [
    aws_lb.mysql_nlb,
    aws_lb_listener.mysql_tcp
  ]

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(local.common_tags, {
    Name    = "${local.prefix}-mysql-endpoint-service"
    Purpose = "PrivateLink"
  })
}

# Allow specific principals to access the endpoint service
resource "aws_vpc_endpoint_service_allowed_principal" "mysql_privatelink" {
  count = var.enable_mysql_proxy && var.enable_nlb && var.enable_endpoint_service ? length(var.endpoint_service_allowed_principals) : 0

  vpc_endpoint_service_id = aws_vpc_endpoint_service.mysql_privatelink[0].id
  
  # Replace region in ARN dynamically
  principal_arn = replace(
    var.endpoint_service_allowed_principals[count.index],
    "ap-northeast-2",  # hardcoded region to replace
    var.aws_region     # dynamic region variable
  )

  depends_on = [
    aws_vpc_endpoint_service.mysql_privatelink
  ]
}
