[CmdletBinding()]
Param(
    [Parameter(Mandatory=$True, Position=0, HelpMessage="The SQL Server Instance against which the script is to run.")]
    [string]$SQLServerInstance,

    [Parameter(Mandatory=$True, Position=1, HelpMessage="Collection Database name.")]
    [string]$CollectionDatabaseName,

    [Parameter(Mandatory=$True, Position=2, HelpMessage="Configuration DB")]
    [string]$ConfigurationDatabaseName,

    [Parameter(Mandatory=$True, Position=3, HelpMessage="Enter the Collection Name here.")]
    [string]$CollectionName,

    [Parameter(Mandatory=$True, Position=4, HelpMessage="Enter the days since last indexing was triggered for this collection")]
    [string]$Days
)

Write-Host "Checking indexing state for last $Days days" -ForegroundColor Green

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

# Checking for valid Collection Name.
$queryResults = Invoke-Sqlcmd -Query "Select HostID from [dbo].[tbl_ServiceHost] where Name = '$CollectionName'" -serverInstance $SQLServerInstance -database $ConfigurationDatabaseName  -Verbose

$CollectionID = $queryResults  | Select-object  -ExpandProperty  HOSTID

if(!$CollectionID)
{
    throw "Invalid Collection Name: '$CollectionName'"
}

# Validating if the collection has extension installed.
$isCollectionIndexed = Invoke-Sqlcmd -Query "Select RegValue from tbl_RegistryItems where ChildItem like '%IsCollectionIndexed%' and PartitionId > 0" -ServerInstance $SQLServerInstance -Database $CollectionDatabaseName

if($isCollectionIndexed.RegValue -eq "True")
{
    $Params = "CollectionId='$CollectionID'"
    $indexingCompletedQueryParams = "DaysAgo='$Days'","CollectionId='$CollectionID'"

    # Gets the count of repositories for which fresh indexing has completed.
    $SqlFullPath = Join-Path $PWD -ChildPath 'SqlScripts\BulkIndexingActivity.sql'
    $queryResults = Invoke-Sqlcmd -InputFile $SqlFullPath -serverInstance $SQLServerInstance -database $ConfigurationDatabaseName -Variable $indexingCompletedQueryParams
    $bulkIndexingCompletedRepositoryCount = $queryResults  | Select-object  -ExpandProperty  BulkIndexingCompletedCount

    if($bulkIndexingCompletedRepositoryCount -gt 0)
    {
        Write-Host "Repositories completed fresh indexing: '$bulkIndexingCompletedRepositoryCount'" -ForegroundColor Yellow
    }
    else
    {
        Write-Host "No repositories completed fresh indexing in this collection in last $Days days" -ForegroundColor Cyan
    }

    # Gets the count of repositories for which fresh indexing is InProgress.
    $SqlFullPath = Join-Path $PWD -ChildPath 'SqlScripts\BulkIndexingInProgressActivity.sql'
    $queryResults = Invoke-Sqlcmd -InputFile $SqlFullPath -serverInstance $SQLServerInstance -database $CollectionDatabaseName
    $bulkIndexingInProgressRepositoryCount = $queryResults  | Select-object  -ExpandProperty  BulkIndexingInProgressCount

    if($bulkIndexingInProgressRepositoryCount -gt 0)
    {
        Write-Host "Count of repositories with fresh indexing IN PROGRESS: '$bulkIndexingInProgressRepositoryCount'" -ForegroundColor Yellow
    }
    else
    {
        Write-Host "No repositories with fresh Indexing in progress" -ForegroundColor Cyan
    }


     # Gets the count of repositories for which continuous indexing has completed.
    $SqlFullPath = Join-Path $PWD -ChildPath 'SqlScripts\ContinuousIndexingActivity.sql'
    $queryResults = Invoke-Sqlcmd -InputFile $SqlFullPath -serverInstance $SQLServerInstance -database $ConfigurationDatabaseName -Variable $indexingCompletedQueryParams
    $continuousIndexingCompletedRepositoryCount = $queryResults  | Select-object  -ExpandProperty  ContinuousIndexingCompletedCount

    if($continuousIndexingCompletedRepositoryCount -gt 0)
    {
        Write-Host "Repositories completed continuous indexing: '$continuousIndexingCompletedRepositoryCount'" -ForegroundColor Yellow
    }
    else
    {
        Write-Host "No repositories completed continuous indexing in this collection in last $Days days" -ForegroundColor Cyan
    }

    # Gets the count of repositories for which continuous indexing is InProgress.
    $SqlFullPath = Join-Path $PWD -ChildPath 'SqlScripts\ContinuousIndexingInProgressActivity.sql'
    $queryResults = Invoke-Sqlcmd -InputFile $SqlFullPath -serverInstance $SQLServerInstance -database $CollectionDatabaseName
    $continuousIndexingInProgressRepositoryCount = $queryResults  | Select-object  -ExpandProperty  ContinuousIndexingInProgressCount

    if($continuousIndexingInProgressRepositoryCount -gt 0)
    {
        Write-Host "Count of repositories with continuous indexing IN PROGRESS: '$continuousIndexingInProgressRepositoryCount'" -ForegroundColor Yellow
    }
    else
    {
        Write-Host "No repositories with Continuous Indexing in progress" -ForegroundColor Cyan
    }

    # Gets the count of Failed Indexing jobs.
    $SqlFullPath = Join-Path $PWD -ChildPath 'SqlScripts\FailedIndexingActivity.sql'
    $queryResults = Invoke-Sqlcmd -InputFile $SqlFullPath -serverInstance $SQLServerInstance -database $ConfigurationDatabaseName -Variable $indexingCompletedQueryParams
    $failedIndexingJobsCount = $queryResults  | Select-object  -ExpandProperty  FailedIndexingCount

    if($failedIndexingJobsCount -gt 0)
    {
        Write-Host "Count of indexing jobs failed: '$failedIndexingJobsCount'" -ForegroundColor Yellow
    }
    else
    {
        Write-Host "No indexing jobs failed" -ForegroundColor Cyan
    }
}
else
{
    Write-Host "The extension is disabled for this account. Install the extension and then try again." -ForegroundColor DarkYellow
}

Pop-Location
