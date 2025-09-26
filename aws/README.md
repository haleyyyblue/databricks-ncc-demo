# Databricks Private MySQL Connectivity with Terraform

This project provisions a complete AWS infrastructure solution that enables **Databricks Serverless SQL Warehouses** to securely connect to **private RDS MySQL databases** through **AWS PrivateLink** and **Databricks Network Connectivity Configuration (NCC)**. 

**🔑 Key Feature:** Uses **Databricks Lakehouse Federation** to connect to MySQL, bypassing the Serverless SQL Warehouses limitation of not supporting custom JDBC drivers.

**🎯 Perfect for:** Databricks demos, POCs, and production deployments requiring private database connectivity without internet exposure.

## 🏗️ Architecture Overview

The infrastructure creates a secure, scalable AWS environment with the following components:

- **VPC** with DNS support and multiple availability zones
- **Public Subnet** for EC2 instances
- **Private Subnets** for RDS and NLB resources  
- **Internet Gateway** and Route Tables for network routing
- **EC2 Instance** running Amazon Linux 2 with web server
- **RDS MySQL** database in private subnets
- **Security Groups** with configurable CIDR restrictions
- **Optional MySQL Proxy** for external database access
- **Optional Network Load Balancer** for high availability
- **Optional VPC Endpoint Service** for PrivateLink connectivity
- **Optional Databricks Network Connectivity Configuration (NCC)** for Databricks integration

### Architecture Diagrams

#### **Flexible EC2 Subnet Placement**

EC2 instance placement is configurable based on `assign_public_ip_to_ec2` variable:

```
                        AWS VPC Infrastructure Overview
+===========================================================================+
|                            AWS Account (Current)                         |
|                              VPC (10.0.0.0/16)                           |
+===========================================================================+
|                                                                          |
| +------------------+ +------------------+ +---------------------+        |
| | Public Subnet    | | Private Subnet   | | Private Subnet      |        |
| | (10.0.1.0/24)    | | RDS: 10.0.2.0/24 | | NLB: 10.0.4.0/24    |        |
| |                  | |      10.0.3.0/24 | |                     |        |
| | +-------------+  | | +-------------+  | | +----------------+  |        |
| | | Internet    |  | | | RDS MySQL   |  | | | Network        |  |        |
| | | Gateway     |  | | | Database    |  | | | Load Balancer  |  |        |
| | |             |  | | | Port: 3306  |  | | | Port: 3306     |  |        |
| | +------+------+  | | +------^------+  | | +-------+--------+  |        |
| |        |         | |        |         | |         |           |        |
| |        v         | |        |         | |         |           |        |
| | +------+------+  | |        |         | | +-------v--------+  |        |
| | | EC2 Instance|<-+-+--------+         | | | VPC Endpoint    | |        |
| | | Web + Proxy |  | |  MySQL Connection| | | Service         | |        |
| | | :80, :3306  |  | |                  | | | (PrivateLink)   | |        |
| | +------^------+  | |                  | | +-------+---------+ |        |
| |        |         | |                  | |         |           |        |
| +--------+---------+ +------------------+ +---------+-----------+        |
|          |                                          |                    |
| +--------v---------+                    +-----------v-----------+        |
| | Internet Access  |                    | AWS PrivateLink       |        |
| | (Users/Apps)     |                    | (AWS Backbone)        |        |
| +------------------+                    +-----------+-----------+        |
|                                                     |                    |
+=====================================================+===================+
                                                      |
+=====================================================+===================+
|                     External AWS Account                                 |
|                         VPC (External)                                   |
+=====================================================+===================+
|                                                                          |
| +------------------+                    +---------------------+          |
| | Private Subnet   |                    | VPC Endpoint        |          |
| | (External VPC)   |                    | (Interface Type)    |          |
| |                  |                    |                     |          |
| | +-------------+  | <--mysql connect-- | +----------------+  |          |
| | | Client      |  |                    | | VPC Endpoint   |  |          |
| | | Application |  |   mysql -h vpce... | | DNS Name       |  |          |
| | +-------------+  |                    | +----------------+  |          |
| +------------------+                    +---------------------+          |
|                                                                          |
+===========================================================================+
```

#### **Configuration Scenarios Visualization**

```
SCENARIO 1: DEVELOPMENT (assign_public_ip_to_ec2 = true)

+---------------------------------------------------------------------+
| Internet > IGW > Public Subnet (EC2) > Private Subnet (RDS)        |
|                       |                        ^                   |
|                  MySQL Proxy                   |                   |
|                  Port 3306                     |                   |
+---------------------------------------------------------------------+

SCENARIO 2: PRODUCTION (assign_public_ip_to_ec2 = false)  

+---------------------------------------------------------------------+
| Users > NLB > Private Subnet (EC2) > Private Subnet (RDS)         |
|             ^    |                          ^                     |
|        NAT Gateway                          |                     |
|          Internet > MySQL Proxy > > > > > > |                     |
+---------------------------------------------------------------------+

SCENARIO 3: CROSS-ACCOUNT (PrivateLink enabled)

+---------------------------------------------------------------------+
| External VPC > VPC Endpoint > PrivateLink > NLB > EC2 > RDS       |
|                             (AWS Backbone)   ^                    |
|                                      Private Subnet               |
+---------------------------------------------------------------------+
```

**Traffic Flow Patterns:**

```
[Web Traffic]
Internet > IGW > EC2:80

[MySQL Direct via Proxy]  
Internet > IGW > EC2:3306 > RDS:3306

[MySQL via NLB]
VPC Internal > NLB:3306 > EC2:3306 > RDS:3306

[MySQL via PrivateLink]
External VPC > VPC Endpoint > PrivateLink > NLB:3306 > EC2:3306 > RDS:3306
```

### Traffic Flow Details

1. **Web Traffic (Public)**: `Internet > IGW > EC2:80` 
   - Standard web traffic to Apache HTTP server
   
2. **MySQL Direct (Public)**: `Internet > IGW > EC2:3306 > RDS:3306`
   - Direct MySQL access via proxy (requires public IP)
   
3. **MySQL via NLB (Internal)**: `VPC Internal > NLB:3306 > EC2:3306 > RDS:3306`
   - High availability MySQL access within VPC
   
4. **MySQL via PrivateLink (Cross-Account)**: 
   `External VPC > VPC Endpoint > AWS PrivateLink > NLB:3306 > EC2:3306 > RDS:3306`
   - Secure cross-account database access without internet transit
   
5. **Database Isolation**: `RDS in private subnets only (no direct internet access)`

## 🏢 **Databricks Network Connectivity Configuration (NCC)**

