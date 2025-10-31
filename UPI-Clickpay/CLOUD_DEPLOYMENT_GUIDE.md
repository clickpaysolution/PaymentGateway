# Cloud Deployment Guide - Railway & Vercel

## Overview

This guide covers deploying our Payment Gateway application to cloud platforms for testing and demonstration purposes. We'll use:

- **Railway** - For backend microservices and database
- **Vercel** - For frontend React applications
- **Railway PostgreSQL** - For database hosting

## Architecture Overview

```
Frontend (Vercel) → API Gateway (Railway) → Microservices (Railway) → PostgreSQL (Railway)
```

## Part 1: Railway Deployment (Backend + Database)

### Step 1: Railway Setup

#### 1.1 Create Railway Account
1. Visit [railway.app](https://railway.app)
2. Sign up with GitHub account
3. Verify email and complete profile

#### 1.2 Install Railway CLI
```bash
# Install Railway CLI
npm install -g @railway/cli

# Login to Railway
railway login
```

### Step 2: Database Setup on Railway

#### 2.1 Create PostgreSQL Database
```bash
# Create new Railway project
railway new

# Add PostgreSQL service
railway add postgresql

# Get database connection details
railway variables
```

#### 2.2 Database Configuration
Railway will provide these environment variables:
```bash
DATABASE_URL=postgresql://username:password@host:port/database
PGHOST=host
PGPORT=port
PGUSER=username
PGPASSWORD=password
PGDATABASE=database
```

#### 2.3 Initialize Database Schema
Create initialization script:

```bash
# Connect to Railway PostgreSQL
railway connect postgresql

# Or use the connection string
psql $DATABASE_URL
```

### Step 3: Backend Services Deployment

#### 3.1 Prepare Application Properties
Create `application-railway.yml` for each service:

```yaml
# backend/auth-service/src/main/resources/application-railway.yml
server:
  port: ${PORT:8081}

spring:
  profiles:
    active: railway
  
  datasource:
    url: ${DATABASE_URL}
    driver-class-name: org.postgresql.Driver
  
  jpa:
    hibernate:
      ddl-auto: update
    show-sql: false
    properties:
      hibernate:
        dialect: org.hibernate.dialect.PostgreSQLDialect

jwt:
  secret: ${JWT_SECRET}
  expiration: ${JWT_EXPIRATION:86400000}

logging:
  level:
    com.paymentgateway: INFO
    org.springframework.web: INFO
```

#### 3.2 Create Railway Configuration Files

**railway.json** (for each service):
```json
{
  "$schema": "https://railway.app/railway.schema.json",
  "build": {
    "builder": "NIXPACKS"
  },
  "deploy": {
    "startCommand": "java -Dspring.profiles.active=railway -jar target/auth-service-1.0.0.jar",
    "healthcheckPath": "/actuator/health",
    "healthcheckTimeout": 100,
    "restartPolicyType": "ON_FAILURE",
    "restartPolicyMaxRetries": 10
  }
}
```

**nixpacks.toml** (for Java services):
```toml
[phases.build]
cmds = ["mvn clean package -DskipTests"]

[phases.start]
cmd = "java -Dspring.profiles.active=railway -jar target/*.jar"

[variables]
MAVEN_OPTS = "-Xmx1024m"
```

#### 3.3 Deploy Each Service

**Deploy Auth Service:**
```bash
# Navigate to auth service
cd backend/auth-service

# Initialize Railway project
railway init

# Set environment variables
railway variables set SPRING_PROFILES_ACTIVE=railway
railway variables set JWT_SECRET=your_jwt_secret_here
railway variables set DATABASE_URL=$DATABASE_URL

# Deploy
railway up
```

**Deploy Payment Service:**
```bash
cd backend/payment-service

railway init
railway variables set SPRING_PROFILES_ACTIVE=railway
railway variables set JWT_SECRET=your_jwt_secret_here
railway variables set DATABASE_URL=$DATABASE_URL
railway variables set UPI_MERCHANT_ID=your_upi_merchant_id

railway up
```

**Deploy Merchant Service:**
```bash
cd backend/merchant-service

railway init
railway variables set SPRING_PROFILES_ACTIVE=railway
railway variables set JWT_SECRET=your_jwt_secret_here
railway variables set DATABASE_URL=$DATABASE_URL

railway up
```

**Deploy Transaction Service:**
```bash
cd backend/transaction-service

railway init
railway variables set SPRING_PROFILES_ACTIVE=railway
railway variables set JWT_SECRET=your_jwt_secret_here
railway variables set DATABASE_URL=$DATABASE_URL

railway up
```

**Deploy API Gateway:**
```bash
cd backend/api-gateway

railway init
railway variables set SPRING_PROFILES_ACTIVE=railway
railway variables set AUTH_SERVICE_URL=https://your-auth-service.railway.app
railway variables set PAYMENT_SERVICE_URL=https://your-payment-service.railway.app
railway variables set MERCHANT_SERVICE_URL=https://your-merchant-service.railway.app
railway variables set TRANSACTION_SERVICE_URL=https://your-transaction-service.railway.app

railway up
```

### Step 4: Configure API Gateway Routing

Update `application-railway.yml` for API Gateway:

```yaml
server:
  port: ${PORT:8080}

spring:
  profiles:
    active: railway
  
  cloud:
    gateway:
      routes:
        - id: auth-service
          uri: ${AUTH_SERVICE_URL:http://localhost:8081}
          predicates:
            - Path=/api/auth/**
        
        - id: payment-service
          uri: ${PAYMENT_SERVICE_URL:http://localhost:8083}
          predicates:
            - Path=/api/payments/**
        
        - id: merchant-service
          uri: ${MERCHANT_SERVICE_URL:http://localhost:8082}
          predicates:
            - Path=/api/merchants/**,/api/merchant/**
        
        - id: transaction-service
          uri: ${TRANSACTION_SERVICE_URL:http://localhost:8084}
          predicates:
            - Path=/api/transactions/**

      globalcors:
        cors-configurations:
          '[/**]':
            allowedOrigins: 
              - "https://*.vercel.app"
              - "http://localhost:3000"
              - "http://localhost:3001"
            allowedMethods: "*"
            allowedHeaders: "*"
            allowCredentials: true

logging:
  level:
    org.springframework.cloud.gateway: INFO
```

## Part 2: Vercel Deployment (Frontend)

### Step 1: Prepare Frontend for Deployment

#### 1.1 Update Environment Configuration
Create `.env.production` in frontend directory:

```bash
REACT_APP_API_URL=https://your-api-gateway.railway.app
REACT_APP_ENVIRONMENT=production
```

#### 1.2 Create Vercel Configuration
Create `vercel.json` in frontend directory:

```json
{
  "version": 2,
  "builds": [
    {
      "src": "package.json",
      "use": "@vercel/static-build",
      "config": {
        "distDir": "build"
      }
    }
  ],
  "routes": [
    {
      "src": "/static/(.*)",
      "headers": {
        "cache-control": "s-maxage=31536000,immutable"
      }
    },
    {
      "src": "/(.*)",
      "dest": "/index.html"
    }
  ],
  "env": {
    "REACT_APP_API_URL": "@react_app_api_url"
  }
}
```

#### 1.3 Update Package.json
Add build script optimization:

```json
{
  "scripts": {
    "build": "react-scripts build",
    "build:vercel": "CI=false npm run build"
  }
}
```

### Step 2: Deploy to Vercel

#### 2.1 Install Vercel CLI
```bash
npm install -g vercel
```

#### 2.2 Deploy Frontend
```bash
# Navigate to frontend directory
cd frontend

# Login to Vercel
vercel login

# Deploy
vercel

# Set environment variables
vercel env add REACT_APP_API_URL production
# Enter your Railway API Gateway URL

# Redeploy with environment variables
vercel --prod
```

#### 2.3 Deploy Test Merchant App
```bash
# Navigate to test merchant app
cd test-merchant-app

# Deploy to Vercel
vercel

# Set environment variables
vercel env add REACT_APP_PAYMENT_GATEWAY_URL production
vercel env add REACT_APP_MERCHANT_API_KEY production

# Redeploy
vercel --prod
```

## Part 3: Database Connection & Configuration

### Step 1: Database Schema Setup

#### 1.1 Create Database Initialization Script
Create `railway-init.sql`:

```sql
-- Create database schema for Railway deployment
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Users table
CREATE TABLE IF NOT EXISTS users (
    id BIGSERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    role VARCHAR(20) NOT NULL DEFAULT 'MERCHANT',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Merchants table
CREATE TABLE IF NOT EXISTS merchants (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT UNIQUE NOT NULL REFERENCES users(id),
    business_name VARCHAR(255),
    api_key VARCHAR(255) UNIQUE NOT NULL,
    webhook_url VARCHAR(500),
    upi_id VARCHAR(100),
    is_active BOOLEAN DEFAULT TRUE,
    operation_mode VARCHAR(20) DEFAULT 'FULL_PROCESSOR',
    fee_structure TEXT,
    bank_config TEXT,
    settlement_config TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Payments table
CREATE TABLE IF NOT EXISTS payments (
    id BIGSERIAL PRIMARY KEY,
    merchant_id BIGINT NOT NULL,
    transaction_id VARCHAR(100) UNIQUE NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'INR',
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    payment_method VARCHAR(20),
    upi_id VARCHAR(100),
    upi_provider VARCHAR(50),
    bank_reference VARCHAR(100),
    qr_code_data TEXT,
    callback_url VARCHAR(500),
    description TEXT,
    cancellation_reason TEXT,
    failure_reason TEXT,
    cancelled_by VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP
);

-- Transactions table
CREATE TABLE IF NOT EXISTS transactions (
    id BIGSERIAL PRIMARY KEY,
    payment_id BIGINT REFERENCES payments(id),
    merchant_id BIGINT NOT NULL,
    transaction_id VARCHAR(100) NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    status VARCHAR(20) NOT NULL,
    payment_method VARCHAR(20),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_payments_merchant_id ON payments(merchant_id);
CREATE INDEX IF NOT EXISTS idx_payments_transaction_id ON payments(transaction_id);
CREATE INDEX IF NOT EXISTS idx_payments_status ON payments(status);
CREATE INDEX IF NOT EXISTS idx_payments_created_at ON payments(created_at);
CREATE INDEX IF NOT EXISTS idx_transactions_merchant_id ON transactions(merchant_id);
CREATE INDEX IF NOT EXISTS idx_transactions_created_at ON transactions(created_at);

-- Insert default admin user
INSERT INTO users (username, email, password, role) 
VALUES ('admin', 'admin@paymentgateway.com', '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'ADMIN')
ON CONFLICT (username) DO NOTHING;

-- Insert test merchant
INSERT INTO users (username, email, password, role) 
VALUES ('testmerchant', 'merchant@test.com', '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'MERCHANT')
ON CONFLICT (username) DO NOTHING;

-- Insert merchant record
INSERT INTO merchants (user_id, business_name, api_key, upi_id, operation_mode)
SELECT u.id, 'Test Business', 'test_api_key_123', 'testmerchant@upi', 'FULL_PROCESSOR'
FROM users u 
WHERE u.username = 'testmerchant'
ON CONFLICT (user_id) DO NOTHING;
```

#### 1.2 Execute Database Setup
```bash
# Connect to Railway PostgreSQL
railway connect postgresql

# Execute the initialization script
\i railway-init.sql

# Or using psql with connection string
psql $DATABASE_URL -f railway-init.sql
```

### Step 2: Connection Pool Configuration

#### 2.1 Update Application Properties
Add connection pool settings:

```yaml
spring:
  datasource:
    url: ${DATABASE_URL}
    driver-class-name: org.postgresql.Driver
    hikari:
      maximum-pool-size: 10
      minimum-idle: 2
      idle-timeout: 300000
      max-lifetime: 600000
      connection-timeout: 20000
      validation-timeout: 5000
      leak-detection-threshold: 60000
```

## Part 4: Environment Variables Configuration

### Step 1: Railway Environment Variables

Set these variables for each service on Railway:

#### Common Variables (All Services)
```bash
SPRING_PROFILES_ACTIVE=railway
DATABASE_URL=postgresql://username:password@host:port/database
JWT_SECRET=your_very_long_and_secure_jwt_secret_key_here
JWT_EXPIRATION=86400000
```

#### Service-Specific Variables

**Auth Service:**
```bash
SERVER_PORT=8081
```

**Payment Service:**
```bash
SERVER_PORT=8083
UPI_MERCHANT_ID=your_upi_merchant_id
UPI_MERCHANT_NAME=Your Company Name
BANK_API_URL=https://api.bank.com
BANK_API_KEY=your_bank_api_key
```

**Merchant Service:**
```bash
SERVER_PORT=8082
```

**Transaction Service:**
```bash
SERVER_PORT=8084
```

**API Gateway:**
```bash
SERVER_PORT=8080
AUTH_SERVICE_URL=https://your-auth-service.railway.app
PAYMENT_SERVICE_URL=https://your-payment-service.railway.app
MERCHANT_SERVICE_URL=https://your-merchant-service.railway.app
TRANSACTION_SERVICE_URL=https://your-transaction-service.railway.app
```

### Step 2: Vercel Environment Variables

Set these in Vercel dashboard or CLI:

#### Frontend
```bash
REACT_APP_API_URL=https://your-api-gateway.railway.app
REACT_APP_ENVIRONMENT=production
```

#### Test Merchant App
```bash
REACT_APP_PAYMENT_GATEWAY_URL=https://your-api-gateway.railway.app
REACT_APP_MERCHANT_API_KEY=test_api_key_123
```

## Part 5: Deployment Scripts

### Step 1: Automated Deployment Script

Create `deploy-cloud.sh`:

```bash
#!/bin/bash

echo "🚀 Deploying Payment Gateway to Cloud..."

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
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

# Check if Railway CLI is installed
if ! command -v railway &> /dev/null; then
    print_error "Railway CLI not found. Please install it first:"
    echo "npm install -g @railway/cli"
    exit 1
fi

# Check if Vercel CLI is installed
if ! command -v vercel &> /dev/null; then
    print_error "Vercel CLI not found. Please install it first:"
    echo "npm install -g vercel"
    exit 1
fi

# Build backend services
print_status "Building backend services..."
cd backend
mvn clean package -DskipTests
if [ $? -ne 0 ]; then
    print_error "Backend build failed"
    exit 1
fi
cd ..

# Deploy to Railway
print_status "Deploying backend services to Railway..."

services=("auth-service" "payment-service" "merchant-service" "transaction-service" "api-gateway")

for service in "${services[@]}"; do
    print_status "Deploying $service..."
    cd "backend/$service"
    
    # Deploy to Railway
    railway up --detach
    
    if [ $? -eq 0 ]; then
        print_success "$service deployed successfully"
    else
        print_error "Failed to deploy $service"
    fi
    
    cd ../..
done

# Deploy frontend to Vercel
print_status "Deploying frontend to Vercel..."
cd frontend
vercel --prod --yes
if [ $? -eq 0 ]; then
    print_success "Frontend deployed successfully"
else
    print_error "Failed to deploy frontend"
fi
cd ..

# Deploy test merchant app to Vercel
print_status "Deploying test merchant app to Vercel..."
cd test-merchant-app
vercel --prod --yes
if [ $? -eq 0 ]; then
    print_success "Test merchant app deployed successfully"
else
    print_error "Failed to deploy test merchant app"
fi
cd ..

print_success "🎉 Deployment completed!"
print_status "Check your Railway and Vercel dashboards for deployment status."
```

### Step 2: Environment Setup Script

Create `setup-env.sh`:

```bash
#!/bin/bash

echo "🔧 Setting up environment variables..."

# Railway environment variables
echo "Setting up Railway environment variables..."

# Generate JWT secret
JWT_SECRET=$(openssl rand -base64 64 | tr -d '\n')

# Set common variables for all services
railway_services=("auth-service" "payment-service" "merchant-service" "transaction-service" "api-gateway")

for service in "${railway_services[@]}"; do
    echo "Setting variables for $service..."
    
    # Switch to service context
    railway service $service
    
    # Set common variables
    railway variables set SPRING_PROFILES_ACTIVE=railway
    railway variables set JWT_SECRET="$JWT_SECRET"
    railway variables set JWT_EXPIRATION=86400000
done

echo "✅ Environment variables setup completed!"
echo "🔑 Generated JWT Secret: $JWT_SECRET"
echo "📝 Please save this JWT secret securely!"
```

## Part 6: Testing & Verification

### Step 1: Health Checks

Create health check endpoints for each service:

```java
@RestController
@RequestMapping("/actuator")
public class HealthController {
    
    @GetMapping("/health")
    public ResponseEntity<Map<String, String>> health() {
        Map<String, String> status = new HashMap<>();
        status.put("status", "UP");
        status.put("service", "auth-service");
        status.put("timestamp", LocalDateTime.now().toString());
        return ResponseEntity.ok(status);
    }
}
```

### Step 2: Deployment Verification

Create `verify-deployment.sh`:

```bash
#!/bin/bash

echo "🔍 Verifying deployment..."

# Check Railway services
echo "Checking Railway services..."

services=(
    "https://your-auth-service.railway.app/actuator/health"
    "https://your-payment-service.railway.app/actuator/health"
    "https://your-merchant-service.railway.app/actuator/health"
    "https://your-transaction-service.railway.app/actuator/health"
    "https://your-api-gateway.railway.app/actuator/health"
)

for service in "${services[@]}"; do
    echo "Checking $service..."
    response=$(curl -s -o /dev/null -w "%{http_code}" "$service")
    
    if [ "$response" = "200" ]; then
        echo "✅ Service is healthy"
    else
        echo "❌ Service is not responding (HTTP $response)"
    fi
done

# Check Vercel deployments
echo "Checking Vercel deployments..."

vercel_apps=(
    "https://your-frontend.vercel.app"
    "https://your-test-merchant.vercel.app"
)

for app in "${vercel_apps[@]}"; do
    echo "Checking $app..."
    response=$(curl -s -o /dev/null -w "%{http_code}" "$app")
    
    if [ "$response" = "200" ]; then
        echo "✅ App is accessible"
    else
        echo "❌ App is not responding (HTTP $response)"
    fi
done

echo "🎉 Deployment verification completed!"
```

## Part 7: Monitoring & Logs

### Step 1: Railway Monitoring

```bash
# View logs for a service
railway logs

# Follow logs in real-time
railway logs --follow

# View specific service logs
railway service auth-service
railway logs --follow
```

### Step 2: Vercel Monitoring

```bash
# View deployment logs
vercel logs

# View function logs
vercel logs --follow
```

## Part 8: Troubleshooting

### Common Issues & Solutions

#### 1. Database Connection Issues
```bash
# Check database connectivity
railway connect postgresql

# Verify connection string
railway variables | grep DATABASE_URL
```

#### 2. Service Communication Issues
```bash
# Check service URLs
railway status

# Verify environment variables
railway variables
```

#### 3. CORS Issues
Update API Gateway CORS configuration:
```yaml
allowedOrigins: 
  - "https://*.vercel.app"
  - "https://your-frontend-domain.vercel.app"
```

#### 4. Build Failures
```bash
# Check build logs
railway logs --build

# Verify Java version and dependencies
railway exec java -version
```

## Part 9: Cost Optimization

### Railway Optimization
- Use Railway's free tier for testing
- Monitor resource usage
- Scale down unused services

### Vercel Optimization
- Use Vercel's free tier for frontend
- Optimize build times
- Enable caching for static assets

## Deployment URLs

After successful deployment, you'll have:

- **API Gateway:** `https://your-api-gateway.railway.app`
- **Frontend Dashboard:** `https://your-frontend.vercel.app`
- **Test Merchant App:** `https://your-test-merchant.vercel.app`
- **Database:** Railway PostgreSQL instance

## Security Considerations

1. **Environment Variables:** Never commit secrets to git
2. **CORS Configuration:** Restrict to specific domains
3. **Database Access:** Use connection pooling and SSL
4. **API Keys:** Rotate regularly and use strong secrets
5. **HTTPS:** Ensure all communications are encrypted

This deployment setup provides a production-ready environment for testing and demonstrating your payment gateway to potential partners and customers.