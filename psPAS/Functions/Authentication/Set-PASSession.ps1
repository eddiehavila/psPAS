# .ExternalHelp psPAS-help.xml
function Set-PASSession {
	<#
	.SYNOPSIS
	Initializes a psPAS session with an existing authenticated WebSession

	.DESCRIPTION
	Establishes a psPAS session using a pre-authenticated WebSession object
	(e.g., from WebView2 or another authentication flow) that already contains
	the necessary cookies and authentication token.

	This is useful when you've already authenticated externally and have a valid
	WebSession with cookies, and just need to initialize the psPAS module to use it.

	.PARAMETER BaseURI
	The base URI of the CyberArk PVWA server (e.g., https://pvwa.company.com)

	.PARAMETER WebSession
	An authenticated WebRequestSession object containing valid cookies and session data

	.PARAMETER AuthToken
	Optional authentication token (e.g., SAML token, bearer token) to use for API requests.
	If not provided, the function relies on cookies in the WebSession for authentication.

	.PARAMETER SkipVersionCheck
	Skip checking the CyberArk server version

	.PARAMETER SkipUserCheck
	Skip checking the logged-on user information

	.PARAMETER PVWAAppName
	The name of the PVWA application (defaults to 'PasswordVault')

	.EXAMPLE
	# After authenticating with WebView2 and obtaining a WebSession with cookies
	$authToken = "your-saml-token-here"
	$webSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
	# ... populate webSession with cookies from WebView2 ...

	Set-PASSession -BaseURI "https://pvwa.company.com" -WebSession $webSession -AuthToken $authToken

	.EXAMPLE
	# Initialize session without checking version or user
	Set-PASSession -BaseURI "https://pvwa.company.com" -WebSession $webSession -AuthToken $authToken -SkipVersionCheck -SkipUserCheck

	.EXAMPLE
	# Initialize session using only cookies (no AuthToken) - useful when already authenticated via browser
	$webSession = ConvertTo-PASWebSession -Cookies $authResponse.cookies -BaseURI "https://pvwa.company.com"
	Set-PASSession -BaseURI "https://pvwa.company.com" -WebSession $webSession

	.NOTES
	This function is designed for scenarios where authentication has already been completed
	externally (e.g., via browser-based SSO with WebView2) and you need to establish
	the psPAS session with the existing authenticated session.
	#>
	[CmdletBinding(SupportsShouldProcess)]
	param(
		[Parameter(
			Mandatory = $true,
			ValueFromPipeline = $false,
			ValueFromPipelinebyPropertyName = $true
		)]
		[string]$BaseURI,

		[Parameter(
			Mandatory = $true,
			ValueFromPipeline = $false,
			ValueFromPipelinebyPropertyName = $true
		)]
		[Microsoft.PowerShell.Commands.WebRequestSession]$WebSession,

		[Parameter(
			Mandatory = $false,
			ValueFromPipeline = $false,
			ValueFromPipelinebyPropertyName = $true
		)]
		[AllowEmptyString()]
		[string]$AuthToken,

		[Parameter(
			Mandatory = $false,
			ValueFromPipeline = $false,
			ValueFromPipelinebyPropertyName = $true
		)]
		[string]$PVWAAppName = 'PasswordVault',

		[Parameter(
			Mandatory = $false,
			ValueFromPipeline = $false,
			ValueFromPipelinebyPropertyName = $false
		)]
		[switch]$SkipVersionCheck,

		[Parameter(
			Mandatory = $false,
			ValueFromPipeline = $false,
			ValueFromPipelinebyPropertyName = $false
		)]
		[switch]$SkipUserCheck
	)

	begin {
		Write-Verbose "[Set-PASSession] Initializing psPAS session with provided WebSession"
	}

	process {

		if ($PSCmdlet.ShouldProcess($BaseURI, 'Initialize PAS Session')) {

			# Ensure URL is in expected format
			$baseURI = $baseURI -replace '/$', ''
			$baseURI = $baseURI -replace '/PasswordVault$', ''
			$Uri = "$baseURI/$PVWAAppName"

			Write-Verbose "[Set-PASSession] Base URI: $Uri"

			# Create a new WebSession for psPAS module if needed
			if ($null -eq $psPASSession.WebSession) {
				$psPASSession.WebSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
			}

			# Directly assign the CookieContainer from input WebSession to psPAS WebSession
			# This preserves all cookies without needing to enumerate/copy them individually
			Write-Verbose "[Set-PASSession] Assigning CookieContainer from input WebSession"
			try {
				# Direct assignment of the CookieContainer reference
				$psPASSession.WebSession.Cookies = $WebSession.Cookies
				Write-Verbose "[Set-PASSession] CookieContainer assigned successfully"
				Write-Verbose "[Set-PASSession] CookieContainer Capacity: $($psPASSession.WebSession.Cookies.Capacity)"
				Write-Verbose "[Set-PASSession] CookieContainer Count: $($psPASSession.WebSession.Cookies.Count)"
			} catch {
				$cookieErr = $_.Exception.Message
				Write-Warning "[Set-PASSession] Failed to assign CookieContainer: $cookieErr"
			}

			# Extract CA88888 and CA66666 cookie values and set as headers
			# CyberArk requires session cookies to be sent as both cookies AND headers
			Write-Verbose "[Set-PASSession] Extracting CyberArk session cookies for headers"
			try {
				# Use GetCookies with the base URI to get cookies that match
				# IMPORTANT: Add trailing slash to ensure cookies with Path=/PasswordVault/ are matched
				$uriWithSlash = if ($Uri.EndsWith('/')) { $Uri } else { "$Uri/" }
				$requestUri = [Uri]$uriWithSlash
				$cookiesForUri = $psPASSession.WebSession.Cookies.GetCookies($requestUri)

				Write-Verbose "[Set-PASSession] Found $($cookiesForUri.Count) cookies matching URI: $uriWithSlash"

				# Extract CA88888 and CA66666 cookies and add as headers
				foreach ($cookie in $cookiesForUri) {
					Write-Verbose "[Set-PASSession]   Found cookie: $($cookie.Name) (Domain: $($cookie.Domain), Path: $($cookie.Path))"
					if ($cookie.Name -eq 'CA88888') {
						if (-not $psPASSession.WebSession.Headers) {
							$psPASSession.WebSession.Headers = @{}
						}
						# CyberArk expects the session token in the Authorization header
						$psPASSession.WebSession.Headers['Authorization'] = $cookie.Value
						Write-Verbose "[Set-PASSession] Added Authorization header with CA88888 value: $($cookie.Value.Substring(0, [Math]::Min(20, $cookie.Value.Length)))..."
					}
					elseif ($cookie.Name -eq 'CA66666') {
						if (-not $psPASSession.WebSession.Headers) {
							$psPASSession.WebSession.Headers = @{}
						}
						$psPASSession.WebSession.Headers['X-CA66666'] = $cookie.Value
						Write-Verbose "[Set-PASSession] Added X-CA66666 header: $($cookie.Value.Substring(0, [Math]::Min(20, $cookie.Value.Length)))..."
					}
				}
			} catch {
				$headerErr = $_.Exception.Message
				Write-Warning "[Set-PASSession] Could not extract session cookies for headers: $headerErr"
			}

			# Copy headers from input WebSession to psPAS WebSession
			if ($WebSession.Headers) {
				foreach ($headerKey in $WebSession.Headers.Keys) {
					$psPASSession.WebSession.Headers[$headerKey] = $WebSession.Headers[$headerKey]
				}
			}

			# Add Authorization header to WebSession if AuthToken is provided (overrides CA88888 cookie value)
			if ($PSBoundParameters.ContainsKey('AuthToken') -and -not [string]::IsNullOrEmpty($AuthToken)) {
				if (-not $psPASSession.WebSession.Headers) {
					$psPASSession.WebSession.Headers = @{}
				}
				$psPASSession.WebSession.Headers['Authorization'] = $AuthToken
				Write-Verbose "[Set-PASSession] Authorization header overridden with provided AuthToken"
			} elseif (-not $psPASSession.WebSession.Headers.ContainsKey('Authorization')) {
				Write-Verbose "[Set-PASSession] No Authorization header set - relying on cookies only"
			}

			# CookieContainer assignment complete
			Write-Verbose "[Set-PASSession] CookieContainer assignment complete"

			# Record Session Start Time
			$psPASSession.StartTime = Get-Date

			# BaseURI set in Module Scope
			$psPASSession.BaseURI = $Uri

			Write-Verbose "[Set-PASSession] Session initialized"

			# Initial Value for Version variable
			[System.Version]$Version = '0.0'

			if (-not $SkipVersionCheck) {
				try {
					Write-Verbose "[Set-PASSession] Checking CyberArk server version"
					# Get CyberArk ExternalVersion number
					[System.Version]$Version = Get-PASServer -ErrorAction Stop |
						Select-Object -ExpandProperty ExternalVersion
					Write-Verbose "[Set-PASSession] Server version: $Version"
				} catch {
					Write-Verbose "[Set-PASSession] Could not determine server version: $($_.Exception.Message)"
					[System.Version]$Version = '0.0'
				}
			}

			# Version information available in module scope
			$psPASSession.ExternalVersion = $Version

			if (-not $SkipUserCheck) {
				try {
					Write-Verbose "[Set-PASSession] Checking logged-on user"
					# Get Authenticated User
					$User = Get-PASLoggedOnUser -ErrorAction Stop
					$Username = $User | Select-Object -ExpandProperty UserName
					Write-Verbose "[Set-PASSession] Logged on as: $Username"
				} catch {
					Write-Verbose "[Set-PASSession] Could not determine logged-on user: $($_.Exception.Message)"
					$Username = $null
				}
			} else {
				$Username = $null
			}

			$psPASSession.User = $Username

			Write-Verbose "[Set-PASSession] Session initialization complete"

			# Return session info
			Get-PASSession

		}

	}

	end { }

}
