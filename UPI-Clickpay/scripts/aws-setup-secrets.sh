#!/bin/bash

set -e

# Configuration
ENVIRONMENT=${1:-dev}
AWS_REGION=${AWS_REGION:-us-east-1}

echo "Setting up AWS Systems Manager Parameter Store secrets for $ENVIRONMENT environment..."

# Function to create parameter
create_parameter() {
    local name=$1
    local value=$2
    local type=${3:-String}
    
    echo "Creating parameter: $name"
    aws ssm put-parameter \
        --name "/payment-gateway/${ENVIRONMENT}/${name}" \
        --value "$value" \
        --type "$type" \
        --overwrite \
        --tags Key=Environment,Value=$ENVIRONMENT Key=Project,Value=payment-gateway
}

# Database configuration
if [ "$ENVIRONMENT" = "prod" ]; then
    DB_PASSWORD="ProdSecurePassword123!"
else
    DB_PASSWORD="DevPassword123!"
fi

create_parameter "db-password" "$DB_PASSWORD" "SecureString"

# JWT configuration
JWT_SECRET=$(openssl rand -base64 32)
create_parameter "jwt-secret" "$JWT_SECRET" "SecureString"

# Bank API configuration (placeholder values)
create_parameter "hdfc-api-key" "hdfc-test-api-key-placeholder" "SecureString"
create_parameter "hdfc-api-secret" "hdfc-test-api-secret-placeholder" "SecureString"
create_parameter "hdfc-api-url" "https://api-test.hdfcbank.com" "String"

# UPI configuration
create_parameter "upi-merchant-id" "test-merchant-id" "String"
create_parameter "upi-merchant-key" "test-merchant-key-placeholder" "SecureString"

# Redis configuration (if using ElastiCache)
create_parameter "redis-host" "localhost" "String"
create_parameter "redis-port" "6379" "String"

# Application configuration
create_parameter "app-name" "Payment Gateway" "String"
create_parameter "app-version" "1.0.0" "String"
create_parameter "log-level" "INFO" "String"

# Email configuration (for notifications)
create_parameter "smtp-host" "smtp.gmail.com" "String"
create_parameter "smtp-port" "587" "String"
create_parameter "smtp-username" "noreply@paymentgateway.com" "String"
create_parameter "smtp-password" "smtp-password-placeholder" "SecureString"

# Webhook configuration
create_parameter "webhook-secret" "$(openssl rand -base64 32)" "SecureString"

# API rate limiting
create_parameter "rate-limit-requests" "1000" "String"
create_parameter "rate-limit-window" "3600" "String"

echo "All parameters created successfully!"
echo "Parameters created under namespace: /payment-gateway/${ENVIRONMENT}/"

# List all created parameters
echo "Created parameters:"
aws ssm get-parameters-by-path \
    --path "/payment-gateway/${ENVIRONMENT}/" \
    --query 'Parameters[*].[Name,Type]' \
    --output table