# Advanced example: WebView2 SAML authentication with error handling and multiple scenarios

Import-Module psPAS

#region Scenario 1: Standard cookie-based authentication (recommended)
function Connect-CyberArkWithCookies {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$BaseURI,

        [Parameter(Mandatory = $true)]
        [string]$WebView2ExePath
    )

    try {
        # Get SAML response from WebView2
        Write-Verbose "Launching WebView2 for authentication..."
        $jsonResponse = & $WebView2ExePath "$BaseURI/PasswordVault/v10/logon/saml"

        if ([string]::IsNullOrEmpty($jsonResponse)) {
            throw "No response received from WebView2"
        }

        $authResponse = $jsonResponse | ConvertFrom-Json

        # Verify we have cookies
        if ($null -eq $authResponse.cookies -or $authResponse.cookies.Count -eq 0) {
            throw "No cookies received from WebView2"
        }

        Write-Verbose "Received $($authResponse.cookies.Count) cookies from WebView2"

        # Convert to WebSession
        $webSession = ConvertTo-PASWebSession -Cookies $authResponse.cookies -BaseURI $BaseURI

        # Initialize psPAS session (no AuthToken needed)
        Set-PASSession -BaseURI $BaseURI -WebSession $webSession

        # Verify authentication
        $user = Get-PASLoggedOnUser
        Write-Host "Successfully authenticated as: $($user.UserName)" -ForegroundColor Green

        return $true

    } catch {
        Write-Error "Authentication failed: $($_.Exception.Message)"
        return $false
    }
}
#endregion

#region Scenario 2: Using cookie header string (alternative)
function Connect-CyberArkWithCookieHeader {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$BaseURI,

        [Parameter(Mandatory = $true)]
        [string]$WebView2ExePath
    )

    try {
        $jsonResponse = & $WebView2ExePath "$BaseURI/PasswordVault/v10/logon/saml"
        $authResponse = $jsonResponse | ConvertFrom-Json

        # Use cookie header string instead of cookie objects
        $webSession = ConvertTo-PASWebSession -CookieHeader $authResponse.cookieHeader -BaseURI $BaseURI

        Set-PASSession -BaseURI $BaseURI -WebSession $webSession

        $user = Get-PASLoggedOnUser
        Write-Host "Successfully authenticated as: $($user.UserName)" -ForegroundColor Green

        return $true

    } catch {
        Write-Error "Authentication failed: $($_.Exception.Message)"
        return $false
    }
}
#endregion

#region Scenario 3: With additional AuthToken (if required by environment)
function Connect-CyberArkWithCookiesAndToken {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$BaseURI,

        [Parameter(Mandatory = $true)]
        [string]$WebView2ExePath
    )

    try {
        $jsonResponse = & $WebView2ExePath "$BaseURI/PasswordVault/v10/logon/saml"
        $authResponse = $jsonResponse | ConvertFrom-Json

        # Convert cookies
        $webSession = ConvertTo-PASWebSession -Cookies $authResponse.cookies -BaseURI $BaseURI

        # Initialize with both cookies AND SAML token (if your environment requires it)
        Set-PASSession -BaseURI $BaseURI -WebSession $webSession -AuthToken $authResponse.saml

        $user = Get-PASLoggedOnUser
        Write-Host "Successfully authenticated as: $($user.UserName)" -ForegroundColor Green

        return $true

    } catch {
        Write-Error "Authentication failed: $($_.Exception.Message)"
        return $false
    }
}
#endregion

#region Scenario 4: Session management and re-authentication
function Test-PASSessionValid {
    <#
    .SYNOPSIS
    Tests if the current psPAS session is still valid

    .DESCRIPTION
    Attempts to call Get-PASLoggedOnUser to verify the session is still active.
    Returns $true if valid, $false if not.
    #>
    try {
        $null = Get-PASLoggedOnUser -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

function Connect-CyberArkWithSessionCheck {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$BaseURI,

        [Parameter(Mandatory = $true)]
        [string]$WebView2ExePath,

        [switch]$Force
    )

    # Check if we already have a valid session
    if (-not $Force -and (Test-PASSessionValid)) {
        Write-Host "Already authenticated with valid session" -ForegroundColor Green
        $user = Get-PASLoggedOnUser
        Write-Host "Current user: $($user.UserName)" -ForegroundColor White
        return $true
    }

    # Need to authenticate
    Write-Host "Authenticating to CyberArk..." -ForegroundColor Cyan
    return Connect-CyberArkWithCookies -BaseURI $BaseURI -WebView2ExePath $WebView2ExePath
}
#endregion

#region Example Usage
# Configuration
$BaseURI = "https://passm.us.lmco.com"
$WebView2ExePath = "C:\Path\To\getSAMLResponse.exe"

# Use the appropriate scenario for your environment:

# Standard authentication (recommended)
$success = Connect-CyberArkWithCookies -BaseURI $BaseURI -WebView2ExePath $WebView2ExePath -Verbose

# Alternative: Using cookie header string
# $success = Connect-CyberArkWithCookieHeader -BaseURI $BaseURI -WebView2ExePath $WebView2ExePath

# With session check (only re-authenticate if needed)
# $success = Connect-CyberArkWithSessionCheck -BaseURI $BaseURI -WebView2ExePath $WebView2ExePath

# Force re-authentication
# $success = Connect-CyberArkWithSessionCheck -BaseURI $BaseURI -WebView2ExePath $WebView2ExePath -Force

if ($success) {
    # Now you can use any psPAS commands

    # Example: List all safes
    # $safes = Get-PASSafe
    # $safes | Format-Table SafeName, Description

    # Example: Search for accounts
    # $accounts = Get-PASAccount -search "prod"
    # $accounts | Format-Table userName, address, safeName

    # Example: Get specific account details
    # $account = Get-PASAccount -id "123_45"
    # $account | Format-List

    Write-Host "`nReady to use psPAS commands!" -ForegroundColor Green
} else {
    Write-Host "`nAuthentication failed - please check errors above" -ForegroundColor Red
    exit 1
}
#endregion
