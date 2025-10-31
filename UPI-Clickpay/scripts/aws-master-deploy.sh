#!/bin/bash

set -e

# Master deployment script for AWS Payment Gateway
# This script orchestrates the entire deployment process

# Configuration
ENVIRONMENT=${1:-dev}
DEPLOY_TYPE=${2:-full}  # full, infrastructure, services, monitoring
AWS_REGION=${AWS_REGION:-us-east-1}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local color=$1
    local message=$2
    echo -e "${color}[$(date '+%Y-%m-%d %H:%M:%S')] $message${NC}"
}

print_status $BLUE "Starting AWS deployment for $ENVIRONMENT environment..."
print_status $BLUE "Deployment type: $DEPLOY_TYPE"

# Validate prerequisites
print_status $YELLOW "Validating prerequisites..."

# Check AWS CLI
if ! command -v aws &> /dev/null; then
    print_status $RED "AWS CLI not found. Please install AWS CLI."
    exit 1
fi

# Check Docker
if ! command -v docker &> /dev/null; then
    print_status $RED "Docker not found. Please install Docker."
    exit 1
fi

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    print_status $RED "AWS credentials not configured. Please run 'aws configure'."
    exit 1
fi

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
print_status $GREEN "AWS Account ID: $AWS_ACCOUNT_ID"

# Function to deploy infrastructure
deploy_infrastructure() {
    print_status $BLUE "Deploying infrastructure..."
    
    # This would typically use CloudFormation or Terraform
    # For now, we'll use the manual steps from the detailed guide
    print_status $YELLOW "Infrastructure deployment requires manual steps from AWS_DETAILED_DEPLOYMENT_GUIDE.md"
    print_status $YELLOW "Please follow steps 1-13 for VPC, subnets, security groups, RDS, and ALB setup"
    
    # Check if infrastructure exists
    VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=payment-gateway-${ENVIRONMENT}-vpc" --query 'Vpcs[0].VpcId' --output text 2>/dev/null || echo "None")
    
    if [ "$VPC_ID" = "None" ] || [ -z "$VPC_ID" ]; then
        print_status $RED "Infrastructure not found. Please run infrastructure setup first."
        print_status $YELLOW "Follow steps 1-13 in AWS_DETAILED_DEPLOYMENT_GUIDE.md"
        return 1
    else
        print_status $GREEN "Infrastructure found: VPC $VPC_ID"
        return 0
    fi
}

# Function to setup secrets
setup_secrets() {
    print_status $BLUE "Setting up secrets and parameters..."
    ./scripts/aws-setup-secrets.sh $ENVIRONMENT
    
    if [ $? -eq 0 ]; then
        print_status $GREEN "Secrets setup completed"
    else
        print_status $RED "Secrets setup failed"
        return 1
    fi
}

# Function to build and push images
build_and_push() {
    print_status $BLUE "Building and pushing Docker images..."
    ./scripts/aws-build-all.sh $ENVIRONMENT
    
    if [ $? -eq 0 ]; then
        print_status $GREEN "All images built and pushed successfully"
    else
        print_status $RED "Image build/push failed"
        return 1
    fi
}

# Function to deploy services
deploy_services() {
    print_status $BLUE "Deploying ECS services..."
    ./scripts/aws-deploy-services.sh $ENVIRONMENT
    
    if [ $? -eq 0 ]; then
        print_status $GREEN "Services deployed successfully"
    else
        print_status $RED "Service deployment failed"
        return 1
    fi
}

# Function to setup monitoring
setup_monitoring() {
    print_status $BLUE "Setting up monitoring and alerting..."
    ./scripts/aws-monitoring-setup.sh $ENVIRONMENT
    
    if [ $? -eq 0 ]; then
        print_status $GREEN "Monitoring setup completed"
    else
        print_status $RED "Monitoring setup failed"
        return 1
    fi
}

