# CiTriX published Applications Report
#   Patrice Afriat - pafriat@gmail.com

# v1.1 - nov. 17 2016


# You are free to use this script in your environment but please e-mail me any improvements.

# Change log:
# v1.1 script constants changed into input parameters
# v1.0 first release

[CmdletBinding()]
param (
	[string]$server="your_XA_server_name",
	[string]$delim=";",
	[string]$outputfile=".\CitrixPublishedAppReport.csv",
	[string]$version="1.1, "+(Get-Item ($MyInvocation.MyCommand.Definition)).LastWriteTime
)

begin {
    # Enter-PSSession can only be used interactively, you can't use it in a script
    Function CanRemote ($srv) {
        Try {
            $s = New-PSSession $srv -Name "Test" -ErrorAction Stop
            Write-Host "Remote test succeeded: $srv." -ForegroundColor Green
            $true
            Remove-PSSession $s
            }
        Catch {
            Write-Host "Remote test failed: $srv." -ForegroundColor Red
            $false
        }
    }

    Clear
    Write-Host ("`n| Citrix published applications extraction`n|`n|`tscript v"+$version+"`n|`n|`tremote server: $server`n|`toutput file  : $outputfile")
    Write-Host "`n`no Attempting to connect to $server with PowerShell remoting..."
    if (CanRemote $server) { New-PSSession -ComputerName $server } else { Write-Host "`nExiting script.`n" ; exit }
    Write-host "`n"
    
	# loading snappins
	# ----------------

	if (Get-PSSnapin Citrix.Common.Commands -ea 0)
	{
			Write-Host "Citrix.Common.Commands snapin already loaded" -ForegroundColor Yellow
	}
	else
	{
			Write-Host "Loading Citrix.Common.Commands snapin..." -ForegroundColor Yellow
			Add-PSSnapIn Citrix.Common.Commands
	}

	# If the snap-in is registered (i.e. this is a XenApp server), then load it
	if (Get-PSSnapin Citrix.XenApp.Commands -ea 0)
	{
			Write-Host "Citrix.XenApp.Commands snapin already loaded" -ForegroundColor Yellow
	}
	else
	{
			if (Get-PSSnapIn "Citrix.XenApp.Commands" -registered -ea 0)
			{
					Write-Host "Loading Citrix.XenApp.Commands snapin..." -ForegroundColor Yellow
					Add-PSSnapin "Citrix.XenApp.Commands"
			}
	}

	if (Get-PSSnapin Citrix.Common.GroupPolicy -ea 0)
	{
			Write-Host "Citrix.Common.GroupPolicy snapin already loaded" -ForegroundColor Yellow
	}
	else
	{
			Write-Host "Loading Citrix.Common.GroupPolicy snapin..." -ForegroundColor Yellow
			Add-PSSnapIn Citrix.Common.GroupPolicy
	}

    # --- list of properties to extract
	$prop=(
	'ApplicationType',
	'DisplayName',
	'Description',
	'FolderPath',
	'BrowserName',
	'Enabled',
	'HideWhenDisabled',
	'CommandLineExecutable',
	'WorkingDirectory',
	'ClientFolder',
	'WindowType',
	'ColorDepth',
	'TitleBarHidden',
	'MaximizedOnStartup',
	'DefinedAccounts')

}


process {

    # output file initialisation
    # --------------------------

    Write-Host "`no Deleting output file: $outputfile - please close it if already open" -NoNewline
    if (Test-Path $outputfile) {
        do { 
            Write-Host "." -NoNewline 
            Start-Sleep -Milliseconds 500
            Remove-Item $outputfile -ErrorAction SilentlyContinue 
        } until ($?)
    }
	
    # --- generating the CSV header from properties list
    $temp="WorkerGroup;"
    for ($p = 0; $p -lt $prop.count; $p++) {
        $temp+=$prop[$p]+$delim*($p -lt $prop.count-1)
    
    }
    $temp | Out-file -FilePath $outputfile -Encoding Default
    
    # output file generation
    # ----------------------
    
    Get-XAWorkerGroup -ComputerName $server | sort WorkerGroupName | foreach {

        $workergrp=$_.WorkerGroupName
        
        # --- retrieving application list
        $applist=(Get-XAWorkerGroup $workergrp -ComputerName $server | Select WorkerGroupName | Get-XAApplication -ComputerName $server | sort FolderPath, DisplayName)

        Write-host "`n`no Application report for workergroup $workergrp :`n"
        for ($i = 0; $i -lt $applist.count; $i++) {
            $temp="$workergrp;"
            # --- retrieving properties of the current application
            for ($p = 0; $p -lt $prop.count; $p++) {
                $temp+=""+$applist[$i].($prop[$p])+$delim*($p -lt $prop.count-1)
            }
            # --- retrieving accounts of the current application
            $accounts=(Get-XAApplicationReport -ComputerName $server -BrowserName $applist[$i].($prop[4])).Accounts.AccountName
            if ($accounts.count) {
                $accounts | Sort | foreach {
                    $temp+$_ | Out-file -FilePath $outputfile -Encoding Default -Append
                }
            }
            else {
                $temp+"[N/A]" | Out-file -FilePath $outputfile -Encoding Default -Append
            }
            Write-host ("`to "+($applist[$i].BrowserName))
        }

    }
	    
 }


end {
    Write-Host "`n`nO End of script - closing session to $server."
    Remove-PSSession -ComputerName $server
}