### **Overview**
The Databricks Network Connectivity Configuration (NCC) enables **Databricks Serverless workspaces** to securely connect to private resources like your RDS MySQL database through **AWS PrivateLink**, without exposing data to the public internet.

### **Key Features**
- **🔐 Private Connectivity**: Direct connection from Databricks to your VPC via PrivateLink
- **🚀 Serverless Compatible**: Works with Databricks Serverless SQL warehouses via Lakehouse Federation
- **⚡ High Performance**: Low-latency database access without internet routing
- **🛡️ Enterprise Security**: All traffic stays within AWS backbone
- **🔧 No JDBC Drivers**: Uses built-in MySQL federation, no custom driver installation required
- **🎯 MySQL-Focused**: Optimized specifically for MySQL database connectivity

### **Architecture Flow**
```
Databricks Workspace → NCC → PrivateLink → NLB:3306 → EC2:3306 → RDS:3306
```

### **Prerequisites**
To enable Databricks NCC, you need:
```hcl
# terraform.tfvars - All required
enable_mysql_proxy      = true                              # MySQL proxy required
enable_nlb             = true                              # NLB required for PrivateLink  
enable_endpoint_service = true                             # VPC Endpoint Service required
enable_databricks_ncc   = true                             # Enable NCC
databricks_account_id   = "your-databricks-account-uuid"   # Databricks Account ID
databricks_client_id    = "your-oauth-client-id"           # OAuth Client ID
databricks_client_secret = "your-oauth-client-secret"      # OAuth Client Secret
```

### **Configuration Steps**

**1. Get Your Databricks Account ID**
```bash
# From Databricks Account Console
# URL: https://accounts.cloud.databricks.com
# Account Settings → Account ID (UUID format)
```

**2. Create OAuth Application for API Access**
```bash
# In Databricks Account Console:
# 1. Go to https://accounts.cloud.databricks.com
# 2. Settings → App connections → OAuth published apps
# 3. Create new OAuth app with scope: account
# 4. Copy Client ID and Client Secret
```

**3. Enable NCC in terraform.tfvars**
```hcl
enable_databricks_ncc    = true
databricks_account_id    = "12345678-1234-1234-1234-123456789abc"
databricks_client_id     = "your-oauth-client-id"
databricks_client_secret = "your-oauth-client-secret"
```

**4. Deploy Infrastructure**
```bash
terraform init
terraform plan
terraform apply
```

**5. Get NCC Information**
```bash
terraform output databricks_ncc_info
```

### **Usage in Databricks**

**⚠️ Prerequisites: AWS Console Configuration**

Before using the NCC in Databricks, you must complete these AWS setup steps:

**1. Accept VPC Endpoint Connection in AWS Console**
```bash
# After terraform apply, check the VPC Endpoint Service
terraform output endpoint_service_info

# Go to AWS Console → VPC → Endpoint Services
# Find your endpoint service: com.amazonaws.vpce.[region].[service-name]
# Accept the pending endpoint connection from Databricks
```

**2. Workspace Configuration & Wait Time**
```
⏰ IMPORTANT: After accepting the endpoint connection,
   wait ~10 minutes for the connection to be fully established
   before testing MySQL connectivity in Databricks.
```

**Create New Workspace with NCC**

or

**Update Existing Workspace with NCC**


**⏰ Important Timing Notes:**
```
1. Complete AWS Console endpoint acceptance
2. Update/create Databricks workspace with NCC
3. Wait ~10 minutes for connection establishment
4. Test connectivity with Lakehouse Federation
```

**✅ Recommended Approach: Use Lakehouse Federation**

Instead of direct JDBC connections, use **Databricks Lakehouse Federation** with foreign catalogs:

**Step 1: Create Connection in Databricks**
```sql
-- In Databricks SQL Editor or Notebook
CREATE CONNECTION IF NOT EXISTS mysql_private_connection
TYPE mysql
OPTIONS (
  host 'your-mysql-instance.xxxxx.ap-northeast-2.rds.amazonaws.com',
  port '3306',
  user 'admin',
  password 'your_password'
);
```

**Step 2: Create Foreign Catalog**
```sql
-- Create foreign catalog using the connection
CREATE FOREIGN CATALOG IF NOT EXISTS mysql_catalog 
USING CONNECTION mysql_private_connection;
```

**Step 3: Query MySQL Data via Foreign Catalog**
```sql
-- Query MySQL data through foreign catalog
SELECT * FROM mysql_catalog.test.hr LIMIT 10;

-- Check available tables in the catalog
SHOW TABLES IN mysql_catalog.test;

**Step 4: Python/PySpark Usage**
```python
# In Databricks notebook
# Query via SQL with foreign catalog
df = spark.sql("""
  SELECT * FROM mysql_catalog.test.hr 
  WHERE department = 'Engineering'
""")
df.show()

# Create DataFrame directly
mysql_data = spark.table("mysql_catalog.test.hr")
filtered_data = mysql_data.filter(mysql_data.salary > 80000)
filtered_data.show()

# Advanced analytics with PySpark
from pyspark.sql import functions as F

# Department statistics
dept_stats = spark.sql("""
  SELECT 
    department,
    COUNT(*) as total_employees,
    AVG(salary) as avg_salary,
    MIN(hire_date) as earliest_hire,
    MAX(hire_date) as latest_hire
  FROM mysql_catalog.test.hr
  GROUP BY department
  ORDER BY avg_salary DESC
""")
dept_stats.show()
```

### **NCC Components Created**

**Network Connectivity Configuration:**
- **Name**: `ncc-for-{project}-{environment}`
- **Region**: Same as your AWS infrastructure
- **Type**: Account-level Databricks resource

**Private Endpoint Rules:**
- **MySQL Access**: Your VPC Endpoint Service → MySQL database (Port 3306)
- **Domain Name**: Uses RDS endpoint address directly (e.g., `mysql-instance.xxxxx.ap-northeast-2.rds.amazonaws.com`)

### **Verification**

**Check NCC Status:**
```bash
terraform output databricks_ncc_info
```

**Expected Output:**
```json
{
  "ncc_enabled": true,
  "ncc_id": "ncc-xxxxx",
  "vpc_endpoint_service_name": "com.amazonaws.vpce.ap-northeast-2.vpce-svc-xxxxx",
  "mysql_domain_name": "haley-serverless-dev-mysql.xxxxx.ap-northeast-2.rds.amazonaws.com",
  "authentication_method": "OAuth Client Credentials",
  "mysql_connection_pattern": "Databricks → NCC → PrivateLink → NLB:3306 → EC2:3306 → RDS:3306"
}
```

### **Cost Considerations**
- **NCC**: Free (Databricks managed service)
- **PrivateLink**: ~$7.20/month per VPC endpoint  
- **NLB**: ~$16.20/month + data processing
- **Total Additional Cost**: ~$5-8/month for NCC integration (MySQL-only configuration)

### **Troubleshooting**

**Problem: NCC creation fails**
```bash
# Check prerequisites
terraform plan
# Ensure all required services are enabled
```

**Problem: Connection from Databricks fails**
```bash
# Verify VPC Endpoint Service status  
aws ec2 describe-vpc-endpoint-services --service-names [SERVICE_NAME]

