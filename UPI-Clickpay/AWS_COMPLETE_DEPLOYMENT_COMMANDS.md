# AWS Complete Deployment Commands - Step by Step

## Quick Start Commands

### For Development Environment
```bash
# 1. Set up environment variables
export AWS_REGION=us-east-1
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export ENVIRONMENT=dev

# 2. Run master deployment script
./scripts/aws-master-deploy.sh dev full
```

### For Production Environment
```bash
# 1. Set up environment variables
export AWS_REGION=us-east-1
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export ENVIRONMENT=prod

# 2. Run master deployment script
./scripts/aws-master-deploy.sh prod full
```

---

## Detailed Step-by-Step Commands

### Phase 1: Prerequisites and Setup

#### Step 1: Install and Configure AWS CLI
```bash
# Install AWS CLI (Windows PowerShell)
Invoke-WebRequest -Uri "https://awscli.amazonaws.com/AWSCLIV2.msi" -OutFile "AWSCLIV2.msi"
Start-Process msiexec.exe -Wait -ArgumentList '/I AWSCLIV2.msi /quiet'

# Configure AWS CLI
aws configure
# Enter your AWS Access Key ID, Secret Access Key, Region (us-east-1), and output format (json)

# Verify configuration
aws sts get-caller-identity
```

#### Step 2: Set Environment Variables
```bash
# Set environment variables
$env:AWS_REGION = "us-east-1"
$env:AWS_ACCOUNT_ID = (aws sts get-caller-identity --query Account --output text)
$env:ENVIRONMENT = "dev"  # or "prod" for production

# Verify variables
echo "AWS Account ID: $env:AWS_ACCOUNT_ID"
echo "AWS Region: $env:AWS_REGION"
echo "Environment: $env:ENVIRONMENT"
```

### Phase 2: Infrastructure Setup (Development)

#### Step 3: Create VPC and Networking
```bash
# Create VPC
$VPC_ID = (aws ec2 create-vpc --cidr-block 10.0.0.0/16 --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=payment-gateway-dev-vpc},{Key=Environment,Value=development}]' --query 'Vpc.VpcId' --output text)

# Enable DNS hostnames
aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-hostnames

# Create Internet Gateway
$IGW_ID = (aws ec2 create-internet-gateway --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=payment-gateway-dev-igw}]' --query 'InternetGateway.InternetGatewayId' --output text)

# Attach Internet Gateway to VPC
aws ec2 attach-internet-gateway --vpc-id $VPC_ID --internet-gateway-id $IGW_ID
```

#### Step 4: Create Subnets
```bash
# Create Public Subnets
$PUBLIC_SUBNET_1 = (aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.1.0/24 --availability-zone us-east-1a --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=payment-gateway-dev-public-1a}]' --query 'Subnet.SubnetId' --output text)

$PUBLIC_SUBNET_2 = (aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.2.0/24 --availability-zone us-east-1b --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=payment-gateway-dev-public-1b}]' --query 'Subnet.SubnetId' --output text)

# Create Private Subnets
$PRIVATE_SUBNET_1 = (aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.3.0/24 --availability-zone us-east-1a --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=payment-gateway-dev-private-1a}]' --query 'Subnet.SubnetId' --output text)

$PRIVATE_SUBNET_2 = (aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.4.0/24 --availability-zone us-east-1b --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=payment-gateway-dev-private-1b}]' --query 'Subnet.SubnetId' --output text)

echo "Subnets created: Public: $PUBLIC_SUBNET_1, $PUBLIC_SUBNET_2 | Private: $PRIVATE_SUBNET_1, $PRIVATE_SUBNET_2"
```

#### Step 5: Configure Route Tables
```bash
# Create public route table
$PUBLIC_RT = (aws ec2 create-route-table --vpc-id $VPC_ID --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=payment-gateway-dev-public-rt}]' --query 'RouteTable.RouteTableId' --output text)

# Add route to internet gateway
aws ec2 create-route --route-table-id $PUBLIC_RT --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID

# Associate public subnets with public route table
aws ec2 associate-route-table --subnet-id $PUBLIC_SUBNET_1 --route-table-id $PUBLIC_RT
aws ec2 associate-route-table --subnet-id $PUBLIC_SUBNET_2 --route-table-id $PUBLIC_RT

# Enable auto-assign public IP for public subnets
aws ec2 modify-subnet-attribute --subnet-id $PUBLIC_SUBNET_1 --map-public-ip-on-launch
aws ec2 modify-subnet-attribute --subnet-id $PUBLIC_SUBNET_2 --map-public-ip-on-launch
```

