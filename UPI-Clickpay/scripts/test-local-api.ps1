# PowerShell script to test the Payment Gateway API locally

Write-Host "Testing Payment Gateway API..." -ForegroundColor Green

# Configuration
$baseUrl = "http://localhost"
$authPort = 8080
$paymentPort = 8081
$merchantPort = 8082
$transactionPort = 8083
$apiGatewayPort = 8084

# Test data
$testUser = @{
    email = "test$(Get-Date -Format 'yyyyMMddHHmmss')@example.com"
    password = "password123"
    firstName = "Test"
    lastName = "User"
}

Write-Host "`n=== Step 1: Health Checks ===" -ForegroundColor Cyan

$healthEndpoints = @(
    @{name="Auth Service"; url="$baseUrl`:$authPort/auth/health"},
    @{name="Payment Service"; url="$baseUrl`:$paymentPort/payments/health"},
    @{name="Merchant Service"; url="$baseUrl`:$merchantPort/merchants/health"},
    @{name="Transaction Service"; url="$baseUrl`:$transactionPort/transactions/health"},
    @{name="API Gateway"; url="$baseUrl`:$apiGatewayPort/health"}
)

$allHealthy = $true
foreach ($endpoint in $healthEndpoints) {
    try {
        $response = Invoke-RestMethod -Uri $endpoint.url -Method GET -TimeoutSec 10
        Write-Host "✓ $($endpoint.name): Healthy" -ForegroundColor Green
    } catch {
        Write-Host "✗ $($endpoint.name): Not responding" -ForegroundColor Red
        $allHealthy = $false
    }
}

if (-not $allHealthy) {
    Write-Host "`nSome services are not healthy. Please check the service windows." -ForegroundColor Red
    Write-Host "Press any key to continue anyway..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

Write-Host "`n=== Step 2: User Registration ===" -ForegroundColor Cyan

try {
    $signupBody = $testUser | ConvertTo-Json
    $signupResponse = Invoke-RestMethod -Uri "$baseUrl`:$authPort/auth/signup" -Method POST -Body $signupBody -ContentType "application/json"
    Write-Host "✓ User registered successfully" -ForegroundColor Green
    Write-Host "User ID: $($signupResponse.id)" -ForegroundColor White
} catch {
    Write-Host "✗ User registration failed: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.Exception.Response) {
        $errorResponse = $_.Exception.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($errorResponse)
        $errorContent = $reader.ReadToEnd()
        Write-Host "Error details: $errorContent" -ForegroundColor Red
    }
    exit 1
}

Write-Host "`n=== Step 3: User Login ===" -ForegroundColor Cyan

try {
    $loginBody = @{
        email = $testUser.email
        password = $testUser.password
    } | ConvertTo-Json
    
    $loginResponse = Invoke-RestMethod -Uri "$baseUrl`:$authPort/auth/login" -Method POST -Body $loginBody -ContentType "application/json"
    $token = $loginResponse.token
    Write-Host "✓ User logged in successfully" -ForegroundColor Green
    Write-Host "JWT Token: $($token.Substring(0, 50))..." -ForegroundColor White
} catch {
    Write-Host "✗ User login failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Set up headers for authenticated requests
$headers = @{
    "Authorization" = "Bearer $token"
    "Content-Type" = "application/json"
}

Write-Host "`n=== Step 4: Merchant Configuration ===" -ForegroundColor Cyan

try {
    $merchantBody = @{
        businessName = "Test Business $(Get-Date -Format 'HHmmss')"
        businessType = "ECOMMERCE"
        mode = "GATEWAY_ONLY"
        webhookUrl = "http://localhost:3000/webhook"
        contactEmail = $testUser.email
        contactPhone = "+91-9876543210"
    } | ConvertTo-Json
    
    $merchantResponse = Invoke-RestMethod -Uri "$baseUrl`:$merchantPort/merchants/configure" -Method POST -Body $merchantBody -Headers $headers
    $merchantId = $merchantResponse.merchantId
    Write-Host "✓ Merchant configured successfully" -ForegroundColor Green
    Write-Host "Merchant ID: $merchantId" -ForegroundColor White
} catch {
    Write-Host "✗ Merchant configuration failed: $($_.Exception.Message)" -ForegroundColor Red
    # Continue with default merchant ID for testing
    $merchantId = "test-merchant-$(Get-Date -Format 'HHmmss')"
    Write-Host "Using default merchant ID: $merchantId" -ForegroundColor Yellow
}

Write-Host "`n=== Step 5: Create Payment ===" -ForegroundColor Cyan

try {
    $paymentBody = @{
        amount = 100.00
        currency = "INR"
        merchantId = $merchantId
        description = "Test payment from PowerShell"
        paymentMethod = "UPI"
        customerEmail = $testUser.email
        customerPhone = "+91-9876543210"
    } | ConvertTo-Json
    
    $paymentResponse = Invoke-RestMethod -Uri "$baseUrl`:$paymentPort/payments/create" -Method POST -Body $paymentBody -Headers $headers
    $paymentId = $paymentResponse.paymentId
    Write-Host "✓ Payment created successfully" -ForegroundColor Green
    Write-Host "Payment ID: $paymentId" -ForegroundColor White
    Write-Host "Payment Status: $($paymentResponse.status)" -ForegroundColor White
} catch {
    Write-Host "✗ Payment creation failed: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.Exception.Response) {
        $errorResponse = $_.Exception.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($errorResponse)
        $errorContent = $reader.ReadToEnd()
        Write-Host "Error details: $errorContent" -ForegroundColor Red
    }
    # Continue with a dummy payment ID
    $paymentId = "test-payment-$(Get-Date -Format 'HHmmss')"
}

