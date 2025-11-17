# Working example: WebView2 SAML authentication with psPAS
# This example shows the minimal working authentication

Import-Module psPAS

# Authenticate via WebView2
$jsonResponse = & "C:\Users\e434527\OneDrive - Lockheed Martin US\Documents\Sources\getSAMLResponse-Interactive\webView2 Modern Source\bin\Debug\getSAMLResponse.exe" "https://passm.us.lmco.com/PasswordVault/v10/logon/saml"
$authResponse = $jsonResponse | ConvertFrom-Json

# Convert cookies to WebSession
$webSession = ConvertTo-PASWebSession -Cookies $authResponse.cookies -BaseURI "https://passm.us.lmco.com"

# Initialize psPAS session (skip user check to avoid Gen1 API issues)
Set-PASSession -BaseURI "https://passm.us.lmco.com" -WebSession $webSession -SkipVersionCheck -SkipUserCheck

Write-Host "Authentication successful!" -ForegroundColor Green
Write-Host "CyberArk Server Version: $($psPASSession.ExternalVersion)" -ForegroundColor White

# Now you can use psPAS commands
# Examples:

# Get session info (Gen2 API - more reliable with this auth method)
try {
    $sessionInfo = Get-PASSession
    Write-Host "`nLogged in as: $($sessionInfo.User.UserName)" -ForegroundColor Cyan
    Write-Host "User Type: $($sessionInfo.User.UserType)" -ForegroundColor Cyan
} catch {
    Write-Warning "Could not get session info: $($_.Exception.Message)"
}

# Search for accounts (Gen2 API)
# $accounts = Get-PASAccount -search "myaccount"

# Get a specific safe (Gen1 API - may or may not work)
# $safe = Get-PASSafe -SafeName "MySafe"

# List all safes (Gen1 API - may or may not work)
# $safes = Get-PASSafe
