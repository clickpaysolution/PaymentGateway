# PowerShell script to start all services locally on Windows

Write-Host "Starting Payment Gateway Services Locally..." -ForegroundColor Green

# Check prerequisites
Write-Host "Checking prerequisites..." -ForegroundColor Yellow

# Check Java
try {
    $javaVersion = java -version 2>&1 | Select-String "version"
    Write-Host "✓ Java found: $javaVersion" -ForegroundColor Green
} catch {
    Write-Host "✗ Java not found. Please install Java 17" -ForegroundColor Red
    exit 1
}

# Check Maven
try {
    $mavenVersion = mvn -version | Select-String "Apache Maven"
    Write-Host "✓ Maven found: $mavenVersion" -ForegroundColor Green
} catch {
    Write-Host "✗ Maven not found. Please install Maven" -ForegroundColor Red
    exit 1
}

# Check Node.js
try {
    $nodeVersion = node --version
    Write-Host "✓ Node.js found: $nodeVersion" -ForegroundColor Green
} catch {
    Write-Host "✗ Node.js not found. Please install Node.js" -ForegroundColor Red
    exit 1
}

# Check PostgreSQL
try {
    $pgService = Get-Service -Name "*postgres*" -ErrorAction SilentlyContinue
    if ($pgService) {
        if ($pgService.Status -eq "Running") {
            Write-Host "✓ PostgreSQL is running" -ForegroundColor Green
        } else {
            Write-Host "Starting PostgreSQL..." -ForegroundColor Yellow
            Start-Service $pgService.Name
            Write-Host "✓ PostgreSQL started" -ForegroundColor Green
        }
    } else {
        Write-Host "✗ PostgreSQL service not found. Please install PostgreSQL" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "✗ Error checking PostgreSQL service" -ForegroundColor Red
    exit 1
}

# Test database connection
Write-Host "Testing database connection..." -ForegroundColor Yellow
try {
    $dbTest = psql -U pgadmin -h localhost -d paymentgateway -c "SELECT 1;" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Database connection successful" -ForegroundColor Green
    } else {
        Write-Host "✗ Database connection failed. Please check database setup" -ForegroundColor Red
        Write-Host "Run: psql -U postgres -h localhost" -ForegroundColor Yellow
        Write-Host "Then create database and user as per LOCAL_WINDOWS_DEPLOYMENT.md" -ForegroundColor Yellow
        exit 1
    }
} catch {
    Write-Host "✗ Database connection test failed" -ForegroundColor Red
    exit 1
}

# Build backend services
Write-Host "Building backend services..." -ForegroundColor Yellow
Set-Location backend
try {
    mvn clean install -DskipTests
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Backend services built successfully" -ForegroundColor Green
    } else {
        Write-Host "✗ Backend build failed" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "✗ Error building backend services" -ForegroundColor Red
    exit 1
}
Set-Location ..

# Install frontend dependencies
Write-Host "Installing frontend dependencies..." -ForegroundColor Yellow
Set-Location frontend
try {
    npm install
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Frontend dependencies installed" -ForegroundColor Green
    } else {
        Write-Host "✗ Frontend dependency installation failed" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "✗ Error installing frontend dependencies" -ForegroundColor Red
    exit 1
}
Set-Location ..

# Install test merchant app dependencies
Write-Host "Installing test merchant app dependencies..." -ForegroundColor Yellow
Set-Location test-merchant-app
try {
    npm install
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Test merchant app dependencies installed" -ForegroundColor Green
    } else {
        Write-Host "✗ Test merchant app dependency installation failed" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "✗ Error installing test merchant app dependencies" -ForegroundColor Red
    exit 1
}
Set-Location ..

Write-Host "`n=== Starting Services ===" -ForegroundColor Cyan

# Function to start service in new window
function Start-ServiceInNewWindow {
    param(
        [string]$ServiceName,
        [string]$Path,
        [string]$Command,
        [int]$Port
    )
    
    Write-Host "Starting $ServiceName on port $Port..." -ForegroundColor Yellow
    
    $scriptBlock = "cd '$Path'; $Command; Read-Host 'Press Enter to close'"
    Start-Process powershell -ArgumentList "-NoExit", "-Command", $scriptBlock
    
    # Wait a bit for service to start
    Start-Sleep -Seconds 3
    
    # Test if service is running
    $maxRetries = 10
    $retries = 0
    do {
        try {
            $response = Invoke-WebRequest -Uri "http://localhost:$Port" -TimeoutSec 2 -ErrorAction SilentlyContinue
            if ($response.StatusCode -eq 200) {
                Write-Host "✓ $ServiceName started successfully" -ForegroundColor Green
                return $true
            }
        } catch {
            # Service might not be ready yet
        }
        Start-Sleep -Seconds 2
        $retries++
    } while ($retries -lt $maxRetries)
    
    Write-Host "⚠ $ServiceName may still be starting..." -ForegroundColor Yellow
    return $false
}

# Start backend services
Start-ServiceInNewWindow "Auth Service" "backend/auth-service" "mvn spring-boot:run" 8080
Start-ServiceInNewWindow "Payment Service" "backend/payment-service" "mvn spring-boot:run" 8081
Start-ServiceInNewWindow "Merchant Service" "backend/merchant-service" "mvn spring-boot:run" 8082
Start-ServiceInNewWindow "Transaction Service" "backend/transaction-service" "mvn spring-boot:run" 8083
Start-ServiceInNewWindow "API Gateway" "backend/api-gateway" "mvn spring-boot:run" 8084

# Start frontend
Write-Host "Starting Frontend..." -ForegroundColor Yellow
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd frontend; npm start; Read-Host 'Press Enter to close'"

# Start test merchant app
Write-Host "Starting Test Merchant App..." -ForegroundColor Yellow
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd test-merchant-app; npm start; Read-Host 'Press Enter to close'"

Write-Host "`n=== Services Started ===" -ForegroundColor Green
Write-Host "Frontend: http://localhost:3000" -ForegroundColor Cyan
Write-Host "API Gateway: http://localhost:8084" -ForegroundColor Cyan
Write-Host "Auth Service: http://localhost:8080" -ForegroundColor Cyan
Write-Host "Payment Service: http://localhost:8081" -ForegroundColor Cyan
Write-Host "Merchant Service: http://localhost:8082" -ForegroundColor Cyan
Write-Host "Transaction Service: http://localhost:8083" -ForegroundColor Cyan
Write-Host "Test Merchant App: http://localhost:3001" -ForegroundColor Cyan

Write-Host "`nWaiting for all services to be ready..." -ForegroundColor Yellow
Start-Sleep -Seconds 30

# Run health checks
Write-Host "`n=== Health Checks ===" -ForegroundColor Cyan
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
        $response = Invoke-WebRequest -Uri $service.url -TimeoutSec 10 -ErrorAction SilentlyContinue
        if ($response.StatusCode -eq 200) {
            Write-Host "✓ $($service.name) is healthy" -ForegroundColor Green
        } else {
            Write-Host "⚠ $($service.name) returned status $($response.StatusCode)" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "✗ $($service.name) is not accessible" -ForegroundColor Red
    }
}

Write-Host "`n=== Setup Complete ===" -ForegroundColor Green
Write-Host "All services have been started in separate windows." -ForegroundColor White
Write-Host "You can now test the application using the endpoints above." -ForegroundColor White
Write-Host "`nTo test the API, you can use the test commands in LOCAL_WINDOWS_DEPLOYMENT.md" -ForegroundColor White
Write-Host "`nPress any key to exit this script (services will continue running)..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")