#### Step 6: Create Security Groups
```bash
# ALB Security Group
$ALB_SG = (aws ec2 create-security-group --group-name payment-gateway-dev-alb-sg --description "Security group for ALB" --vpc-id $VPC_ID --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value=payment-gateway-dev-alb-sg}]' --query 'GroupId' --output text)

# Allow HTTP and HTTPS traffic
aws ec2 authorize-security-group-ingress --group-id $ALB_SG --protocol tcp --port 80 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $ALB_SG --protocol tcp --port 443 --cidr 0.0.0.0/0

# ECS Security Group
$ECS_SG = (aws ec2 create-security-group --group-name payment-gateway-dev-ecs-sg --description "Security group for ECS tasks" --vpc-id $VPC_ID --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value=payment-gateway-dev-ecs-sg}]' --query 'GroupId' --output text)

# Allow traffic from ALB
aws ec2 authorize-security-group-ingress --group-id $ECS_SG --protocol tcp --port 8080 --source-group $ALB_SG
aws ec2 authorize-security-group-ingress --group-id $ECS_SG --protocol tcp --port 8081 --source-group $ALB_SG
aws ec2 authorize-security-group-ingress --group-id $ECS_SG --protocol tcp --port 8082 --source-group $ALB_SG
aws ec2 authorize-security-group-ingress --group-id $ECS_SG --protocol tcp --port 8083 --source-group $ALB_SG
aws ec2 authorize-security-group-ingress --group-id $ECS_SG --protocol tcp --port 8084 --source-group $ALB_SG

# RDS Security Group
$RDS_SG = (aws ec2 create-security-group --group-name payment-gateway-dev-rds-sg --description "Security group for RDS" --vpc-id $VPC_ID --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value=payment-gateway-dev-rds-sg}]' --query 'GroupId' --output text)

# Allow PostgreSQL traffic from ECS
aws ec2 authorize-security-group-ingress --group-id $RDS_SG --protocol tcp --port 5432 --source-group $ECS_SG
```

### Phase 3: Database Setup

#### Step 7: Create RDS Database
```bash
# Create DB subnet group
aws rds create-db-subnet-group --db-subnet-group-name payment-gateway-dev-db-subnet-group --db-subnet-group-description "DB subnet group for payment gateway dev" --subnet-ids $PRIVATE_SUBNET_1 $PRIVATE_SUBNET_2 --tags Key=Name,Value=payment-gateway-dev-db-subnet-group Key=Environment,Value=development

# Create RDS instance
aws rds create-db-instance --db-instance-identifier payment-gateway-dev-db --db-instance-class db.t3.micro --engine postgres --engine-version 15.4 --master-username pgadmin --master-user-password DevPassword123! --allocated-storage 20 --storage-type gp2 --vpc-security-group-ids $RDS_SG --db-subnet-group-name payment-gateway-dev-db-subnet-group --backup-retention-period 7 --storage-encrypted --no-multi-az --no-publicly-accessible --tags Key=Name,Value=payment-gateway-dev-db Key=Environment,Value=development

# Wait for RDS to be available
aws rds wait db-instance-available --db-instance-identifier payment-gateway-dev-db

# Get RDS endpoint
$RDS_ENDPOINT = (aws rds describe-db-instances --db-instance-identifier payment-gateway-dev-db --query 'DBInstances[0].Endpoint.Address' --output text)
echo "RDS Endpoint: $RDS_ENDPOINT"
```

### Phase 4: Container Registry and Images

#### Step 8: Create ECR Repositories
```bash
# Create ECR repositories
aws ecr create-repository --repository-name payment-gateway/auth-service --region us-east-1
aws ecr create-repository --repository-name payment-gateway/payment-service --region us-east-1
aws ecr create-repository --repository-name payment-gateway/merchant-service --region us-east-1
aws ecr create-repository --repository-name payment-gateway/transaction-service --region us-east-1
aws ecr create-repository --repository-name payment-gateway/api-gateway --region us-east-1
aws ecr create-repository --repository-name payment-gateway/frontend --region us-east-1

# Get ECR login token
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin "$env:AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com"
```

