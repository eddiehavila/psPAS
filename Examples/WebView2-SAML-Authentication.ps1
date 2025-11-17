# Example: Authenticate to CyberArk using WebView2 SAML with psPAS
# This example shows how to use WebView2 for interactive SAML authentication
# and initialize a psPAS session with the resulting cookies

# Prerequisites:
# - WebView2 application that returns JSON with: saml, cookieHeader, and cookies array
# - psPAS module imported

#region Configuration
$CyberArkURL = "https://passm.us.lmco.com"
$SAMLEndpoint = "$CyberArkURL/PasswordVault/v10/logon/saml"
$WebView2ExePath = "C:\Path\To\getSAMLResponse.exe"
#endregion

#region Step 1: Get SAML authentication response from WebView2
Write-Host "Opening WebView2 for SAML authentication..." -ForegroundColor Cyan

# Launch WebView2 application and get JSON response
$jsonResponse = & $WebView2ExePath $SAMLEndpoint

# Parse JSON response
$authResponse = $jsonResponse | ConvertFrom-Json

# Display what we received (optional)
Write-Host "`nAuthentication response received:" -ForegroundColor Green
Write-Host "  SAML Token: $($authResponse.saml.Length) characters"
Write-Host "  Cookie Header: $($authResponse.cookieHeader.Length) characters"
Write-Host "  Cookies Array: $($authResponse.cookies.Count) cookies"
#endregion

#region Step 2: Convert cookies to PowerShell WebSession
Write-Host "`nConverting cookies to WebSession..." -ForegroundColor Cyan

# Option A: Using cookie objects (recommended)
$webSession = ConvertTo-PASWebSession -Cookies $authResponse.cookies `
                                       -BaseURI $CyberArkURL `
                                       -Verbose

# Option B: Using raw cookie header string (alternative)
# $webSession = ConvertTo-PASWebSession -CookieHeader $authResponse.cookieHeader `
#                                        -BaseURI $CyberArkURL `
#                                        -Verbose

Write-Host "WebSession created with $($webSession.Cookies.Count) cookies" -ForegroundColor Green
#endregion

#region Step 3: Initialize psPAS session with the WebSession
Write-Host "`nInitializing psPAS session..." -ForegroundColor Cyan

# Set up the psPAS session with authenticated cookies
# No AuthToken needed - cookies contain the session
Set-PASSession -BaseURI $CyberArkURL `
               -WebSession $webSession `
               -Verbose

Write-Host "psPAS session initialized successfully" -ForegroundColor Green
#endregion

#region Step 4: Verify authentication by getting logged-on user
Write-Host "`nVerifying authentication..." -ForegroundColor Cyan

try {
    $loggedOnUser = Get-PASLoggedOnUser

    Write-Host "`nAuthentication successful!" -ForegroundColor Green
    Write-Host "Logged in as: $($loggedOnUser.UserName)" -ForegroundColor White
    Write-Host "Source: $($loggedOnUser.Source)" -ForegroundColor White
    Write-Host "User Type: $($loggedOnUser.UserType)" -ForegroundColor White

} catch {
    Write-Host "`nAuthentication failed!" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
#endregion

#region Step 5: Use psPAS commands (examples)
Write-Host "`n--- Ready to use psPAS commands ---" -ForegroundColor Cyan

# Example: Get a specific safe
# $safe = Get-PASSafe -SafeName "MySafeName"

# Example: Search for accounts
# $accounts = Get-PASAccount -search "username"

# Example: Get account password
# $password = Get-PASAccountPassword -AccountID "12_3"

Write-Host "`nYou can now use any psPAS command to interact with CyberArk" -ForegroundColor Green
#endregion
