# WebView2 SAML Authentication Examples

This directory contains examples for authenticating to CyberArk using WebView2 with SAML and the psPAS module.

## Overview

When your CyberArk environment uses SAML with SSO (Single Sign-On), you can use a WebView2 application to handle the interactive browser-based authentication. The WebView2 app captures the SAML token and cookies, which are then used to initialize a psPAS session.

## Prerequisites

1. **psPAS module** with WebView2 support functions:
   - `ConvertTo-PASWebSession`
   - `Set-PASSession`

2. **WebView2 application** that:
   - Opens a browser window for SAML authentication
   - Returns JSON with three properties:
     - `saml`: Base64-encoded SAML token
     - `cookieHeader`: Raw cookie string
     - `cookies`: Array of cookie objects with Name, Value, Domain, Path, Secure, HttpOnly

## Examples Provided

### 1. WebView2-Minimal-Example.ps1

**Use case**: Quick start / getting started

The bare minimum code needed to authenticate. Good for understanding the basic workflow.

```powershell
# Just 4 steps:
$authResponse = (& $WebView2ExePath $SAMLEndpoint) | ConvertFrom-Json
$webSession = ConvertTo-PASWebSession -Cookies $authResponse.cookies -BaseURI $BaseURI
Set-PASSession -BaseURI $BaseURI -WebSession $webSession
Get-PASLoggedOnUser
```

### 2. WebView2-SAML-Authentication.ps1

**Use case**: Production-ready script with clear steps

A complete, well-documented script showing:
- Configuration section
- Step-by-step authentication flow
- Verification of successful login
- Examples of using psPAS commands after authentication

Includes verbose output and color-coded status messages.

### 3. WebView2-Advanced-Example.ps1

**Use case**: Enterprise environments / complex scenarios

Demonstrates:
- **Reusable functions** for authentication
- **Error handling** and validation
- **Session checking** (avoid re-authenticating if session is valid)
- **Multiple authentication methods**:
  - Cookie objects (recommended)
  - Cookie header string (alternative)
  - Cookies + SAML token (if required)
- **Force re-authentication** option

## Quick Start

### Option 1: Using Cookie Objects (Recommended)

```powershell
Import-Module psPAS

# Get authentication from WebView2
$jsonResponse = & "C:\Path\To\getSAMLResponse.exe" "https://cyberark.company.com/PasswordVault/v10/logon/saml"
$authResponse = $jsonResponse | ConvertFrom-Json

# Convert cookies to WebSession
$webSession = ConvertTo-PASWebSession -Cookies $authResponse.cookies `
                                       -BaseURI "https://cyberark.company.com"

# Initialize psPAS session
Set-PASSession -BaseURI "https://cyberark.company.com" -WebSession $webSession

# Verify authentication
Get-PASLoggedOnUser
```

### Option 2: Using Cookie Header String

```powershell
# Convert cookie header string to WebSession
$webSession = ConvertTo-PASWebSession -CookieHeader $authResponse.cookieHeader `
                                       -BaseURI "https://cyberark.company.com"

# Initialize psPAS session
Set-PASSession -BaseURI "https://cyberark.company.com" -WebSession $webSession
```

## Function Reference

### ConvertTo-PASWebSession

Converts WebView2 authentication response to a PowerShell WebRequestSession.

**Parameters:**
- `-Cookies` - Array of cookie objects from WebView2 (recommended)
- `-CookieHeader` - Raw cookie header string from WebView2 (alternative)
- `-BaseURI` - The base URI of your CyberArk server (required)

**Returns:** `Microsoft.PowerShell.Commands.WebRequestSession`

### Set-PASSession

Initializes the psPAS module session with an authenticated WebSession.

**Parameters:**
- `-BaseURI` - The base URI of your CyberArk server (required)
- `-WebSession` - The authenticated WebRequestSession (required)
- `-AuthToken` - Optional SAML token (usually not needed, cookies are sufficient)
- `-SkipVersionCheck` - Skip CyberArk version check
- `-SkipUserCheck` - Skip logged-on user check

### Get-PASLoggedOnUser

Verifies authentication by retrieving the currently logged-on user.

**Returns:** Object with UserName, Source, UserType, etc.

## Troubleshooting

### Issue: 403 "Couldn't retrieve session token from request header"

**Cause:** Cookies weren't transferred properly to the psPAS session.

**Solution:**
- Ensure you're using the latest version of `Set-PASSession` which directly assigns the CookieContainer
- Verify your WebView2 app is returning cookies in the JSON response
- Check that the cookie domain matches your CyberArk server

### Issue: WebSession has 0 cookies

**Cause:** Cookie objects may not have proper Domain/Path values.

**Solution:**
- Verify cookie objects from WebView2 include Domain and Path properties
- Use `-Verbose` flag to see diagnostic output:
  ```powershell
  ConvertTo-PASWebSession -Cookies $authResponse.cookies -BaseURI $BaseURI -Verbose
  ```

### Issue: Session works but expires quickly

**Cause:** Session timeout in CyberArk.

**Solution:**
- Check session timeout settings in CyberArk
- Implement session checking before long-running operations:
  ```powershell
  if (-not (Test-PASSessionValid)) {
      # Re-authenticate
  }
  ```

## Authentication Flow Diagram

```
┌─────────────────┐
│  User runs      │
│  PowerShell     │
│  script         │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Launch         │
│  WebView2.exe   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  User logs in   │
│  via SAML/SSO   │
│  in browser     │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  WebView2       │
│  returns JSON   │
│  with cookies   │
└────────┬────────┘
         │
         ▼
┌─────────────────────────┐
│  ConvertTo-PASWebSession│
│  creates WebSession     │
└────────┬────────────────┘
         │
         ▼
┌─────────────────┐
│  Set-PASSession │
│  initializes    │
│  psPAS module   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Use psPAS      │
│  commands       │
└─────────────────┘
```

## Additional Resources

- [psPAS Documentation](https://pspas.pspete.dev/)
- [CyberArk REST API Documentation](https://docs.cyberark.com/Product-Doc/OnlineHelp/PAS/Latest/en/Content/SDK/CyberArk%20REST%20API.htm)
- [WebView2 Documentation](https://docs.microsoft.com/en-us/microsoft-edge/webview2/)

## Notes

- **Cookies vs. SAML Token**: In most environments, cookies alone are sufficient for authentication. The SAML token is typically only needed if you're making direct API calls or if your environment specifically requires it.

- **Session Persistence**: The psPAS session (including cookies) is stored in the `$psPASSession` module variable. This persists for the duration of your PowerShell session unless you explicitly clear it or restart PowerShell.

- **Security**: The authentication cookies contain sensitive session information. Ensure your scripts:
  - Don't log cookie values
  - Don't export cookies to insecure locations
  - Run in a secure environment
