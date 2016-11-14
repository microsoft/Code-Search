[CmdletBinding()]
Param(
    [Parameter(Mandatory=$True, Position=0, HelpMessage="The Server Instance against which the script is to run.")]
    [string]$SQLServerInstance,

    [Parameter(Mandatory=$True, Position=1, HelpMessage="Configuration DB")]
    [string]$ConfigurationDatabaseName
)
[System.ENVIRONMENT]::CurrentDirectory = $PWD
Push-Location

$moduleCheck = Get-Module -List SQLPS
if($moduleCheck)
{
	Import-Module -Name SQLPS -DisableNameChecking
}
else
{
	Write-Error "Cannot load module SQLPS. Please try from a machine running SQL Server 2012 or higher."
    Pop-Location
	exit
}

Invoke-Sqlcmd -InputFile "$PWD\SqlScripts\StartSearchIndexing.sql" -serverInstance $SQLServerInstance -database $ConfigurationDatabaseName
Write-Host "Indexing has been resumed!!" -ForegroundColor Green
Pop-Location