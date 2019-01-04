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
    
    [Parameter(Mandatory=$False, Position=5, HelpMessage="Extension install indexing state for Code, WorkItem or All")]
    [string]$EntityType = "All"
)

Import-Module .\Common.psm1 -Force

# Fetches the Code Extension install indexing status.
function CodeExtensionInstallIndexingStatus
{
    # Validating if the collection has code extension installed.
    if(IsExtensionInstalled $SQLServerInstance $CollectionDatabaseName "IsCollectionIndexed")
    {
        #Gets the result of the Code Extension AccountFaultIn job
        $SqlFullPath = Join-Path $PWD -ChildPath 'SqlScripts\CodeAccountFaultInResult.sql'
        $queryResults = Invoke-Sqlcmd -InputFile "$PWD\SqlScripts\CodeAccountFaultInResult.sql" -serverInstance $SQLServerInstance -database $ConfigurationDatabaseName  -Verbose -Variable $Params
    
        if($queryResults)
        {
            $resultState = $queryResults  | Select-object  -ExpandProperty  Result
            $resultMessage = $queryResults  | Select-object  -ExpandProperty  ResultMessage

            if($resultState -eq 0)
            {
                Write-Host "Collection Code indexing was triggered successfully" -ForegroundColor Yellow
            }
            else
            {
                Write-Error "Collection Code indexing was not triggered with this message: $resultMessage"
            }

            # Gets the count of repositories for which the code indexing has completed.
            $SqlFullPath = Join-Path $PWD -ChildPath 'SqlScripts\CountCodeIndexingCompleted.sql'
            $queryResults = Invoke-Sqlcmd -InputFile $SqlFullPath -serverInstance $SQLServerInstance -database $ConfigurationDatabaseName -Variable $indexingCompletedQueryParams
            $indexingCompletedRepositoryCount = $queryResults  | Select-object  -ExpandProperty  IndexingCompletedCount

            if($indexingCompletedRepositoryCount -gt 0)
            {
                Write-Host "Code Repositories completed indexing: '$indexingCompletedRepositoryCount'" -ForegroundColor Yellow
            }
            else
            {
                Write-Host "No Code repositories completed fresh indexing in this collection in last $Days days" -ForegroundColor Cyan
            }
        
            # Gets the data for repositories which are still inprogress.
            $SqlFullPath = Join-Path $PWD -ChildPath 'SqlScripts\CodeIndexingInProgressRepositoryCount.sql'
            $queryResults = Invoke-Sqlcmd -InputFile $SqlFullPath -serverInstance $SQLServerInstance -database $CollectionDatabaseName  -Verbose -Variable $Params
            
            if($queryResults.ItemArray.Count -gt 0)
            {
                Write-Host "Status of code indexing:" -ForegroundColor Yellow
                Write-Host "Repository Id                         | Repository Name" -ForegroundColor Green
 
                foreach($row in $queryResults)
                {
                    Write-Host "$($row.TfsEntityId)  | $($row.RepositoryIndexingInProgress)" -ForegroundColor Yellow
                }
            }
            else
            {
                Write-Host "No code repositories are currently in indexing state." -ForegroundColor Cyan
            }
        }
        else
        {
            Write-Host "No code indexing job found for Configuration/Extension installs. Try a day range near to the date of configuration/extension install"
        }
    }
    else
    {
        Write-Host "The code search extension is disabled for this account. Install the extension and then try again." -ForegroundColor DarkYellow
    }
}


