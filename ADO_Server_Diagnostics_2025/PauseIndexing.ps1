# Azure DevOps Server 2025 - Elasticsearch 8.14
# Script to pause indexing operations for Azure DevOps Server 2025
#
# PURPOSE: Temporarily stops indexing operations for maintenance, troubleshooting, or performance reasons.
#          Use this before performing maintenance on Elasticsearch or during high-load periods.
#
# USAGE: .\PauseIndexing.ps1 -SQLServerInstance <server> -ConfigurationDatabaseName <config_db> [-EntityType <type>]
#
# EXAMPLES:
#   .\PauseIndexing.ps1 -SQLServerInstance "." -ConfigurationDatabaseName "AzureDevOps_Configuration"
#   .\PauseIndexing.ps1 -SQLServerInstance "MYSERVER" -ConfigurationDatabaseName "AzureDevOps_Configuration" -EntityType "Code"
#
# NOTE: Remember to run ResumeIndexing.ps1 after maintenance is complete.
#
[CmdletBinding()]
Param(
    [Parameter(Mandatory=$True, Position=0, HelpMessage="SQL Server instance name (e.g., '.', 'ServerName', 'ServerName\InstanceName')")]
    [string]$SQLServerInstance,

    [Parameter(Mandatory=$True, Position=1, HelpMessage="Configuration database name (usually 'AzureDevOps_Configuration')")]
    [string]$ConfigurationDatabaseName,
    
    [Parameter(Mandatory=$False, Position=2, HelpMessage="Entity type to pause: All (default), Code, WorkItem, or Wiki")]
    [ValidateSet("All", "Code", "WorkItem", "Wiki")]
    [string]$EntityType = "All"
)

function ImportSQLModule
{
    $moduleCheck = Get-Module -List SQLPS
    if($moduleCheck)
    {
	    Import-Module -Name SQLPS -DisableNameChecking
        Write-Host "Loaded SQLPS module..." -ForegroundColor Green
    }
    else
    {
	    Write-Error "Cannot load module SQLPS. Please try from a machine running SQL Server 2012 or higher."
        Pop-Location
	    exit
    }
}

function PauseCodeIndexing
{
    $SqlFullPath = Join-Path $PWD -ChildPath 'SqlScripts\PauseCodeIndexing.sql'
    Invoke-Sqlcmd -InputFile $SqlFullPath -serverInstance $SQLServerInstance -database $ConfigurationDatabaseName  
}

function PauseWorkItemIndexing
{
    $SqlFullPath = Join-Path $PWD -ChildPath 'SqlScripts\PauseWorkItemIndexing.sql'
    Invoke-Sqlcmd -InputFile $SqlFullPath -serverInstance $SQLServerInstance -database $ConfigurationDatabaseName  
}

function PauseWikiIndexing
{
    $SqlFullPath = Join-Path $PWD -ChildPath 'SqlScripts\PauseWikiIndexing.sql'
    Invoke-Sqlcmd -InputFile $SqlFullPath -serverInstance $SQLServerInstance -database $ConfigurationDatabaseName  
}

Write-Host "This would pause indexing for all the collections. Do you want to continue - Yes or No? " -NoNewline -ForegroundColor Magenta
$userInput = Read-Host

if($userInput -like "Yes")
{
    [System.ENVIRONMENT]::CurrentDirectory = $PWD
    Push-Location
    ImportSQLModule

    switch ($EntityType)
    {
        "All" 
            {
                Write-Host "Pausing indexing for Code, WorkItem and Wiki..." -ForegroundColor Green
                PauseCodeIndexing
                PauseWorkItemIndexing
                PauseWikiIndexing
                Write-Host "Code, WorkItem and Wiki Indexing has been paused!! Run ResumeIndexing.ps1 to resume indexing." -ForegroundColor Green
            }
        "WorkItem" 
            {
                Write-Host "Pausing indexing for WorkItem..." -ForegroundColor Green
                PauseWorkItemIndexing
                Write-Host "WorkItem Indexing has been paused!! Run ResumeIndexing.ps1 to resume indexing." -ForegroundColor Green
            }
        "Code"
            {
                Write-Host "Pausing indexing for Code..." -ForegroundColor Green
                PauseCodeIndexing
                Write-Host "Code Indexing has been paused!! Run ResumeIndexing.ps1 to resume indexing." -ForegroundColor Green
            }
		"Wiki"
			{
                Write-Host "Pausing indexing for Wiki..." -ForegroundColor Green
                PauseWikiIndexing
                Write-Host "Wiki Indexing has been paused!! Run ResumeIndexing.ps1 to resume indexing." -ForegroundColor Green
			}
        default 
            {
                Write-Host "Enter a valid EntityType i.e. Code, WorkItem, Wiki or All" -ForegroundColor Red
            }
    }

    Pop-Location
}
else
{
    Write-Warning "Exiting! Indexing was not paused." -ForegroundColor Cyan
}