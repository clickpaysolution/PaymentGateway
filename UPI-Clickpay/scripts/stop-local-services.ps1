# PowerShell script to stop all local Payment Gateway services

Write-Host "Stopping Payment Gateway Services..." -ForegroundColor Yellow

# Function to kill processes by port
function Stop-ProcessByPort {
    param(
        [int]$Port,
        [string]$ServiceName
    )
    
    try {
        $processes = netstat -ano | Select-String ":$Port " | ForEach-Object {
            $fields = $_ -split '\s+'
            $fields[-1]
        }
        
        if ($processes) {
            foreach ($pid in $processes) {
                if ($pid -and $pid -ne "0") {
                    try {
                        $process = Get-Process -Id $pid -ErrorAction SilentlyContinue
                        if ($process) {
                            Write-Host "Stopping $ServiceName (PID: $pid)..." -ForegroundColor Yellow
                            Stop-Process -Id $pid -Force
                            Write-Host "✓ $ServiceName stopped" -ForegroundColor Green
                        }
                    } catch {
                        Write-Host "⚠ Could not stop process $pid for $ServiceName" -ForegroundColor Yellow
                    }
                }
            }
        } else {
            Write-Host "✓ $ServiceName not running on port $Port" -ForegroundColor Green
        }
    } catch {
        Write-Host "⚠ Error checking port $Port for $ServiceName" -ForegroundColor Yellow
    }
}

# Function to kill processes by name
function Stop-ProcessByName {
    param(
        [string]$ProcessName,
        [string]$ServiceName
    )
    
    try {
        $processes = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
        if ($processes) {
            foreach ($process in $processes) {
                Write-Host "Stopping $ServiceName (PID: $($process.Id))..." -ForegroundColor Yellow
                Stop-Process -Id $process.Id -Force
                Write-Host "✓ $ServiceName stopped" -ForegroundColor Green
            }
        } else {
            Write-Host "✓ No $ServiceName processes found" -ForegroundColor Green
        }
    } catch {
        Write-Host "⚠ Error stopping $ServiceName processes" -ForegroundColor Yellow
    }
}

Write-Host "`n=== Stopping Backend Services ===" -ForegroundColor Cyan

# Stop services by port
Stop-ProcessByPort -Port 8080 -ServiceName "Auth Service"
Stop-ProcessByPort -Port 8081 -ServiceName "Payment Service"
Stop-ProcessByPort -Port 8082 -ServiceName "Merchant Service"
Stop-ProcessByPort -Port 8083 -ServiceName "Transaction Service"
Stop-ProcessByPort -Port 8084 -ServiceName "API Gateway"

Write-Host "`n=== Stopping Frontend Services ===" -ForegroundColor Cyan

# Stop frontend services
Stop-ProcessByPort -Port 3000 -ServiceName "Frontend (React)"
Stop-ProcessByPort -Port 3001 -ServiceName "Test Merchant App"

Write-Host "`n=== Stopping Java Processes ===" -ForegroundColor Cyan

# Stop any remaining Java processes (Spring Boot applications)
try {
    $javaProcesses = Get-Process -Name "java" -ErrorAction SilentlyContinue | Where-Object {
        $_.CommandLine -like "*spring-boot*" -or 
        $_.CommandLine -like "*paymentgateway*" -or
        $_.MainWindowTitle -like "*spring-boot*"
    }
    
    if ($javaProcesses) {
        foreach ($process in $javaProcesses) {
            Write-Host "Stopping Java process (PID: $($process.Id))..." -ForegroundColor Yellow
            Stop-Process -Id $process.Id -Force
            Write-Host "✓ Java process stopped" -ForegroundColor Green
        }
    } else {
        Write-Host "✓ No Spring Boot Java processes found" -ForegroundColor Green
    }
} catch {
    Write-Host "⚠ Error stopping Java processes" -ForegroundColor Yellow
}

Write-Host "`n=== Stopping Node.js Processes ===" -ForegroundColor Cyan

# Stop Node.js processes
try {
    $nodeProcesses = Get-Process -Name "node" -ErrorAction SilentlyContinue | Where-Object {
        $_.CommandLine -like "*npm*" -or 
        $_.CommandLine -like "*react-scripts*" -or
        $_.CommandLine -like "*start*"
    }
    
    if ($nodeProcesses) {
        foreach ($process in $nodeProcesses) {
            Write-Host "Stopping Node.js process (PID: $($process.Id))..." -ForegroundColor Yellow
            Stop-Process -Id $process.Id -Force
            Write-Host "✓ Node.js process stopped" -ForegroundColor Green
        }
    } else {
        Write-Host "✓ No Node.js development processes found" -ForegroundColor Green
    }
} catch {
    Write-Host "⚠ Error stopping Node.js processes" -ForegroundColor Yellow
}

Write-Host "`n=== Cleaning Up Temporary Files ===" -ForegroundColor Cyan

# Clean up temporary files and caches
try {
    # Clean Maven target directories
    if (Test-Path "backend/*/target") {
        Write-Host "Cleaning Maven target directories..." -ForegroundColor Yellow
        Get-ChildItem -Path "backend" -Recurse -Directory -Name "target" | ForEach-Object {
            $targetPath = "backend/$_"
            if (Test-Path $targetPath) {
                Remove-Item -Path $targetPath -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
        Write-Host "✓ Maven target directories cleaned" -ForegroundColor Green
    }
    
    # Clean npm cache (optional)
    Write-Host "Cleaning npm cache..." -ForegroundColor Yellow
    npm cache clean --force 2>$null
    Write-Host "✓ npm cache cleaned" -ForegroundColor Green
    
} catch {
    Write-Host "⚠ Error cleaning temporary files" -ForegroundColor Yellow
}

Write-Host "`n=== Final Port Check ===" -ForegroundColor Cyan

# Final check to ensure all ports are free
$ports = @(8080, 8081, 8082, 8083, 8084, 3000, 3001)
$stillRunning = @()

foreach ($port in $ports) {
    $processes = netstat -ano | Select-String ":$port "
    if ($processes) {
        $stillRunning += $port
        Write-Host "⚠ Port $port is still in use" -ForegroundColor Yellow
    } else {
        Write-Host "✓ Port $port is free" -ForegroundColor Green
    }
}

if ($stillRunning.Count -gt 0) {
    Write-Host "`nSome ports are still in use: $($stillRunning -join ', ')" -ForegroundColor Yellow
    Write-Host "You may need to manually kill these processes or restart your computer." -ForegroundColor Yellow
    
    # Show processes still using the ports
    foreach ($port in $stillRunning) {
        Write-Host "`nProcesses using port $port`:" -ForegroundColor Yellow
        netstat -ano | Select-String ":$port " | ForEach-Object {
            $fields = $_ -split '\s+'
            $pid = $fields[-1]
            if ($pid -and $pid -ne "0") {
                try {
                    $process = Get-Process -Id $pid -ErrorAction SilentlyContinue
                    if ($process) {
                        Write-Host "  PID $pid`: $($process.ProcessName)" -ForegroundColor White
                    }
                } catch {
                    Write-Host "  PID $pid`: Unknown process" -ForegroundColor White
                }
            }
        }
    }
} else {
    Write-Host "`n✓ All Payment Gateway services stopped successfully!" -ForegroundColor Green
}

Write-Host "`n=== Cleanup Complete ===" -ForegroundColor Green
Write-Host "All Payment Gateway services have been stopped." -ForegroundColor White
Write-Host "You can now restart the services using start-local-windows.ps1" -ForegroundColor White

Write-Host "`nPress any key to exit..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")