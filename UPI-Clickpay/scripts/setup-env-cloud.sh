#!/bin/bash

echo "🔧 Setting up Cloud Environment Variables..."

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

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

# Generate secure secrets
generate_secrets() {
    print_status "Generating secure secrets..."
    
    # Generate JWT secret (64 bytes base64 encoded)
    JWT_SECRET=$(openssl rand -base64 64 | tr -d '\n')
    
    # Generate API keys
    ADMIN_API_KEY="admin_$(openssl rand -hex 16)"
    TEST_MERCHANT_API_KEY="test_api_key_123"
    
    print_success "Secrets generated successfully"
}

# Setup Railway environment variables
setup_railway_env() {
    print_status "Setting up Railway environment variables..."
    
    # Get database URL from Railway
    DATABASE_URL=$(railway variables get DATABASE_URL 2>/dev/null)
    
    if [ -z "$DATABASE_URL" ]; then
        print_warning "Database URL not found. Make sure PostgreSQL is added to your Railway project."
        print_status "Adding PostgreSQL to Railway project..."
        railway add postgresql
        sleep 10
        DATABASE_URL=$(railway variables get DATABASE_URL)
    fi
    
    # Services to configure
    services=("auth-service" "payment-service" "merchant-service" "transaction-service" "api-gateway")
    
    for service in "${services[@]}"; do
        print_status "Configuring $service..."
        
        # Switch to service (assuming services are already created)
        railway service "payment-gateway-$service" 2>/dev/null || {
            print_warning "Service payment-gateway-$service not found. Skipping..."
            continue
        }
        
        # Set common variables
        railway variables set SPRING_PROFILES_ACTIVE=railway
        railway variables set JWT_SECRET="$JWT_SECRET"
        railway variables set JWT_EXPIRATION=86400000
        railway variables set DATABASE_URL="$DATABASE_URL"
        
        # Service-specific variables
        case $service in
            "auth-service")
                railway variables set SERVER_PORT=8081
                print_success "Auth service configured"
                ;;
            "payment-service")
                railway variables set SERVER_PORT=8083
                railway variables set UPI_MERCHANT_ID="merchant@upi"
                railway variables set UPI_MERCHANT_NAME="Payment Gateway Pro"
                railway variables set BANK_API_URL="https://api.bank.com"
                railway variables set BANK_API_KEY="demo_bank_api_key"
                print_success "Payment service configured"
                ;;
            "merchant-service")
                railway variables set SERVER_PORT=8082
                print_success "Merchant service configured"
                ;;
            "transaction-service")
                railway variables set SERVER_PORT=8084
                print_success "Transaction service configured"
                ;;
            "api-gateway")
                railway variables set SERVER_PORT=8080
                # Service URLs will be set after deployment
                print_success "API Gateway configured"
                ;;
        esac
    done
}

# Setup Vercel environment variables
setup_vercel_env() {
    print_status "Setting up Vercel environment variables..."
    
    # Get API Gateway URL (you'll need to update this after Railway deployment)
    read -p "Enter your Railway API Gateway URL (e.g., https://your-api-gateway.railway.app): " API_GATEWAY_URL
    
    if [ -z "$API_GATEWAY_URL" ]; then
        print_warning "API Gateway URL not provided. You'll need to set this manually later."
        API_GATEWAY_URL="https://your-api-gateway.railway.app"
    fi
    
    # Setup frontend environment
    print_status "Configuring frontend environment..."
    cd frontend 2>/dev/null || {
        print_error "Frontend directory not found"
        return 1
    }
    
    # Set Vercel environment variables
    vercel env add REACT_APP_API_URL production <<< "$API_GATEWAY_URL"
    vercel env add REACT_APP_ENVIRONMENT production <<< "production"
    
    cd ..
    print_success "Frontend environment configured"
    
    # Setup test merchant app environment
    print_status "Configuring test merchant app environment..."
    cd test-merchant-app 2>/dev/null || {
        print_error "Test merchant app directory not found"
        return 1
    }
    
    # Set Vercel environment variables
    vercel env add REACT_APP_PAYMENT_GATEWAY_URL production <<< "$API_GATEWAY_URL"
    vercel env add REACT_APP_MERCHANT_API_KEY production <<< "$TEST_MERCHANT_API_KEY"
    
    cd ..
    print_success "Test merchant app environment configured"
}

