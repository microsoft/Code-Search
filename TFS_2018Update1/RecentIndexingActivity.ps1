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
    [string]$Days,
    
    [Parameter(Mandatory=$False, Position=5, HelpMessage="Trigger collection indexing for Code, WorkItem or All")]
    [string]$EntityType = "All"
)

function CodeIndexingActivity
{
    Write-Host "Code Indexing Stats:" -ForegroundColor Green

    if(IsExtensionInstalled $SQLServerInstance $CollectionDatabaseName "IsCollectionIndexed")
    {
        $Params = "CollectionId='$CollectionID'" 
        $indexingCompletedQueryParams = "DaysAgo='$Days'","CollectionId='$CollectionID'"

        # Gets the count of code repositories for which fresh indexing has completed.
        $SqlFullPath = Join-Path $PWD -ChildPath 'SqlScripts\CodeBulkIndexingActivity.sql'
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
        $SqlFullPath = Join-Path $PWD -ChildPath 'SqlScripts\CodeBulkIndexingInProgressActivity.sql'
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
        $SqlFullPath = Join-Path $PWD -ChildPath 'SqlScripts\CodeContinuousIndexingActivity.sql'
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
        $SqlFullPath = Join-Path $PWD -ChildPath 'SqlScripts\CodeContinuousIndexingInProgressActivity.sql'
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
        $SqlFullPath = Join-Path $PWD -ChildPath 'SqlScripts\CodeFailedIndexingActivity.sql'
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
        Write-Host "The Code Search extension is disabled for this account. Install the extension and then try again." -ForegroundColor DarkYellow
    } 
}

function WorkItemIndexingActivity
{
    Write-Host "WorkItem Indexing Stats:" -ForegroundColor Green

    if(IsExtensionInstalled $SQLServerInstance $CollectionDatabaseName "IsCollectionIndexedForWorkItem")
    {
        $Params = "CollectionId='$CollectionID'" 
        $indexingCompletedQueryParams = "DaysAgo='$Days'","CollectionId='$CollectionID'"

        # Gets the count of code repositories for which fresh indexing has completed.
        $SqlFullPath = Join-Path $PWD -ChildPath 'SqlScripts\WorkItemBulkIndexingActivity.sql'
        $queryResults = Invoke-Sqlcmd -InputFile $SqlFullPath -serverInstance $SQLServerInstance -database $ConfigurationDatabaseName -Variable $indexingCompletedQueryParams
        $bulkIndexingCompletedRepositoryCount = $queryResults  | Select-object  -ExpandProperty  BulkIndexingCompletedCount

        if($bulkIndexingCompletedRepositoryCount -gt 0)
        {
            Write-Host "Projects completed fresh indexing: '$bulkIndexingCompletedRepositoryCount'" -ForegroundColor Yellow
        }
        else
        {
            Write-Host "No projects completed fresh indexing in this collection in last $Days days" -ForegroundColor Cyan
        }

        # Gets the count of repositories for which fresh indexing is InProgress.
        $SqlFullPath = Join-Path $PWD -ChildPath 'SqlScripts\WorkItemBulkIndexingInProgressActivity.sql'
        $queryResults = Invoke-Sqlcmd -InputFile $SqlFullPath -serverInstance $SQLServerInstance -database $CollectionDatabaseName
        $bulkIndexingInProgressRepositoryCount = $queryResults  | Select-object  -ExpandProperty  BulkIndexingInProgressCount

        if($bulkIndexingInProgressRepositoryCount -gt 0)
        {
            Write-Host "Count of projects with fresh indexing IN PROGRESS: '$bulkIndexingInProgressRepositoryCount'" -ForegroundColor Yellow
        }
        else
        {
            Write-Host "No projects with fresh Indexing in progress" -ForegroundColor Cyan
        }


         # Gets the count of repositories for which continuous indexing has completed.
        $SqlFullPath = Join-Path $PWD -ChildPath 'SqlScripts\WorkItemContinuousIndexingActivity.sql'
        $queryResults = Invoke-Sqlcmd -InputFile $SqlFullPath -serverInstance $SQLServerInstance -database $ConfigurationDatabaseName -Variable $indexingCompletedQueryParams
        $continuousIndexingCompletedRepositoryCount = $queryResults  | Select-object  -ExpandProperty  ContinuousIndexingCompletedCount

        if($continuousIndexingCompletedRepositoryCount -gt 0)
        {
            Write-Host "Projects completed continuous indexing: '$continuousIndexingCompletedRepositoryCount'" -ForegroundColor Yellow
        }
        else
        {
            Write-Host "No projects completed continuous indexing in this collection in last $Days days" -ForegroundColor Cyan
        }

        # Gets the count of repositories for which continuous indexing is InProgress.
        $SqlFullPath = Join-Path $PWD -ChildPath 'SqlScripts\WorkItemContinuousIndexingInProgressActivity.sql'
        $queryResults = Invoke-Sqlcmd -InputFile $SqlFullPath -serverInstance $SQLServerInstance -database $CollectionDatabaseName
        $continuousIndexingInProgressRepositoryCount = $queryResults  | Select-object  -ExpandProperty  ContinuousIndexingInProgressCount

        if($continuousIndexingInProgressRepositoryCount -gt 0)
        {
            Write-Host "Count of projects with continuous indexing IN PROGRESS: '$continuousIndexingInProgressRepositoryCount'" -ForegroundColor Yellow
        }
        else
        {
            Write-Host "No projects with Continuous Indexing in progress" -ForegroundColor Cyan
        }

        # Gets the count of Failed Indexing jobs.
        $SqlFullPath = Join-Path $PWD -ChildPath 'SqlScripts\WorkItemFailedIndexingActivity.sql'
        $queryResults = Invoke-Sqlcmd -InputFile $SqlFullPath -serverInstance $SQLServerInstance -database $ConfigurationDatabaseName -Variable $indexingCompletedQueryParams
        $failedIndexingJobsCount = $queryResults  | Select-object  -ExpandProperty  FailedIndexingCount

        if($failedIndexingJobsCount -gt 0)
        {
            Write-Host "Count of workitem indexing jobs failed: '$failedIndexingJobsCount'" -ForegroundColor Yellow
        }
        else
        {
            Write-Host "No workitem indexing jobs failed" -ForegroundColor Cyan
        }
    }
    else
    {
        Write-Host "The WorkItem search extension is disabled for this account. Install the extension and then try again." -ForegroundColor DarkYellow
    } 
}

Import-Module .\Common.psm1 -Force
Write-Host "Checking indexing state for last $Days days" -ForegroundColor Green

[System.ENVIRONMENT]::CurrentDirectory = $PWD
Push-Location
ImportSQLModule

$CollectionID = ValidateCollectionName $SQLServerInstance $ConfigurationDatabaseName $CollectionName
switch ($EntityType)
{
    "All" 
        {
            Write-Host "Fetching Indexing Activity for Code and WorkItem..." -ForegroundColor Green
            CodeIndexingActivity
            WorkItemIndexingActivity
        }
    "WorkItem" 
        {
            Write-Host "Fetching Indexing Activity for WorkItem..." -ForegroundColor Green
            WorkItemIndexingActivity
        }
    "Code"
        {
            Write-Host "Fetching Indexing Activity for Code..." -ForegroundColor Green
            CodeIndexingActivity
        }
    default 
        {
            Write-Host "Enter a valid EntityType i.e. Code or WorkItem or All" -ForegroundColor Red
        }
}


Pop-Location