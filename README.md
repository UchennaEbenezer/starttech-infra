# StartTech Infrastructure Codebase (Terraform)

This repository contains the Infrastructure as Code (IaC) configuration for deploying StartTech's full-stack ToDo application on AWS.

## Architecture Overview

The infrastructure provisions a highly available, secure, and autoscaled network:
- **Networking**: Custom VPC with 2 Public Subnets (active in AZ-A and AZ-B) and 2 Private Subnets. Trailing NAT Gateways provide internet egress for backend systems.
- **Load Balancing**: An internet-facing Application Load Balancer (ALB) routing public requests to the private backend cluster.
- **Compute Tier**: An Auto Scaling Group (ASG) of EC2 instances running Go API Docker containers in the private subnets.
- **Database Tier**: A dedicated EC2 instance running MongoDB 8.0 in a private subnet, locked down to only accept connections from the backend ASG.
- **Cache Tier**: An Amazon ElastiCache Redis replication group inside private subnets for sessions and cache layers.
- **Static Hosting**: An AWS S3 bucket holding React assets, served securely over HTTPS via a CloudFront CDN using Origin Access Control (OAC).
- **Monitoring**: AWS CloudWatch Log Groups collecting application logs via the Docker `awslogs` log driver, plus alarms and dashboards.

---

## Directory Structure

```text
starttech-infra/
├── .github/
│   └── workflows/
│       └── infrastructure-deploy.yml    # Terraform CI/CD pipeline
├── terraform/
│   ├── main.tf                          # Root module calling modules & setting SSM parameters
│   ├── variables.tf                     # Root variables
│   ├── outputs.tf                       # Exposed output parameters
│   ├── terraform.tfvars.example         # Example configuration
│   └── modules/
│       ├── networking/                  # VPC, Subnets, Gateways, Route Tables
│       ├── compute/                     # ALB, ASG, Bastion, MongoDB, Security Groups, ECR
│       ├── storage/                     # S3 bucket, CloudFront distribution, ElastiCache
│       └── monitoring/                  # Log Groups, IAM policies, instance profiles
├── scripts/
│   └── deploy-infrastructure.sh         # Helper wrapper script for local execution
├── monitoring/
│   ├── cloudwatch-dashboard.json        # Operations dashboard JSON template
│   ├── alarm-definitions.json           # Alarm definitions templates
│   └── log-insights-queries.txt         # Pre-written CloudWatch Logs Queries
└── README.md
```

---

## Local Deployment Guide

### Prerequisites
1. Install [Terraform](https://www.terraform.io/downloads.html) (version >= 1.0.0).
2. Configure AWS CLI with appropriate credentials:
   ```bash
   aws configure
   ```

### Steps to Provision
1. Navigate to the `terraform` directory:
   ```bash
   cd terraform
   ```
2. Copy the variables file and adjust it for your environment (specify your IP for SSH access):
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```
3. Initialize and provision using the wrapper script:
   ```bash
   chmod +x ../scripts/deploy-infrastructure.sh
   ../scripts/deploy-infrastructure.sh apply prod
   ```

---

## CI/CD Pipeline Integration (GitHub Actions)

On merges/pushes to the `main` branch, the `.github/workflows/infrastructure-deploy.yml` pipeline automatically runs `terraform fmt`, `terraform validate`, `terraform plan`, and executes `terraform apply`.

### GitHub Secrets Required:
To run the pipelines successfully, add the following secrets to your GitHub repository (`Settings -> Secrets and variables -> Actions`):
- `AWS_ACCESS_KEY_ID`: IAM deployment user Access Key ID.
- `AWS_SECRET_ACCESS_KEY`: IAM deployment user Secret Access Key.
- `AWS_REGION`: Target AWS Region (e.g. `us-east-1`).
- `KEY_PAIR_NAME`: The name of an existing EC2 Key Pair in the target region for SSH access.
- `MY_IP_ADDRESS`: Your public IP address in CIDR format (e.g. `198.51.100.42/32`) to authorize Bastion host access.
- `ENVIRONMENT`: Deployment environment tag (e.g. `prod`).
