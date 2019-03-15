[CmdletBinding()]
Param(
    [Parameter(Mandatory=$True, Position=0, HelpMessage="The SQL Server Instance against which the script is to run.")]
    [string]$SQLServerInstance,
    
    [Parameter(Mandatory=$True, Position=1, HelpMessage="Configuration Database name")]
    [string]$ConfigurationDatabaseName,
	
    [Parameter(Mandatory=$True, Position=2, HelpMessage="Collection Database name.")]
    [string]$CollectionDatabaseName,
       
    [Parameter(Mandatory=$True, Position=3, HelpMessage="Collection Name")]
    [string]$CollectionName,

    [Parameter(Mandatory=$True, Position=3, HelpMessage="Repository Name")]
    [string]$RepositoryName,
	
    [Parameter(Mandatory=$True, Position=4, HelpMessage="Search Url")]
    [string]$SearchUrl
)

$LogFile = "RepositoryHealthCheck.log"
$RepositoryHealthCheckLogPath = Join-Path $PWD -ChildPath $LogFile

function RepositoryHealthCheck
{
    WriteLogToConsoleAndFile "[RepositoryHealthCheck] Performing Repository sanity tests ... " -LogFilePath $RepositoryHealthCheckLogPath

    # [RepositoryHealthCheckTEST 1] Verify there exists a valid Repo -> Proj -> Col IU hierarchy in tbl_IndexingUnit
    WriteLogToConsoleAndFile "[RepositoryHealthCheckTEST 1] Verifying Repo -> Proj -> Col IU hierarchy in tbl_IndexingUnit ... " -LogFilePath $RepositoryHealthCheckLogPath

    $SqlFullPath = Join-Path $PWD -ChildPath 'RepoIUHierarchy.sql'
    $RepoIUHierarchyParams = "RepoName='$RepositoryName'"
    $queryResults = Invoke-Sqlcmd -InputFile $SqlFullPath -serverInstance $SQLServerInstance -database $CollectionDatabaseName -Variable $RepoIUHierarchyParams

    $resultCount = 0
    $associatedJobId = ''
    $projTfsEntityId = ''
    $colTfsEntityId = ''

    foreach($row in $queryResults)
    {
        $resultCount++
        $colTfsEntityId = $row | Select-object -ExpandProperty COL_ID
        $projTfsEntityId = $row | Select-object -ExpandProperty PROJ_ID
        $associatedJobId = $row | Select-object -ExpandProperty AssociatedJobId
    }

    if ($resultCount -ne 1)
    {
        WriteLogToConsoleAndFile "[ERROR] Invalid/Missing Repository IU hierarchy ... " -Level "Error" -LogFilePath $RepositoryHealthCheckLogPath
    }

    # [RepositoryHealthCheckTEST 2] Verify recent Job History from the Associated JobId for the Repository
    WriteLogToConsoleAndFile "[RepositoryHealthCheckTEST 2] Verifying recent indexing job history for the Repository ... " -LogFilePath $RepositoryHealthCheckLogPath

    if ($associatedJobId -ne '')
    {
        # $queryResults = Invoke-Sqlcmd -Query "Select COUNT(*) from [dbo].[tbl_ServiceHost] where Name = '$CollectionName' and HostType = 4" -serverInstance $SQLServerInstance -database $ConfigurationDatabaseName -Verbose
        $queryResults = Invoke-Sqlcmd -Query `
                            "Select COUNT(*) as IndexingSuccessCount from [dbo].[tbl_JobHistory] `
                            where JobSource = '$colTfsEntityId' and `
                            JobId = '$associatedJobId' and `
                            EndTime >  DATEADD(DAY, -7, GETUTCDATE()) and `
                            Result = 0 and `
                            ResultMessage like '%Successfully indexed Git_Repository%'" `
                        -serverInstance $SQLServerInstance -database $ConfigurationDatabaseName -Verbose
        
        $successJobCount = $queryResults | Select-object -ExpandProperty IndexingSuccessCount
        
        $queryResults = Invoke-Sqlcmd -Query `
                            "Select COUNT(*) as IndexingFailureCount from [dbo].[tbl_JobHistory] `
                            where JobSource = '$colTfsEntityId' and `
                            JobId = '$associatedJobId' and `
                            EndTime >  DATEADD(DAY, -7, GETUTCDATE()) and `
                            Result = 2" `
                        -serverInstance $SQLServerInstance -database $ConfigurationDatabaseName -Verbose
        
        $failureJobCount = $queryResults | Select-object -ExpandProperty IndexingFailureCount

        if ($failureJobCount > 0)
        {
            WriteLogToConsoleAndFile "[ERROR] Indexing Jobs for Repository (last 7d) SuccessCount = $successJobCount FailureCount = $failureJobCount " -Level "Error" -LogFilePath $RepositoryHealthCheckLogPath
        }
        else 
        {
            WriteLogToConsoleAndFile "Indexing Jobs for Repository (last 7d) SuccessCount = $successJobCount FailureCount = $failureJobCount " -LogFilePath $RepositoryHealthCheckLogPath
        }
    }
    else 
    {
        WriteLogToConsoleAndFile "[ERROR] Missing AssociatedJobId for Repository" -LogFilePath $RepositoryHealthCheckLogPath
    }

    # [RepositoryHealthCheckTEST 3] [TODO] Check for Pending IUCEs for this Repository IU
    # [RepositoryHealthCheckTEST 4] [TODO] Verify RoutingId is valid and there are documents indexed
    # [RepositoryHealthCheckTEST 5] [TODO] Display the last commit Id and Commit Time for this Repository
}

Import-Module .\Common.psm1 -Force

[System.ENVIRONMENT]::CurrentDirectory = $PWD
Push-Location
ImportSQLModule

# Run basic DBDataSyncTest at configuration/collection level
DBDataSyncTest $SQLServerInstance $ConfigurationDatabaseName $CollectionDatabaseName $CollectionName $SearchUrl $LogFile

# Run the overall ES Health status check
# [TODO]

# Run Repository specific Health Check
RepositoryHealthCheck

Pop-Location
