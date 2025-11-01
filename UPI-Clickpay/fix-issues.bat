@echo off
echo Fixing Payment Gateway Local Issues...
echo.

REM Check if PowerShell execution policy allows script execution
powershell -Command "Get-ExecutionPolicy" | findstr /C:"Restricted" >nul
if %errorlevel% equ 0 (
    echo PowerShell execution policy is restricted. Setting it to RemoteSigned for current user...
    powershell -Command "Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force"
)

REM Run the PowerShell script
powershell -ExecutionPolicy Bypass -File "scripts/fix-local-issues.ps1"

pause