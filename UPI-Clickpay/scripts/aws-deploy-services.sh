#!/bin/bash

set -e

# Configuration
ENVIRONMENT=${1:-dev}
AWS_REGION=${AWS_REGION:-us-east-1}
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "Deploying ECS services for $ENVIRONMENT environment..."

# Function to create and register task definition
create_task_definition() {
    local service_name=$1
    local port=$2
    local health_path=$3
    
    echo "Creating task definition for $service_name..."
    
    cat > /tmp/${service_name}-${ENVIRONMENT}.json << EOF
{
    "family": "payment-gateway-${service_name}-${ENVIRONMENT}",
    "networkMode": "awsvpc",
    "requiresCompatibilities": ["FARGATE"],
    "cpu": "256",
    "memory": "512",
    "executionRoleArn": "arn:aws:iam::${AWS_ACCOUNT_ID}:role/ecsTaskExecutionRole-${ENVIRONMENT}",
    "containerDefinitions": [
        {
            "name": "${service_name}",
            "image": "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/payment-gateway/${service_name}:${ENVIRONMENT}",
            "portMappings": [
                {
                    "containerPort": ${port},
                    "protocol": "tcp"
                }
            ],
            "environment": [
                {
                    "name": "SPRING_PROFILES_ACTIVE",
                    "value": "${ENVIRONMENT}"
                },
                {
                    "name": "DB_HOST",
                    "value": "$(aws rds describe-db-instances --db-instance-identifier payment-gateway-${ENVIRONMENT}-db --query 'DBInstances[0].Endpoint.Address' --output text)"
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
                }
            ],
            "secrets": [
                {
                    "name": "DB_PASSWORD",
                    "valueFrom": "arn:aws:ssm:${AWS_REGION}:${AWS_ACCOUNT_ID}:parameter/payment-gateway/${ENVIRONMENT}/db-password"
                },
                {
                    "name": "JWT_SECRET",
                    "valueFrom": "arn:aws:ssm:${AWS_REGION}:${AWS_ACCOUNT_ID}:parameter/payment-gateway/${ENVIRONMENT}/jwt-secret"
                }
            ],
            "logConfiguration": {
                "logDriver": "awslogs",
                "options": {
                    "awslogs-group": "/ecs/payment-gateway-${service_name}-${ENVIRONMENT}",
                    "awslogs-region": "${AWS_REGION}",
                    "awslogs-stream-prefix": "ecs"
                }
            },
            "healthCheck": {
                "command": ["CMD-SHELL", "curl -f http://localhost:${port}${health_path} || exit 1"],
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
    aws ecs register-task-definition --cli-input-json file:///tmp/${service_name}-${ENVIRONMENT}.json
    
    # Clean up temp file
    rm /tmp/${service_name}-${ENVIRONMENT}.json
}

# Function to create ECS service
create_ecs_service() {
    local service_name=$1
    local port=$2
    local target_group_arn=$3
    
    echo "Creating ECS service for $service_name..."
    
    # Get subnet IDs
    PRIVATE_SUBNETS=$(aws ec2 describe-subnets \
        --filters "Name=tag:Name,Values=payment-gateway-${ENVIRONMENT}-private-*" \
        --query 'Subnets[*].SubnetId' --output text | tr '\t' ',')
    
    # Get security group ID
    ECS_SG=$(aws ec2 describe-security-groups \
        --filters "Name=group-name,Values=payment-gateway-${ENVIRONMENT}-ecs-sg" \
        --query 'SecurityGroups[0].GroupId' --output text)
    
    # Create service
    aws ecs create-service \
        --cluster payment-gateway-${ENVIRONMENT} \
        --service-name ${service_name} \
        --task-definition payment-gateway-${service_name}-${ENVIRONMENT} \
        --desired-count 2 \
        --launch-type FARGATE \
        --network-configuration "awsvpcConfiguration={subnets=[${PRIVATE_SUBNETS}],securityGroups=[${ECS_SG}],assignPublicIp=DISABLED}" \
        --load-balancers targetGroupArn=${target_group_arn},containerName=${service_name},containerPort=${port} \
        --health-check-grace-period-seconds 300 \
        --tags key=Environment,value=${ENVIRONMENT}
    
    echo "Waiting for $service_name to be stable..."
    aws ecs wait services-stable --cluster payment-gateway-${ENVIRONMENT} --services ${service_name}
}

# Get target group ARNs
AUTH_TG_ARN=$(aws elbv2 describe-target-groups --names payment-gateway-${ENVIRONMENT}-auth-tg --query 'TargetGroups[0].TargetGroupArn' --output text)
PAYMENT_TG_ARN=$(aws elbv2 describe-target-groups --names payment-gateway-${ENVIRONMENT}-payment-tg --query 'TargetGroups[0].TargetGroupArn' --output text)
MERCHANT_TG_ARN=$(aws elbv2 describe-target-groups --names payment-gateway-${ENVIRONMENT}-merchant-tg --query 'TargetGroups[0].TargetGroupArn' --output text)
TRANSACTION_TG_ARN=$(aws elbv2 describe-target-groups --names payment-gateway-${ENVIRONMENT}-transaction-tg --query 'TargetGroups[0].TargetGroupArn' --output text)
API_GW_TG_ARN=$(aws elbv2 describe-target-groups --names payment-gateway-${ENVIRONMENT}-api-gw-tg --query 'TargetGroups[0].TargetGroupArn' --output text)

# Create task definitions and services
create_task_definition "auth-service" "8080" "/auth/health"
create_ecs_service "auth-service" "8080" "$AUTH_TG_ARN"

create_task_definition "payment-service" "8081" "/payments/health"
create_ecs_service "payment-service" "8081" "$PAYMENT_TG_ARN"

create_task_definition "merchant-service" "8082" "/merchants/health"
create_ecs_service "merchant-service" "8082" "$MERCHANT_TG_ARN"

create_task_definition "transaction-service" "8083" "/transactions/health"
create_ecs_service "transaction-service" "8083" "$TRANSACTION_TG_ARN"

create_task_definition "api-gateway" "8084" "/health"
create_ecs_service "api-gateway" "8084" "$API_GW_TG_ARN"

echo "All services deployed successfully!"