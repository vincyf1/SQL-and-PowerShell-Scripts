# Embed PowerShell code in a batch file
# Source Link: https://blogs.technet.microsoft.com/pstips/2018/01/25/embed-powershell-code-in-a-batch-file/


@@ECHO off
@@setlocal EnableDelayedExpansion
@@set LF=^


@@SET command=#
@@FOR /F "tokens=*" %%i in ('findstr -bv @@ "%~f0"') DO SET command=!command!!LF!%%i
@@powershell -noprofile -noexit -command !command! & goto:eof


# *** POWERSHELL CODE STARTS HERE *** #
Write-Host 'This is PowerShell code being run from inside a batch file!' -Fore red
$PSVersionTable
Get-Process -Id $PID | Format-Table