# Check NLB health
aws elbv2 describe-target-health --target-group-arn [ARN]
```

**Problem: Invalid Databricks Account ID**
```bash
# Verify UUID format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
# Get from: https://accounts.cloud.databricks.com
```

## 📁 Project Structure

```
├── main.tf           # Terraform and AWS provider configuration with common tags
├── vpc.tf            # VPC, subnets, route tables, IGW, and NAT Gateway  
├── ec2.tf            # EC2 AMI data source, security group, and instance
├── rds.tf            # RDS security group, subnet group, and MySQL instance
├── nlb.tf            # Network Load Balancer, target group, listener, and VPC Endpoint Service
├── databricks.tf     # Databricks Network Connectivity Configuration (NCC) and private endpoint rules
├── keypair.tf        # Auto-generated SSH key pair for EC2 access
├── variables.tf      # Variable definitions with validation rules
├── outputs.tf        # Output values for created resources
├── terraform.tfvars  # Variable values configuration
├── init_db.sql       # Database initialization script with test data
└── README.md         # This file
```

## 🚀 Getting Started

### Prerequisites

1. **AWS CLI** configured with appropriate credentials
   ```bash
   aws configure
   ```

2. **Terraform** installed (version >= 1.0)
   ```bash
   terraform --version
   ```

3. **EC2 Key Pair** ✨ **Automatically Generated**
   - SSH key pair is automatically created by Terraform
   - Private key file will be saved as `[project-name]-[environment]-key.pem`
   - No manual key creation needed!

## 📋 Use Cases & Configuration Scenarios

Choose the configuration that best matches your use case:

### 🔧 **Scenario 1: Development & Testing (Default)**
**Best for:** Quick testing, development, learning Databricks connectivity
```hcl
# terraform.tfvars
assign_public_ip_to_ec2 = true   # EC2 in public subnet
enable_mysql_proxy      = true   # Enable MySQL proxy  
enable_nlb              = false  # No load balancer needed
enable_nat_gateway      = false  # Not needed for public subnet
enable_endpoint_service = false  # No PrivateLink needed
```
**✅ Pros:** Easy setup, internet accessible, lower cost  
**⚠️ Cons:** Less secure (public IP), not production-ready

### 🏢 **Scenario 2: Production Environment**
**Best for:** Production workloads, high security requirements
```hcl
# terraform.tfvars
assign_public_ip_to_ec2 = false  # EC2 in private subnet
enable_mysql_proxy      = true   # Enable MySQL proxy
enable_nlb              = true   # Load balancer for HA
enable_nat_gateway      = true   # Internet access for updates
enable_endpoint_service = false  # Optional PrivateLink
```
**✅ Pros:** High security, no public IPs, production-ready  
**💰 Cons:** Higher cost (~$45/month NAT Gateway)

### ☁️ **Scenario 3: Cross-Account/VPC Integration**
**Best for:** Multi-account architecture, Databricks Private Access  
```hcl
# terraform.tfvars  
assign_public_ip_to_ec2 = false  # EC2 in private subnet
enable_mysql_proxy      = true   # Enable MySQL proxy
enable_nlb              = true   # NLB required for PrivateLink
enable_nat_gateway      = true   # Internet access for setup
enable_endpoint_service = true   # Enable PrivateLink
endpoint_service_allowed_principal = "arn:aws:iam::123456789012:role/databricks-role"
```
**✅ Pros:** Maximum security, cross-account access, enterprise-grade  
**💰 Cons:** Highest cost, more complex setup

### 💰 **Scenario 4: Cost-Optimized Private**
**Best for:** Demo environment with private setup but minimal cost
```hcl
# terraform.tfvars
assign_public_ip_to_ec2 = false  # EC2 in private subnet  
enable_mysql_proxy      = false  # No proxy to save costs
enable_nlb              = false  # No load balancer
enable_nat_gateway      = false  # No internet access
enable_endpoint_service = false  # No PrivateLink
enable_databricks_ncc   = false  # No Databricks integration
```
**⚠️ Warning:** This configuration may fail during deployment because EC2 cannot install required packages without internet access. Consider using pre-configured AMI.

### 🏢 **Scenario 5: Databricks NCC Integration**
**Best for:** Databricks Serverless workspaces with private MySQL connectivity
```hcl
# terraform.tfvars  
assign_public_ip_to_ec2   = false  # EC2 in private subnet
enable_mysql_proxy        = true   # Enable MySQL proxy
enable_nlb                = true   # NLB required for PrivateLink
enable_nat_gateway        = true   # Internet access for setup
enable_endpoint_service   = true   # Enable PrivateLink
enable_databricks_ncc     = true   # Enable Databricks NCC  
databricks_account_id     = "12345678-1234-1234-1234-123456789abc"
databricks_client_id      = "your-oauth-client-id"
databricks_client_secret  = "your-oauth-client-secret"
```
**✅ Pros:** Complete Databricks integration, private connectivity, enterprise-grade security  
**💰 Cons:** Highest cost (~$60/month), requires Databricks Account setup  
**🎯 Use Case:** Databricks Serverless SQL warehouses accessing private RDS databases

### 📊 **Scenario Comparison Table**

| Feature | Development | Production | Cross-Account | Cost-Optimized | Databricks NCC |
|---------|------------|------------|---------------|----------------|----------------|
| **EC2 Location** | Public Subnet | Private Subnet | Private Subnet | Private Subnet | Private Subnet |
| **Internet Access** | Direct (IGW) | Via NAT Gateway | Via NAT Gateway | None ❌ | Via NAT Gateway |
| **MySQL Proxy** | ✅ | ✅ | ✅ | ❌ | ✅ |
| **Load Balancer** | ❌ | ✅ | ✅ | ❌ | ✅ |
| **PrivateLink** | ❌ | Optional | ✅ | ❌ | ✅ |
| **Databricks NCC** | ❌ | ❌ | ❌ | ❌ | ✅ |
| **Monthly Cost** | ~$10 | ~$55 | ~$60 | ~$8 | ~$65 |
| **Security Level** | Low | High | Highest | Medium | Highest |
| **Setup Complexity** | Simple | Medium | Complex | Simple | Most Complex |
| **SSH Access** | Direct | VPN/Bastion | VPN/Bastion | VPN/Bastion | VPN/Bastion |
| **Target Use Case** | Development | Production | Partner Access | Cost Savings | Databricks Integration |

### Configuration

1. **Update variables** in `terraform.tfvars`:
   ```hcl
   # Update with your preferred AWS region
   aws_region = "ap-northeast-2"
   
   # EC2 Key Pair is automatically generated - no manual configuration needed
   
   # Configure allowed IP ranges for security
   ec2_ssh_allowed_cidrs = [
     "YOUR_COMPANY_IP/24",  # Replace with actual corporate IPs
     "YOUR_VPN_IP/24"       # Replace with actual VPN IPs
   ]
   ```

2. **Customize resources** (optional):
   - Modify CIDR blocks in `terraform.tfvars`
   - Adjust instance types for cost optimization
   - Update RDS configuration as needed

### Deployment

1. **Initialize Terraform**:
   ```bash
   terraform init
   ```

2. **Plan the deployment**:
   ```bash
   terraform plan
   ```

3. **Apply the configuration**:
   ```bash
   terraform apply
   ```

4. **View outputs**:
   ```bash
   terraform output
   ```

### Cleanup

To destroy all created resources:
```bash
terraform destroy
```

## 🔒 Security Features

### Network Security
- **Private RDS**: Database accessible only from EC2 instances
- **Security Groups**: Restrictive ingress rules with configurable CIDR blocks
- **No public RDS access**: `publicly_accessible = false`

### Access Control
- **SSH Access**: Configurable IP range restrictions (recommended: corporate IPs only)
- **Web Traffic**: Separately configurable HTTP/HTTPS access
- **Database Access**: Limited to EC2 security group only

### Best Practices
- **Encrypted Storage**: RDS storage encryption enabled
- **Backup Configuration**: 7-day backup retention
- **Lifecycle Management**: `create_before_destroy` for safe updates
- **Variable Validation**: Input validation for CIDR blocks and other parameters

## 📋 Resource Details

### VPC Configuration
- **CIDR**: `10.0.0.0/16` (configurable)
- **Availability Zones**: 2 AZs for RDS high availability
- **Subnets**: 
  - 1 Public subnet for EC2
  - 2 Private subnets for RDS (multi-AZ requirement)
  - 1 Private subnet for NLB

### EC2 Instance
- **Instance Type**: `t2.micro` (AWS Free Tier)
- **AMI**: Latest Amazon Linux 2
- **Services**: Apache HTTP server pre-installed
- **Security**: SSH, HTTP, HTTPS access with configurable IP restrictions

### RDS MySQL
- **Engine**: MySQL 8.0
- **Instance Class**: `db.t3.micro`
- **Storage**: 20GB GP2 (encrypted)
- **Backup**: 7-day retention with automated backups
- **Network**: Private subnets only, no public access

## 🧪 Database Testing

### Test Database Setup
The RDS MySQL instance is automatically initialized with test data for easy validation:

- **Database**: `test`
- **Table**: `hr` (Human Resources sample data)
- **Records**: 10 sample employee records
- **Columns**: id, name, department, position, salary, hire_date, created_at

### 🔧 **Database Initialization Methods**

The project uses **different initialization methods** based on EC2 subnet configuration:

#### **Public Subnet Mode** (`assign_public_ip_to_ec2 = true`)
- **Method**: Terraform `remote-exec` provisioner
- **Execution**: From local machine via SSH
- **Timing**: After EC2 and RDS are ready
- **Logging**: Terraform output shows initialization status
- **Pros**: Real-time feedback, immediate error reporting
- **Cons**: Requires SSH access from local machine

#### **Private Subnet Mode** (`assign_public_ip_to_ec2 = false`)
- **Method**: EC2 `user_data` script  
- **Execution**: During EC2 boot process
- **Timing**: Automatically after EC2 starts
- **Logging**: Check `/var/log/db_init.log` and `/var/log/setup.log` on EC2
- **Pros**: No external SSH required, works in isolated environments
- **Cons**: Must SSH to EC2 to check logs

### 📋 **Checking Initialization Status**

**For Public Subnet:**
```bash
# Status shown in Terraform output
terraform apply
# Look for database initialization messages