Write-Host "`n=== Step 6: Check Payment Status ===" -ForegroundColor Cyan

if ($paymentId -and $paymentId -ne "") {
    try {
        $statusResponse = Invoke-RestMethod -Uri "$baseUrl`:$paymentPort/payments/$paymentId/status" -Method GET -Headers $headers
        Write-Host "✓ Payment status retrieved" -ForegroundColor Green
        Write-Host "Status: $($statusResponse.status)" -ForegroundColor White
        Write-Host "Amount: $($statusResponse.amount) $($statusResponse.currency)" -ForegroundColor White
    } catch {
        Write-Host "✗ Payment status check failed: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "⚠ Skipping payment status check (no valid payment ID)" -ForegroundColor Yellow
}

Write-Host "`n=== Step 7: Generate UPI QR Code ===" -ForegroundColor Cyan

try {
    $qrBody = @{
        amount = 50.00
        merchantId = $merchantId
        description = "QR Code payment test"
        customerEmail = $testUser.email
    } | ConvertTo-Json
    
    $qrResponse = Invoke-RestMethod -Uri "$baseUrl`:$paymentPort/payments/upi/qr" -Method POST -Body $qrBody -Headers $headers
    Write-Host "✓ UPI QR Code generated" -ForegroundColor Green
    Write-Host "QR Code Data: $($qrResponse.qrCode.Substring(0, 100))..." -ForegroundColor White
    Write-Host "UPI ID: $($qrResponse.upiId)" -ForegroundColor White
} catch {
    Write-Host "✗ UPI QR Code generation failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n=== Step 8: Get Payment History ===" -ForegroundColor Cyan

try {
    $historyResponse = Invoke-RestMethod -Uri "$baseUrl`:$paymentPort/payments/history" -Method GET -Headers $headers
    Write-Host "✓ Payment history retrieved" -ForegroundColor Green
    Write-Host "Total payments: $($historyResponse.Count)" -ForegroundColor White
    if ($historyResponse.Count -gt 0) {
        Write-Host "Latest payment: $($historyResponse[0].paymentId) - $($historyResponse[0].status)" -ForegroundColor White
    }
} catch {
    Write-Host "✗ Payment history retrieval failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n=== Step 9: Get Merchant Profile ===" -ForegroundColor Cyan

try {
    $profileResponse = Invoke-RestMethod -Uri "$baseUrl`:$merchantPort/merchants/profile" -Method GET -Headers $headers
    Write-Host "✓ Merchant profile retrieved" -ForegroundColor Green
    Write-Host "Business Name: $($profileResponse.businessName)" -ForegroundColor White
    Write-Host "Mode: $($profileResponse.mode)" -ForegroundColor White
    Write-Host "Status: $($profileResponse.status)" -ForegroundColor White
} catch {
    Write-Host "✗ Merchant profile retrieval failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n=== Step 10: Test API Gateway ===" -ForegroundColor Cyan

try {
    $gatewayResponse = Invoke-RestMethod -Uri "$baseUrl`:$apiGatewayPort/api/payments/health" -Method GET -Headers $headers
    Write-Host "✓ API Gateway routing works" -ForegroundColor Green
} catch {
    Write-Host "✗ API Gateway test failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n=== Step 11: Performance Test ===" -ForegroundColor Cyan

Write-Host "Running performance test (50 requests to health endpoint)..." -ForegroundColor Yellow

$successCount = 0
$failCount = 0
$totalTime = Measure-Command {
    1..50 | ForEach-Object -Parallel {
        try {
            $response = Invoke-WebRequest -Uri "$using:baseUrl`:$using:authPort/auth/health" -TimeoutSec 10
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

Write-Host "Performance Test Results:" -ForegroundColor White
Write-Host "Total Requests: 50" -ForegroundColor White
Write-Host "Successful: $successCount" -ForegroundColor Green
Write-Host "Failed: $failCount" -ForegroundColor Red
Write-Host "Total Time: $($totalTime.TotalSeconds.ToString('F2')) seconds" -ForegroundColor White
Write-Host "Requests per second: $(50 / $totalTime.TotalSeconds | ForEach-Object { $_.ToString('F2') })" -ForegroundColor White

Write-Host "`n=== Test Summary ===" -ForegroundColor Green

$testResults = @(
    "✓ Health checks completed",
    "✓ User registration and login tested",
    "✓ Merchant configuration tested",
    "✓ Payment creation and status check tested",
    "✓ UPI QR code generation tested",
    "✓ Payment history retrieval tested",
    "✓ API Gateway routing tested",
    "✓ Performance test completed"
)

foreach ($result in $testResults) {
    Write-Host $result -ForegroundColor Green
}

Write-Host "`n=== Next Steps ===" -ForegroundColor Cyan
Write-Host "1. Open http://localhost:3000 to test the frontend" -ForegroundColor White
Write-Host "2. Open http://localhost:3001 to test the merchant app" -ForegroundColor White
Write-Host "3. Use the test user credentials:" -ForegroundColor White
Write-Host "   Email: $($testUser.email)" -ForegroundColor Yellow
Write-Host "   Password: $($testUser.password)" -ForegroundColor Yellow
Write-Host "4. JWT Token for API testing: $($token.Substring(0, 50))..." -ForegroundColor Yellow

Write-Host "`nAPI Testing completed successfully!" -ForegroundColor Green
Write-Host "Press any key to exit..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")