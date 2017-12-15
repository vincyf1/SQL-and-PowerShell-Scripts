## Path to Text File with list of Servers

$ServerList = Get-Content "C:\temp\Serverlist.txt"
Write-Host "Number of Servers Listed: " $ServerList.Count -ForegroundColor Yellow

## Path to Output file 

$OutputFile = "C:\temp\Output.htm" 

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
            <TH><B>RecoveryModel</B></TD> 
            <TH><B>Last Full Backup Date</B></TH> 
            <TH><B>Last Differential Backup Date</B></TH> 
            <TH><B>Last Log Backup Date</B></TH> 
        </TR>" 
 
 ## Load SQL Management Objects Assembly

[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | Out-Null 

## Iterate Each Server through the Server list

ForEach ($ServerName in $ServerList) 
{ 
    $HTML += "<TR bgColor='#ccff66'><TD colspan=5 align=center><B>$ServerName</B></TD></TR>" 
     
    $SQLServer = New-Object ('Microsoft.SqlServer.Management.Smo.Server') $ServerName  

    ## Check Server Status

    If($SQLServer.Status -eq 'Online') 
    {
        Foreach($Database in $SQLServer.Databases) 
        { 

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
                            <TD>$DBLastDiffDate</TD> 
                            <TD>$DBLastLogDate</TD> 
                        </TR>" 
            }
        }

               
    }
    else ## Server Unable to Connect
    {
        $HTML += "<TR> 
                    <TD colspan=5 align=center style='background-color:red'><B>Unable to Connect to SQL Server</B></TD> 
                  </TR>" 
    
    }    
} 
$HTML += "</Table></BODY></HTML>" 
$HTML | Out-File $OutputFile

Write-Host "Output File Successfully Generated: " $OutputFile -ForegroundColor Yellow
###############################################################
## ENHANCEMENTS TO-DO
## 1. Generate CSV File
## 2. Send Mail Functionality
## 3. Color Code Backups Older than 2 \ 7 \ 30 Days? 
## 4. Addition of Corresponding Backup Paths 
## 5. Scheduling via Windows Task Scheduler as a batch file
###############################################################