function WorkItemExtensionInstallIndexingStatus
{
    # Validating if the collection has workitem extension installed.
    if(IsExtensionInstalled $SQLServerInstance $CollectionDatabaseName "IsCollectionIndexedForWorkItem")
    {
        #Gets the result of the Code Extension AccountFaultIn job
        $SqlFullPath = Join-Path $PWD -ChildPath 'SqlScripts\WorkItemAccountFaultInResult.sql'
        $queryResults = Invoke-Sqlcmd -InputFile $SqlFullPath -serverInstance $SQLServerInstance -database $ConfigurationDatabaseName  -Verbose -Variable $Params
    
        if($queryResults)
        {
            $resultState = $queryResults  | Select-object  -ExpandProperty  Result
            $resultMessage = $queryResults  | Select-object  -ExpandProperty  ResultMessage

            if($resultState -eq 0)
            {
                Write-Host "Collection WorkItem indexing was triggered successfully" -ForegroundColor Yellow
            }
            else
            {
                Write-Error "Collection WorkItem indexing was not triggered with this message: $resultMessage"
            }

            # Gets the count of repositories for which the indexing has completed.
            $SqlFullPath = Join-Path $PWD -ChildPath 'SqlScripts\CountWorkItemIndexingCompleted.sql'
            $queryResults = Invoke-Sqlcmd -InputFile $SqlFullPath -serverInstance $SQLServerInstance -database $ConfigurationDatabaseName -Variable $indexingCompletedQueryParams
            $indexingCompletedRepositoryCount = $queryResults  | Select-object  -ExpandProperty  IndexingCompletedCount

            if($indexingCompletedRepositoryCount -gt 0)
            {
                Write-Host "WorkItem Projects completed indexing: '$indexingCompletedRepositoryCount'" -ForegroundColor Yellow
            }
            else
            {
                Write-Host "No WorkItem Projects completed fresh indexing in this collection in last $Days days" -ForegroundColor Cyan
            }
        
            # Gets the data for projects with workitem indexing still inprogress.
            $SqlFullPath = Join-Path $PWD -ChildPath 'SqlScripts\WorkItemIndexingInProgressRepositoryCount.sql'
            $queryResults = Invoke-Sqlcmd -InputFile $SqlFullPath -serverInstance $SQLServerInstance -database $CollectionDatabaseName  -Verbose -Variable $Params
            
            if($queryResults.ItemArray.Count -gt 0)
            {
                Write-Host "Status of WorkItem indexing:" -ForegroundColor Yellow
                Write-Host "Project Id                         | Project Name" -ForegroundColor Green
 
                foreach($row in $queryResults)
                {
                    Write-Host "$($row.TfsEntityId)  | $($row.ProjectWorkItemIndexingInProgress)" -ForegroundColor Yellow
                }
            }
            else
            {
                Write-Host "No workitem projects are currently in indexing state." -ForegroundColor Cyan
            }
        }
        else
        {
            Write-Host "No workitem projects indexing job found for Configuration/Extension installs. Try a day range near to the date of configuration/extension install"
        }
    }
    else
    {
        Write-Host "The workitem search extension is disabled for this account. Install the extension and then try again." -ForegroundColor DarkYellow
    }
}

Write-Host "Checking indexing state for last $Days days" -ForegroundColor Green

[System.ENVIRONMENT]::CurrentDirectory = $PWD
Push-Location
ImportSQLModule

# Checking for valid Collection Name.
$CollectionID = ValidateCollectionName $SQLServerInstance $ConfigurationDatabaseName $CollectionName

$Params = "CollectionId='$CollectionID'" 
$indexingCompletedQueryParams = "DaysAgo='$Days'","CollectionId='$CollectionID'"

switch ($EntityType)
{
    "All" 
        {
            Write-Host "Fetching Indexing Activity for Code and WorkItem..." -ForegroundColor Green
            CodeExtensionInstallIndexingStatus
            WorkItemExtensionInstallIndexingStatus
        }
    "WorkItem" 
        {
            Write-Host "Fetching Indexing Activity for WorkItem..." -ForegroundColor Green
            WorkItemExtensionInstallIndexingStatus
        }
    "Code"
        {
            Write-Host "Fetching Indexing Activity for Code..." -ForegroundColor Green
            CodeExtensionInstallIndexingStatus
        }
    default 
        {
            Write-Host "Enter a valid EntityType i.e. Code or WorkItem or All" -ForegroundColor Red
        }
}

Pop-Location