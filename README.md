# Databricks Network Connectivity Configuration (NCC) Demo

🏗️ **Multi-Cloud Infrastructure Templates for Databricks Private Connectivity**

This repository provides production-ready Terraform templates for enabling **Databricks Serverless SQL Warehouses** to securely connect to **private cloud databases** through **Network Connectivity Configuration (NCC)** and cloud-native private networking solutions.

## 🌟 Project Overview

The Databricks NCC Demo project showcases how to establish secure, private connectivity between Databricks workspaces and cloud databases without exposing data to the public internet. This is particularly valuable for enterprise environments that require:

- 🔐 **Private Database Connectivity**: Direct access to private RDS/SQL databases
- ⚡ **Serverless SQL Compatibility**: Works with Databricks Serverless SQL Warehouses
- 🛡️ **Zero Internet Exposure**: All traffic stays within cloud backbone networks
- 🏢 **Enterprise Security**: Meets compliance and security requirements
- 🚀 **Easy Deployment**: Infrastructure as Code (IaC) with Terraform

### Key Features

- **🔗 Databricks Lakehouse Federation**: Connects to databases using built-in federation (no custom JDBC drivers)
- **🌐 PrivateLink Integration**: Leverages cloud-native private connectivity
- **📊 Load Balancing**: High availability with Network Load Balancers
- **🔧 Flexible Configuration**: Multiple deployment scenarios (dev, prod, enterprise)
- **📈 Cost Optimization**: Multiple configuration options for different budgets

## 🌥️ Supported Cloud Platforms

### ✅ Currently Available

| Cloud Provider | Status | Features | Documentation |
|---------------|--------|----------|---------------|
| **AWS** | 🟢 Production Ready | VPC, EC2, RDS, NLB, PrivateLink, Databricks NCC | [AWS Documentation](./aws/README.md) |

### 🚧 Planned Support

| Cloud Provider | Status | Target Features | ETA |
|---------------|--------|-----------------|-----|
| **Azure** | 🔄 Planned | VNET, VM, SQL Database, Load Balancer, Private Link | TBD |
| **GCP** | 🔄 Planned | VPC, Compute Engine, Cloud SQL, Load Balancer, Private Service Connect | TBD |

## 📁 Project Structure

```
databricks-ncc-demo/
├── README.md                    # This file - project overview
├── aws/                         # AWS implementation
│   ├── README.md               # AWS-specific documentation
│   ├── main.tf                 # Terraform configuration
│   ├── variables.tf            # Variable definitions
│   ├── outputs.tf              # Output values
│   ├── terraform.tfvars        # Configuration values
│   ├── vpc.tf                  # VPC networking
│   ├── ec2.tf                  # EC2 instances
│   ├── rds.tf                  # RDS MySQL database
│   ├── nlb.tf                  # Network Load Balancer
│   ├── databricks.tf           # Databricks NCC configuration
│   ├── keypair.tf              # SSH key management
│   └── init_db.sql             # Database initialization
├── azure/                      # (Coming Soon) Azure implementation
│   └── README.md               # Azure-specific documentation
└── gcp/                        # (Coming Soon) GCP implementation
    └── README.md               # GCP-specific documentation
```

## 🚀 Quick Start

### Prerequisites

1. **Terraform** installed (version >= 1.0)
   ```bash
   terraform --version
   ```

2. **Cloud CLI** configured for your target platform:
   - AWS: `aws configure` 
   - Azure: `az login` (coming soon)
   - GCP: `gcloud auth login` (coming soon)

3. **Databricks Account** with admin privileges
   - Account Console access: https://accounts.cloud.databricks.com
   - OAuth application configured for API access

### Getting Started with AWS

1. **Navigate to AWS directory**:
   ```bash
   cd aws/
   ```

2. **Follow AWS-specific instructions**:
   ```bash
   # Read the comprehensive AWS documentation
   cat README.md
   
   # Or open in your browser/editor
   open README.md
   ```

