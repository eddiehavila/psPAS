# Test script to verify WebView2 SAML authentication with psPAS
# This script tests various psPAS commands to see which work with cookie-based auth

Import-Module psPAS

# Step 1: Authenticate via WebView2
Write-Host "`n=== Step 1: WebView2 Authentication ===" -ForegroundColor Cyan
$jsonResponse = & "C:\Users\e434527\OneDrive - Lockheed Martin US\Documents\Sources\getSAMLResponse-Interactive\webView2 Modern Source\bin\Debug\getSAMLResponse.exe" "https://passm.us.lmco.com/PasswordVault/v10/logon/saml"
$authResponse = $jsonResponse | ConvertFrom-Json

Write-Host "Got SAML response with $($authResponse.cookies.Count) cookies" -ForegroundColor Green

# Step 2: Convert to WebSession
Write-Host "`n=== Step 2: Convert to WebSession ===" -ForegroundColor Cyan
$webSession = ConvertTo-PASWebSession -Cookies $authResponse.cookies -BaseURI "https://passm.us.lmco.com"
Write-Host "WebSession created with $($webSession.Cookies.Count) cookies" -ForegroundColor Green

# Step 3: Initialize psPAS session (skip checks to avoid Gen1 API issues)
Write-Host "`n=== Step 3: Initialize psPAS Session ===" -ForegroundColor Cyan
Set-PASSession -BaseURI "https://passm.us.lmco.com" -WebSession $webSession -SkipVersionCheck -SkipUserCheck
Write-Host "Session initialized successfully" -ForegroundColor Green
Write-Host "External Version: $($psPASSession.ExternalVersion)" -ForegroundColor White

# Step 4: Test various psPAS commands
Write-Host "`n=== Step 4: Testing psPAS Commands ===" -ForegroundColor Cyan

# Test 1: Get-PASLoggedOnUser (Gen1 API)
Write-Host "`nTest 1: Get-PASLoggedOnUser (Gen1 API)" -ForegroundColor Yellow
try {
    $user = Get-PASLoggedOnUser -ErrorAction Stop
    Write-Host "  SUCCESS: Logged in as $($user.UserName)" -ForegroundColor Green
} catch {
    Write-Host "  FAILED: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 2: Get-PASSession (Gen2 API)
Write-Host "`nTest 2: Get-PASSession (Gen2 API)" -ForegroundColor Yellow
try {
    $sessionInfo = Get-PASSession -ErrorAction Stop
    Write-Host "  SUCCESS: User = $($sessionInfo.User.UserName)" -ForegroundColor Green
} catch {
    Write-Host "  FAILED: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 3: Get-PASAccount (search)
Write-Host "`nTest 3: Get-PASAccount -search 'test' (Gen2 API)" -ForegroundColor Yellow
try {
    $accounts = Get-PASAccount -search "test" -ErrorAction Stop
    Write-Host "  SUCCESS: Found $($accounts.Count) accounts" -ForegroundColor Green
} catch {
    Write-Host "  FAILED: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 4: Get-PASSafe (list safes)
Write-Host "`nTest 4: Get-PASSafe (Gen1 API)" -ForegroundColor Yellow
try {
    $safes = Get-PASSafe -ErrorAction Stop | Select-Object -First 5
    Write-Host "  SUCCESS: Found safes" -ForegroundColor Green
    $safes | Format-Table SafeName, Description -AutoSize
} catch {
    Write-Host "  FAILED: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 5: Get-PASServer (Gen2 API)
Write-Host "`nTest 5: Get-PASServer (Gen2 API)" -ForegroundColor Yellow
try {
    $server = Get-PASServer -ErrorAction Stop
    Write-Host "  SUCCESS: Server version = $($server.ExternalVersion)" -ForegroundColor Green
} catch {
    Write-Host "  FAILED: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n=== Testing Complete ===" -ForegroundColor Cyan
Write-Host "Session information:" -ForegroundColor White
$psPASSession | Format-List BaseURI, ExternalVersion, StartTime

Write-Host "`nYou can now use psPAS commands interactively!" -ForegroundColor Green
