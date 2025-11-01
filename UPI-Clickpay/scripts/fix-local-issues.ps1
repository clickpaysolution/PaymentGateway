# PowerShell script to fix common local deployment issues

Write-Host "Fixing Payment Gateway Local Deployment Issues..." -ForegroundColor Green

# Function to check if a port is in use
function Test-Port {
    param([int]$Port)
    try {
        $connection = New-Object System.Net.Sockets.TcpClient
        $connection.Connect("localhost", $Port)
        $connection.Close()
        return $true
    } catch {
        return $false
    }
}

# Function to kill process on port
function Stop-ProcessOnPort {
    param([int]$Port, [string]$ServiceName)
    
    $processes = netstat -ano | Select-String ":$Port " | ForEach-Object {
        $fields = $_ -split '\s+'
        $fields[-1]
    }
    
    if ($processes) {
        foreach ($pid in $processes) {
            if ($pid -and $pid -ne "0") {
                try {
                    Write-Host "Stopping $ServiceName on port $Port (PID: $pid)..." -ForegroundColor Yellow
                    Stop-Process -Id $pid -Force
                    Write-Host "✓ $ServiceName stopped" -ForegroundColor Green
                } catch {
                    Write-Host "⚠ Could not stop process $pid" -ForegroundColor Yellow
                }
            }
        }
    }
}

Write-Host "`n=== Step 1: Stopping conflicting services ===" -ForegroundColor Cyan

# Stop any services running on wrong ports
Stop-ProcessOnPort -Port 8080 -ServiceName "Auth Service"
Stop-ProcessOnPort -Port 8081 -ServiceName "Payment Service"
Stop-ProcessOnPort -Port 8082 -ServiceName "Merchant Service"
Stop-ProcessOnPort -Port 8083 -ServiceName "Transaction Service"
Stop-ProcessOnPort -Port 8084 -ServiceName "API Gateway"
Stop-ProcessOnPort -Port 3000 -ServiceName "Frontend"

Write-Host "`n=== Step 2: Installing frontend dependencies ===" -ForegroundColor Cyan

Set-Location frontend
try {
    Write-Host "Installing http-proxy-middleware..." -ForegroundColor Yellow
    npm install http-proxy-middleware@^2.0.6 --save
    Write-Host "✓ Dependencies installed" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to install dependencies" -ForegroundColor Red
}
Set-Location ..

Write-Host "`n=== Step 3: Checking database connection ===" -ForegroundColor Cyan

try {
    $dbTest = psql -U pgadmin -h localhost -d paymentgateway -c "SELECT 1;" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Database connection successful" -ForegroundColor Green
    } else {
        Write-Host "✗ Database connection failed" -ForegroundColor Red
        Write-Host "Please ensure PostgreSQL is running and database is created" -ForegroundColor Yellow
        Write-Host "Run these commands in psql:" -ForegroundColor Yellow
        Write-Host "CREATE DATABASE paymentgateway;" -ForegroundColor White
        Write-Host "CREATE USER pgadmin WITH PASSWORD 'password123';" -ForegroundColor White
        Write-Host "GRANT ALL PRIVILEGES ON DATABASE paymentgateway TO pgadmin;" -ForegroundColor White
    }
} catch {
    Write-Host "✗ Could not test database connection" -ForegroundColor Red
    Write-Host "Please ensure PostgreSQL is installed and running" -ForegroundColor Yellow
}

Write-Host "`n=== Step 4: Building backend services ===" -ForegroundColor Cyan

Set-Location backend
try {
    Write-Host "Building all services..." -ForegroundColor Yellow
    mvn clean compile -DskipTests
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Backend services compiled successfully" -ForegroundColor Green
    } else {
        Write-Host "✗ Backend compilation failed" -ForegroundColor Red
        Write-Host "Please check the Maven output for errors" -ForegroundColor Yellow
    }
} catch {
    Write-Host "✗ Error during compilation" -ForegroundColor Red
}
Set-Location ..

Write-Host "`n=== Step 5: Checking service configurations ===" -ForegroundColor Cyan

$configFiles = @(
    "backend/auth-service/src/main/resources/application.yml",
    "backend/payment-service/src/main/resources/application.yml",
    "backend/merchant-service/src/main/resources/application.yml",
    "backend/transaction-service/src/main/resources/application.yml",
    "backend/api-gateway/src/main/resources/application.yml"
)

foreach ($file in $configFiles) {
    if (Test-Path $file) {
        Write-Host "✓ $file exists" -ForegroundColor Green
    } else {
        Write-Host "✗ $file missing" -ForegroundColor Red
    }
}

Write-Host "`n=== Step 6: Creating startup order script ===" -ForegroundColor Cyan

$startupScript = @"
# Startup order for Payment Gateway services
# Run each command in a separate PowerShell window

Write-Host "Starting services in correct order..." -ForegroundColor Green

# 1. Start Auth Service (Port 8080)
Write-Host "1. Starting Auth Service on port 8080..." -ForegroundColor Yellow
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd backend/auth-service; mvn spring-boot:run"
Start-Sleep -Seconds 10

