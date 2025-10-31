#!/bin/bash

echo "🔍 Verifying Cloud Deployment..."

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

# Check Railway services
check_railway_services() {
    print_status "Checking Railway services..."
    
    services=("auth-service" "payment-service" "merchant-service" "transaction-service" "api-gateway")
    
    for service in "${services[@]}"; do
        print_status "Checking payment-gateway-$service..."
        
        # Get service status
        railway service "payment-gateway-$service" > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            # Get service URL
            SERVICE_URL=$(railway status --json 2>/dev/null | jq -r '.deployments[0].url // empty')
            
            if [ -n "$SERVICE_URL" ]; then
                print_status "Service URL: $SERVICE_URL"
                
                # Check health endpoint
                response=$(curl -s -o /dev/null -w "%{http_code}" "$SERVICE_URL/actuator/health" 2>/dev/null)
                
                if [ "$response" = "200" ]; then
                    print_success "$service is healthy ✅"
                elif [ "$response" = "404" ]; then
                    print_warning "$service is running but health endpoint not found ⚠️"
                else
                    print_error "$service health check failed (HTTP $response) ❌"
                fi
            else
                print_error "$service URL not found ❌"
            fi
        else
            print_error "$service not found ❌"
        fi
        
        echo ""
    done
}

# Check Vercel deployments
check_vercel_deployments() {
    print_status "Checking Vercel deployments..."
    
    # Get Vercel deployments
    deployments=$(vercel ls 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        echo "$deployments" | while read -r line; do
            if [[ $line == *"frontend"* ]] || [[ $line == *"test-merchant"* ]]; then
                app_name=$(echo "$line" | awk '{print $1}')
                app_url=$(echo "$line" | awk '{print $2}')
                
                print_status "Checking $app_name at https://$app_url..."
                
                response=$(curl -s -o /dev/null -w "%{http_code}" "https://$app_url" 2>/dev/null)
                
                if [ "$response" = "200" ]; then
                    print_success "$app_name is accessible ✅"
                else
                    print_error "$app_name check failed (HTTP $response) ❌"
                fi
            fi
        done
    else
        print_error "Failed to get Vercel deployments ❌"
    fi
    
    echo ""
}

# Test API endpoints
test_api_endpoints() {
    print_status "Testing API endpoints..."
    
    # Get API Gateway URL
    railway service "payment-gateway-api-gateway" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        API_GATEWAY_URL=$(railway status --json 2>/dev/null | jq -r '.deployments[0].url // empty')
        
        if [ -n "$API_GATEWAY_URL" ]; then
            print_status "API Gateway URL: $API_GATEWAY_URL"
            
            # Test health endpoint
            print_status "Testing health endpoint..."
            response=$(curl -s "$API_GATEWAY_URL/actuator/health" 2>/dev/null)
            if [[ $response == *"UP"* ]]; then
                print_success "Health endpoint working ✅"
            else
                print_error "Health endpoint failed ❌"
            fi
            
            # Test auth endpoints
            print_status "Testing auth endpoints..."
            response=$(curl -s -o /dev/null -w "%{http_code}" "$API_GATEWAY_URL/api/auth/login" -X POST -H "Content-Type: application/json" -d '{}' 2>/dev/null)
            if [ "$response" = "400" ] || [ "$response" = "401" ]; then
                print_success "Auth endpoint accessible ✅"
            else
                print_warning "Auth endpoint response: HTTP $response ⚠️"
            fi
            
            # Test payment endpoints
            print_status "Testing payment endpoints..."
            response=$(curl -s -o /dev/null -w "%{http_code}" "$API_GATEWAY_URL/api/payments/create" -X POST -H "Content-Type: application/json" 2>/dev/null)
            if [ "$response" = "401" ] || [ "$response" = "403" ]; then
                print_success "Payment endpoint accessible (requires auth) ✅"
            else
                print_warning "Payment endpoint response: HTTP $response ⚠️"
            fi
        else
            print_error "API Gateway URL not found ❌"
        fi
    else
        print_error "API Gateway service not found ❌"
    fi
    
    echo ""
}

# Check database connectivity
check_database() {
    print_status "Checking database connectivity..."
    
    # Try to connect to Railway PostgreSQL
    railway service "payment-gateway-db" > /dev/null 2>&1 || railway service "payment-gateway-auth-service" > /dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        DATABASE_URL=$(railway variables get DATABASE_URL 2>/dev/null)
        
        if [ -n "$DATABASE_URL" ]; then
            print_status "Database URL found"
            
            # Test database connection
            connection_test=$(railway run psql "$DATABASE_URL" -c "SELECT 1;" 2>/dev/null)
            
            if [[ $connection_test == *"1"* ]]; then
                print_success "Database connection working ✅"
                
                # Check if tables exist
                tables=$(railway run psql "$DATABASE_URL" -c "\dt" 2>/dev/null)
                
                if [[ $tables == *"users"* ]] && [[ $tables == *"merchants"* ]] && [[ $tables == *"payments"* ]]; then
                    print_success "Database schema initialized ✅"
                else
                    print_warning "Database schema may not be fully initialized ⚠️"
                fi
            else
                print_error "Database connection failed ❌"
            fi
        else
            print_error "Database URL not found ❌"
        fi
    else
        print_error "Database service not found ❌"
    fi
    
    echo ""
}

# Test complete payment flow
test_payment_flow() {
    print_status "Testing complete payment flow..."
    
    # Get API Gateway URL
    railway service "payment-gateway-api-gateway" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        API_GATEWAY_URL=$(railway status --json 2>/dev/null | jq -r '.deployments[0].url // empty')
        
        if [ -n "$API_GATEWAY_URL" ]; then
            # Test login
            print_status "Testing merchant login..."
            login_response=$(curl -s "$API_GATEWAY_URL/api/auth/login" \
                -X POST \
                -H "Content-Type: application/json" \
                -d '{"username":"testmerchant","password":"password"}' 2>/dev/null)
            
            if [[ $login_response == *"token"* ]]; then
                print_success "Merchant login working ✅"
                
                # Extract token
                token=$(echo "$login_response" | jq -r '.data.token // empty' 2>/dev/null)
                
                if [ -n "$token" ]; then
                    # Test payment creation
                    print_status "Testing payment creation..."
                    payment_response=$(curl -s "$API_GATEWAY_URL/api/payments/create" \
                        -X POST \
                        -H "Content-Type: application/json" \
                        -H "Authorization: Bearer $token" \
                        -d '{"amount":100.00,"paymentMethod":"UPI_QR","description":"Test Payment"}' 2>/dev/null)
                    
                    if [[ $payment_response == *"transactionId"* ]]; then
                        print_success "Payment creation working ✅"
                        
                        # Extract transaction ID
                        transaction_id=$(echo "$payment_response" | jq -r '.data.transactionId // empty' 2>/dev/null)
                        
                        if [ -n "$transaction_id" ]; then
                            # Test payment status
                            print_status "Testing payment status check..."
                            status_response=$(curl -s "$API_GATEWAY_URL/api/payments/status/$transaction_id" \
                                -H "Authorization: Bearer $token" 2>/dev/null)
                            
                            if [[ $status_response == *"PENDING"* ]]; then
                                print_success "Payment status check working ✅"
                            else
                                print_warning "Payment status check response unexpected ⚠️"
                            fi
                        fi
                    else
                        print_error "Payment creation failed ❌"
                        echo "Response: $payment_response"
                    fi
                fi
            else
                print_error "Merchant login failed ❌"
                echo "Response: $login_response"
            fi
        fi
    fi
    
    echo ""
}

# Generate deployment report
generate_report() {
    print_status "Generating deployment report..."
    
    report_file="deployment-report-$(date +%Y%m%d-%H%M%S).txt"
    
    {
        echo "Payment Gateway Cloud Deployment Report"
        echo "======================================="
        echo "Generated: $(date)"
        echo ""
        
        echo "Railway Services:"
        echo "----------------"
        railway service "payment-gateway-auth-service" > /dev/null 2>&1 && echo "✅ Auth Service: $(railway status --json 2>/dev/null | jq -r '.deployments[0].url // "URL not found"')"
        railway service "payment-gateway-payment-service" > /dev/null 2>&1 && echo "✅ Payment Service: $(railway status --json 2>/dev/null | jq -r '.deployments[0].url // "URL not found"')"
        railway service "payment-gateway-merchant-service" > /dev/null 2>&1 && echo "✅ Merchant Service: $(railway status --json 2>/dev/null | jq -r '.deployments[0].url // "URL not found"')"
        railway service "payment-gateway-transaction-service" > /dev/null 2>&1 && echo "✅ Transaction Service: $(railway status --json 2>/dev/null | jq -r '.deployments[0].url // "URL not found"')"
        railway service "payment-gateway-api-gateway" > /dev/null 2>&1 && echo "✅ API Gateway: $(railway status --json 2>/dev/null | jq -r '.deployments[0].url // "URL not found"')"
        echo ""
        
        echo "Vercel Deployments:"
        echo "------------------"
        vercel ls 2>/dev/null | grep -E "(frontend|test-merchant)" | while read -r line; do
            app_name=$(echo "$line" | awk '{print $1}')
            app_url=$(echo "$line" | awk '{print $2}')
            echo "✅ $app_name: https://$app_url"
        done
        echo ""
        
        echo "Database:"
        echo "--------"
        railway service "payment-gateway-auth-service" > /dev/null 2>&1 && echo "✅ PostgreSQL: $(railway variables get DATABASE_URL 2>/dev/null | cut -d'@' -f2 | cut -d'/' -f1)"
        echo ""
        
        echo "Test Credentials:"
        echo "----------------"
        echo "Admin: admin / password"
        echo "Merchant: testmerchant / password"
        echo "API Key: test_api_key_123"
        
    } > "$report_file"
    
    print_success "Deployment report saved to: $report_file"
}

# Main verification function
main() {
    echo "🔍 Cloud Deployment Verification"
    echo "================================"
    
    check_railway_services
    check_vercel_deployments
    test_api_endpoints
    check_database
    test_payment_flow
    generate_report
    
    print_success "🎉 Deployment verification completed!"
    print_status "Check the generated report for detailed information."
}

# Run main function
main "$@"