#### Step 9: Build and Push Images
```bash
# Build and push auth service
cd backend/auth-service
docker build -t payment-gateway/auth-service .
docker tag payment-gateway/auth-service:latest "$env:AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/payment-gateway/auth-service:dev"
docker push "$env:AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/payment-gateway/auth-service:dev"

# Build and push payment service
cd ../payment-service
docker build -t payment-gateway/payment-service .
docker tag payment-gateway/payment-service:latest "$env:AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/payment-gateway/payment-service:dev"
docker push "$env:AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/payment-gateway/payment-service:dev"

# Build and push merchant service
cd ../merchant-service
docker build -t payment-gateway/merchant-service .
docker tag payment-gateway/merchant-service:latest "$env:AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/payment-gateway/merchant-service:dev"
docker push "$env:AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/payment-gateway/merchant-service:dev"

# Build and push transaction service
cd ../transaction-service
docker build -t payment-gateway/transaction-service .
docker tag payment-gateway/transaction-service:latest "$env:AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/payment-gateway/transaction-service:dev"
docker push "$env:AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/payment-gateway/transaction-service:dev"

# Build and push API gateway
cd ../api-gateway
docker build -t payment-gateway/api-gateway .
docker tag payment-gateway/api-gateway:latest "$env:AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/payment-gateway/api-gateway:dev"
docker push "$env:AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/payment-gateway/api-gateway:dev"

# Build and push frontend
cd ../../frontend
docker build -t payment-gateway/frontend .
docker tag payment-gateway/frontend:latest "$env:AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/payment-gateway/frontend:dev"
docker push "$env:AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/payment-gateway/frontend:dev"

cd ..
```

### Phase 5: ECS Setup

#### Step 10: Create ECS Cluster
```bash
# Create ECS cluster
aws ecs create-cluster --cluster-name payment-gateway-dev --capacity-providers FARGATE --default-capacity-provider-strategy capacityProvider=FARGATE,weight=1 --tags key=Environment,value=development
```

#### Step 11: Create Task Execution Role
```bash
# Create task execution role
aws iam create-role --role-name ecsTaskExecutionRole-dev --assume-role-policy-document '{
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
aws iam attach-role-policy --role-name ecsTaskExecutionRole-dev --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy

# Get role ARN
$TASK_EXECUTION_ROLE_ARN = (aws iam get-role --role-name ecsTaskExecutionRole-dev --query 'Role.Arn' --output text)
echo "Task Execution Role ARN: $TASK_EXECUTION_ROLE_ARN"
```

#### Step 12: Create Application Load Balancer
```bash
# Create ALB
$ALB_ARN = (aws elbv2 create-load-balancer --name payment-gateway-dev-alb --subnets $PUBLIC_SUBNET_1 $PUBLIC_SUBNET_2 --security-groups $ALB_SG --tags Key=Environment,Value=development --query 'LoadBalancers[0].LoadBalancerArn' --output text)

# Get ALB DNS name
$ALB_DNS = (aws elbv2 describe-load-balancers --load-balancer-arns $ALB_ARN --query 'LoadBalancers[0].DNSName' --output text)
echo "ALB DNS: $ALB_DNS"
```