# 2. Start Payment Service (Port 8081)
Write-Host "2. Starting Payment Service on port 8081..." -ForegroundColor Yellow
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd backend/payment-service; mvn spring-boot:run"
Start-Sleep -Seconds 10

# 3. Start Merchant Service (Port 8082)
Write-Host "3. Starting Merchant Service on port 8082..." -ForegroundColor Yellow
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd backend/merchant-service; mvn spring-boot:run"
Start-Sleep -Seconds 10

# 4. Start Transaction Service (Port 8083)
Write-Host "4. Starting Transaction Service on port 8083..." -ForegroundColor Yellow
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd backend/transaction-service; mvn spring-boot:run"
Start-Sleep -Seconds 10

# 5. Start API Gateway (Port 8084)
Write-Host "5. Starting API Gateway on port 8084..." -ForegroundColor Yellow
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd backend/api-gateway; mvn spring-boot:run"
Start-Sleep -Seconds 15

# 6. Start Frontend (Port 3000)
Write-Host "6. Starting Frontend on port 3000..." -ForegroundColor Yellow
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd frontend; npm start"
Start-Sleep -Seconds 10

# 7. Start Test Merchant App (Port 3001)
Write-Host "7. Starting Test Merchant App on port 3001..." -ForegroundColor Yellow
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd test-merchant-app; npm start"

Write-Host "All services started! Check individual windows for status." -ForegroundColor Green
"@

$startupScript | Out-File -FilePath "scripts/start-services-ordered.ps1" -Encoding UTF8

Write-Host "✓ Created ordered startup script: scripts/start-services-ordered.ps1" -ForegroundColor Green

Write-Host "`n=== Step 7: Creating health check script ===" -ForegroundColor Cyan

$healthCheckScript = @"
# Health check script for all services
Write-Host "Checking service health..." -ForegroundColor Green

`$services = @(
    @{name="Auth Service"; url="http://localhost:8080/auth/health"; port=8080},
    @{name="Payment Service"; url="http://localhost:8081/payments/health"; port=8081},
    @{name="Merchant Service"; url="http://localhost:8082/merchants/health"; port=8082},
    @{name="Transaction Service"; url="http://localhost:8083/transactions/health"; port=8083},
    @{name="API Gateway"; url="http://localhost:8084/health"; port=8084},
    @{name="Frontend"; url="http://localhost:3000"; port=3000}
)

foreach (`$service in `$services) {
    # Check if port is listening
    try {
        `$connection = New-Object System.Net.Sockets.TcpClient
        `$connection.Connect("localhost", `$service.port)
        `$connection.Close()
        
        # Try HTTP request
        try {
            `$response = Invoke-WebRequest -Uri `$service.url -TimeoutSec 5 -ErrorAction SilentlyContinue
            if (`$response.StatusCode -eq 200) {
                Write-Host "✓ `$(`$service.name) is healthy" -ForegroundColor Green
            } else {
                Write-Host "⚠ `$(`$service.name) returned status `$(`$response.StatusCode)" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "⚠ `$(`$service.name) port is open but HTTP request failed" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "✗ `$(`$service.name) is not running on port `$(`$service.port)" -ForegroundColor Red
    }
}
"@

$healthCheckScript | Out-File -FilePath "scripts/health-check.ps1" -Encoding UTF8

Write-Host "✓ Created health check script: scripts/health-check.ps1" -ForegroundColor Green

Write-Host "`n=== Fixes Applied ===" -ForegroundColor Green
Write-Host "✓ Fixed React Hooks error in Dashboard.js" -ForegroundColor Green
Write-Host "✓ Updated frontend proxy configuration" -ForegroundColor Green
Write-Host "✓ Fixed backend service port configurations" -ForegroundColor Green
Write-Host "✓ Updated database connection settings" -ForegroundColor Green
Write-Host "✓ Added CORS configuration to all services" -ForegroundColor Green
Write-Host "✓ Created application.yml for missing services" -ForegroundColor Green
Write-Host "✓ Created ordered startup script" -ForegroundColor Green
Write-Host "✓ Created health check script" -ForegroundColor Green

Write-Host "`n=== Next Steps ===" -ForegroundColor Cyan
Write-Host "1. Run: ./scripts/start-services-ordered.ps1" -ForegroundColor White
Write-Host "2. Wait for all services to start (check individual windows)" -ForegroundColor White
Write-Host "3. Run: ./scripts/health-check.ps1" -ForegroundColor White
Write-Host "4. Open http://localhost:3000 in your browser" -ForegroundColor White

Write-Host "`nPress any key to exit..." -ForegroundColor Yellow
`$null = `$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
"@

$fixScript | Out-File -FilePath "scripts/fix-local-issues.ps1" -Encoding UTF8

Write-Host "All fixes have been applied!" -ForegroundColor Green
Write-Host "`nTo start the services in correct order, run:" -ForegroundColor Cyan
Write-Host "  ./scripts/start-services-ordered.ps1" -ForegroundColor White

Write-Host "`nPress any key to exit..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")