# Manual verification
ssh -i key.pem ec2-user@[PUBLIC_IP]
mysql -h [RDS_ENDPOINT] -u admin -p[PASSWORD] -e "SELECT COUNT(*) FROM test.hr;"
```

**For Private Subnet:**
```bash  
# Check initialization logs
ssh -i key.pem ec2-user@[PRIVATE_IP]  # Via VPN/bastion
cat /var/log/db_init.log
cat /var/log/setup.log

# Verify database
mysql -h [RDS_ENDPOINT] -u admin -p[PASSWORD] -e "SELECT COUNT(*) FROM test.hr;"
```

### Connecting to the Database

1. **From EC2 instance** (MySQL client pre-installed):
   ```bash
   # SSH to EC2 instance
   ssh -i your-key.pem ec2-user@[EC2_PUBLIC_IP]
   
   # Connect to MySQL
   mysql -h [RDS_ENDPOINT] -P 3306 -u admin -ptest1234
   ```

2. **Sample queries** to test the setup:
   ```sql
   USE test;
   
   -- Show all tables
   SHOW TABLES;
   
   -- View sample employee data
   SELECT * FROM hr LIMIT 5;
   
   -- Department summary
   SELECT department, COUNT(*) as employee_count, AVG(salary) as avg_salary 
   FROM hr GROUP BY department;
   ```

3. **Web interface**: Visit `http://[EC2_PUBLIC_IP]` for infrastructure status and connection instructions.

### Test Data Sample
```
+----+-------------+------------+----------+----------------------------+-------------+----------+
| id | employee_id | first_name | last_name| email                      | department  | position |
+----+-------------+------------+----------+----------------------------+-------------+----------+
|  1 | EMP001      | John       | Smith    | john.smith@company.com     | Engineering | Senior SE|
|  2 | EMP002      | Sarah      | Johnson  | sarah.johnson@company.com  | Engineering | DevOps   |
|  3 | EMP003      | Michael    | Brown    | michael.brown@company.com  | Product     | PM       |
+----+-------------+------------+----------+----------------------------+-------------+----------+
```

## 🔗 MySQL Proxy (Optional)

