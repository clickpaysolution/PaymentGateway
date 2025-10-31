# Local Windows Deployment Guide

This guide will help you deploy and test the Payment Gateway application on your local Windows machine using localhost.

## Table of Contents
1. [Prerequisites Installation](#prerequisites-installation)
2. [Database Setup](#database-setup)
3. [Backend Services Setup](#backend-services-setup)
4. [Frontend Setup](#frontend-setup)
5. [Testing the Application](#testing-the-application)
6. [Troubleshooting](#troubleshooting)

---

## Prerequisites Installation

### Step 1: Install Java 17
```powershell
# Download and install Java 17 from Oracle or use Chocolatey
choco install openjdk17

# Verify installation
java -version
javac -version
```

### Step 2: Install Maven
```powershell
# Using Chocolatey
choco install maven

# Verify installation
mvn -version
```

### Step 3: Install Node.js and npm
```powershell
# Download from https://nodejs.org/ or use Chocolatey
choco install nodejs

# Verify installation
node --version
npm --version
```

### Step 4: Install PostgreSQL
```powershell
# Download from https://www.postgresql.org/download/windows/ or use Chocolatey
choco install postgresql

# During installation, set password for postgres user (remember this password)
```

### Step 5: Install Git (if not already installed)
```powershell
choco install git
```

### Step 6: Install Docker Desktop (Optional - for containerized deployment)
```powershell
# Download from https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe
# Or use Chocolatey
choco install docker-desktop
```

---

## Database Setup

### Step 1: Start PostgreSQL Service
```powershell
# Start PostgreSQL service
net start postgresql-x64-14

# Or if using different version
Get-Service -Name "*postgres*" | Start-Service
```

### Step 2: Create Database and User
```powershell
# Connect to PostgreSQL as postgres user
psql -U postgres -h localhost

# In PostgreSQL prompt, run these commands:
```

```sql
-- Create database
CREATE DATABASE paymentgateway;

-- Create user
CREATE USER pgadmin WITH PASSWORD 'password123';

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE paymentgateway TO pgadmin;

-- Connect to the database
\c paymentgateway

-- Grant schema privileges
GRANT ALL ON SCHEMA public TO pgadmin;

-- Exit
\q
```

### Step 3: Initialize Database Schema
```powershell
# Run the database initialization script
psql -U pgadmin -h localhost -d paymentgateway -f database/init.sql
```

---

## Backend Services Setup

### Step 1: Build All Backend Services
```powershell
# Navigate to backend directory
cd backend

# Build all services
mvn clean install

# This will build:
# - common module
# - auth-service
# - payment-service
# - merchant-service
# - transaction-service
# - api-gateway
```

### Step 2: Start Services in Order

#### Terminal 1: Start Auth Service
```powershell
cd backend/auth-service
mvn spring-boot:run

# Service will start on http://localhost:8080
# Wait for "Started AuthServiceApplication" message
```

#### Terminal 2: Start Payment Service
```powershell
cd backend/payment-service
mvn spring-boot:run

# Service will start on http://localhost:8081
# Wait for "Started PaymentServiceApplication" message
```

#### Terminal 3: Start Merchant Service
```powershell
cd backend/merchant-service
mvn spring-boot:run

# Service will start on http://localhost:8082
# Wait for "Started MerchantServiceApplication" message
```

#### Terminal 4: Start Transaction Service
```powershell
cd backend/transaction-service
mvn spring-boot:run

# Service will start on http://localhost:8083
# Wait for "Started TransactionServiceApplication" message
```

#### Terminal 5: Start API Gateway
```powershell
cd backend/api-gateway
mvn spring-boot:run

# Service will start on http://localhost:8084
# Wait for "Started ApiGatewayApplication" message
```

---

## Frontend Setup

### Step 1: Install Dependencies
```powershell
# Navigate to frontend directory
cd frontend

# Install npm dependencies
npm install
```

### Step 2: Start Frontend Development Server
```powershell
# Start React development server
npm start

# Frontend will start on http://localhost:3000
# Browser should automatically open
```

---

## Alternative: Docker Compose Deployment

If you prefer to use Docker, you can run everything with Docker Compose:

### Step 1: Start with Docker Compose
```powershell
# Make sure Docker Desktop is running
# From the root directory
docker-compose up --build

# This will start:
# - PostgreSQL database on port 5432
# - All backend services on ports 8080-8084
# - Frontend on port 3000
```

### Step 2: Initialize Database (Docker)
```powershell
# Wait for all services to start, then initialize database
docker-compose exec postgres psql -U pgadmin -d paymentgateway -f /docker-entrypoint-initdb.d/init.sql
```

---

## Testing the Application

### Step 1: Verify All Services Are Running

#### Check Service Health Endpoints
```powershell
# Test each service health endpoint
curl http://localhost:8080/auth/health
curl http://localhost:8081/payments/health
curl http://localhost:8082/merchants/health
curl http://localhost:8083/transactions/health
curl http://localhost:8084/health

# All should return HTTP 200 with health status
```

#### Check Frontend
```powershell
# Open browser and navigate to:
# http://localhost:3000
```

### Step 2: Test User Registration and Login

#### Register a New User
```powershell
# Using PowerShell with Invoke-RestMethod
$body = @{
    email = "test@example.com"
    password = "password123"
    firstName = "Test"
    lastName = "User"
} | ConvertTo-Json

$response = Invoke-RestMethod -Uri "http://localhost:8080/auth/signup" -Method POST -Body $body -ContentType "application/json"
Write-Output $response
```

#### Login User
```powershell
$loginBody = @{
    email = "test@example.com"
    password = "password123"
} | ConvertTo-Json

$loginResponse = Invoke-RestMethod -Uri "http://localhost:8080/auth/login" -Method POST -Body $loginBody -ContentType "application/json"
$token = $loginResponse.token
Write-Output "JWT Token: $token"
```

### Step 3: Test Payment Functionality

#### Create a Payment
```powershell
$headers = @{
    "Authorization" = "Bearer $token"
    "Content-Type" = "application/json"
}

$paymentBody = @{
    amount = 100.00
    currency = "INR"
    merchantId = "test-merchant"
    description = "Test payment"
    paymentMethod = "UPI"
} | ConvertTo-Json

$paymentResponse = Invoke-RestMethod -Uri "http://localhost:8081/payments/create" -Method POST -Body $paymentBody -Headers $headers -ContentType "application/json"
Write-Output $paymentResponse
```

#### Get Payment Status
```powershell
$paymentId = $paymentResponse.paymentId
$statusResponse = Invoke-RestMethod -Uri "http://localhost:8081/payments/$paymentId/status" -Method GET -Headers $headers
Write-Output $statusResponse
```

### Step 4: Test UPI QR Code Generation
```powershell
$qrBody = @{
    amount = 50.00
    merchantId = "test-merchant"
    description = "QR Code payment"
} | ConvertTo-Json

$qrResponse = Invoke-RestMethod -Uri "http://localhost:8081/payments/upi/qr" -Method POST -Body $qrBody -Headers $headers -ContentType "application/json"
Write-Output "QR Code: $($qrResponse.qrCode)"
```

### Step 5: Test Merchant Configuration
```powershell
$merchantBody = @{
    businessName = "Test Business"
    businessType = "ECOMMERCE"
    mode = "GATEWAY_ONLY"
    webhookUrl = "http://localhost:3000/webhook"
} | ConvertTo-Json

$merchantResponse = Invoke-RestMethod -Uri "http://localhost:8082/merchants/configure" -Method POST -Body $merchantBody -Headers $headers -ContentType "application/json"
Write-Output $merchantResponse
```

---

## Test Merchant Application

### Step 1: Start Test Merchant App
```powershell
# Navigate to test merchant app
cd test-merchant-app

# Install dependencies
npm install

# Start the test merchant application
npm start

# Test merchant app will start on http://localhost:3001
```

### Step 2: Test Payment Flow
1. Open http://localhost:3001 in browser
2. Browse products and add to cart
3. Proceed to checkout
4. Select payment method (UPI/Card)
5. Complete payment flow
6. Verify payment success/failure pages

---

## Monitoring and Logs

### View Application Logs
```powershell
# Each service will show logs in their respective terminal windows
# Look for any ERROR or WARN messages

# For Docker Compose deployment:
docker-compose logs -f auth-service
docker-compose logs -f payment-service
docker-compose logs -f merchant-service
docker-compose logs -f transaction-service
```

### Database Monitoring
```powershell
# Connect to database and check tables
psql -U pgadmin -h localhost -d paymentgateway

# Check users table
SELECT * FROM users;

# Check payments table
SELECT * FROM payments;

# Check merchants table
SELECT * FROM merchants;

# Exit
\q
```

---

## Troubleshooting

### Common Issues and Solutions

#### Issue 1: Port Already in Use
```powershell
# Find process using the port
netstat -ano | findstr :8080

# Kill the process (replace PID with actual process ID)
taskkill /PID <PID> /F
```

#### Issue 2: Database Connection Failed
```powershell
# Check if PostgreSQL is running
Get-Service -Name "*postgres*"

# Start PostgreSQL if not running
Start-Service postgresql-x64-14

# Test database connection
psql -U pgadmin -h localhost -d paymentgateway -c "SELECT 1;"
```

#### Issue 3: Maven Build Fails
```powershell
# Clean and rebuild
cd backend
mvn clean install -U

# Skip tests if needed
mvn clean install -DskipTests
```

#### Issue 4: Frontend Won't Start
```powershell
# Clear npm cache
npm cache clean --force

# Delete node_modules and reinstall
Remove-Item -Recurse -Force node_modules
npm install
```

#### Issue 5: Services Can't Connect to Each Other
```powershell
# Check if all services are running on correct ports
netstat -ano | findstr :8080
netstat -ano | findstr :8081
netstat -ano | findstr :8082
netstat -ano | findstr :8083
netstat -ano | findstr :8084

# Check Windows Firewall settings
# Make sure ports 8080-8084 and 3000-3001 are allowed
```

### Health Check Script
```powershell
# Create a health check script
$services = @(
    @{name="Auth Service"; url="http://localhost:8080/auth/health"},
    @{name="Payment Service"; url="http://localhost:8081/payments/health"},
    @{name="Merchant Service"; url="http://localhost:8082/merchants/health"},
    @{name="Transaction Service"; url="http://localhost:8083/transactions/health"},
    @{name="API Gateway"; url="http://localhost:8084/health"},
    @{name="Frontend"; url="http://localhost:3000"}
)

foreach ($service in $services) {
    try {
        $response = Invoke-WebRequest -Uri $service.url -TimeoutSec 5
        if ($response.StatusCode -eq 200) {
            Write-Host "✓ $($service.name) is running" -ForegroundColor Green
        } else {
            Write-Host "✗ $($service.name) returned status $($response.StatusCode)" -ForegroundColor Red
        }
    } catch {
        Write-Host "✗ $($service.name) is not accessible" -ForegroundColor Red
    }
}
```

---

## Performance Testing

### Load Testing with PowerShell
```powershell
# Simple load test function
function Test-PaymentGatewayLoad {
    param(
        [int]$RequestCount = 100,
        [string]$Endpoint = "http://localhost:8080/auth/health"
    )
    
    $successCount = 0
    $failCount = 0
    $totalTime = Measure-Command {
        1..$RequestCount | ForEach-Object -Parallel {
            try {
                $response = Invoke-WebRequest -Uri $using:Endpoint -TimeoutSec 10
                if ($response.StatusCode -eq 200) {
                    $using:successCount++
                } else {
                    $using:failCount++
                }
            } catch {
                $using:failCount++
            }
        } -ThrottleLimit 10
    }
    
    Write-Host "Load Test Results:"
    Write-Host "Total Requests: $RequestCount"
    Write-Host "Successful: $successCount"
    Write-Host "Failed: $failCount"
    Write-Host "Total Time: $($totalTime.TotalSeconds) seconds"
    Write-Host "Requests per second: $($RequestCount / $totalTime.TotalSeconds)"
}

# Run load test
Test-PaymentGatewayLoad -RequestCount 50 -Endpoint "http://localhost:8080/auth/health"
```

---

## Development Workflow

### Making Changes and Testing

1. **Backend Changes**:
   ```powershell
   # Stop the service (Ctrl+C in the terminal)
   # Make your changes
   # Rebuild and restart
   mvn clean compile
   mvn spring-boot:run
   ```

2. **Frontend Changes**:
   ```powershell
   # Changes are automatically reloaded in development mode
   # Just save the file and refresh browser
   ```

3. **Database Changes**:
   ```powershell
   # Update database/init.sql
   # Restart services to apply changes
   # Or run SQL commands directly:
   psql -U pgadmin -h localhost -d paymentgateway -c "YOUR_SQL_COMMAND"
   ```

---

## Summary

Your Payment Gateway application is now running locally on:

- **Frontend**: http://localhost:3000
- **API Gateway**: http://localhost:8084
- **Auth Service**: http://localhost:8080
- **Payment Service**: http://localhost:8081
- **Merchant Service**: http://localhost:8082
- **Transaction Service**: http://localhost:8083
- **Test Merchant App**: http://localhost:3001
- **Database**: localhost:5432

Use the test commands provided to verify all functionality is working correctly. The application supports user registration, login, payment processing, UPI QR codes, and merchant configuration.