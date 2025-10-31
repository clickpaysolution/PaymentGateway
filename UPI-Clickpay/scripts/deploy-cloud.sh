#!/bin/bash

echo "🚀 Deploying Payment Gateway to Cloud Platforms..."

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check Railway CLI
    if ! command -v railway &> /dev/null; then
        print_error "Railway CLI not found. Installing..."
        npm install -g @railway/cli
        if [ $? -ne 0 ]; then
            print_error "Failed to install Railway CLI"
            exit 1
        fi
    fi
    
    # Check Vercel CLI
    if ! command -v vercel &> /dev/null; then
        print_error "Vercel CLI not found. Installing..."
        npm install -g vercel
        if [ $? -ne 0 ]; then
            print_error "Failed to install Vercel CLI"
            exit 1
        fi
    fi
    
    # Check if logged in to Railway
    if ! railway whoami &> /dev/null; then
        print_warning "Not logged in to Railway. Please login:"
        railway login
    fi
    
    # Check if logged in to Vercel
    if ! vercel whoami &> /dev/null; then
        print_warning "Not logged in to Vercel. Please login:"
        vercel login
    fi
    
    print_success "Prerequisites check completed"
}

# Setup Railway database
setup_database() {
    print_status "Setting up Railway PostgreSQL database..."
    
    # Create new Railway project for database
    railway new payment-gateway-db
    railway add postgresql
    
    # Get database URL
    DATABASE_URL=$(railway variables get DATABASE_URL)
    
    if [ -z "$DATABASE_URL" ]; then
        print_error "Failed to get database URL"
        exit 1
    fi
    
    print_success "Database setup completed"
    print_status "Database URL: $DATABASE_URL"
    
    # Initialize database schema
    print_status "Initializing database schema..."
    railway connect postgresql < database/init.sql
    
    print_success "Database schema initialized"
}

# Deploy backend services to Railway
deploy_backend() {
    print_status "Deploying backend services to Railway..."
    
    # Generate JWT secret
    JWT_SECRET=$(openssl rand -base64 64 | tr -d '\n')
    print_status "Generated JWT Secret: $JWT_SECRET"
    
    # Services to deploy
    services=("auth-service" "payment-service" "merchant-service" "transaction-service" "api-gateway")
    
    # Build all services first
    print_status "Building backend services..."
    cd backend
    mvn clean package -DskipTests
    if [ $? -ne 0 ]; then
        print_error "Backend build failed"
        exit 1
    fi
    cd ..
    
    # Deploy each service
    for service in "${services[@]}"; do
        print_status "Deploying $service to Railway..."
        
        cd "backend/$service"
        
        # Copy Railway configuration files
        cp "../../railway-deploy/railway.json" .
        cp "../../railway-deploy/nixpacks.toml" .
        cp "../../railway-deploy/application-railway.yml" "src/main/resources/"
        
        # Create new Railway service
        railway new "payment-gateway-$service"
        
        # Set environment variables
        railway variables set SPRING_PROFILES_ACTIVE=railway
        railway variables set JWT_SECRET="$JWT_SECRET"
        railway variables set JWT_EXPIRATION=86400000
        railway variables set DATABASE_URL="$DATABASE_URL"
        
        # Service-specific variables
        case $service in
            "auth-service")
                railway variables set SERVER_PORT=8081
                ;;
            "payment-service")
                railway variables set SERVER_PORT=8083
                railway variables set UPI_MERCHANT_ID=merchant@upi
                railway variables set UPI_MERCHANT_NAME="Payment Gateway"
                ;;
            "merchant-service")
                railway variables set SERVER_PORT=8082
                ;;
            "transaction-service")
                railway variables set SERVER_PORT=8084
                ;;
            "api-gateway")
                railway variables set SERVER_PORT=8080
                ;;
        esac
        
        # Deploy to Railway
        railway up --detach
        
        if [ $? -eq 0 ]; then
            print_success "$service deployed successfully"
            
            # Get service URL
            SERVICE_URL=$(railway status --json | jq -r '.deployments[0].url')
            print_status "$service URL: $SERVICE_URL"
            
            # Store URL for API Gateway configuration
            case $service in
                "auth-service")
                    AUTH_SERVICE_URL=$SERVICE_URL
                    ;;
                "payment-service")
                    PAYMENT_SERVICE_URL=$SERVICE_URL
                    ;;
                "merchant-service")
                    MERCHANT_SERVICE_URL=$SERVICE_URL
                    ;;
                "transaction-service")
                    TRANSACTION_SERVICE_URL=$SERVICE_URL
                    ;;
            esac
        else
            print_error "Failed to deploy $service"
        fi
        
        cd ../..
    done
    
    # Update API Gateway with service URLs
    print_status "Updating API Gateway configuration..."
    cd "backend/api-gateway"
    railway service payment-gateway-api-gateway
    railway variables set AUTH_SERVICE_URL="$AUTH_SERVICE_URL"
    railway variables set PAYMENT_SERVICE_URL="$PAYMENT_SERVICE_URL"
    railway variables set MERCHANT_SERVICE_URL="$MERCHANT_SERVICE_URL"
    railway variables set TRANSACTION_SERVICE_URL="$TRANSACTION_SERVICE_URL"
    
    # Redeploy API Gateway
    railway up --detach
    
    # Get API Gateway URL
    API_GATEWAY_URL=$(railway status --json | jq -r '.deployments[0].url')
    print_success "API Gateway deployed at: $API_GATEWAY_URL"
    
    cd ../..
}