3. **Key configuration steps**:
   ```bash
   # Copy and customize variables
   cp terraform.tfvars.example terraform.tfvars
   
   # Initialize and deploy
   terraform init
   terraform plan
   terraform apply
   ```

📚 **For detailed setup instructions, configuration options, and troubleshooting**, see the [AWS Documentation](./aws/README.md).

## 🎯 Use Cases

### 🧪 **Development & Testing**
- Quick setup for testing Databricks connectivity
- Cost-optimized configuration
- Direct internet access for easy debugging

### 🏢 **Production Deployments**
- High availability with load balancing
- Private subnet placement for enhanced security
- Comprehensive monitoring and logging

### 🌐 **Multi-Account/Cross-VPC**
- PrivateLink for secure cross-account access
- Enterprise-grade security controls
- Compliance-ready architectures

### 🔗 **Databricks Integration**
- Serverless SQL Warehouse connectivity
- Lakehouse Federation support
- Private database access without custom drivers

## 📊 Architecture Overview

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Databricks    │    │   Cloud Network  │    │   Database      │
│   Workspace     │    │   (VPC/VNET)     │    │   (RDS/SQL)     │
│                 │    │                  │    │                 │
│ ┌─────────────┐ │    │ ┌──────────────┐ │    │ ┌─────────────┐ │
│ │ Serverless  │◄┼────┼►│ PrivateLink  │◄┼────┼►│   Private   │ │
│ │ SQL         │ │    │ │ Endpoint     │ │    │ │   Database  │ │
│ │ Warehouse   │ │    │ │              │ │    │ │   Instance  │ │
│ └─────────────┘ │    │ └──────────────┘ │    │ └─────────────┘ │
│                 │    │        │         │    │                 │
│                 │    │ ┌──────▼──────┐  │    │                 │
│                 │    │ │   Network   │  │    │                 │
│                 │    │ │ Load Balance│  │    │                 │
│                 │    │ └─────────────┘  │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
      NCC Config           Private Network         MySQL/SQL DB
```

## 🛠️ Configuration Scenarios

| Scenario | Description | Monthly Cost | Security Level | Use Case |
|----------|-------------|--------------|----------------|-----------|
| **Development** | Public subnet, direct access | ~$10 | Low | Testing, Learning |
| **Production** | Private subnet, high availability | ~$55 | High | Production workloads |
| **Enterprise** | Multi-account, PrivateLink | ~$65 | Highest | Enterprise deployments |

## 🤝 Contributing

We welcome contributions for additional cloud platforms and improvements!

### Adding New Cloud Support

1. **Create cloud directory**: `mkdir azure/` or `mkdir gcp/`
2. **Implement Terraform templates**: Follow AWS structure as reference
3. **Add comprehensive documentation**: Include README.md with setup instructions
4. **Test thoroughly**: Validate all configuration scenarios
5. **Submit pull request**: Include examples and test results

### Contribution Guidelines

- Follow Terraform best practices
- Include comprehensive documentation
- Add validation rules for variables
- Provide multiple configuration scenarios
- Test in development environment first

## 📞 Support & Documentation

### Platform-Specific Documentation
- **AWS**: [Comprehensive AWS Guide](./aws/README.md)
- **Azure**: Coming Soon
- **GCP**: Coming Soon

### Getting Help
1. Check platform-specific README files
2. Review configuration validation errors
3. Consult Terraform and cloud provider documentation
4. Submit issues with detailed error logs

## 👨‍💼 Author

**Lead Scale Solutions Engineer Haley Won**

This multi-cloud infrastructure project was designed as a comprehensive, production-ready solution for enterprise Databricks deployments requiring private database connectivity.

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

---

**🔗 Quick Links:**
- [AWS Setup Guide](./aws/README.md) - Production-ready AWS implementation
- [Databricks Account Console](https://accounts.cloud.databricks.com) - Configure OAuth for API access
- [Terraform Documentation](https://www.terraform.io/docs) - Infrastructure as Code reference