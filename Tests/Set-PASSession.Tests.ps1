Describe $($PSCommandPath -Replace '.Tests.ps1') {

	BeforeAll {
		#Get Current Directory
		$Here = Split-Path -Parent $PSCommandPath

		#Assume ModuleName from Repository Root folder
		$ModuleName = Split-Path (Split-Path $Here -Parent) -Leaf

		#Resolve Path to Module Directory
		$ModulePath = Resolve-Path "$Here\..\$ModuleName"

		#Define Path to Module Manifest
		$ManifestPath = Join-Path "$ModulePath" "$ModuleName.psd1"

		if ( -not (Get-Module -Name $ModuleName -All)) {

			Import-Module -Name "$ManifestPath" -ArgumentList $true -Force -ErrorAction Stop

		}

		$Script:RequestBody = $null
		$psPASSession = [ordered]@{
			BaseURI            = 'https://SomeURL/SomeApp'
			User               = $null
			ExternalVersion    = [System.Version]'0.0'
			WebSession         = New-Object Microsoft.PowerShell.Commands.WebRequestSession
			StartTime          = $null
			ElapsedTime        = $null
			LastCommand        = $null
			LastCommandTime    = $null
			LastCommandResults = $null
		}

		New-Variable -Name psPASSession -Value $psPASSession -Scope Script -Force

	}


	AfterAll {

		$Script:RequestBody = $null
		$Script:psPASSession.BaseURI = 'https://SomeURL/SomeApp'
		$psPASSession.ExternalVersion = '0.0'

	}

	InModuleScope $(Split-Path (Split-Path (Split-Path -Parent $PSCommandPath) -Parent) -Leaf ) {

		Context 'Input' {

			BeforeEach {

				Mock Get-PASServer -MockWith {
					[PSCustomObject]@{
						ExternalVersion = '12.6'
					}
				}

				Mock Get-PASLoggedOnUser -MockWith {
					@{'UserName' = 'TestUser' }
				}

				$testWebSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
				$testAuthToken = 'TestAuthToken123'

				$psPASSession.ExternalVersion = '0.0'
				$psPASSession.WebSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
				$psPASSession.BaseURI = $null
				$psPASSession.User = $null

			}

			It 'initializes the session' {
				Set-PASSession -BaseURI 'https://pvwa.company.com' -WebSession $testWebSession -AuthToken $testAuthToken
				$psPASSession.BaseURI | Should -Be 'https://pvwa.company.com/PasswordVault'
			}

			It 'sets the WebSession' {
				Set-PASSession -BaseURI 'https://pvwa.company.com' -WebSession $testWebSession -AuthToken $testAuthToken
				$psPASSession.WebSession | Should -Be $testWebSession
			}

			It 'sets the Authorization header' {
				Set-PASSession -BaseURI 'https://pvwa.company.com' -WebSession $testWebSession -AuthToken $testAuthToken
				$psPASSession.WebSession.Headers['Authorization'] | Should -Be 'TestAuthToken123'
			}

			It 'calls Get-PASServer when not skipping version check' {
				Set-PASSession -BaseURI 'https://pvwa.company.com' -WebSession $testWebSession -AuthToken $testAuthToken
				Assert-MockCalled Get-PASServer -Times 1 -Exactly -Scope It
			}

			It 'sets the ExternalVersion' {
				Set-PASSession -BaseURI 'https://pvwa.company.com' -WebSession $testWebSession -AuthToken $testAuthToken
				$psPASSession.ExternalVersion | Should -Be '12.6'
			}

			It 'does not call Get-PASServer when skipping version check' {
				Set-PASSession -BaseURI 'https://pvwa.company.com' -WebSession $testWebSession -AuthToken $testAuthToken -SkipVersionCheck
				Assert-MockCalled Get-PASServer -Times 0 -Exactly -Scope It
			}

			It 'calls Get-PASLoggedOnUser when not skipping user check' {
				Set-PASSession -BaseURI 'https://pvwa.company.com' -WebSession $testWebSession -AuthToken $testAuthToken
				Assert-MockCalled Get-PASLoggedOnUser -Times 1 -Exactly -Scope It
			}

			It 'sets the User' {
				Set-PASSession -BaseURI 'https://pvwa.company.com' -WebSession $testWebSession -AuthToken $testAuthToken
				$psPASSession.User | Should -Be 'TestUser'
			}

			It 'does not call Get-PASLoggedOnUser when skipping user check' {
				Set-PASSession -BaseURI 'https://pvwa.company.com' -WebSession $testWebSession -AuthToken $testAuthToken -SkipUserCheck
				Assert-MockCalled Get-PASLoggedOnUser -Times 0 -Exactly -Scope It
			}

			It 'sets StartTime' {
				Set-PASSession -BaseURI 'https://pvwa.company.com' -WebSession $testWebSession -AuthToken $testAuthToken
				$psPASSession.StartTime | Should -Not -BeNullOrEmpty
			}

			It 'handles custom PVWAAppName' {
				Set-PASSession -BaseURI 'https://pvwa.company.com' -WebSession $testWebSession -AuthToken $testAuthToken -PVWAAppName 'CustomApp'
				$psPASSession.BaseURI | Should -Be 'https://pvwa.company.com/CustomApp'
			}

			It 'removes trailing slash from BaseURI' {
				Set-PASSession -BaseURI 'https://pvwa.company.com/' -WebSession $testWebSession -AuthToken $testAuthToken
				$psPASSession.BaseURI | Should -Be 'https://pvwa.company.com/PasswordVault'
			}

			It 'removes /PasswordVault from BaseURI if provided' {
				Set-PASSession -BaseURI 'https://pvwa.company.com/PasswordVault' -WebSession $testWebSession -AuthToken $testAuthToken
				$psPASSession.BaseURI | Should -Be 'https://pvwa.company.com/PasswordVault'
			}

		}

	}

}
