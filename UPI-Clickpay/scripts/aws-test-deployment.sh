#!/bin/bash

set -e

# Configuration
ENVIRONMENT=${1:-dev}
ALB_DNS=$2

if [ -z "$ALB_DNS" ]; then
    echo "Usage: $0 <environment> <ALB_DNS_NAME>"
    echo "Example: $0 dev payment-gateway-dev-alb-123456789.us-east-1.elb.amazonaws.com"
    exit 1
fi

echo "Testing Payment Gateway deployment for $ENVIRONMENT environment..."
echo "ALB DNS: $ALB_DNS"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to test endpoint
test_endpoint() {
    local endpoint=$1
    local expected_status=${2:-200}
    local description=$3
    
    echo -n "Testing $description... "
    
    response=$(curl -s -o /dev/null -w "%{http_code}" "http://$ALB_DNS$endpoint" || echo "000")
    
    if [ "$response" = "$expected_status" ]; then
        echo -e "${GREEN}✓ PASS${NC} (HTTP $response)"
        return 0
    else
        echo -e "${RED}✗ FAIL${NC} (HTTP $response, expected $expected_status)"
        return 1
    fi
}

# Function to test API endpoint with JSON
test_api_endpoint() {
    local method=$1
    local endpoint=$2
    local data=$3
    local description=$4
    local auth_header=$5
    
    echo -n "Testing $description... "
    
    if [ -n "$auth_header" ]; then
        response=$(curl -s -X $method "http://$ALB_DNS$endpoint" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer $auth_header" \
            -d "$data" \
            -w "%{http_code}" -o /tmp/response.json || echo "000")
    else
        response=$(curl -s -X $method "http://$ALB_DNS$endpoint" \
            -H "Content-Type: application/json" \
            -d "$data" \
            -w "%{http_code}" -o /tmp/response.json || echo "000")
    fi
    
    if [ "$response" -ge 200 ] && [ "$response" -lt 300 ]; then
        echo -e "${GREEN}✓ PASS${NC} (HTTP $response)"
        return 0
    else
        echo -e "${RED}✗ FAIL${NC} (HTTP $response)"
        echo "Response: $(cat /tmp/response.json)"
        return 1
    fi
}

echo "=== Health Check Tests ==="

# Test health endpoints
test_endpoint "/auth/health" 200 "Auth Service Health"
test_endpoint "/payments/health" 200 "Payment Service Health"
test_endpoint "/merchants/health" 200 "Merchant Service Health"
test_endpoint "/transactions/health" 200 "Transaction Service Health"
test_endpoint "/api/health" 200 "API Gateway Health"
test_endpoint "/" 200 "Frontend"

echo ""
echo "=== API Functionality Tests ==="

# Test user registration
echo "Testing user registration..."
RANDOM_EMAIL="test$(date +%s)@example.com"
test_api_endpoint "POST" "/auth/signup" '{
    "email": "'$RANDOM_EMAIL'",
    "password": "password123",
    "firstName": "Test",
    "lastName": "User"
}' "User Registration"

# Test user login
echo "Testing user login..."
test_api_endpoint "POST" "/auth/login" '{
    "email": "'$RANDOM_EMAIL'",
    "password": "password123"
}' "User Login"