#### Step 13: Create Target Groups
```bash
# Auth service target group
$AUTH_TG_ARN = (aws elbv2 create-target-group --name payment-gateway-dev-auth-tg --protocol HTTP --port 8080 --vpc-id $VPC_ID --target-type ip --health-check-path /auth/health --health-check-interval-seconds 30 --health-check-timeout-seconds 5 --healthy-threshold-count 2 --unhealthy-threshold-count 3 --query 'TargetGroups[0].TargetGroupArn' --output text)

# Payment service target group
$PAYMENT_TG_ARN = (aws elbv2 create-target-group --name payment-gateway-dev-payment-tg --protocol HTTP --port 8081 --vpc-id $VPC_ID --target-type ip --health-check-path /payments/health --health-check-interval-seconds 30 --health-check-timeout-seconds 5 --healthy-threshold-count 2 --unhealthy-threshold-count 3 --query 'TargetGroups[0].TargetGroupArn' --output text)

# Merchant service target group
$MERCHANT_TG_ARN = (aws elbv2 create-target-group --name payment-gateway-dev-merchant-tg --protocol HTTP --port 8082 --vpc-id $VPC_ID --target-type ip --health-check-path /merchants/health --health-check-interval-seconds 30 --health-check-timeout-seconds 5 --healthy-threshold-count 2 --unhealthy-threshold-count 3 --query 'TargetGroups[0].TargetGroupArn' --output text)

# Transaction service target group
$TRANSACTION_TG_ARN = (aws elbv2 create-target-group --name payment-gateway-dev-transaction-tg --protocol HTTP --port 8083 --vpc-id $VPC_ID --target-type ip --health-check-path /transactions/health --health-check-interval-seconds 30 --health-check-timeout-seconds 5 --healthy-threshold-count 2 --unhealthy-threshold-count 3 --query 'TargetGroups[0].TargetGroupArn' --output text)

# API Gateway target group
$API_GW_TG_ARN = (aws elbv2 create-target-group --name payment-gateway-dev-api-gw-tg --protocol HTTP --port 8084 --vpc-id $VPC_ID --target-type ip --health-check-path /health --health-check-interval-seconds 30 --health-check-timeout-seconds 5 --healthy-threshold-count 2 --unhealthy-threshold-count 3 --query 'TargetGroups[0].TargetGroupArn' --output text)

# Frontend target group
$FRONTEND_TG_ARN = (aws elbv2 create-target-group --name payment-gateway-dev-frontend-tg --protocol HTTP --port 80 --vpc-id $VPC_ID --target-type ip --health-check-path / --health-check-interval-seconds 30 --health-check-timeout-seconds 5 --healthy-threshold-count 2 --unhealthy-threshold-count 3 --query 'TargetGroups[0].TargetGroupArn' --output text)
```

#### Step 14: Create ALB Listeners and Rules
```bash
# Create HTTP listener
$LISTENER_ARN = (aws elbv2 create-listener --load-balancer-arn $ALB_ARN --protocol HTTP --port 80 --default-actions Type=forward,TargetGroupArn=$FRONTEND_TG_ARN --query 'Listeners[0].ListenerArn' --output text)

# Create rules for API routing
aws elbv2 create-rule --listener-arn $LISTENER_ARN --priority 100 --conditions Field=path-pattern,Values="/auth/*" --actions Type=forward,TargetGroupArn=$AUTH_TG_ARN

aws elbv2 create-rule --listener-arn $LISTENER_ARN --priority 200 --conditions Field=path-pattern,Values="/payments/*" --actions Type=forward,TargetGroupArn=$PAYMENT_TG_ARN

aws elbv2 create-rule --listener-arn $LISTENER_ARN --priority 300 --conditions Field=path-pattern,Values="/merchants/*" --actions Type=forward,TargetGroupArn=$MERCHANT_TG_ARN

aws elbv2 create-rule --listener-arn $LISTENER_ARN --priority 400 --conditions Field=path-pattern,Values="/transactions/*" --actions Type=forward,TargetGroupArn=$TRANSACTION_TG_ARN

aws elbv2 create-rule --listener-arn $LISTENER_ARN --priority 500 --conditions Field=path-pattern,Values="/api/*" --actions Type=forward,TargetGroupArn=$API_GW_TG_ARN
```

### Phase 6: Setup Secrets and Parameters

#### Step 15: Setup AWS Systems Manager Parameters
```bash
# Run the secrets setup script
./scripts/aws-setup-secrets.sh dev
```

### Phase 7: Deploy ECS Services

#### Step 16: Deploy Services
```bash
# Run the service deployment script
./scripts/aws-deploy-services.sh dev
```

### Phase 8: Testing and Verification

#### Step 17: Test Deployment
```bash
# Run comprehensive tests
./scripts/aws-test-deployment.sh dev $ALB_DNS
```

#### Step 18: Setup Monitoring
```bash
# Setup CloudWatch monitoring and alerting
./scripts/aws-monitoring-setup.sh dev
```

---

