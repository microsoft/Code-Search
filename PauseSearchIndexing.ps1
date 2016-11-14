[CmdletBinding()]
Param(
    [Parameter(Mandatory=$True, Position=0, HelpMessage="The Server Instance against which the script is to run.")]
    [string]$SQLServerInstance,

    [Parameter(Mandatory=$True, Position=1, HelpMessage="Configuration DB")]
    [string]$ConfigurationDatabaseName
)

Write-Host "This would pause indexing for all the collections. Do you want to continue - Yes or No? " -NoNewline -ForegroundColor Magenta
$userInput = Read-Host

if($userInput -like "Yes")
{
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

    Invoke-Sqlcmd -InputFile "$PWD\SqlScripts\PauseSearchIndexing.sql" -serverInstance $SQLServerInstance -database $ConfigurationDatabaseName  
    Write-Host "Indexing has been paused!! Run ResumeSearchIndexing.ps1 to resume indexing." -ForegroundColor Green
    Pop-Location
}
else
{
    Write-Warning "Exiting! Indexing was not paused." -ForegroundColor Cyan
}