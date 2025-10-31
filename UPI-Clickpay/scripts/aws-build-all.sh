#!/bin/bash

set -e

# Configuration
AWS_REGION=${AWS_REGION:-us-east-1}
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ENVIRONMENT=${1:-dev}

echo "Building and pushing all services to ECR for $ENVIRONMENT environment..."
echo "AWS Account ID: $AWS_ACCOUNT_ID"
echo "AWS Region: $AWS_REGION"

# Get ECR login token
echo "Logging into ECR..."
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# Function to build and push service
build_and_push() {
    local service_name=$1
    local service_path=$2
    
    echo "Building $service_name..."
    cd $service_path
    
    # Build Docker image
    docker build -t payment-gateway/$service_name:$ENVIRONMENT .
    
    # Tag for ECR
    docker tag payment-gateway/$service_name:$ENVIRONMENT $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/payment-gateway/$service_name:$ENVIRONMENT
    
    # Push to ECR
    docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/payment-gateway/$service_name:$ENVIRONMENT
    
    echo "$service_name pushed successfully!"
    cd - > /dev/null
}

# Build and push all services
build_and_push "auth-service" "backend/auth-service"
build_and_push "payment-service" "backend/payment-service"
build_and_push "merchant-service" "backend/merchant-service"
build_and_push "transaction-service" "backend/transaction-service"
build_and_push "api-gateway" "backend/api-gateway"
build_and_push "frontend" "frontend"

echo "All services built and pushed successfully!"
echo "Images tagged with environment: $ENVIRONMENT"