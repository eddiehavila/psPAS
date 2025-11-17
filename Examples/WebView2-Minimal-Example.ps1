# Minimal example: WebView2 SAML authentication with psPAS
# This is the bare minimum code needed to authenticate

Import-Module psPAS

# Step 1: Get authentication response from WebView2
$jsonResponse = & "C:\Path\To\getSAMLResponse.exe" "https://passm.us.lmco.com/PasswordVault/v10/logon/saml"
$authResponse = $jsonResponse | ConvertFrom-Json

# Step 2: Convert cookies to WebSession
$webSession = ConvertTo-PASWebSession -Cookies $authResponse.cookies -BaseURI "https://passm.us.lmco.com"

# Step 3: Initialize psPAS session
Set-PASSession -BaseURI "https://passm.us.lmco.com" -WebSession $webSession

# Step 4: Verify and use
Get-PASLoggedOnUser

# Now use any psPAS commands:
# Get-PASSafe -SafeName "MySafe"
# Get-PASAccount -search "myaccount"