## Production Deployment Differences

For production deployment, use these modified commands:

### Environment Variables for Production
```bash
$env:ENVIRONMENT = "prod"
```

### Production-Specific Configurations

#### Multi-AZ RDS
```bash
# Create production RDS with Multi-AZ
aws rds create-db-instance --db-instance-identifier payment-gateway-prod-db --db-instance-class db.r5.xlarge --engine postgres --engine-version 15.4 --master-username pgadmin --master-user-password ProdSecurePassword123! --allocated-storage 500 --storage-type gp3 --iops 3000 --multi-az --vpc-security-group-ids $RDS_SG --db-subnet-group-name payment-gateway-prod-db-subnet-group --backup-retention-period 30 --preferred-backup-window "03:00-04:00" --preferred-maintenance-window "sun:04:00-sun:05:00" --storage-encrypted --kms-key-id alias/aws/rds --deletion-protection --no-publicly-accessible --performance-insights-enabled --monitoring-interval 60 --tags Key=Name,Value=payment-gateway-prod-db Key=Environment,Value=production
```

#### NAT Gateways for Production
```bash
# Allocate Elastic IPs for NAT Gateways
$NAT_EIP_1 = (aws ec2 allocate-address --domain vpc --query 'AllocationId' --output text)
$NAT_EIP_2 = (aws ec2 allocate-address --domain vpc --query 'AllocationId' --output text)

# Create NAT Gateways
$NAT_GW_1 = (aws ec2 create-nat-gateway --subnet-id $PUBLIC_SUBNET_1 --allocation-id $NAT_EIP_1 --tag-specifications 'ResourceType=nat-gateway,Tags=[{Key=Name,Value=payment-gateway-prod-nat-1a}]' --query 'NatGateway.NatGatewayId' --output text)

$NAT_GW_2 = (aws ec2 create-nat-gateway --subnet-id $PUBLIC_SUBNET_2 --allocation-id $NAT_EIP_2 --tag-specifications 'ResourceType=nat-gateway,Tags=[{Key=Name,Value=payment-gateway-prod-nat-1b}]' --query 'NatGateway.NatGatewayId' --output text)

# Wait for NAT Gateways to be available
aws ec2 wait nat-gateway-available --nat-gateway-ids $NAT_GW_1 $NAT_GW_2
```

---

## Cleanup Commands

### Development Environment Cleanup
```bash
# Delete ECS services
aws ecs update-service --cluster payment-gateway-dev --service auth-service --desired-count 0
aws ecs delete-service --cluster payment-gateway-dev --service auth-service --force

# Delete ALB
aws elbv2 delete-load-balancer --load-balancer-arn $ALB_ARN

# Delete RDS instance
aws rds delete-db-instance --db-instance-identifier payment-gateway-dev-db --skip-final-snapshot

# Delete VPC (this will delete associated resources)
aws ec2 delete-vpc --vpc-id $VPC_ID
```

---

## Troubleshooting Commands

### Check Service Status
```bash
# Check ECS services
aws ecs describe-services --cluster payment-gateway-dev --services auth-service payment-service merchant-service transaction-service

# Check target group health
aws elbv2 describe-target-health --target-group-arn $AUTH_TG_ARN

# Check logs
aws logs get-log-events --log-group-name /ecs/payment-gateway-auth-service-dev --log-stream-name <stream-name>
```

### Health Checks
```bash
# Test endpoints
curl http://$ALB_DNS/auth/health
curl http://$ALB_DNS/payments/health
curl http://$ALB_DNS/merchants/health
curl http://$ALB_DNS/transactions/health
```

---

## Summary

This guide provides complete step-by-step commands for deploying the Payment Gateway application to AWS. The deployment includes:

1. **Infrastructure**: VPC, subnets, security groups, RDS, ALB
2. **Container Registry**: ECR repositories for all services
3. **Container Orchestration**: ECS Fargate with auto-scaling
4. **Load Balancing**: Application Load Balancer with health checks
5. **Security**: IAM roles, security groups, parameter store
6. **Monitoring**: CloudWatch logs, metrics, and alarms
7. **Testing**: Comprehensive deployment verification

Use the master deployment script for automated deployment or follow the detailed commands for manual deployment with full control over each step.