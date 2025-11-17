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

			# Explicitly copy all cookies from input WebSession to psPAS WebSession
			Write-Verbose "[Set-PASSession] Copying cookies from input WebSession"
			try {
				$cookiesToCopy = @()

				# Try to use GetAllCookies if available (PowerShell Core)
				if ($WebSession.Cookies.PSObject.Methods['GetAllCookies']) {
					$cookiesToCopy = $WebSession.Cookies.GetAllCookies()
				} else {
					# Fallback: Use reflection to access internal cookie table
					$cookieCollection = $WebSession.Cookies.GetType().InvokeMember(
						'm_domainTable',
						[System.Reflection.BindingFlags]::NonPublic -bor [System.Reflection.BindingFlags]::GetField -bor [System.Reflection.BindingFlags]::Instance,
						$null,
						$WebSession.Cookies,
						$null
					)
					if ($cookieCollection) {
						foreach ($domain in $cookieCollection.Values) {
							$pathTable = $domain.GetType().InvokeMember(
								'm_list',
								[System.Reflection.BindingFlags]::NonPublic -bor [System.Reflection.BindingFlags]::GetField -bor [System.Reflection.BindingFlags]::Instance,
								$null,
								$domain,
								$null
							)
							if ($pathTable) {
								foreach ($path in $pathTable.Values) {
									foreach ($cookie in $path.Values) {
										$cookiesToCopy += $cookie
									}
								}
							}
						}
					}
				}

				Write-Verbose "[Set-PASSession] Found $($cookiesToCopy.Count) cookies to copy from input WebSession"

				foreach ($cookie in $cookiesToCopy) {
					$psPASSession.WebSession.Cookies.Add($cookie)
					$cookieValuePreview = if ($cookie.Value.Length -gt 20) { $cookie.Value.Substring(0, 20) + '...' } else { $cookie.Value }
					Write-Verbose "[Set-PASSession]   Copied cookie: $($cookie.Name) = $cookieValuePreview (Domain: $($cookie.Domain), Path: $($cookie.Path))"
				}

			} catch {
				$copyErr = $_.Exception.Message
				Write-Warning "[Set-PASSession] Failed to copy cookies: $copyErr"
			}

			# Copy headers from input WebSession to psPAS WebSession
			if ($WebSession.Headers) {
				foreach ($headerKey in $WebSession.Headers.Keys) {
					$psPASSession.WebSession.Headers[$headerKey] = $WebSession.Headers[$headerKey]
				}
			}

			# Add Authorization header to WebSession if AuthToken is provided
			if ($PSBoundParameters.ContainsKey('AuthToken') -and -not [string]::IsNullOrEmpty($AuthToken)) {
				if (-not $psPASSession.WebSession.Headers) {
					$psPASSession.WebSession.Headers = @{}
				}
				$psPASSession.WebSession.Headers['Authorization'] = $AuthToken
				Write-Verbose "[Set-PASSession] Authorization header set to provided token"
			} else {
				Write-Verbose "[Set-PASSession] No AuthToken provided - relying on cookies for authentication"
			}

			# Verify cookies were copied successfully
			Write-Verbose "[Set-PASSession] Cookie copy complete"

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
