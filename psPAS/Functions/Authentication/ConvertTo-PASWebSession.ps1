# .ExternalHelp psPAS-help.xml
function ConvertTo-PASWebSession {
	<#
	.SYNOPSIS
	Converts cookie data into a WebRequestSession object for use with psPAS

	.DESCRIPTION
	Takes cookie information from external authentication flows (like WebView2) and
	creates a properly configured WebRequestSession object with all cookies added.

	This is useful when you have cookie data from browser-based authentication and
	need to create a WebSession object for psPAS.

	.PARAMETER Cookies
	An array of cookie objects with Name, Value, Domain, Path, Secure, and HttpOnly properties

	.PARAMETER CookieHeader
	A raw cookie header string (e.g., "name1=value1; name2=value2")

	.PARAMETER BaseURI
	The base URI for the cookies (used to set the cookie domain if not specified)

	.EXAMPLE
	# From WebView2 auth response with cookie objects
	$webSession = ConvertTo-PASWebSession -Cookies $authResponse.cookies -BaseURI "https://pvwa.company.com"

	.EXAMPLE
	# From raw cookie header string
	$webSession = ConvertTo-PASWebSession -CookieHeader $cookieString -BaseURI "https://pvwa.company.com"

	.NOTES
	The resulting WebRequestSession object can be used with Set-PASSession or New-PASSession
	#>
	[CmdletBinding()]
	[OutputType([Microsoft.PowerShell.Commands.WebRequestSession])]
	param(
		[Parameter(
			Mandatory = $false,
			ValueFromPipeline = $false,
			ValueFromPipelinebyPropertyName = $true,
			ParameterSetName = 'CookieObjects'
		)]
		[Object[]]$Cookies,

		[Parameter(
			Mandatory = $false,
			ValueFromPipeline = $false,
			ValueFromPipelinebyPropertyName = $true,
			ParameterSetName = 'CookieHeader'
		)]
		[string]$CookieHeader,

		[Parameter(
			Mandatory = $true,
			ValueFromPipeline = $false,
			ValueFromPipelinebyPropertyName = $true
		)]
		[string]$BaseURI
	)

	begin {
		Write-Verbose "[ConvertTo-PASWebSession] Creating new WebRequestSession"
		$webSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession

		# Parse BaseURI
		$uri = [System.Uri]$BaseURI
		Write-Verbose "[ConvertTo-PASWebSession] Base URI: $BaseURI"
	}

	process {

		if ($PSCmdlet.ParameterSetName -eq 'CookieObjects' -and $Cookies) {

			Write-Verbose "[ConvertTo-PASWebSession] Processing $($Cookies.Count) cookie objects"

			foreach ($cookieData in $Cookies) {
				try {
					# Create a new cookie object
					$cookie = New-Object System.Net.Cookie
					$cookie.Name = $cookieData.Name
					$cookie.Value = $cookieData.Value

					# Set domain - use provided domain or base URI host
					if ($cookieData.Domain) {
						$cookie.Domain = $cookieData.Domain
					} else {
						$cookie.Domain = $uri.Host
					}

					# Set path
					if ($cookieData.Path) {
						$cookie.Path = $cookieData.Path
					} else {
						$cookie.Path = '/'
					}

					# Set secure flag
					if ($null -ne $cookieData.Secure) {
						$cookie.Secure = [bool]$cookieData.Secure
					} else {
						$cookie.Secure = ($uri.Scheme -eq 'https')
					}

					# Set HttpOnly flag
					if ($null -ne $cookieData.HttpOnly) {
						$cookie.HttpOnly = [bool]$cookieData.HttpOnly
					}

					# Add cookie to WebSession
					$webSession.Cookies.Add($cookie)

					$cookieValuePreview = if ($cookie.Value.Length -gt 20) { $cookie.Value.Substring(0, 20) + "..." } else { $cookie.Value }
					Write-Verbose "[ConvertTo-PASWebSession] Added cookie: $($cookie.Name) = $cookieValuePreview (Domain: $($cookie.Domain), Path: $($cookie.Path), Secure: $($cookie.Secure), HttpOnly: $($cookie.HttpOnly))"

				} catch {
					$errMsg = $_.Exception.Message
					Write-Warning "[ConvertTo-PASWebSession] Failed to add cookie $($cookieData.Name): $errMsg"
				}
			}

		} elseif ($PSCmdlet.ParameterSetName -eq 'CookieHeader' -and $CookieHeader) {

			Write-Verbose "[ConvertTo-PASWebSession] Processing cookie header string"

			# Split cookie header by semicolon
			$cookiePairs = $CookieHeader -split ';' | ForEach-Object { $_.Trim() }

			foreach ($pair in $cookiePairs) {
				if ($pair -match '^([^=]+)=(.*)$') {
					$cookieName = $matches[1].Trim()
					$cookieValue = $matches[2].Trim()

					try {
						$cookie = New-Object System.Net.Cookie
						$cookie.Name = $cookieName
						$cookie.Value = $cookieValue
						$cookie.Domain = $uri.Host
						$cookie.Path = '/'
						$cookie.Secure = ($uri.Scheme -eq 'https')

						$webSession.Cookies.Add($cookie)

						$cookieValuePreview = if ($cookieValue.Length -gt 20) { $cookieValue.Substring(0, 20) + "..." } else { $cookieValue }
						Write-Verbose "[ConvertTo-PASWebSession] Added cookie: $cookieName = $cookieValuePreview"

					} catch {
						$errMsg = $_.Exception.Message
						Write-Warning "[ConvertTo-PASWebSession] Failed to add cookie ${cookieName}: $errMsg"
					}
				}
			}
		}

	}

	end {

		# Get final cookie count and detailed diagnostics
		$finalCount = 0
		try {
			Write-Verbose "[ConvertTo-PASWebSession] Verifying cookies were added correctly"

			# Check if GetAllCookies method exists
			$hasGetAllCookies = $null -ne $webSession.Cookies.PSObject.Methods['GetAllCookies']
			Write-Verbose "[ConvertTo-PASWebSession] GetAllCookies method available: $hasGetAllCookies"

			if ($hasGetAllCookies) {
				$allCookies = @($webSession.Cookies.GetAllCookies())
				$finalCount = $allCookies.Count
				Write-Verbose "[ConvertTo-PASWebSession] GetAllCookies returned $finalCount cookies"
				foreach ($c in $allCookies) {
					Write-Verbose "[ConvertTo-PASWebSession]   Enumerated: $($c.Name) on $($c.Domain)$($c.Path)"
				}
			} else {
				Write-Verbose "[ConvertTo-PASWebSession] Using reflection to enumerate cookies"
				# Use reflection
				$cookieCollection = $webSession.Cookies.GetType().InvokeMember(
					'm_domainTable',
					[System.Reflection.BindingFlags]::NonPublic -bor [System.Reflection.BindingFlags]::GetField -bor [System.Reflection.BindingFlags]::Instance,
					$null,
					$webSession.Cookies,
					$null
				)
				Write-Verbose "[ConvertTo-PASWebSession] m_domainTable has $($cookieCollection.Count) domains"
				if ($cookieCollection) {
					foreach ($domain in $cookieCollection.Keys) {
						Write-Verbose "[ConvertTo-PASWebSession]   Domain: $domain"
						$domainObj = $cookieCollection[$domain]
						$pathTable = $domainObj.GetType().InvokeMember(
							'm_list',
							[System.Reflection.BindingFlags]::NonPublic -bor [System.Reflection.BindingFlags]::GetField -bor [System.Reflection.BindingFlags]::Instance,
							$null,
							$domainObj,
							$null
						)
						Write-Verbose "[ConvertTo-PASWebSession]     Path table has $($pathTable.Count) paths"
						if ($pathTable) {
							foreach ($path in $pathTable.Keys) {
								Write-Verbose "[ConvertTo-PASWebSession]       Path: $path"
								$cookieList = $pathTable[$path]
								$pathCookieCount = @($cookieList.Values).Count
								Write-Verbose "[ConvertTo-PASWebSession]         $pathCookieCount cookies"
								foreach ($c in $cookieList.Values) {
									Write-Verbose "[ConvertTo-PASWebSession]           Enumerated: $($c.Name)"
								}
								$finalCount += $pathCookieCount
							}
						}
					}
				}
			}
		} catch {
			Write-Verbose "[ConvertTo-PASWebSession] Could not count cookies: $($_.Exception.Message)"
		}

		Write-Verbose "[ConvertTo-PASWebSession] WebSession created with $finalCount cookie(s)"

		# Return the WebSession
		$webSession
	}

}
