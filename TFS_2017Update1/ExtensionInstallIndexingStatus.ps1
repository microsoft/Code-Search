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

    #Gets the result of the AccountFaultIn job
    $SqlFullPath = Join-Path $PWD -ChildPath 'SqlScripts\AccountFaultInResult.sql'
    $queryResults = Invoke-Sqlcmd -InputFile $SqlFullPath -serverInstance $SQLServerInstance -database $ConfigurationDatabaseName  -Verbose -Variable $Params

    if($queryResults)
    {
        $resultState = $queryResults  | Select-object  -ExpandProperty  Result
        $resultMessage = $queryResults  | Select-object  -ExpandProperty  ResultMessage

        if($resultState -eq 0)
        {
            Write-Host "Collection indexing was triggered successfully" -ForegroundColor Yellow
        }
        else
        {
            Write-Error "Collection indexing was not triggered with this message: $resultMessage"
        }

        # Gets the count of repositories for which the indexing has completed.
        $SqlFullPath = Join-Path $PWD -ChildPath 'SqlScripts\CountRepositoryIndexingCompleted.sql'
        $queryResults = Invoke-Sqlcmd -InputFile $SqlFullPath -serverInstance $SQLServerInstance -database $ConfigurationDatabaseName -Variable $indexingCompletedQueryParams
        $indexingCompletedRepositoryCount = $queryResults  | Select-object  -ExpandProperty  IndexingCompletedCount

        if($indexingCompletedRepositoryCount -gt 0)
        {
            Write-Host "Repositories completed indexing: '$indexingCompletedRepositoryCount'" -ForegroundColor Yellow
        }
        else
        {
            Write-Host "No repositories completed fresh indexing in this collection in last $Days days" -ForegroundColor Cyan
        }

        # Gets the data for files pending to be indexing for repositories in data crawl stage.
        $SqlFullPath = Join-Path $PWD -ChildPath 'SqlScripts\IndexingInProgressRepositoryCount.sql'
        $queryResults = Invoke-Sqlcmd -InputFile $SqlFullPath -serverInstance $SQLServerInstance -database $CollectionDatabaseName  -Verbose -Variable $Params

        if($queryResults.ChildItem.Length -gt 0)
        {
            Write-Host "Status of repositories currently indexing:" -ForegroundColor Yellow
            Write-Host "Repository Id                         |"

            foreach($row in $queryResults)
            {
                Write-Host "$($row.TfsEntityId)  | $($row.RepositoryIndexingInProgress)" -ForegroundColor Yellow
            }
        }
        else
        {
            Write-Host "No repositories are currently in indexing state." -ForegroundColor Cyan
        }
    }
    else
    {
        Write-Host "No indexing job found for Configuration/Extension installs. Try a day range near to the date of configuration/extension install"
    }
}
else
{
    Write-Host "The extension is disabled for this account. Install the extension and then try again." -ForegroundColor DarkYellow
}

Pop-Location
