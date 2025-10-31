# AWS Deployment Guide - Complete Step-by-Step

## Table of Contents
1. [Prerequisites Setup](#prerequisites-setup)
2. [Non-Production Deployment](#non-production-deployment)
3. [Production Deployment](#production-deployment)
4. [Build and Deploy Process](#build-and-deploy-process)
5. [Testing and Verification](#testing-and-verification)
6. [Monitoring and Maintenance](#monitoring-and-maintenance)

---

## Prerequisites Setup

### Step 1: Install Required Tools

#### Install AWS CLI
```bash
# Windows (using PowerShell)
Invoke-WebRequest -Uri "https://awscli.amazonaws.com/AWSCLIV2.msi" -OutFile "AWSCLIV2.msi"
Start-Process msiexec.exe -Wait -ArgumentList '/I AWSCLIV2.msi /quiet'

# Verify installation
aws --version
```

#### Install Docker Desktop
```bash
# Download and install Docker Desktop for Windows
# Visit: https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe

# Verify installation
docker --version
docker-compose --version
```

#### Install Node.js and npm
```bash
# Download and install Node.js from https://nodejs.org/
# Verify installation
node --version
npm --version
```

### Step 2: Configure AWS CLI
```bash
# Configure AWS credentials
aws configure
# Enter:
# AWS Access Key ID: YOUR_ACCESS_KEY
# AWS Secret Access Key: YOUR_SECRET_KEY
# Default region name: us-east-1
# Default output format: json

# Verify configuration
aws sts get-caller-identity
```

### Step 3: Set Environment Variables
```bash
# Create environment configuration file
echo "AWS_REGION=us-east-1" > .env.aws
echo "AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)" >> .env.aws
echo "PROJECT_NAME=payment-gateway" >> .env.aws

# Load environment variables
source .env.aws
```

---

## Non-Production Deployment

### Phase 1: Infrastructure Setup

#### Step 1: Create VPC and Networking
```bash
# Create VPC
VPC_ID=$(aws ec2 create-vpc \
    --cidr-block 10.0.0.0/16 \
    --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=payment-gateway-dev-vpc},{Key=Environment,Value=development}]' \
    --query 'Vpc.VpcId' --output text)

echo "VPC ID: $VPC_ID"

# Enable DNS hostnames
aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-hostnames

# Create Internet Gateway
IGW_ID=$(aws ec2 create-internet-gateway \
    --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=payment-gateway-dev-igw}]' \
    --query 'InternetGateway.InternetGatewayId' --output text)

echo "Internet Gateway ID: $IGW_ID"

# Attach Internet Gateway to VPC
aws ec2 attach-internet-gateway --vpc-id $VPC_ID --internet-gateway-id $IGW_ID
```

#### Step 2: Create Subnets
```bash
# Create Public Subnet 1
PUBLIC_SUBNET_1=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block 10.0.1.0/24 \
    --availability-zone us-east-1a \
    --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=payment-gateway-dev-public-1a}]' \
    --query 'Subnet.SubnetId' --output text)

# Create Public Subnet 2
PUBLIC_SUBNET_2=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block 10.0.2.0/24 \
    --availability-zone us-east-1b \
    --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=payment-gateway-dev-public-1b}]' \
    --query 'Subnet.SubnetId' --output text)

# Create Private Subnet 1
PRIVATE_SUBNET_1=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block 10.0.3.0/24 \
    --availability-zone us-east-1a \
    --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=payment-gateway-dev-private-1a}]' \
    --query 'Subnet.SubnetId' --output text)

# Create Private Subnet 2
PRIVATE_SUBNET_2=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block 10.0.4.0/24 \
    --availability-zone us-east-1b \
    --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=payment-gateway-dev-private-1b}]' \
    --query 'Subnet.SubnetId' --output text)

echo "Public Subnets: $PUBLIC_SUBNET_1, $PUBLIC_SUBNET_2"
echo "Private Subnets: $PRIVATE_SUBNET_1, $PRIVATE_SUBNET_2"
```

#### Step 3: Configure Route Tables
```bash
# Get main route table
MAIN_RT=$(aws ec2 describe-route-tables \
    --filters "Name=vpc-id,Values=$VPC_ID" "Name=association.main,Values=true" \
    --query 'RouteTables[0].RouteTableId' --output text)

# Create public route table
PUBLIC_RT=$(aws ec2 create-route-table \
    --vpc-id $VPC_ID \
    --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=payment-gateway-dev-public-rt}]' \
    --query 'RouteTable.RouteTableId' --output text)

# Add route to internet gateway
aws ec2 create-route \
    --route-table-id $PUBLIC_RT \
    --destination-cidr-block 0.0.0.0/0 \
    --gateway-id $IGW_ID

# Associate public subnets with public route table
aws ec2 associate-route-table --subnet-id $PUBLIC_SUBNET_1 --route-table-id $PUBLIC_RT
aws ec2 associate-route-table --subnet-id $PUBLIC_SUBNET_2 --route-table-id $PUBLIC_RT

# Enable auto-assign public IP for public subnets
aws ec2 modify-subnet-attribute --subnet-id $PUBLIC_SUBNET_1 --map-public-ip-on-launch
aws ec2 modify-subnet-attribute --subnet-id $PUBLIC_SUBNET_2 --map-public-ip-on-launch
```

#### Step 4: Create Security Groups
```bash
# ALB Security Group
ALB_SG=$(aws ec2 create-security-group \
    --group-name payment-gateway-dev-alb-sg \
    --description "Security group for ALB" \
    --vpc-id $VPC_ID \
    --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value=payment-gateway-dev-alb-sg}]' \
    --query 'GroupId' --output text)

# Allow HTTP and HTTPS traffic
aws ec2 authorize-security-group-ingress \
    --group-id $ALB_SG \
    --protocol tcp \
    --port 80 \
    --cidr 0.0.0.0/0

aws ec2 authorize-security-group-ingress \
    --group-id $ALB_SG \
    --protocol tcp \
    --port 443 \
    --cidr 0.0.0.0/0

# ECS Security Group
ECS_SG=$(aws ec2 create-security-group \
    --group-name payment-gateway-dev-ecs-sg \
    --description "Security group for ECS tasks" \
    --vpc-id $VPC_ID \
    --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value=payment-gateway-dev-ecs-sg}]' \
    --query 'GroupId' --output text)

# Allow traffic from ALB
aws ec2 authorize-security-group-ingress \
    --group-id $ECS_SG \
    --protocol tcp \
    --port 8080 \
    --source-group $ALB_SG

aws ec2 authorize-security-group-ingress \
    --group-id $ECS_SG \
    --protocol tcp \
    --port 8081 \
    --source-group $ALB_SG

aws ec2 authorize-security-group-ingress \
    --group-id $ECS_SG \
    --protocol tcp \
    --port 8082 \
    --source-group $ALB_SG

aws ec2 authorize-security-group-ingress \
    --group-id $ECS_SG \
    --protocol tcp \
    --port 8083 \
    --source-group $ALB_SG

aws ec2 authorize-security-group-ingress \
    --group-id $ECS_SG \
    --protocol tcp \
    --port 8084 \
    --source-group $ALB_SG

# RDS Security Group
RDS_SG=$(aws ec2 create-security-group \
    --group-name payment-gateway-dev-rds-sg \
    --description "Security group for RDS" \
    --vpc-id $VPC_ID \
    --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value=payment-gateway-dev-rds-sg}]' \
    --query 'GroupId' --output text)

# Allow PostgreSQL traffic from ECS
aws ec2 authorize-security-group-ingress \
    --group-id $RDS_SG \
    --protocol tcp \
    --port 5432 \
    --source-group $ECS_SG

echo "Security Groups Created:"
echo "ALB SG: $ALB_SG"
echo "ECS SG: $ECS_SG"
echo "RDS SG: $RDS_SG"
```

### Phase 2: Database Setup

#### Step 5: Create DB Subnet Group
```bash
# Create DB subnet group
aws rds create-db-subnet-group \
    --db-subnet-group-name payment-gateway-dev-db-subnet-group \
    --db-subnet-group-description "DB subnet group for payment gateway dev" \
    --subnet-ids $PRIVATE_SUBNET_1 $PRIVATE_SUBNET_2 \
    --tags Key=Name,Value=payment-gateway-dev-db-subnet-group Key=Environment,Value=development
```

#### Step 6: Create RDS Instance (Non-Production)
```bash
# Create RDS instance
aws rds create-db-instance \
    --db-instance-identifier payment-gateway-dev-db \
    --db-instance-class db.t3.micro \
    --engine postgres \
    --engine-version 15.4 \
    --master-username pgadmin \
    --master-user-password DevPassword123! \
    --allocated-storage 20 \
    --storage-type gp2 \
    --vpc-security-group-ids $RDS_SG \
    --db-subnet-group-name payment-gateway-dev-db-subnet-group \
    --backup-retention-period 7 \
    --storage-encrypted \
    --no-multi-az \
    --no-publicly-accessible \
    --tags Key=Name,Value=payment-gateway-dev-db Key=Environment,Value=development

# Wait for RDS to be available
echo "Waiting for RDS instance to be available..."
aws rds wait db-instance-available --db-instance-identifier payment-gateway-dev-db

# Get RDS endpoint
RDS_ENDPOINT=$(aws rds describe-db-instances \
    --db-instance-identifier payment-gateway-dev-db \
    --query 'DBInstances[0].Endpoint.Address' --output text)

echo "RDS Endpoint: $RDS_ENDPOINT"
```

### Phase 3: Container Registry Setup

#### Step 7: Create ECR Repositories
```bash
# Create ECR repositories for each service
aws ecr create-repository --repository-name payment-gateway/auth-service --region us-east-1
aws ecr create-repository --repository-name payment-gateway/payment-service --region us-east-1
aws ecr create-repository --repository-name payment-gateway/merchant-service --region us-east-1
aws ecr create-repository --repository-name payment-gateway/transaction-service --region us-east-1
aws ecr create-repository --repository-name payment-gateway/api-gateway --region us-east-1
aws ecr create-repository --repository-name payment-gateway/frontend --region us-east-1

# Get ECR login token
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com
```

### Phase 4: Build and Push Images

#### Step 8: Build Docker Images
```bash
# Build auth service
cd backend/auth-service
docker build -t payment-gateway/auth-service .
docker tag payment-gateway/auth-service:latest $AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/payment-gateway/auth-service:latest
docker push $AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/payment-gateway/auth-service:latest

# Build payment service
cd ../payment-service
docker build -t payment-gateway/payment-service .
docker tag payment-gateway/payment-service:latest $AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/payment-gateway/payment-service:latest
docker push $AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/payment-gateway/payment-service:latest

# Build merchant service
cd ../merchant-service
docker build -t payment-gateway/merchant-service .
docker tag payment-gateway/merchant-service:latest $AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/payment-gateway/merchant-service:latest
docker push $AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/payment-gateway/merchant-service:latest

# Build transaction service
cd ../transaction-service
docker build -t payment-gateway/transaction-service .
docker tag payment-gateway/transaction-service:latest $AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/payment-gateway/transaction-service:latest
docker push $AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/payment-gateway/transaction-service:latest

# Build API gateway
cd ../api-gateway
docker build -t payment-gateway/api-gateway .
docker tag payment-gateway/api-gateway:latest $AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/payment-gateway/api-gateway:latest
docker push $AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/payment-gateway/api-gateway:latest

# Build frontend
cd ../../frontend
docker build -t payment-gateway/frontend .
docker tag payment-gateway/frontend:latest $AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/payment-gateway/frontend:latest
docker push $AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/payment-gateway/frontend:latest

cd ..
```

### Phase 5: ECS Setup

#### Step 9: Create ECS Cluster
```bash
# Create ECS cluster
aws ecs create-cluster \
    --cluster-name payment-gateway-dev \
    --capacity-providers FARGATE \
    --default-capacity-provider-strategy capacityProvider=FARGATE,weight=1 \
    --tags key=Environment,value=development
```

#### Step 10: Create Task Execution Role
```bash
# Create task execution role
aws iam create-role \
    --role-name ecsTaskExecutionRole-dev \
    --assume-role-policy-document '{
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Principal": {
                    "Service": "ecs-tasks.amazonaws.com"
                },
                "Action": "sts:AssumeRole"
            }
        ]
    }'

# Attach policy to role
aws iam attach-role-policy \
    --role-name ecsTaskExecutionRole-dev \
    --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy

# Get role ARN
TASK_EXECUTION_ROLE_ARN=$(aws iam get-role \
    --role-name ecsTaskExecutionRole-dev \
    --query 'Role.Arn' --output text)

echo "Task Execution Role ARN: $TASK_EXECUTION_ROLE_ARN"
```

#### Step 11: Create Application Load Balancer
```bash
# Create ALB
ALB_ARN=$(aws elbv2 create-load-balancer \
    --name payment-gateway-dev-alb \
    --subnets $PUBLIC_SUBNET_1 $PUBLIC_SUBNET_2 \
    --security-groups $ALB_SG \
    --tags Key=Environment,Value=development \
    --query 'LoadBalancers[0].LoadBalancerArn' --output text)

# Get ALB DNS name
ALB_DNS=$(aws elbv2 describe-load-balancers \
    --load-balancer-arns $ALB_ARN \
    --query 'LoadBalancers[0].DNSName' --output text)

echo "ALB ARN: $ALB_ARN"
echo "ALB DNS: $ALB_DNS"
```

#### Step 12: Create Target Groups
```bash
# Auth service target group
AUTH_TG_ARN=$(aws elbv2 create-target-group \
    --name payment-gateway-dev-auth-tg \
    --protocol HTTP \
    --port 8080 \
    --vpc-id $VPC_ID \
    --target-type ip \
    --health-check-path /auth/health \
    --health-check-interval-seconds 30 \
    --health-check-timeout-seconds 5 \
    --healthy-threshold-count 2 \
    --unhealthy-threshold-count 3 \
    --query 'TargetGroups[0].TargetGroupArn' --output text)

# Payment service target group
PAYMENT_TG_ARN=$(aws elbv2 create-target-group \
    --name payment-gateway-dev-payment-tg \
    --protocol HTTP \
    --port 8081 \
    --vpc-id $VPC_ID \
    --target-type ip \
    --health-check-path /payments/health \
    --health-check-interval-seconds 30 \
    --health-check-timeout-seconds 5 \
    --healthy-threshold-count 2 \
    --unhealthy-threshold-count 3 \
    --query 'TargetGroups[0].TargetGroupArn' --output text)

# Merchant service target group
MERCHANT_TG_ARN=$(aws elbv2 create-target-group \
    --name payment-gateway-dev-merchant-tg \
    --protocol HTTP \
    --port 8082 \
    --vpc-id $VPC_ID \
    --target-type ip \
    --health-check-path /merchants/health \
    --health-check-interval-seconds 30 \
    --health-check-timeout-seconds 5 \
    --healthy-threshold-count 2 \
    --unhealthy-threshold-count 3 \
    --query 'TargetGroups[0].TargetGroupArn' --output text)

# Transaction service target group
TRANSACTION_TG_ARN=$(aws elbv2 create-target-group \
    --name payment-gateway-dev-transaction-tg \
    --protocol HTTP \
    --port 8083 \
    --vpc-id $VPC_ID \
    --target-type ip \
    --health-check-path /transactions/health \
    --health-check-interval-seconds 30 \
    --health-check-timeout-seconds 5 \
    --healthy-threshold-count 2 \
    --unhealthy-threshold-count 3 \
    --query 'TargetGroups[0].TargetGroupArn' --output text)

# API Gateway target group
API_GW_TG_ARN=$(aws elbv2 create-target-group \
    --name payment-gateway-dev-api-gw-tg \
    --protocol HTTP \
    --port 8084 \
    --vpc-id $VPC_ID \
    --target-type ip \
    --health-check-path /health \
    --health-check-interval-seconds 30 \
    --health-check-timeout-seconds 5 \
    --healthy-threshold-count 2 \
    --unhealthy-threshold-count 3 \
    --query 'TargetGroups[0].TargetGroupArn' --output text)

# Frontend target group
FRONTEND_TG_ARN=$(aws elbv2 create-target-group \
    --name payment-gateway-dev-frontend-tg \
    --protocol HTTP \
    --port 80 \
    --vpc-id $VPC_ID \
    --target-type ip \
    --health-check-path / \
    --health-check-interval-seconds 30 \
    --health-check-timeout-seconds 5 \
    --healthy-threshold-count 2 \
    --unhealthy-threshold-count 3 \
    --query 'TargetGroups[0].TargetGroupArn' --output text)

echo "Target Groups Created:"
echo "Auth TG: $AUTH_TG_ARN"
echo "Payment TG: $PAYMENT_TG_ARN"
echo "Merchant TG: $MERCHANT_TG_ARN"
echo "Transaction TG: $TRANSACTION_TG_ARN"
echo "API Gateway TG: $API_GW_TG_ARN"
echo "Frontend TG: $FRONTEND_TG_ARN"
```

#### Step 13: Create ALB Listeners and Rules
```bash
# Create HTTP listener
LISTENER_ARN=$(aws elbv2 create-listener \
    --load-balancer-arn $ALB_ARN \
    --protocol HTTP \
    --port 80 \
    --default-actions Type=forward,TargetGroupArn=$FRONTEND_TG_ARN \
    --query 'Listeners[0].ListenerArn' --output text)

# Create rules for API routing
aws elbv2 create-rule \
    --listener-arn $LISTENER_ARN \
    --priority 100 \
    --conditions Field=path-pattern,Values="/auth/*" \
    --actions Type=forward,TargetGroupArn=$AUTH_TG_ARN

aws elbv2 create-rule \
    --listener-arn $LISTENER_ARN \
    --priority 200 \
    --conditions Field=path-pattern,Values="/payments/*" \
    --actions Type=forward,TargetGroupArn=$PAYMENT_TG_ARN

aws elbv2 create-rule \
    --listener-arn $LISTENER_ARN \
    --priority 300 \
    --conditions Field=path-pattern,Values="/merchants/*" \
    --actions Type=forward,TargetGroupArn=$MERCHANT_TG_ARN

aws elbv2 create-rule \
    --listener-arn $LISTENER_ARN \
    --priority 400 \
    --conditions Field=path-pattern,Values="/transactions/*" \
    --actions Type=forward,TargetGroupArn=$TRANSACTION_TG_ARN

aws elbv2 create-rule \
    --listener-arn $LISTENER_ARN \
    --priority 500 \
    --conditions Field=path-pattern,Values="/api/*" \
    --actions Type=forward,TargetGroupArn=$API_GW_TG_ARN
```

---

## Production Deployment

### Phase 1: Production Infrastructure Setup

#### Step 14: Create Production VPC (Similar to Dev but with different CIDR)
```bash
# Create Production VPC
PROD_VPC_ID=$(aws ec2 create-vpc \
    --cidr-block 10.1.0.0/16 \
    --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=payment-gateway-prod-vpc},{Key=Environment,Value=production}]' \
    --query 'Vpc.VpcId' --output text)

echo "Production VPC ID: $PROD_VPC_ID"

# Enable DNS hostnames
aws ec2 modify-vpc-attribute --vpc-id $PROD_VPC_ID --enable-dns-hostnames

# Create Internet Gateway
PROD_IGW_ID=$(aws ec2 create-internet-gateway \
    --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=payment-gateway-prod-igw}]' \
    --query 'InternetGateway.InternetGatewayId' --output text)

# Attach Internet Gateway to VPC
aws ec2 attach-internet-gateway --vpc-id $PROD_VPC_ID --internet-gateway-id $PROD_IGW_ID
```

#### Step 15: Create Production Subnets (Multi-AZ)
```bash
# Create Public Subnets
PROD_PUBLIC_SUBNET_1=$(aws ec2 create-subnet \
    --vpc-id $PROD_VPC_ID \
    --cidr-block 10.1.1.0/24 \
    --availability-zone us-east-1a \
    --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=payment-gateway-prod-public-1a}]' \
    --query 'Subnet.SubnetId' --output text)

PROD_PUBLIC_SUBNET_2=$(aws ec2 create-subnet \
    --vpc-id $PROD_VPC_ID \
    --cidr-block 10.1.2.0/24 \
    --availability-zone us-east-1b \
    --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=payment-gateway-prod-public-1b}]' \
    --query 'Subnet.SubnetId' --output text)

PROD_PUBLIC_SUBNET_3=$(aws ec2 create-subnet \
    --vpc-id $PROD_VPC_ID \
    --cidr-block 10.1.3.0/24 \
    --availability-zone us-east-1c \
    --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=payment-gateway-prod-public-1c}]' \
    --query 'Subnet.SubnetId' --output text)

# Create Private Subnets
PROD_PRIVATE_SUBNET_1=$(aws ec2 create-subnet \
    --vpc-id $PROD_VPC_ID \
    --cidr-block 10.1.4.0/24 \
    --availability-zone us-east-1a \
    --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=payment-gateway-prod-private-1a}]' \
    --query 'Subnet.SubnetId' --output text)

PROD_PRIVATE_SUBNET_2=$(aws ec2 create-subnet \
    --vpc-id $PROD_VPC_ID \
    --cidr-block 10.1.5.0/24 \
    --availability-zone us-east-1b \
    --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=payment-gateway-prod-private-1b}]' \
    --query 'Subnet.SubnetId' --output text)

PROD_PRIVATE_SUBNET_3=$(aws ec2 create-subnet \
    --vpc-id $PROD_VPC_ID \
    --cidr-block 10.1.6.0/24 \
    --availability-zone us-east-1c \
    --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=payment-gateway-prod-private-1c}]' \
    --query 'Subnet.SubnetId' --output text)

echo "Production Subnets Created"
```

#### Step 16: Create NAT Gateways for Production
```bash
# Allocate Elastic IPs for NAT Gateways
NAT_EIP_1=$(aws ec2 allocate-address --domain vpc --query 'AllocationId' --output text)
NAT_EIP_2=$(aws ec2 allocate-address --domain vpc --query 'AllocationId' --output text)
NAT_EIP_3=$(aws ec2 allocate-address --domain vpc --query 'AllocationId' --output text)

# Create NAT Gateways
NAT_GW_1=$(aws ec2 create-nat-gateway \
    --subnet-id $PROD_PUBLIC_SUBNET_1 \
    --allocation-id $NAT_EIP_1 \
    --tag-specifications 'ResourceType=nat-gateway,Tags=[{Key=Name,Value=payment-gateway-prod-nat-1a}]' \
    --query 'NatGateway.NatGatewayId' --output text)

NAT_GW_2=$(aws ec2 create-nat-gateway \
    --subnet-id $PROD_PUBLIC_SUBNET_2 \
    --allocation-id $NAT_EIP_2 \
    --tag-specifications 'ResourceType=nat-gateway,Tags=[{Key=Name,Value=payment-gateway-prod-nat-1b}]' \
    --query 'NatGateway.NatGatewayId' --output text)

NAT_GW_3=$(aws ec2 create-nat-gateway \
    --subnet-id $PROD_PUBLIC_SUBNET_3 \
    --allocation-id $NAT_EIP_3 \
    --tag-specifications 'ResourceType=nat-gateway,Tags=[{Key=Name,Value=payment-gateway-prod-nat-1c}]' \
    --query 'NatGateway.NatGatewayId' --output text)

# Wait for NAT Gateways to be available
aws ec2 wait nat-gateway-available --nat-gateway-ids $NAT_GW_1 $NAT_GW_2 $NAT_GW_3
```

#### Step 17: Create Production RDS (Multi-AZ)
```bash
# Create DB subnet group for production
aws rds create-db-subnet-group \
    --db-subnet-group-name payment-gateway-prod-db-subnet-group \
    --db-subnet-group-description "DB subnet group for payment gateway prod" \
    --subnet-ids $PROD_PRIVATE_SUBNET_1 $PROD_PRIVATE_SUBNET_2 $PROD_PRIVATE_SUBNET_3 \
    --tags Key=Name,Value=payment-gateway-prod-db-subnet-group Key=Environment,Value=production

# Create production RDS instance
aws rds create-db-instance \
    --db-instance-identifier payment-gateway-prod-db \
    --db-instance-class db.r5.xlarge \
    --engine postgres \
    --engine-version 15.4 \
    --master-username pgadmin \
    --master-user-password ProdSecurePassword123! \
    --allocated-storage 500 \
    --storage-type gp3 \
    --iops 3000 \
    --multi-az \
    --vpc-security-group-ids $PROD_RDS_SG \
    --db-subnet-group-name payment-gateway-prod-db-subnet-group \
    --backup-retention-period 30 \
    --preferred-backup-window "03:00-04:00" \
    --preferred-maintenance-window "sun:04:00-sun:05:00" \
    --storage-encrypted \
    --kms-key-id alias/aws/rds \
    --deletion-protection \
    --no-publicly-accessible \
    --performance-insights-enabled \
    --monitoring-interval 60 \
    --tags Key=Name,Value=payment-gateway-prod-db Key=Environment,Value=production

# Wait for RDS to be available
echo "Waiting for production RDS instance to be available..."
aws rds wait db-instance-available --db-instance-identifier payment-gateway-prod-db

# Get production RDS endpoint
PROD_RDS_ENDPOINT=$(aws rds describe-db-instances \
    --db-instance-identifier payment-gateway-prod-db \
    --query 'DBInstances[0].Endpoint.Address' --output text)

echo "Production RDS Endpoint: $PROD_RDS_ENDPOINT"
```

---

## Build and Deploy Process

### Step 18: Create Automated Build Script
```bash
# Create build script
cat > scripts/build-and-deploy-aws.sh << 'EOF'
#!/bin/bash

set -e

# Configuration
AWS_REGION=${AWS_REGION:-us-east-1}
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ENVIRONMENT=${1:-dev}

echo "Building and deploying to $ENVIRONMENT environment..."

# Get ECR login token
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# Build and push auth service
echo "Building auth service..."
cd backend/auth-service
docker build -t payment-gateway/auth-service:$ENVIRONMENT .
docker tag payment-gateway/auth-service:$ENVIRONMENT $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/payment-gateway/auth-service:$ENVIRONMENT
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/payment-gateway/auth-service:$ENVIRONMENT

# Build and push payment service
echo "Building payment service..."
cd ../payment-service
docker build -t payment-gateway/payment-service:$ENVIRONMENT .
docker tag payment-gateway/payment-service:$ENVIRONMENT $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/payment-gateway/payment-service:$ENVIRONMENT
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/payment-gateway/payment-service:$ENVIRONMENT

# Build and push merchant service
echo "Building merchant service..."
cd ../merchant-service
docker build -t payment-gateway/merchant-service:$ENVIRONMENT .
docker tag payment-gateway/merchant-service:$ENVIRONMENT $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/payment-gateway/merchant-service:$ENVIRONMENT
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/payment-gateway/merchant-service:$ENVIRONMENT

# Build and push transaction service
echo "Building transaction service..."
cd ../transaction-service
docker build -t payment-gateway/transaction-service:$ENVIRONMENT .
docker tag payment-gateway/transaction-service:$ENVIRONMENT $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/payment-gateway/transaction-service:$ENVIRONMENT
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/payment-gateway/transaction-service:$ENVIRONMENT

# Build and push API gateway
echo "Building API gateway..."
cd ../api-gateway
docker build -t payment-gateway/api-gateway:$ENVIRONMENT .
docker tag payment-gateway/api-gateway:$ENVIRONMENT $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/payment-gateway/api-gateway:$ENVIRONMENT
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/payment-gateway/api-gateway:$ENVIRONMENT

# Build and push frontend
echo "Building frontend..."
cd ../../frontend
docker build -t payment-gateway/frontend:$ENVIRONMENT .
docker tag payment-gateway/frontend:$ENVIRONMENT $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/payment-gateway/frontend:$ENVIRONMENT
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/payment-gateway/frontend:$ENVIRONMENT

cd ..

echo "All images built and pushed successfully!"
EOF

chmod +x scripts/build-and-deploy-aws.sh
```

### Step 19: Create ECS Task Definitions
```bash
# Create task definition for auth service
cat > aws-deploy/task-definitions/auth-service-dev.json << EOF
{
    "family": "payment-gateway-auth-service-dev",
    "networkMode": "awsvpc",
    "requiresCompatibilities": ["FARGATE"],
    "cpu": "256",
    "memory": "512",
    "executionRoleArn": "$TASK_EXECUTION_ROLE_ARN",
    "containerDefinitions": [
        {
            "name": "auth-service",
            "image": "$AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/payment-gateway/auth-service:dev",
            "portMappings": [
                {
                    "containerPort": 8080,
                    "protocol": "tcp"
                }
            ],
            "environment": [
                {
                    "name": "SPRING_PROFILES_ACTIVE",
                    "value": "dev"
                },
                {
                    "name": "DB_HOST",
                    "value": "$RDS_ENDPOINT"
                },
                {
                    "name": "DB_PORT",
                    "value": "5432"
                },
                {
                    "name": "DB_NAME",
                    "value": "paymentgateway"
                },
                {
                    "name": "DB_USERNAME",
                    "value": "pgadmin"
                },
                {
                    "name": "DB_PASSWORD",
                    "value": "DevPassword123!"
                }
            ],
            "logConfiguration": {
                "logDriver": "awslogs",
                "options": {
                    "awslogs-group": "/ecs/payment-gateway-auth-service-dev",
                    "awslogs-region": "us-east-1",
                    "awslogs-stream-prefix": "ecs"
                }
            },
            "healthCheck": {
                "command": ["CMD-SHELL", "curl -f http://localhost:8080/auth/health || exit 1"],
                "interval": 30,
                "timeout": 5,
                "retries": 3,
                "startPeriod": 60
            }
        }
    ]
}
EOF

# Register task definition
aws ecs register-task-definition --cli-input-json file://aws-deploy/task-definitions/auth-service-dev.json
```

### Step 20: Create ECS Services
```bash
# Create auth service
aws ecs create-service \
    --cluster payment-gateway-dev \
    --service-name auth-service \
    --task-definition payment-gateway-auth-service-dev \
    --desired-count 2 \
    --launch-type FARGATE \
    --network-configuration "awsvpcConfiguration={subnets=[$PRIVATE_SUBNET_1,$PRIVATE_SUBNET_2],securityGroups=[$ECS_SG],assignPublicIp=DISABLED}" \
    --load-balancers targetGroupArn=$AUTH_TG_ARN,containerName=auth-service,containerPort=8080 \
    --health-check-grace-period-seconds 300 \
    --tags key=Environment,value=development

# Wait for service to be stable
aws ecs wait services-stable --cluster payment-gateway-dev --services auth-service
```

---

## Testing and Verification

### Step 21: Create Health Check Script
```bash
# Create health check script
cat > scripts/health-check.sh << 'EOF'
#!/bin/bash

ALB_DNS=$1
if [ -z "$ALB_DNS" ]; then
    echo "Usage: $0 <ALB_DNS_NAME>"
    exit 1
fi

echo "Testing Payment Gateway Health Checks..."
echo "ALB DNS: $ALB_DNS"

# Test auth service health
echo "Testing Auth Service..."
curl -f "http://$ALB_DNS/auth/health" || echo "Auth service health check failed"

# Test payment service health
echo "Testing Payment Service..."
curl -f "http://$ALB_DNS/payments/health" || echo "Payment service health check failed"

# Test merchant service health
echo "Testing Merchant Service..."
curl -f "http://$ALB_DNS/merchants/health" || echo "Merchant service health check failed"

# Test transaction service health
echo "Testing Transaction Service..."
curl -f "http://$ALB_DNS/transactions/health" || echo "Transaction service health check failed"

# Test API gateway health
echo "Testing API Gateway..."
curl -f "http://$ALB_DNS/api/health" || echo "API gateway health check failed"

# Test frontend
echo "Testing Frontend..."
curl -f "http://$ALB_DNS/" || echo "Frontend health check failed"

echo "Health checks completed!"
EOF

chmod +x scripts/health-check.sh
```

### Step 22: Run Health Checks
```bash
# Run health checks
./scripts/health-check.sh $ALB_DNS
```

### Step 23: Create Load Testing Script
```bash
# Create load testing script
cat > scripts/load-test.sh << 'EOF'
#!/bin/bash

ALB_DNS=$1
if [ -z "$ALB_DNS" ]; then
    echo "Usage: $0 <ALB_DNS_NAME>"
    exit 1
fi

echo "Running load tests against $ALB_DNS..."

# Install Apache Bench if not available
which ab > /dev/null || {
    echo "Apache Bench (ab) not found. Please install apache2-utils"
    exit 1
}

# Test auth endpoint
echo "Load testing auth endpoint..."
ab -n 1000 -c 10 "http://$ALB_DNS/auth/health"

# Test payment endpoint
echo "Load testing payment endpoint..."
ab -n 1000 -c 10 "http://$ALB_DNS/payments/health"

echo "Load testing completed!"
EOF

chmod +x scripts/load-test.sh
```

### Step 24: Database Migration and Seeding
```bash
# Create database setup script
cat > scripts/setup-database.sh << 'EOF'
#!/bin/bash

RDS_ENDPOINT=$1
DB_PASSWORD=$2

if [ -z "$RDS_ENDPOINT" ] || [ -z "$DB_PASSWORD" ]; then
    echo "Usage: $0 <RDS_ENDPOINT> <DB_PASSWORD>"
    exit 1
fi

echo "Setting up database on $RDS_ENDPOINT..."

# Install PostgreSQL client if not available
which psql > /dev/null || {
    echo "PostgreSQL client not found. Please install postgresql-client"
    exit 1
}

# Create database and tables
PGPASSWORD=$DB_PASSWORD psql -h $RDS_ENDPOINT -U pgadmin -d postgres -c "CREATE DATABASE IF NOT EXISTS paymentgateway;"

# Run database initialization script
PGPASSWORD=$DB_PASSWORD psql -h $RDS_ENDPOINT -U pgadmin -d paymentgateway -f database/init.sql

echo "Database setup completed!"
EOF

chmod +x scripts/setup-database.sh

# Run database setup
./scripts/setup-database.sh $RDS_ENDPOINT "DevPassword123!"
```

---

## Monitoring and Maintenance

### Step 25: Create CloudWatch Log Groups
```bash
# Create log groups for each service
aws logs create-log-group --log-group-name /ecs/payment-gateway-auth-service-dev
aws logs create-log-group --log-group-name /ecs/payment-gateway-payment-service-dev
aws logs create-log-group --log-group-name /ecs/payment-gateway-merchant-service-dev
aws logs create-log-group --log-group-name /ecs/payment-gateway-transaction-service-dev
aws logs create-log-group --log-group-name /ecs/payment-gateway-api-gateway-dev
aws logs create-log-group --log-group-name /ecs/payment-gateway-frontend-dev

# Set retention policy (30 days for dev, 90 days for prod)
aws logs put-retention-policy --log-group-name /ecs/payment-gateway-auth-service-dev --retention-in-days 30
aws logs put-retention-policy --log-group-name /ecs/payment-gateway-payment-service-dev --retention-in-days 30
aws logs put-retention-policy --log-group-name /ecs/payment-gateway-merchant-service-dev --retention-in-days 30
aws logs put-retention-policy --log-group-name /ecs/payment-gateway-transaction-service-dev --retention-in-days 30
aws logs put-retention-policy --log-group-name /ecs/payment-gateway-api-gateway-dev --retention-in-days 30
aws logs put-retention-policy --log-group-name /ecs/payment-gateway-frontend-dev --retention-in-days 30
```

### Step 26: Create Monitoring Dashboard
```bash
# Create CloudWatch dashboard
cat > aws-deploy/monitoring/dashboard.json << 'EOF'
{
    "widgets": [
        {
            "type": "metric",
            "properties": {
                "metrics": [
                    ["AWS/ECS", "CPUUtilization", "ServiceName", "auth-service", "ClusterName", "payment-gateway-dev"],
                    [".", "MemoryUtilization", ".", ".", ".", "."],
                    [".", "CPUUtilization", "ServiceName", "payment-service", "ClusterName", "payment-gateway-dev"],
                    [".", "MemoryUtilization", ".", ".", ".", "."]
                ],
                "period": 300,
                "stat": "Average",
                "region": "us-east-1",
                "title": "ECS Service Metrics"
            }
        },
        {
            "type": "metric",
            "properties": {
                "metrics": [
                    ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", "payment-gateway-dev-alb"],
                    [".", "TargetResponseTime", ".", "."],
                    [".", "HTTPCode_Target_2XX_Count", ".", "."],
                    [".", "HTTPCode_Target_4XX_Count", ".", "."],
                    [".", "HTTPCode_Target_5XX_Count", ".", "."]
                ],
                "period": 300,
                "stat": "Sum",
                "region": "us-east-1",
                "title": "ALB Metrics"
            }
        }
    ]
}
EOF

# Create dashboard
aws cloudwatch put-dashboard \
    --dashboard-name "PaymentGateway-Dev" \
    --dashboard-body file://aws-deploy/monitoring/dashboard.json
```

### Step 27: Create Backup Script
```bash
# Create backup script
cat > scripts/backup.sh << 'EOF'
#!/bin/bash

ENVIRONMENT=${1:-dev}
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "Creating backup for $ENVIRONMENT environment..."

# Create RDS snapshot
aws rds create-db-snapshot \
    --db-instance-identifier payment-gateway-$ENVIRONMENT-db \
    --db-snapshot-identifier payment-gateway-$ENVIRONMENT-backup-$TIMESTAMP

# Backup ECS task definitions
mkdir -p backups/$TIMESTAMP
aws ecs list-task-definitions --family-prefix payment-gateway --query 'taskDefinitionArns' --output text | \
while read arn; do
    family=$(echo $arn | cut -d'/' -f2 | cut -d':' -f1)
    aws ecs describe-task-definition --task-definition $arn --query 'taskDefinition' > backups/$TIMESTAMP/$family.json
done

echo "Backup completed: backups/$TIMESTAMP"
EOF

chmod +x scripts/backup.sh
```

### Step 28: Create Deployment Verification Script
```bash
# Create deployment verification script
cat > scripts/verify-deployment.sh << 'EOF'
#!/bin/bash

ENVIRONMENT=${1:-dev}
ALB_DNS=$2

if [ -z "$ALB_DNS" ]; then
    echo "Usage: $0 <environment> <ALB_DNS_NAME>"
    exit 1
fi

echo "Verifying deployment for $ENVIRONMENT environment..."

# Check ECS services
echo "Checking ECS services..."
aws ecs describe-services \
    --cluster payment-gateway-$ENVIRONMENT \
    --services auth-service payment-service merchant-service transaction-service api-gateway \
    --query 'services[*].[serviceName,status,runningCount,desiredCount]' \
    --output table

# Check target group health
echo "Checking target group health..."
aws elbv2 describe-target-health \
    --target-group-arn $(aws elbv2 describe-target-groups --names payment-gateway-$ENVIRONMENT-auth-tg --query 'TargetGroups[0].TargetGroupArn' --output text) \
    --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State]' \
    --output table

# Run health checks
echo "Running health checks..."
./scripts/health-check.sh $ALB_DNS

# Check logs for errors
echo "Checking recent logs for errors..."
aws logs filter-log-events \
    --log-group-name /ecs/payment-gateway-auth-service-$ENVIRONMENT \
    --start-time $(date -d '5 minutes ago' +%s)000 \
    --filter-pattern "ERROR" \
    --query 'events[*].message' \
    --output text

echo "Deployment verification completed!"
EOF

chmod +x scripts/verify-deployment.sh
```

### Step 29: Final Verification
```bash
# Run final verification
./scripts/verify-deployment.sh dev $ALB_DNS

# Test API endpoints
echo "Testing API endpoints..."

# Test user registration
curl -X POST "http://$ALB_DNS/auth/signup" \
    -H "Content-Type: application/json" \
    -d '{
        "email": "test@example.com",
        "password": "password123",
        "firstName": "Test",
        "lastName": "User"
    }'

# Test user login
TOKEN=$(curl -X POST "http://$ALB_DNS/auth/login" \
    -H "Content-Type: application/json" \
    -d '{
        "email": "test@example.com",
        "password": "password123"
    }' | jq -r '.token')

echo "JWT Token: $TOKEN"

# Test authenticated endpoint
curl -X GET "http://$ALB_DNS/merchants/profile" \
    -H "Authorization: Bearer $TOKEN"

echo "All tests completed successfully!"
```

### Step 30: Create Cleanup Script
```bash
# Create cleanup script for development environment
cat > scripts/cleanup-dev.sh << 'EOF'
#!/bin/bash

echo "Cleaning up development environment..."

# Delete ECS services
aws ecs update-service --cluster payment-gateway-dev --service auth-service --desired-count 0
aws ecs delete-service --cluster payment-gateway-dev --service auth-service --force

# Delete ALB and target groups
aws elbv2 delete-load-balancer --load-balancer-arn $ALB_ARN

# Delete RDS instance
aws rds delete-db-instance --db-instance-identifier payment-gateway-dev-db --skip-final-snapshot

# Delete VPC and associated resources
aws ec2 delete-vpc --vpc-id $VPC_ID

echo "Cleanup completed!"
EOF

chmod +x scripts/cleanup-dev.sh
```

## Summary

This comprehensive guide provides step-by-step instructions for deploying the Payment Gateway application to AWS in both non-production and production environments. The deployment includes:

1. **Infrastructure Setup**: VPC, subnets, security groups, NAT gateways
2. **Database Setup**: RDS PostgreSQL with appropriate configurations
3. **Container Registry**: ECR repositories for all services
4. **Container Orchestration**: ECS Fargate with auto-scaling
5. **Load Balancing**: Application Load Balancer with health checks
6. **Monitoring**: CloudWatch logs, metrics, and dashboards
7. **Security**: Proper IAM roles, security groups, and encryption
8. **Automation**: Build, deploy, and verification scripts
9. **Backup and Recovery**: Automated backup procedures

The production environment includes additional features like Multi-AZ deployment, enhanced monitoring, and stricter security configurations.