# Deploy frontend to Vercel
deploy_frontend() {
    print_status "Deploying frontend to Vercel..."
    
    cd frontend
    
    # Copy Vercel configuration
    cp "../vercel-deploy/vercel.json" .
    
    # Create .env.production
    cat > .env.production << EOF
REACT_APP_API_URL=$API_GATEWAY_URL
REACT_APP_ENVIRONMENT=production
EOF
    
    # Deploy to Vercel
    vercel --prod --yes --env REACT_APP_API_URL="$API_GATEWAY_URL"
    
    if [ $? -eq 0 ]; then
        print_success "Frontend deployed successfully"
        FRONTEND_URL=$(vercel ls --scope=team | grep frontend | awk '{print $2}')
        print_status "Frontend URL: https://$FRONTEND_URL"
    else
        print_error "Failed to deploy frontend"
    fi
    
    cd ..
}

# Deploy test merchant app to Vercel
deploy_test_merchant() {
    print_status "Deploying test merchant app to Vercel..."
    
    cd test-merchant-app
    
    # Copy Vercel configuration
    cp "../vercel-deploy/vercel.json" .
    
    # Create .env.production
    cat > .env.production << EOF
REACT_APP_PAYMENT_GATEWAY_URL=$API_GATEWAY_URL
REACT_APP_MERCHANT_API_KEY=test_api_key_123
EOF
    
    # Deploy to Vercel
    vercel --prod --yes --env REACT_APP_PAYMENT_GATEWAY_URL="$API_GATEWAY_URL" --env REACT_APP_MERCHANT_API_KEY="test_api_key_123"
    
    if [ $? -eq 0 ]; then
        print_success "Test merchant app deployed successfully"
        TEST_MERCHANT_URL=$(vercel ls --scope=team | grep test-merchant | awk '{print $2}')
        print_status "Test Merchant URL: https://$TEST_MERCHANT_URL"
    else
        print_error "Failed to deploy test merchant app"
    fi
    
    cd ..
}

# Verify deployment
verify_deployment() {
    print_status "Verifying deployment..."
    
    # Wait for services to start
    sleep 30
    
    # Check API Gateway health
    print_status "Checking API Gateway health..."
    response=$(curl -s -o /dev/null -w "%{http_code}" "$API_GATEWAY_URL/actuator/health")
    
    if [ "$response" = "200" ]; then
        print_success "API Gateway is healthy"
    else
        print_warning "API Gateway health check failed (HTTP $response)"
    fi
    
    # Check frontend
    print_status "Checking frontend..."
    response=$(curl -s -o /dev/null -w "%{http_code}" "https://$FRONTEND_URL")
    
    if [ "$response" = "200" ]; then
        print_success "Frontend is accessible"
    else
        print_warning "Frontend check failed (HTTP $response)"
    fi
    
    print_success "Deployment verification completed"
}

# Main deployment process
main() {
    echo "🚀 Payment Gateway Cloud Deployment"
    echo "===================================="
    
    check_prerequisites
    setup_database
    deploy_backend
    deploy_frontend
    deploy_test_merchant
    verify_deployment
    
    echo ""
    print_success "🎉 Deployment completed successfully!"
    echo ""
    print_status "📋 Deployment Summary:"
    echo "   🔗 API Gateway: $API_GATEWAY_URL"
    echo "   🖥️  Frontend: https://$FRONTEND_URL"
    echo "   🛍️  Test Merchant: https://$TEST_MERCHANT_URL"
    echo "   🗄️  Database: Railway PostgreSQL"
    echo ""
    print_status "🔑 Important Information:"
    echo "   JWT Secret: $JWT_SECRET"
    echo "   Database URL: $DATABASE_URL"
    echo ""
    print_warning "⚠️  Please save the JWT secret and database URL securely!"
    echo ""
    print_status "🧪 Test your deployment:"
    echo "   1. Visit the frontend URL to access the merchant dashboard"
    echo "   2. Login with: admin / password (for admin) or testmerchant / password (for merchant)"
    echo "   3. Visit the test merchant URL to see the integration demo"
    echo "   4. Create test payments and verify the flow"
}

# Run main function
main "$@"