### Overview
The infrastructure supports an optional MySQL proxy feature that allows direct connections to the RDS instance through the EC2 instance on port 3306. 

**⚠️ SECURITY WARNING**: This feature should only be enabled for development and testing environments, not production.

### How It Works
When enabled, the EC2 instance runs a `socat` proxy that forwards traffic from `EC2:3306` to `RDS:3306`, allowing external tools to connect to the private RDS instance through the public EC2 instance.

```
External Client → EC2:3306 (Public) → RDS:3306 (Private)
```

### Enabling MySQL Proxy

1. **Set proxy variables** in `terraform.tfvars`:
   ```hcl
   # Enable MySQL proxy
   enable_mysql_proxy = true
   
   # Configure allowed IP ranges (restrict to your IPs!)
   mysql_proxy_allowed_cidrs = [
     "YOUR_OFFICE_IP/32",     # Your office IP
     "YOUR_HOME_IP/32"        # Your home IP
   ]
   ```

2. **Deploy the infrastructure**:
   ```bash
   terraform apply
   ```

3. **Connect via proxy**:
   ```bash
   # Connect to RDS through EC2 proxy
   mysql -h [EC2_PUBLIC_IP] -P 3306 -u admin -p test1234
   ```

### Proxy Management

**Check proxy status**:
```bash
# SSH to EC2 instance
ssh -i your-key.pem ec2-user@[EC2_PUBLIC_IP]

# Check proxy status
sudo /usr/local/bin/mysql-proxy-status.sh
```

**View proxy logs**:
```bash
# SSH to EC2 instance
tail -f /var/log/mysql-proxy.log
```

### Security Considerations

- **🚨 Never use `0.0.0.0/0`** for `mysql_proxy_allowed_cidrs`
- **Restrict access** to specific IP addresses or corporate networks only
- **Monitor proxy logs** for unauthorized access attempts
- **Disable proxy** in production environments
- **Use VPN** or bastion hosts for secure database access instead

### When to Use MySQL Proxy

**✅ Good use cases**:
- Development and testing environments
- Database administration tasks
- Quick data analysis and reporting
- CI/CD pipeline database connections

**❌ Avoid for**:
- Production environments
- Public-facing applications
- Long-term database connections
- High-traffic scenarios

## 🌐 Network Load Balancer (Optional)

### Overview
The infrastructure supports an optional internal Network Load Balancer (NLB) that provides load balancing and high availability for the MySQL proxy service.

**⚠️ PREREQUISITE**: This feature requires `enable_mysql_proxy = true` to function.

### Architecture
When both MySQL proxy and NLB are enabled, the traffic flow becomes:
```
VPC Internal → NLB:3306 → EC2:3306 (MySQL Proxy) → RDS:3306
```

### Key Features
- **Internal NLB**: Only accessible within the VPC (no internet access)
- **TCP Load Balancing**: Layer 4 load balancing for MySQL traffic
- **Health Checks**: Monitors EC2 instance health on port 3306
- **Private Link Support**: `enforce_security_group_inbound_rules_on_private_link_traffic = off`
- **Dedicated Security Group**: Fine-grained access control

### Enabling NLB

1. **Enable prerequisites** in `terraform.tfvars`:
   ```hcl
   # First enable MySQL proxy
   enable_mysql_proxy = true
   
   # Then enable NLB
   enable_nlb = true
   
   # Configure NLB access (VPC internal only)
   nlb_allowed_cidrs = [
     "10.0.0.0/16",        # VPC CIDR
     "192.168.0.0/16"      # Corporate network (if needed)
   ]
   ```

2. **Deploy the infrastructure**:
   ```bash
   terraform apply
   ```

3. **Connect via NLB**:
   ```bash
   # Get NLB DNS name from outputs
   terraform output nlb_info
   
   # Connect to RDS through NLB
   mysql -h [NLB_DNS_NAME] -P 3306 -u admin -ptest1234
   ```

### NLB Configuration Details

- **Load Balancer Type**: Network (Layer 4)
- **Scheme**: Internal only
- **IP Address Type**: IPv4
- **Subnets**: Uses the dedicated NLB private subnet
- **Target Group**: EC2 instance on port 3306
- **Health Check**: TCP health check on port 3306
- **Listener**: TCP port 3306 → Target Group

### Health Monitoring

**Target Group Health**:
```bash
# Check target group status in AWS Console
# Navigate to: EC2 → Load Balancers → [NLB_NAME] → Target Groups
```

**Connection Testing**:
```bash
# Test NLB connectivity
telnet [NLB_DNS_NAME] 3306

# Test MySQL connection
mysql -h [NLB_DNS_NAME] -P 3306 -u admin -ptest1234 -e "SELECT 1;"
```

### Use Cases

**✅ Good for**:
- Multi-client database access within VPC
- Load balancing across multiple MySQL proxy instances (future expansion)
- High availability requirements
- VPC-to-VPC database connectivity
- Microservices accessing shared database

**⚠️ Considerations**:
- Adds additional network hop (minimal latency)
- Requires MySQL proxy to be enabled
- Internal VPC access only
- Single target initially (can be expanded)

### Security Features

- **Network Security Group**: Restricts access to specified CIDR blocks
- **Internal Only**: No internet gateway access
- **VPC Isolation**: Traffic stays within your VPC
- **Private Link Ready**: Configured for VPC endpoints

## 🔗 VPC Endpoint Service (PrivateLink)

The infrastructure supports an optional VPC Endpoint Service that enables secure, private connectivity from other AWS accounts or VPCs without traversing the public internet.

### Overview

When enabled, a VPC Endpoint Service is created using the Network Load Balancer, allowing authorized external accounts to create VPC Endpoints for private access to your MySQL database.

```
External Account/VPC → VPC Endpoint → PrivateLink → NLB:3306 → EC2:3306 → RDS:3306
```

### Key Features

- **Cross-Account Access**: Secure access from different AWS accounts
- **Cross-VPC Access**: Private connectivity between VPCs  
- **No Internet Transit**: Traffic stays within AWS backbone
- **Connection Approval**: Requires acceptance for each connection request
- **IPv4 Support**: Standard IPv4 addressing

### Enabling PrivateLink

**Prerequisites**: Both MySQL Proxy and NLB must be enabled first.

1. **Set variables** in `terraform.tfvars`:
   ```hcl
   # Enable all required components
   enable_mysql_proxy = true
   enable_nlb = true
   enable_endpoint_service = true
   
   # Configure allowed AWS principals (replace account ID as needed)
endpoint_service_allowed_principal = "arn:aws:iam::565502421330:role/private-connectivity-role-ap-northeast-2"
   ```

