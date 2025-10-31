# AWS Deployment Guide - Production & Non-Production

## Overview

This guide covers deploying our Payment Gateway application to AWS using modern cloud-native services for both production and non-production environments.

## Architecture Overview

### Non-Production (Development/Staging)
```
CloudFront → ALB → ECS Fargate → RDS (Single AZ) → ElastiCache
```

### Production
```
CloudFront → ALB → ECS Fargate (Multi-AZ) → RDS (Multi-AZ) → ElastiCache → S3 → CloudWatch
```

## AWS Services Used

- **ECS Fargate** - Container orchestration
- **RDS PostgreSQL** - Managed database
- **ElastiCache Redis** - Caching layer
- **Application Load Balancer** - Traffic distribution
- **CloudFront** - CDN for frontend
- **S3** - Static assets and backups
- **CloudWatch** - Monitoring and logging
- **Secrets Manager** - Secure configuration
- **VPC** - Network isolation

## Prerequisites

- AWS CLI installed and configured
- Docker installed
- Terraform installed (optional)
- Domain name for production deployment## P
art 1: AWS Infrastructure Setup

### Step 1: VPC and Networking

Create VPC with public and private subnets:

```bash
# Create VPC
aws ec2 create-vpc --cidr-block 10.0.0.0/16 --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=payment-gateway-vpc}]'

# Create Internet Gateway
aws ec2 create-internet-gateway --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=payment-gateway-igw}]'

# Create subnets
aws ec2 create-subnet --vpc-id vpc-xxx --cidr-block 10.0.1.0/24 --availability-zone us-east-1a --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=public-subnet-1a}]'
aws ec2 create-subnet --vpc-id vpc-xxx --cidr-block 10.0.2.0/24 --availability-zone us-east-1b --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=public-subnet-1b}]'
aws ec2 create-subnet --vpc-id vpc-xxx --cidr-block 10.0.3.0/24 --availability-zone us-east-1a --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=private-subnet-1a}]'
aws ec2 create-subnet --vpc-id vpc-xxx --cidr-block 10.0.4.0/24 --availability-zone us-east-1b --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=private-subnet-1b}]'
```

### Step 2: RDS Database Setup

#### Non-Production RDS
```bash
aws rds create-db-instance \
    --db-instance-identifier payment-gateway-dev-db \
    --db-instance-class db.t3.micro \
    --engine postgres \
    --engine-version 15.4 \
    --master-username pgadmin \
    --master-user-password YourSecurePassword123 \
    --allocated-storage 20 \
    --vpc-security-group-ids sg-xxx \
    --db-subnet-group-name payment-gateway-db-subnet-group \
    --backup-retention-period 7 \
    --storage-encrypted \
    --tags Key=Environment,Value=development
```

#### Production RDS
```bash
aws rds create-db-instance \
    --db-instance-identifier payment-gateway-prod-db \
    --db-instance-class db.r5.large \
    --engine postgres \
    --engine-version 15.4 \
    --master-username pgadmin \
    --master-user-password YourSecurePassword123 \
    --allocated-storage 100 \
    --storage-type gp3 \
    --multi-az \
    --vpc-security-group-ids sg-xxx \
    --db-subnet-group-name payment-gateway-db-subnet-group \
    --backup-retention-period 30 \
    --storage-encrypted \
    --deletion-protection \
    --tags Key=Environment,Value=production
```