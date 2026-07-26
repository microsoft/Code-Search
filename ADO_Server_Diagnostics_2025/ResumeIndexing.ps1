# Azure DevOps Server 2025 - Elasticsearch 8.14
# Script to resume indexing operations for Azure DevOps Server 2025
#
# PURPOSE: Resumes indexing operations that were previously paused using PauseIndexing.ps1.
#          Use this after completing maintenance or troubleshooting activities.
#
# USAGE: .\ResumeIndexing.ps1 -SQLServerInstance <server> -ConfigurationDatabaseName <config_db> [-EntityType <type>]
#
# EXAMPLES:
#   .\ResumeIndexing.ps1 -SQLServerInstance "." -ConfigurationDatabaseName "AzureDevOps_Configuration"
#   .\ResumeIndexing.ps1 -SQLServerInstance "MYSERVER" -ConfigurationDatabaseName "AzureDevOps_Configuration" -EntityType "Code"
#
# NOTE: Only run this after you have completed maintenance and are ready to resume normal indexing operations.
#
[CmdletBinding()]
Param(
    [Parameter(Mandatory=$True, Position=0, HelpMessage="SQL Server instance name (e.g., '.', 'ServerName', 'ServerName\InstanceName')")]
    [string]$SQLServerInstance,

    [Parameter(Mandatory=$True, Position=1, HelpMessage="Configuration database name (usually 'AzureDevOps_Configuration')")]
    [string]$ConfigurationDatabaseName,
    
    [Parameter(Mandatory=$False, Position=2, HelpMessage="Entity type to resume: All (default), Code, WorkItem, or Wiki")]
    [ValidateSet("All", "Code", "WorkItem", "Wiki")]
    [string]$EntityType = "All"
)

function ResumeCodeIndexing
{
    $SqlFullPath = Join-Path $PWD -ChildPath 'SqlScripts\ResumeCodeIndexing.sql'
    Invoke-Sqlcmd -InputFile $SqlFullPath -serverInstance $SQLServerInstance -database $ConfigurationDatabaseName
    Write-Host "Code Indexing has been resumed!!" -ForegroundColor Green
}

function ResumeWorkItemIndexing
{
    $SqlFullPath = Join-Path $PWD -ChildPath 'SqlScripts\ResumeWorkItemIndexing.sql'
    Invoke-Sqlcmd -InputFile $SqlFullPath -serverInstance $SQLServerInstance -database $ConfigurationDatabaseName
    Write-Host "WorkItem Indexing has been resumed!!" -ForegroundColor Green
}

function ResumeWikiIndexing
{
    $SqlFullPath = Join-Path $PWD -ChildPath 'SqlScripts\ResumeWikiIndexing.sql'
    Invoke-Sqlcmd -InputFile $SqlFullPath -serverInstance $SQLServerInstance -database $ConfigurationDatabaseName
    Write-Host "Wiki Indexing has been resumed!!" -ForegroundColor Green
}

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

[System.ENVIRONMENT]::CurrentDirectory = $PWD
Push-Location
ImportSQLModule

switch ($EntityType)
{
    "All" 
        {
            Write-Host "Resuming indexing for Code, WorkItem and Wiki..." -ForegroundColor Green
            ResumeCodeIndexing
            ResumeWorkItemIndexing
            ResumeWikiIndexing
        }
    "WorkItem" 
        {
            Write-Host "Resuming indexing for WorkItem..." -ForegroundColor Green
            ResumeWorkItemIndexing
        }
    "Code"
        {
            Write-Host "Resuming indexing for Code..." -ForegroundColor Green
            ResumeCodeIndexing
        }
	"Wiki"
		{
            Write-Host "Resuming indexing for Wiki..." -ForegroundColor Green
            ResumeWikiIndexing
		}
    default 
        {
            Write-Host "Enter a valid EntityType i.e. Code, WorkItem, Wiki or All" -ForegroundColor Red
        }
}


Pop-Location