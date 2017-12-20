[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | Out-Null
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SmoExtended") | Out-Null

Function Get-LastBackupFile {
    Param(
        [string]$server,
        [string]$database
    )
    
    $qry = @"
DECLARE @dbname sysname 
SET @dbname = '$database'
SELECT  f.physical_device_name as [backup]
FROM    msdb.dbo.backupset AS s WITH (nolock) INNER JOIN
            msdb.dbo.backupmediafamily AS f WITH (nolock) ON s.media_set_id = f.media_set_id
WHERE   (s.database_name = @dbname) AND (s.type = 'D') AND (f.device_type <> 7) 
        AND (s.backup_finish_date = (SELECT MAX(backup_finish_date)
FROM         msdb.dbo.backupset WITH (nolock)
WHERE     (database_name = @dbname) AND (type = 'D') AND (is_snapshot = 0)))
"@
 
    # Get an SMO Connection
    $smo = New-Object ('Microsoft.SqlServer.Management.Smo.Server') $server
    # most appropriate to use MSDB
    $db = $smo.Databases["msdb"]
    # Execute query with results
    $rs = $db.ExecuteWithResults($qry)
    # SMO connection is no longer needed
    $smo.ConnectionContext.Disconnect()
    # Return the result
    $rs.Tables[0].Rows[0].Item('backup')|Out-String
}

## Path to Text File with list of Servers

$ServerList = Get-Content "C:\temp\Serverlist.txt"
Write-Host "Number of Servers Listed: " $ServerList.Count -ForegroundColor Yellow

## Path to Output file 

$RootPath = "C:\temp"
$HTMLPath = $RootPath + "\Output_$(Get-Date -Format "yyyymmmdd_hh-mm-ss").htm" 
$CSVPath = $RootPath + "\Output_$(Get-Date -Format "yyyymmmdd_hh-mm-ss").csv" 
$FailPath = $RootPath + "\Failure_$(Get-Date -Format "yyyymmmdd_hh-mm-ss").txt"

$ResultCSV = @()
$Failures = @()

## Generate HTML Table Formatting
 
$HTML = '<style type="text/css"> 
    #Header{font-family:"Trebuchet MS", Arial, Helvetica, sans-serif;width:100%;border-collapse:collapse;} 
    #Header td, #Header th {font-size:14px;border:1px solid #98bf21;padding:3px 7px 2px 7px;} 
    #Header th {font-size:14px;text-align:left;padding-top:5px;padding-bottom:4px;background-color:#A7C942;color:#fff;} 
    #Header tr.alt td {color:#000;background-color:#EAF2D3;} 
    </Style>' 

## Generate HTML Column Headers

$HTML += "<HTML><BODY><Table border=1 cellpadding=0 cellspacing=0 width=100% id=Header> 
        <TR> 
            <TH><B>Database Name</B></TH> 
            <TH><B>RecoveryModel</B></TH> 
            <TH><B>Last Full Backup Date</B></TH>
            <TH><B>Backup File</B></TH>  
            <TH><B>Last Differential Backup Date</B></TH> 
            <TH><B>Last Log Backup Date</B></TH> 
        </TR>" 
 
 ## Load SQL Management Objects Assembly



## Iterate Each Server through the Server list

ForEach ($ServerName in $ServerList) 
{ 
    $HTML += "<TR bgColor='#ccff66'><TD colspan=6 align=center><B>$ServerName</B></TD></TR>" 
     
    $SQLServer = New-Object ('Microsoft.SqlServer.Management.Smo.Server') $ServerName  

    ## Check Server Status

    If($SQLServer.Status -eq 'Online') 
    {
        Foreach($Database in $SQLServer.Databases) 
        { 
            ## Get Backup File Information
            $BackupFile = $null
            try
            {
                $BackupFile = Get-LastBackupFile -server $ServerName.ToString() -database $Database.Name
            }
            Catch
            {
                $BackupFile = "NA"
            }

            If($Database.LastBackupDate -eq '01/01/0001 00:00:00')
            {
                $DBLastFullDate = "No Backup Available"
                $DBLastDiffDate = "NA"
            }
            else
            {
                $DBLastFullDate = $Database.LastBackupDate
                $DBLastDiffDate = $Database.LastDifferentialBackupDate
                If($Database.LastDifferentialBackupDate -eq '01/01/0001 00:00:00')
                {
                    $DBLastDiffDate = "No Diff Backup taken"
                }
            }
            
            If($Database.LastLogBackupDate -eq '01/01/0001 00:00:00')
            {
                $DBLastLogDate = "NA"
            }
            else
            {
                $DBLastLogDate = $Database.LastLogBackupDate
            }

            If($Database.RecoveryModel -eq 'SIMPLE')
            {
                
                $HTML += "<TR> 
                            <TD>$($Database.Name)</TD> 
                            <TD>$($Database.RecoveryModel)</TD> 
                            <TD>$DBLastFullDate</TD>
                            <TD>$BackupFile</TD> 
                            <TD>$DBLastDiffDate</TD> 
                            <TD>$DBLastLogDate</TD> 
                        </TR>" 
            }
            else
            {
                $HTML += "<TR> 
                            <TD>$($Database.Name)</TD> 
                            <TD>$($Database.RecoveryModel)</TD> 
                            <TD>$DBLastFullDate</TD>
                            <TD>$BackupFile</TD>  
                            <TD>$DBLastDiffDate</TD> 
                            <TD>$DBLastLogDate</TD> 
                        </TR>" 
            }
        
            $CSV = @{

            Server = $ServerName
            DatabaseName = $Database.Name
            RecoveryModel = $Database.RecoveryModel
            LastFullBackup = $DBLastFullDate
            BackupFile = $BackupFile
            LastDiffBackup = $DBLastDiffDate
            LastLogBackup = $DBLastLogDate
        
            }
        $ResultCSV += New-Object psobject -Property $CSV       
        }
    }
    else ## Server Unable to Connect
    {
        $HTML += "<TR> 
                    <TD colspan=6 align=center style='background-color:red'><B>Unable to Connect to SQL Server</B></TD> 
                  </TR>" 
        $FailureServer = @{
        ServerName = $ServerName
        Message = "Connection Failed"
        }

        $Failures += New-Object psobject -Property $FailureServer
    }    
    
    

} 
$HTML += "</Table></BODY></HTML>" 
$HTML | Out-File $HTMLPath
 
$ResultCSV | Select-Object Server, DatabaseName, RecoveryModel, LastFullBackup, BackupFile, LastDiffBackup, LastLogBackup | Export-Csv -notypeinformation -Path $CSVPath
$Failures | Select-Object ServerName, Message | Out-File $FailPath

Write-Host "Output File Successfully Generated: " $HTMLPath -ForegroundColor Yellow
Write-Host "Output File Successfully Generated: " $CSVPath -ForegroundColor Yellow

## Send Mail
Send-MailMessage -to "<EmailID>" -from "BackupReport@hpe.com" -Subject "Backup Report" -SmtpServer "<SMTPHost>" -Attachments $HTMLPath, $FailPath, $CSVPath
