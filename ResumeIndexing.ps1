[CmdletBinding()]
Param(
    [Parameter(Mandatory=$True, Position=0, HelpMessage="The Server Instance against which the script is to run.")]
    [string]$SQLServerInstance,

    [Parameter(Mandatory=$True, Position=1, HelpMessage="Configuration DB")]
    [string]$ConfigurationDatabaseName,

    [Parameter(Mandatory=$False, Position=2, HelpMessage="Resume Indexing for Code, WorkItem or All")]
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
            Write-Host "Resuming indexing for Code and WorkItem..." -ForegroundColor Green
            ResumeCodeIndexing
            ResumeWorkItemIndexing
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
    default
        {
            Write-Host "Enter a valid EntityType i.e. Code or WorkItem or All" -ForegroundColor Red
        }
}


Pop-Location