2. **Deploy** the infrastructure:
   ```bash
   terraform plan
   terraform apply
   ```

3. **Get service information**:
   ```bash
   terraform output endpoint_service_info
   ```

### Connection Process

**From the target account (565502421330):**

1. **Create VPC Endpoint** (Interface type):
   - Service Name: Use output from `terraform output endpoint_service_info`
   - Select target VPC and subnets
   - Configure security groups (allow port 3306)

2. **Connection Request**: 
   - Request will be sent for approval
   - Check AWS Console → VPC → Endpoint Services → Connection requests

3. **Approve Connection**:
   - Approve the connection request in the source account
   - VPC Endpoint becomes "Available"

4. **Connect to MySQL**:
   ```bash
   # Use VPC Endpoint DNS name
   mysql -h vpce-xxxxx-xxxxx.vpce-svc-xxxxx.region.vpce.amazonaws.com -P 3306 -u admin -p
   ```

### Security Considerations

- **Approval Required**: All connections require manual approval
- **Principal-Based Access**: Only specified IAM principals can create connections
- **Network Isolation**: Traffic doesn't traverse public internet
- **Monitoring**: Connection attempts are logged in CloudTrail

### Use Cases

- **Multi-Account Architecture**: Access database from different AWS accounts
- **Hybrid Cloud**: Connect from on-premises through AWS Direct Connect
- **Partner Access**: Secure database access for business partners
- **Development/Testing**: Isolated access for development environments

## 🔧 Troubleshooting Guide

### 🚨 **Configuration Validation Errors**

#### **Error: EC2 in private subnet without NAT Gateway**
```bash
ERROR: EC2 in private subnet without NAT Gateway cannot install required packages
```
**Solution:** Enable NAT Gateway or switch to public subnet
```hcl
# Option 1: Enable NAT Gateway
enable_nat_gateway = true

# Option 2: Switch to public subnet  
assign_public_ip_to_ec2 = true
```

#### **Error: PrivateLink requires MySQL proxy and NLB**
```bash
ERROR: PrivateLink requires both MySQL proxy and NLB to be enabled
```
**Solution:** Enable prerequisites
```hcl
enable_mysql_proxy = true
enable_nlb = true
enable_endpoint_service = true
```

### 🌐 **Deployment Issues**

#### **Problem: Terraform init fails**
```bash
# Check AWS credentials
aws sts get-caller-identity

# Verify AWS CLI version
aws --version

# Re-initialize if needed
rm -rf .terraform .terraform.lock.hcl
terraform init
```

#### **Problem: RDS creation timeout**
- **Cause:** RDS takes 10-15 minutes to create
- **Solution:** Wait patiently or increase timeout
```hcl
# In rds.tf - increase timeout (if needed)
timeouts {
  create = "20m"
  update = "20m"
  delete = "20m"
}
```

#### **Problem: Key pair already exists error**
```bash
# Delete existing key if needed
aws ec2 delete-key-pair --key-name [PROJECT-NAME]-[ENV]-key

# Clean Terraform state
terraform state rm aws_key_pair.ec2_key_pair
terraform apply
```

### 🔗 **Connectivity Issues**

#### **Problem: Cannot SSH to EC2 instance**

**For Public Subnet:**
```bash
# Check security group allows your IP
terraform output ec2_subnet_info

# SSH with correct key
ssh -i [PROJECT-NAME]-[ENV]-key.pem ec2-user@[PUBLIC_IP]
```

**For Private Subnet:**
```bash  
# Use Session Manager (recommended)
aws ssm start-session --target [INSTANCE_ID]

# Or setup bastion host/VPN access
```

#### **Problem: MySQL connection fails**

**From EC2 to RDS:**
```bash
# SSH to EC2 first
ssh -i key.pem ec2-user@[EC2_IP]

# Test RDS connection
mysql -h [RDS_ENDPOINT] -P 3306 -u admin -p[PASSWORD]

# Check security groups
aws ec2 describe-security-groups --group-ids [SG_ID]
```

**External to MySQL Proxy:**
```bash
# Test EC2 MySQL proxy port
telnet [EC2_IP] 3306
nc -zv [EC2_IP] 3306

# Check socat process
ssh ec2-user@[EC2_IP] "ps aux | grep socat"
```

### ⚖️ **NLB & PrivateLink Issues**

#### **Problem: NLB target unhealthy**
```bash
# Check target group health
aws elbv2 describe-target-health \
  --target-group-arn [TARGET_GROUP_ARN]

# Verify EC2 is listening on port 3306
ssh ec2-user@[EC2_IP] "netstat -ln | grep 3306"

# Check NLB security group rules
terraform output nlb_info
```

#### **Problem: VPC Endpoint Service connection fails**
```bash
# Check service status
terraform output endpoint_service_info

# Verify NLB is healthy first
aws elbv2 describe-target-health --target-group-arn [ARN]

# Check endpoint service
aws ec2 describe-vpc-endpoint-services \
  --service-names [SERVICE_NAME]

# Approve connection requests
aws ec2 accept-vpc-endpoint-connections \
  --service-id [SERVICE_ID] \
  --vpc-endpoint-ids [ENDPOINT_ID]
```

### 🗄️ **Database Issues**

#### **Problem: Test database not created**
```bash
# Check database initialization logs
ssh ec2-user@[EC2_IP] "ls -la /tmp/terraform_db_init_*.log"
ssh ec2-user@[EC2_IP] "cat /tmp/terraform_db_init_*.log"

# Manual verification
mysql -h [RDS_ENDPOINT] -u admin -p[PASSWORD] -e "SHOW DATABASES;"
mysql -h [RDS_ENDPOINT] -u admin -p[PASSWORD] -e "SELECT COUNT(*) FROM test.hr;"
```

#### **Problem: MySQL client not installed**
```bash
# Install manually if needed
ssh ec2-user@[EC2_IP] "sudo yum install -y mysql"

# Re-run database initialization
terraform taint null_resource.db_initialization
terraform apply -target=null_resource.db_initialization
```

### 🏢 **Databricks NCC Issues**

#### **Problem: NCC creation fails with prerequisites**
```bash
ERROR: Databricks NCC requires MySQL proxy, NLB, and VPC Endpoint Service
```
**Solution:** Enable all prerequisites
```hcl
# terraform.tfvars - All must be true
enable_mysql_proxy = true
enable_nlb = true  
enable_endpoint_service = true
enable_databricks_ncc = true
```

