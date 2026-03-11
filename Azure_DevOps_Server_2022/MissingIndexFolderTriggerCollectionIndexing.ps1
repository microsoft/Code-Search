[CmdletBinding()]
Param(
    [Parameter(Mandatory=$True, Position=0, HelpMessage="The Server Instance against which the script is to run.")]
    [string]$SQLServerInstance,
   
    [Parameter(Mandatory=$True, Position=1, HelpMessage="Collection Database name.")]
    [string]$CollectionDatabaseName,
    
    [Parameter(Mandatory=$True, Position=2, HelpMessage="Configuration DB")]
    [string]$ConfigurationDatabaseName,
   
    [Parameter(Mandatory=$True, Position=3, HelpMessage="Enter the Collection Name here.")]
    [string]$CollectionName,

    [Parameter(Mandatory=$False)]
    [switch]$TrustServerCertificate
)
$trustCertParam = if ($TrustServerCertificate) { @{TrustServerCertificate = $true} } else { @{} }

Import-Module .\Common.psm1 -Force

function CleanUpIndexingState
{
    $trustCertParam = if ($TrustServerCertificate) { @{TrustServerCertificate = $true} } else { @{} }
    $SqlFullPath = Join-Path $PWD -ChildPath 'SqlScripts\CleanUpCollectionIndexingState_IndexDelete.sql'
    Invoke-Sqlcmd -InputFile $SqlFullPath -serverInstance $SQLServerInstance -database $CollectionDatabaseName @trustCertParam
    Write-Host "Cleaned up the Collection Indexing state..." -ForegroundColor Yellow    
}

[System.ENVIRONMENT]::CurrentDirectory = $PWD
Push-Location
ImportSQLModule

$CollectionID = ValidateCollectionName $SQLServerInstance $ConfigurationDatabaseName $CollectionName -TrustServerCertificate:$TrustServerCertificate

CleanUpIndexingState

# Queue Collection code indexing job.
if(IsExtensionInstalled $SQLServerInstance $CollectionDatabaseName "IsCollectionIndexed" -TrustServerCertificate:$TrustServerCertificate)
{
    $Params = "CollectionId='$CollectionID'"

    $SqlFullPath = Join-Path $PWD -ChildPath 'SqlScripts\QueueCodeExtensionInstallIndexing.sql'
    Invoke-Sqlcmd -InputFile $SqlFullPath -serverInstance $SQLServerInstance -database $ConfigurationDatabaseName  -Verbose -Variable $Params @trustCertParam
    Write-Host "Successfully queued the Code Indexing job for the collection!!" -ForegroundColor Green
}
else
{
   Write-Host "No jobs queued. Please install the Code Search extension for the collection. You DON'T need to run indexing via script after extension is installed." -ForegroundColor DarkYellow
}

# Queue Collection workitem indexing job.
if(IsExtensionInstalled $SQLServerInstance $CollectionDatabaseName "IsCollectionIndexedForWorkItem" -TrustServerCertificate:$TrustServerCertificate)
{
    $Params = "CollectionId='$CollectionID'"

    $SqlFullPath = Join-Path $PWD -ChildPath 'SqlScripts\QueueWorkItemExtensionInstallIndexing.sql'
    Invoke-Sqlcmd -InputFile $SqlFullPath -serverInstance $SQLServerInstance -database $ConfigurationDatabaseName  -Verbose -Variable $Params @trustCertParam
    Write-Host "Successfully queued the WorkItem Indexing job for the collection!!" -ForegroundColor Green
}
else
{
   Write-Host "No jobs queued. Please install the WorkItem Search extension for the collection. You DON'T need to run indexing via script after extension is installed." -ForegroundColor DarkYellow
}

# Queue Collection wiki indexing job.
if(IsExtensionInstalled $SQLServerInstance $CollectionDatabaseName "IsCollectionIndexedForWiki" -TrustServerCertificate:$TrustServerCertificate)
{
    $Params = "CollectionId='$CollectionID'"

    $SqlFullPath = Join-Path $PWD -ChildPath 'SqlScripts\QueueWikiExtensionInstallIndexing.sql'
    Invoke-Sqlcmd -InputFile $SqlFullPath -serverInstance $SQLServerInstance -database $ConfigurationDatabaseName  -Verbose -Variable $Params @trustCertParam
    Write-Host "Successfully queued the Wiki Indexing job for the collection!!" -ForegroundColor Green
}
else
{
   Write-Host "No jobs queued. Please install the Wiki Search extension for the collection. You DON'T need to run indexing via script after extension is installed." -ForegroundColor DarkYellow
}

Pop-Location