# Create environment files for local development
create_local_env_files() {
    print_status "Creating local environment files..."
    
    # Create .env.local for frontend
    cat > frontend/.env.local << EOF
REACT_APP_API_URL=http://localhost:8080
REACT_APP_ENVIRONMENT=development
EOF
    
    # Create .env.local for test merchant app
    cat > test-merchant-app/.env.local << EOF
REACT_APP_PAYMENT_GATEWAY_URL=http://localhost:8080
REACT_APP_MERCHANT_API_KEY=test_api_key_123
EOF
    
    # Create application-local.yml for backend services
    cat > backend/application-local.yml << EOF
spring:
  profiles:
    active: local
  
  datasource:
    url: jdbc:postgresql://localhost:5432/payment_gateway
    username: admin
    password: password
    driver-class-name: org.postgresql.Driver
  
  jpa:
    hibernate:
      ddl-auto: update
    show-sql: true

jwt:
  secret: $JWT_SECRET
  expiration: 86400000

logging:
  level:
    com.paymentgateway: DEBUG
EOF
    
    print_success "Local environment files created"
}

# Display configuration summary
display_summary() {
    print_success "🎉 Environment setup completed!"
    echo ""
    print_status "📋 Configuration Summary:"
    echo ""
    echo "🔑 Generated Secrets:"
    echo "   JWT Secret: $JWT_SECRET"
    echo "   Admin API Key: $ADMIN_API_KEY"
    echo "   Test Merchant API Key: $TEST_MERCHANT_API_KEY"
    echo ""
    echo "🗄️ Database:"
    echo "   Database URL: $DATABASE_URL"
    echo ""
    echo "🚀 Railway Services:"
    echo "   - payment-gateway-auth-service"
    echo "   - payment-gateway-payment-service"
    echo "   - payment-gateway-merchant-service"
    echo "   - payment-gateway-transaction-service"
    echo "   - payment-gateway-api-gateway"
    echo ""
    echo "☁️ Vercel Apps:"
    echo "   - Frontend (React Dashboard)"
    echo "   - Test Merchant App"
    echo ""
    print_warning "⚠️ IMPORTANT: Save these secrets securely!"
    echo ""
    print_status "📝 Next Steps:"
    echo "   1. Deploy services to Railway: ./scripts/deploy-cloud.sh"
    echo "   2. Update API Gateway URLs after Railway deployment"
    echo "   3. Deploy frontend and test app to Vercel"
    echo "   4. Test the complete flow"
    echo ""
    
    # Save secrets to file
    cat > .env.secrets << EOF
# Generated secrets - DO NOT COMMIT TO GIT
JWT_SECRET=$JWT_SECRET
ADMIN_API_KEY=$ADMIN_API_KEY
TEST_MERCHANT_API_KEY=$TEST_MERCHANT_API_KEY
DATABASE_URL=$DATABASE_URL
EOF
    
    print_status "🔐 Secrets saved to .env.secrets (added to .gitignore)"
}

# Main function
main() {
    echo "🔧 Cloud Environment Setup"
    echo "=========================="
    
    # Check if Railway CLI is available
    if ! command -v railway &> /dev/null; then
        print_error "Railway CLI not found. Please install it first:"
        echo "npm install -g @railway/cli"
        exit 1
    fi
    
    # Check if Vercel CLI is available
    if ! command -v vercel &> /dev/null; then
        print_error "Vercel CLI not found. Please install it first:"
        echo "npm install -g vercel"
        exit 1
    fi
    
    generate_secrets
    setup_railway_env
    setup_vercel_env
    create_local_env_files
    display_summary
}

# Run main function
main "$@"