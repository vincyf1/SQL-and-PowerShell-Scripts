function Export-DbaDetails {
<#
.SYNOPSIS
PowerShell Cmdlet to Export entire SQL Instance Details into an output file.

.DESCRIPTION
Long description

.EXAMPLE
An example

.NOTES
General notes
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