#### **Problem: Invalid Databricks Account ID**
```bash
ERROR: Databricks NCC requires a valid account ID
```
**Solution:** Get correct Account ID
```bash
# 1. Go to https://accounts.cloud.databricks.com
# 2. Account Settings → Account ID
# 3. Copy UUID format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

#### **Problem: Databricks provider authentication fails**
```bash  
Error: cannot configure databricks provider
```
**Solution:** Configure OAuth Client Credentials
```bash
# Get OAuth credentials from Databricks Account Console:
# 1. https://accounts.cloud.databricks.com
# 2. Settings → App connections → OAuth published apps
# 3. Create OAuth app with "account" scope
# 4. Set in terraform.tfvars:
#    databricks_client_id = "your-client-id"
#    databricks_client_secret = "your-client-secret"
```

#### **Problem: Missing client credentials**
```bash
ERROR: Databricks NCC requires client credentials for authentication
```
**Solution:** Set OAuth credentials in terraform.tfvars
```hcl
databricks_client_id     = "your-oauth-client-id"
databricks_client_secret = "your-oauth-client-secret"
```

#### **Problem: NCC private endpoint rule fails**
```bash
Error: cannot create private endpoint rule
```
**Solution:** Verify VPC Endpoint Service
```bash
# Check service exists and is available
terraform output endpoint_service_info

# Verify service name format
aws ec2 describe-vpc-endpoint-services --service-names [SERVICE_NAME]
```

#### **Problem: Databricks workspace cannot connect to MySQL**
```bash
# Connection timeout from Databricks to database
```

**Most Common Cause: Insufficient Wait Time**
```
⚠️ WAIT ~10 MINUTES after:
   - Accepting VPC Endpoint connection in AWS Console
   - Creating/updating workspace with NCC
   - Before testing MySQL connectivity
```

**Solution:** Step-by-step verification
```bash
# 1. Check AWS VPC Endpoint Service acceptance
# AWS Console → VPC → Endpoint Services → Check connection status
# Status should be "Available" not "Pending Acceptance"

# 2. Verify NCC status
terraform output databricks_ncc_info

# 3. Check workspace NCC configuration
# Databricks Account Console → Workspaces → [Workspace] → Configuration
# Verify ncc is set

# 4. Wait for connection establishment (10+ minutes)
# Then verify NLB health  
aws elbv2 describe-target-health --target-group-arn [TARGET_GROUP_ARN]

# 5. Test MySQL proxy on EC2
ssh ec2-user@[EC2_IP] "telnet [RDS_ENDPOINT] 3306"

# 6. Test from Databricks workspace
# Try creating CONNECTION in Databricks SQL Editor
```

**Connection Timeline:**
```
T+0:  Accept VPC Endpoint in AWS Console
T+2:  Update Databricks workspace with NCC  
T+10: Connection fully established ✅
T+11: Test MySQL connection in Databricks
```

### 💰 **Cost Optimization Issues**

#### **Problem: Unexpected AWS charges**
```bash
# Check running resources
aws ec2 describe-instances --query 'Reservations[].Instances[?State.Name==`running`].[InstanceId,InstanceType]'
aws rds describe-db-instances --query 'DBInstances[?DBInstanceStatus==`available`].[DBInstanceIdentifier,DBInstanceClass]'
aws ec2 describe-nat-gateways --query 'NatGateways[?State==`available`].[NatGatewayId]'

# Clean up when done
terraform destroy
```

### 🆘 **Emergency Commands**

```bash
# Complete cleanup (USE WITH CAUTION!)
terraform destroy -auto-approve

# Remove stuck resources
terraform state list
terraform state rm [RESOURCE_NAME]

# Force recreate problematic resource  
terraform taint [RESOURCE_NAME]
terraform apply

