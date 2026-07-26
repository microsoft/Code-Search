#Display collection indexing status for a given collection.

[CmdletBinding()]
Param(
    
    [Parameter(Mandatory=$True, Position=0, HelpMessage="Collection name.")]
    [String]
    $userCollection,

    [Parameter(Mandatory=$True, Position=1, HelpMessage="The SQL Server instance.")]
    [String]
    $SQLServerInstance,
    
    [Parameter(Mandatory=$True, Position=2, HelpMessage="Configuration Database name.")]
    [String]
    $ConfigurationdatabaseName,
    
    [Parameter(Mandatory=$True, Position=3, HelpMessage="Collection database name.")]
    [String]
    $CollectionDatabaseName,

    [Parameter(Mandatory=$False, Position=4, HelpMessage="Location of previous Elasticsearch aggregation output.")]
    [String]
    $Source,

    [Parameter(Mandatory=$False, Position=5, HelpMessage="URI for Elasticsearch instance.")]
    [String]
    $Uri
)


function getCollectionIndexingStatus
{
    if(!$ConfigurationDatabaseName -or !$CollectionDatabaseName)
    {
        Write-Host "Please enter ConfigurationDatabaseName and CollectionDatabaseName"
        return
    }
    Import-Module .\Common.psm1 -Force
    $collectionId = ValidateCollectionName $SQLServerInstance $ConfigurationDatabaseName $userCollection
    $SqlFullPath = Join-Path $PWD -ChildPath 'SqlScripts\CodeIndexingCompletedCount.sql'
    $queryResults = Invoke-Sqlcmd -InputFile $SqlFullPath -ServerInstance $SQLServerInstance -Database $collectionDatabaseName
    $completed =  $queryResults.BulkIndexingCompletedCount
    Write-Host "No of repositories completed: $completed"
                                              
    $SqlFullPath = Join-Path $PWD -ChildPath 'SqlScripts\CodeIndexingInProgressRepositories.sql'
    $queryResults = Invoke-Sqlcmd -InputFile $SqlFullPath -ServerInstance $SQLServerInstance -Database $collectionDatabaseName
    $inProgress = $queryResults.Length
    Write-Host "Repositories InProgress: $inProgress"
    if($inProgress -gt 0)
    {
        Write-Host "`nInProgress Status:"
    }
    foreach($repository in $queryResults)
    {
         $project = $repository.ProjectName
         $repository = $repository.RepositoryName
         Write-Host "`nProject: $project Repository: $repository"
         if($Source -and $Uri)
         {
              &.\GetRepositoryReIndexingActivityStatus.ps1 $userCollection $project $repository $Source $Uri
         }         
    }
}

getCollectionIndexingStatus