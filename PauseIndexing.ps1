[CmdletBinding()]
Param(
    [Parameter(Mandatory=$True, Position=0, HelpMessage="The Server Instance against which the script is to run.")]
    [string]$SQLServerInstance,

    [Parameter(Mandatory=$True, Position=1, HelpMessage="Configuration DB")]
    [string]$ConfigurationDatabaseName,

    [Parameter(Mandatory=$False, Position=2, HelpMessage="Pause Indexing for Code, WorkItem or All.")]
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
                Write-Host "Pausing indexing for Code and WorkItem..." -ForegroundColor Green
                PauseCodeIndexing
                PauseWorkItemIndexing
                Write-Host "Code and WorkItem Indexing has been paused!! Run ResumeIndexing.ps1 to resume indexing." -ForegroundColor Green
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
        default
            {
                Write-Host "Enter a valid EntityType i.e. Code or WorkItem or All" -ForegroundColor Red
            }
    }

    Pop-Location
}
else
{
    Write-Warning "Exiting! Indexing was not paused." -ForegroundColor Cyan
}