# Extract JWT token from login response
if [ -f /tmp/response.json ]; then
    JWT_TOKEN=$(cat /tmp/response.json | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
    if [ -n "$JWT_TOKEN" ]; then
        echo -e "${GREEN}JWT Token extracted successfully${NC}"
        
        # Test authenticated endpoints
        echo "Testing authenticated endpoints..."
        test_api_endpoint "GET" "/merchants/profile" "" "Get Merchant Profile" "$JWT_TOKEN"
        test_api_endpoint "GET" "/payments/history" "" "Get Payment History" "$JWT_TOKEN"
        test_api_endpoint "GET" "/transactions/list" "" "Get Transaction List" "$JWT_TOKEN"
    else
        echo -e "${YELLOW}Warning: Could not extract JWT token${NC}"
    fi
fi

echo ""
echo "=== Load Balancer Tests ==="

# Test load balancer distribution
echo "Testing load balancer distribution..."
for i in {1..5}; do
    response=$(curl -s "http://$ALB_DNS/auth/health" | grep -o '"instance":"[^"]*"' | cut -d'"' -f4 || echo "unknown")
    echo "Request $i: Instance $response"
done

echo ""
echo "=== Performance Tests ==="

# Simple performance test
echo "Running basic performance test..."
echo "Testing 100 requests with 10 concurrent connections..."

# Check if Apache Bench is available
if command -v ab &> /dev/null; then
    ab -n 100 -c 10 -q "http://$ALB_DNS/auth/health" | grep -E "(Requests per second|Time per request|Transfer rate)"
else
    echo -e "${YELLOW}Apache Bench (ab) not found. Skipping performance test.${NC}"
    echo "To install: sudo apt-get install apache2-utils (Ubuntu/Debian) or brew install httpie (macOS)"
fi

echo ""
echo "=== Database Connectivity Test ==="

# Test database connectivity through API
echo "Testing database connectivity..."
test_api_endpoint "GET" "/auth/users/count" "" "Database Connection Test" "$JWT_TOKEN"

echo ""
echo "=== Security Tests ==="

# Test CORS headers
echo "Testing CORS headers..."
cors_response=$(curl -s -H "Origin: http://localhost:3000" -H "Access-Control-Request-Method: POST" -H "Access-Control-Request-Headers: X-Requested-With" -X OPTIONS "http://$ALB_DNS/auth/login" -I)
if echo "$cors_response" | grep -q "Access-Control-Allow-Origin"; then
    echo -e "${GREEN}✓ CORS headers present${NC}"
else
    echo -e "${YELLOW}⚠ CORS headers not found${NC}"
fi

# Test rate limiting (if implemented)
echo "Testing rate limiting..."
for i in {1..20}; do
    response=$(curl -s -o /dev/null -w "%{http_code}" "http://$ALB_DNS/auth/health")
    if [ "$response" = "429" ]; then
        echo -e "${GREEN}✓ Rate limiting working (HTTP 429 after $i requests)${NC}"
        break
    fi
done

echo ""
echo "=== Infrastructure Tests ==="

# Check ECS service status
echo "Checking ECS service status..."
aws ecs describe-services \
    --cluster payment-gateway-$ENVIRONMENT \
    --services auth-service payment-service merchant-service transaction-service \
    --query 'services[*].[serviceName,status,runningCount,desiredCount]' \
    --output table

# Check target group health
echo "Checking target group health..."
for tg_name in auth payment merchant transaction; do
    tg_arn=$(aws elbv2 describe-target-groups --names payment-gateway-$ENVIRONMENT-$tg_name-tg --query 'TargetGroups[0].TargetGroupArn' --output text 2>/dev/null || echo "")
    if [ -n "$tg_arn" ] && [ "$tg_arn" != "None" ]; then
        healthy_count=$(aws elbv2 describe-target-health --target-group-arn $tg_arn --query 'TargetHealthDescriptions[?TargetHealth.State==`healthy`] | length(@)' --output text)
        total_count=$(aws elbv2 describe-target-health --target-group-arn $tg_arn --query 'length(TargetHealthDescriptions)' --output text)
        echo "$tg_name service: $healthy_count/$total_count targets healthy"
    fi
done

echo ""
echo "=== Log Analysis ==="

# Check for recent errors in logs
echo "Checking for recent errors in logs..."
for service in auth-service payment-service merchant-service transaction-service; do
    error_count=$(aws logs filter-log-events \
        --log-group-name /ecs/payment-gateway-$service-$ENVIRONMENT \
        --start-time $(date -d '10 minutes ago' +%s)000 \
        --filter-pattern "ERROR" \
        --query 'length(events)' --output text 2>/dev/null || echo "0")
    
    if [ "$error_count" -gt 0 ]; then
        echo -e "${RED}⚠ $service: $error_count errors in last 10 minutes${NC}"
    else
        echo -e "${GREEN}✓ $service: No errors in last 10 minutes${NC}"
    fi
done

echo ""
echo "=== Test Summary ==="
echo "Deployment testing completed for $ENVIRONMENT environment"
echo "ALB DNS: $ALB_DNS"
echo "Check the output above for any failed tests"

# Cleanup
rm -f /tmp/response.json

echo ""
echo "=== Next Steps ==="
echo "1. Monitor CloudWatch logs for any issues"
echo "2. Set up CloudWatch alarms for critical metrics"
echo "3. Configure auto-scaling policies"
echo "4. Set up backup schedules"
echo "5. Configure SSL certificate for production"