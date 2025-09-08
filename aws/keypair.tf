# Generate RSA private key for EC2 access
resource "tls_private_key" "ec2_key" {
  algorithm = "RSA"
  rsa_bits  = 4096

  lifecycle {
    create_before_destroy = true
  }
}

# Create AWS Key Pair from generated public key
resource "aws_key_pair" "ec2_key_pair" {
  key_name   = "${var.project_name}-${var.environment}-key"
  public_key = tls_private_key.ec2_key.public_key_openssh

  depends_on = [
    tls_private_key.ec2_key
  ]

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(local.common_tags, {
    Name = "${local.prefix}-key"
  })
}

# Save private key to local file for SSH access
resource "local_file" "private_key" {
  content  = tls_private_key.ec2_key.private_key_pem
  filename = "${var.project_name}-${var.environment}-key.pem"
  
  # Set proper permissions for SSH key file
  file_permission = "0400"

  depends_on = [
    tls_private_key.ec2_key
  ]

  lifecycle {
    create_before_destroy = true
  }
}