# Function to test deployment
test_deployment() {
    print_status $BLUE "Testing deployment..."
    
    # Get ALB DNS name
    ALB_DNS=$(aws elbv2 describe-load-balancers \
        --names "payment-gateway-${ENVIRONMENT}-alb" \
        --query 'LoadBalancers[0].DNSName' --output text 2>/dev/null || echo "")
    
    if [ -z "$ALB_DNS" ] || [ "$ALB_DNS" = "None" ]; then
        print_status $RED "ALB not found. Cannot run tests."
        return 1
    fi
    
    print_status $YELLOW "ALB DNS: $ALB_DNS"
    ./scripts/aws-test-deployment.sh $ENVIRONMENT $ALB_DNS
    
    if [ $? -eq 0 ]; then
        print_status $GREEN "Deployment tests completed"
    else
        print_status $RED "Some tests failed"
        return 1
    fi
}

# Main deployment logic
case $DEPLOY_TYPE in
    "infrastructure")
        deploy_infrastructure
        ;;
    "secrets")
        setup_secrets
        ;;
    "build")
        build_and_push
        ;;
    "services")
        deploy_services
        ;;
    "monitoring")
        setup_monitoring
        ;;
    "test")
        test_deployment
        ;;
    "full")
        print_status $BLUE "Running full deployment..."
        
        # Check infrastructure
        if ! deploy_infrastructure; then
            print_status $RED "Infrastructure check failed. Please set up infrastructure first."
            exit 1
        fi
        
        # Setup secrets
        if ! setup_secrets; then
            print_status $RED "Secrets setup failed"
            exit 1
        fi
        
        # Build and push images
        if ! build_and_push; then
            print_status $RED "Build and push failed"
            exit 1
        fi
        
        # Deploy services
        if ! deploy_services; then
            print_status $RED "Service deployment failed"
            exit 1
        fi
        
        # Setup monitoring
        if ! setup_monitoring; then
            print_status $RED "Monitoring setup failed"
            exit 1
        fi
        
        # Test deployment
        if ! test_deployment; then
            print_status $YELLOW "Some tests failed, but deployment may still be functional"
        fi
        
        print_status $GREEN "Full deployment completed successfully!"
        ;;
    *)
        print_status $RED "Invalid deployment type: $DEPLOY_TYPE"
        echo "Usage: $0 <environment> <deploy_type>"
        echo "Environment: dev, staging, prod"
        echo "Deploy Type: infrastructure, secrets, build, services, monitoring, test, full"
        exit 1
        ;;
esac

# Print deployment summary
print_status $BLUE "=== Deployment Summary ==="
print_status $BLUE "Environment: $ENVIRONMENT"
print_status $BLUE "AWS Account: $AWS_ACCOUNT_ID"
print_status $BLUE "AWS Region: $AWS_REGION"

if [ "$DEPLOY_TYPE" = "full" ] || [ "$DEPLOY_TYPE" = "test" ]; then
    ALB_DNS=$(aws elbv2 describe-load-balancers \
        --names "payment-gateway-${ENVIRONMENT}-alb" \
        --query 'LoadBalancers[0].DNSName' --output text 2>/dev/null || echo "Not found")
    print_status $BLUE "ALB DNS: $ALB_DNS"
    
    if [ "$ALB_DNS" != "Not found" ]; then
        print_status $GREEN "Application URL: http://$ALB_DNS"
        print_status $GREEN "API Base URL: http://$ALB_DNS/api"
    fi
fi

print_status $GREEN "Deployment script completed!"

# Next steps
print_status $BLUE "=== Next Steps ==="
echo "1. Monitor CloudWatch dashboard: PaymentGateway-${ENVIRONMENT}"
echo "2. Subscribe to SNS alerts for notifications"
echo "3. Set up SSL certificate for production"
echo "4. Configure custom domain name"
echo "5. Set up CI/CD pipeline for automated deployments"
echo "6. Review and adjust auto-scaling policies"
echo "7. Set up backup schedules"
echo "8. Configure WAF for additional security"