# Debug terraform state
terraform show
terraform state show [RESOURCE_NAME]
```

### 📞 **Getting Help**

1. **Check terraform logs:** `export TF_LOG=DEBUG && terraform apply`
2. **Validate configuration:** `terraform validate && terraform plan`
3. **Review AWS CloudTrail** for permission issues
4. **Check AWS Service Health Dashboard** for regional issues

**Common Log Locations:**
- Terraform logs: Set `TF_LOG=DEBUG`  
- EC2 user-data logs: `/var/log/cloud-init-output.log`
- Database init logs: `/tmp/terraform_db_init_*.log`
- Setup logs: `/var/log/setup.log`

## 🛠️ Customization

### Environment Variables
All key parameters are configurable through `terraform.tfvars`:

| Variable | Description | Default |
|----------|-------------|---------|
| `aws_region` | AWS region for deployment | `ap-northeast-2` |
| `vpc_cidr` | VPC CIDR block | `10.0.0.0/16` |
| `ec2_instance_type` | EC2 instance type | `t2.micro` |
| `rds_instance_class` | RDS instance class | `db.t3.micro` |
| `ec2_ssh_allowed_cidrs` | SSH access IP ranges | `["10.0.0.0/8"]` |
| `ec2_web_allowed_cidrs` | HTTP/HTTPS access IP ranges | `["0.0.0.0/0"]` |
| `enable_mysql_proxy` | Enable MySQL proxy on EC2 | `false` |
| `mysql_proxy_allowed_cidrs` | MySQL proxy access IP ranges | `["10.0.0.0/8"]` |
| `enable_nlb` | Enable Network Load Balancer | `false` |
| `nlb_allowed_cidrs` | NLB access IP ranges | `["10.0.0.0/16"]` |
| `enable_endpoint_service` | Enable VPC Endpoint Service (PrivateLink) | `false` |
| `endpoint_service_allowed_principal` | IAM principal allowed to access endpoint service | `""` |
| `assign_public_ip_to_ec2` | Assign public IP to EC2 instance | `true` |
| `enable_nat_gateway` | Enable NAT Gateway for internet access | `false` |

## 🏗️ EC2 Public IP Configuration

### Overview
The infrastructure places the EC2 instance in the public subnet but allows you to control whether it gets a public IP address, providing flexibility between public accessibility and private-only access.

### Configuration Options

#### **Option 1: Public IP Assigned (Default - Testing/Development)**
```hcl
# terraform.tfvars
assign_public_ip_to_ec2 = true   # Assign public IP
enable_nat_gateway      = false  # Not needed when public IP is assigned
```

**Characteristics:**
- ✅ **Direct Internet Access**: EC2 has public IP and direct internet connectivity
- ✅ **Easy Testing**: SSH and web access directly from internet
- ✅ **Cost Effective**: No NAT Gateway charges
- ⚠️ **Security Consideration**: EC2 exposed to internet (mitigated by security groups)

#### **Option 2: Private IP Only (Production/Secure)**
```hcl
# terraform.tfvars  
assign_public_ip_to_ec2 = false  # No public IP assigned
enable_nat_gateway      = true   # Recommended for outbound internet access
```

**Characteristics:**
- 🔒 **Enhanced Security**: EC2 not directly accessible from internet
- 🌐 **Internet via NAT**: Outbound internet access through NAT Gateway (optional)
- 💰 **Additional Cost**: NAT Gateway charges apply (~$45/month) if enabled
- 🔧 **Access Methods**: Requires bastion host, VPN, or NLB for access

### Network Architecture

#### **Configuration Comparison**

```
┌──────────────────────────────────┐    ┌──────────────────────────────────┐
│   🧪 Option 1: Public IP        │    │   🏢 Option 2: Private IP Only  │
│      (Testing/Development)       │    │      (Production/Secure)         │
├──────────────────────────────────┤    ├──────────────────────────────────┤
│                                  │    │                                  │
│     ☁️  Internet                 │    │     ☁️  Internet                 │
│          │                       │    │          │    ╳                  │
│          ▼                       │    │          ▼    ╳ No Direct Access │
│   ┌──────────────┐               │    │   ┌──────────────┐               │
│   │ 🖥️  EC2       │               │    │   │ 🚪 NAT Gateway│               │
│   │   Instance   │               │    │   │              │               │
│   │ (Public IP)  │               │    │   └──────┬───────┘               │
│   │   :80,:3306  │               │    │          │ Outbound Only         │
│   └──────┬───────┘               │    │          ▼                       │
│          │                       │    │   ┌──────────────┐               │
│          ▼                       │    │   │ 🖥️  EC2       │◄──────────────┤
│   ┌──────────────┐               │    │   │   Instance   │ 🔒 VPN/Bastion │
│   │ 🗄️  RDS       │               │    │   │(Private IP) │               │
│   │   MySQL      │               │    │   │   :80,:3306  │               │
│   │   :3306      │               │    │   └──────┬───────┘               │
│   └──────────────┘               │    │          │                       │
│                                  │    │          ▼                       │
│                                  │    │   ┌──────────────┐               │
│ ✅ Direct Internet Access        │    │   │ 🗄️  RDS       │               │
│ ✅ Easy SSH & Web Access         │    │   │   MySQL      │               │
│ ✅ Cost Effective               │    │   │   :3306      │               │
│ ⚠️  Internet Exposure           │    │   └──────────────┘               │
│                                  │    │                                  │
│                                  │    │ 🔒 No Internet Exposure          │
│                                  │    │ 🌐 Outbound via NAT             │
│                                  │    │ 💰 Additional NAT Costs         │
│                                  │    │ 🔧 Requires VPN/Bastion        │
└──────────────────────────────────┘    └──────────────────────────────────┘
```

### Access Patterns by Configuration

| Configuration | SSH Access | Web Access | MySQL Proxy Access | Database Access |
|---------------|------------|------------|-------------------|-----------------|
| **Public IP** | Direct via public IP | Direct via public IP | Direct via public IP | Via proxy or NLB |
| **Private IP Only** | Via bastion/VPN | Via bastion/VPN/NLB | Via NLB | Via proxy or NLB |

### Choosing the Right Configuration

#### **Use Public IP When:**
- 🧪 **Development/Testing**: Need quick and easy access
- 💰 **Cost Optimization**: Avoiding NAT Gateway charges  
- 🚀 **Proof of Concept**: Rapid prototyping and validation
- 🔧 **Simple Architecture**: Minimal complexity requirements

#### **Use Private IP Only When:**
- 🏢 **Production Environment**: Enhanced security posture
- 🔒 **Compliance Requirements**: No direct internet exposure
- 🌐 **Enterprise Network**: Integration with existing VPN/bastion infrastructure
- 🛡️ **Defense in Depth**: Layered security architecture

### Switching Between Configurations

You can easily switch between public IP and private IP only configurations:

```bash
# Switch to private IP only (production mode)
sed -i 's/assign_public_ip_to_ec2 = true/assign_public_ip_to_ec2 = false/' terraform.tfvars
sed -i 's/enable_nat_gateway = false/enable_nat_gateway = true/' terraform.tfvars

# Apply changes
terraform plan
terraform apply
```

### Cost Considerations

| Resource | Public IP Assigned | Private IP Only |
|----------|-------------------|-----------------|
| **EC2 Instance** | ~$8.50/month | ~$8.50/month |
| **NAT Gateway** | $0 | ~$45/month (if enabled) |
| **Elastic IP** | $0 | ~$3.60/month (if NAT enabled) |
| **Total** | ~$8.50/month | ~$8.50-57/month |

### Multi-Environment Support
Create separate `.tfvars` files for different environments:
```bash
# Development
terraform apply -var-file="dev.tfvars"

# Production  
terraform apply -var-file="prod.tfvars"
```

## 🔍 Outputs

After deployment, the following information will be available:

- **VPC ID** and CIDR block
- **Subnet IDs** for all created subnets
- **EC2 Public IP** and DNS name
- **RDS Endpoint** (sensitive output)
- **Security Group IDs**
- **SSH Key Information** with auto-generated private key file path
- **MySQL Proxy Information** (if enabled)
- **NLB Information** (if enabled)
- **VPC Endpoint Service Information** (if enabled) - service name and connection details

## 📚 Dependencies

The infrastructure has the following dependency chain:
```
VPC → Subnets → Security Groups → EC2/RDS
     → Internet Gateway → Route Tables
```

All dependencies are explicitly defined using `depends_on` attributes for reliable deployment order.

## 🤝 Contributing

1. Update variable definitions in `variables.tf` with proper validation
2. Test changes in a development environment first
3. Update this README when adding new features
4. Follow Terraform best practices for resource naming and tagging

## 👨‍💼 Author

**Lead Scale Solutions Engineer Haley Won**

This AWS infrastructure project was designed and implemented as a comprehensive, production-ready Terraform solution for enterprise cloud deployments.

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🆘 Troubleshooting

### Common Issues

1. **Key Pair Not Found**: Ensure the key pair exists in your AWS region
2. **CIDR Overlap**: Verify subnet CIDR blocks don't overlap
3. **Security Group Rules**: Check if corporate firewall blocks the configured ports
4. **RDS Subnet Group**: Requires at least 2 subnets in different AZs

### Useful Commands

```bash
# Check current state
terraform show

# Format code
terraform fmt

# Validate configuration
terraform validate

# Show specific resource
terraform state show aws_instance.web
```

For additional help, please check the [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs).
