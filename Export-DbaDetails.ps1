function Export-DbaDetails {
<#
		.SYNOPSIS
            Copies Noun between SQL Server instances.
		.DESCRIPTION
            Longer description of what Copy-Noun does.
		.PARAMETER Source
			Source SQL Server. You must have sysadmin access and server version must be SQL Server version XXXX or higher.
		.PARAMETER SourceSqlCredential
			Allows you to login to servers using SQL Logins instead of Windows Authentication (AKA Integrated or Trusted). To use:
			$scred = Get-Credential, then pass $scred object to the -SourceSqlCredential parameter.
			Windows Authentication will be used if SourceSqlCredential is not specified. SQL Server does not accept Windows credentials being passed as credentials.
			To connect as a different Windows user, run PowerShell as that user.
		.PARAMETER Destination
			Destination SQL Server. You must have sysadmin access and the server must be SQL Server XXXX or higher.
		.PARAMETER DestinationSqlCredential
			Allows you to login to servers using SQL Logins instead of Windows Authentication (AKA Integrated or Trusted). To use:
			$dcred = Get-Credential, then pass this $dcred to the -DestinationSqlCredential parameter.
			Windows Authentication will be used if DestinationSqlCredential is not specified. SQL Server does not accept Windows credentials being passed as credentials.
			To connect as a different Windows user, run PowerShell as that user.
		.PARAMETER WhatIf
			If this switch is enabled, no actions are performed but informational messages will be displayed that explain what would happen if the command were to run.
		.PARAMETER Confirm
			If this switch is enabled, you will be prompted for confirmation before executing any operations that change state.
		.PARAMETER Force
			If this switch is enabled, the Noun will be dropped and recreated on Destination.
		.PARAMETER EnableException
			By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
			This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
			Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.
		.NOTES
            Tags: TAGS_HERE 
            Author: Your name (@TwitterHandle)
            Website: https://dbatools.io
            Copyright: (C) Chrissy LeMaire, clemaire@gmail.com
			License: GNU GPL v3 https://opensource.org/licenses/GPL-3.0
			
			Feature Request
			Issue #2655
			The purpose of Export-DbaDetails is to export an entire instance of SQL Server to a file. This is useful for source control purposes or even "dataless" migration purposes.

			Problem to solve
			Ability to create a dataless export of a SQL Server instance or instances for source control or migration purposes

		.LINK
			https://dbatools.io/Copy-Noun
		.EXAMPLE
			Copy-Noun -Source sqlserver2014a -Destination sqlcluster
			Copies all Nouns from sqlserver2014a to sqlcluster using Windows credentials. If Nouns with the same name exist on sqlcluster, they will be skipped.
		.EXAMPLE
			Copy-Noun -Source sqlserver2014a -Destination sqlcluster -Noun SqlNoun -SourceSqlCredential $cred -Force
			Copies a single Noun (SqlNoun) from sqlserver2014a to sqlcluster using SQL credentials for sqlserver2014a and Windows credentials for sqlcluster. If a alert with the same name exists on sqlcluster, it will be dropped and recreated because -Force was used.
		.EXAMPLE
			Copy-Noun -Source sqlserver2014a -Destination sqlcluster -WhatIf -Force
			Shows what would happen if the command were executed using force.
	#>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [object[]]$InputObject,
        [Alias("ScriptingOptionObject")]
		[Microsoft.SqlServer.Management.Smo.ScriptingOptions]$ScriptingOptionsObject,
		[string]$Path,
		[ValidateSet('ASCII', 'BigEndianUnicode', 'Byte', 'String', 'Unicode', 'UTF7', 'UTF8', 'Unknown')]
		[string]$Encoding = 'UTF8',
		[switch]$Passthru,
		[switch]$NoClobber,
		[switch]$Append,
		[switch][Alias('Silent')]$EnableException
    )

    begin {
		$executingUser = [Security.Principal.WindowsIdentity]::GetCurrent().Name
		$commandName = $MyInvocation.MyCommand.Name
		$timeNow = (Get-Date -uformat "%m%d%Y%H%M%S")
		$prefixArray = @()
	}

	process {
		foreach ($object in $InputObject) {

			$typename = $object.GetType().ToString()

			if ($typename.StartsWith('Microsoft.SqlServer.')) {
				$shortype = $typename.Split(".")[-1]
			}
			else {
				Stop-Function -Message "InputObject is of type $typename which is not a SQL Management Object. Only SMO objects are supported." -Category InvalidData -Target $object -Continue
			}

			if ($shortype -in "LinkedServer", "Credential", "Login") {
				Write-Message -Level Warning -Message "Support for $shortype is limited at this time. No passwords, hashed or otherwise, will be exported if they exist."
			}

			# Just gotta add the stuff that Nic Cain added to his script

			if ($shortype -eq "Configuration") {
				Write-Message -Level Warning -Message "Support for $shortype is limited at this time."
			}

			# Find the server object to pass on to the function
			$parent = $object.parent

			do {
				if ($parent.Urn.Type -ne "Server") {
					$parent = $parent.Parent
				}
			}
			until (($parent.Urn.Type -eq "Server") -or (-not $parent))

			if (-not $parent) {
				Stop-Function -Message "Failed to find valid SMO server object in input: $object." -Category InvalidData -Target $object -Continue
			}

			$server = $parent
			$serverName = $server.Name.Replace('\', '$')

			if ($ScriptingOptionsObject) {
				$scripter = New-Object Microsoft.SqlServer.Management.Smo.Scripter $server
				$scripter.Options = $ScriptingOptionsObject
			}

			if (!$passthru) {
				if ($path) {
					$actualPath = $path
				}
				else {
					$actualPath = "$serverName-$shortype-Export-$timeNow.sql"
				}
			}

			$prefix = "/*`n`tCreated by $executingUser using dbatools $commandName for objects on $serverName at $(Get-Date)`n`tSee https://dbatools.io/$commandName for more information`n*/"

			if ($passthru) {
				$prefix | Out-String
			}
			else {
				if ($prefixArray -notcontains $actualPath) {

					if ((Test-Path -Path $actualPath) -and $NoClobber){
						Stop-Function -Message "File already exists. If you want to overwrite it remove the -NoClobber parameter. If you want to append data, please Use -Append parameter." -Target $actualPath -Continue
					}
					#Only at the first output we use the passed variables Append & NoClobber. For this execution the next ones need to buse -Append
					$prefix | Out-File -FilePath $actualPath -Encoding $encoding -Append:$Append -NoClobber:$NoClobber
					$prefixArray += $actualPath
				}
			}

			if ($Pscmdlet.ShouldProcess($env:computername, "Exporting $object from $server to $actualPath")) {
				Write-Message -Level Verbose -Message "Exporting $object"

				if ($passthru) {
					if ($ScriptingOptionsObject) {
						foreach ($script in $scripter.EnumScript($object)) {
							$script | Out-String
						}
					}
					else {
						$object.Script() | Out-String
					}
				}
				else {
					if ($ScriptingOptionsObject) {
						foreach ($script in $scripter.EnumScript($object)) {
							$script | Out-File -FilePath $actualPath -Encoding $encoding -Append
						}
					}
					else {
						$object.Script() | Out-File -FilePath $actualPath -Encoding $encoding -Append
					}
				}
			}

			if (!$passthru) {
				Write-Message -Level Output -Message "Exported $object on $server to $actualPath"
			}
		}
	}

    
}
