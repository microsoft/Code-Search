Set-StrictMode -Version Latest

function Test-InefficientTfvcCrawlingStoredProcedure
{
    [CmdletBinding(SupportsShouldProcess=$True, ConfirmImpact = "None")]
    [OutputType([string[]])]
    Param
    (
        [Parameter(Mandatory=$True)]
        [string] $SQLServerInstance,

        [Parameter(Mandatory=$False)]
        [uri] $ElasticsearchServiceUrl,

        [Parameter(Mandatory=$True)]
        [string] $ConfigurationDatabaseName,

        [Parameter(Mandatory=$True)]
        [string] $CollectionDatabaseName,

        [Parameter(Mandatory=$True)]
        [string] $CollectionName,

        [Parameter(Mandatory=$True)]
        [ValidateSet("Code", "WorkItem")]
        [string] $EntityType
    )
    
    if ($EntityType -ne "Code")
    {
        Write-Log "This analyzer is only valid for Code entity type. It is not valid for [$EntityType] entity type."
        return @()
    }
    
    # Get all job Ids corresponding to TFVC repository indexing units
    $tfvcJobIds = Invoke-Sqlcmd -Query "SELECT AssociatedJobId FROM Search.tbl_IndexingUnit WHERE EntityType = 'Code' AND IndexingUnitType = 'TFVC_Repository' AND AssociatedJobId IS NOT NULL AND IsDeleted = 0 AND PartitionId = 1" -ServerInstance $SQLServerInstance -Database $CollectionDatabaseName | Select-Object -ExpandProperty AssociatedJobId
    if (!$tfvcJobIds)
    {
        Write-Log "This analyzer is only valid for TFVC repositories. No TFVC repository was found in collection [$CollectionName]."
        return @()
    }

    Write-Log "TFVC Job Ids: [$tfvcJobIds]." -Level Verbose
    
    $collectionId = Get-CollectionId -SqlServerInstance $SQLServerInstance -ConfigurationDatabaseName $ConfigurationDatabaseName -CollectionName $CollectionName
    
    # For each job Id, check if latest jobs are all failing with the expected error message and return appropriate action.
    
    # Below is the threshold count of failed jobs with the expected error message we want to detect in latest jobs.
    $minNumberOfConsistentJobFailures = 3

    foreach ($tfvcJobId in $tfvcJobIds)
    {
        $queryResults = Invoke-Sqlcmd -Query "SELECT TOP($minNumberOfConsistentJobFailures) Result, ResultMessage FROM dbo.tbl_JobHistory WHERE JobSource = '$CollectionId' AND JobId = '$tfvcJobId' AND Result IN (0, 2) ORDER BY StartTime DESC" -ServerInstance $SQLServerInstance -Database $ConfigurationDatabaseName
        if ($queryResults)
        {
            # All rows should correspond to a failed job with the expected error message
            $knownIssueDetected = $true
            foreach ($queryResult in $queryResults)
            {
                Write-Log "SQL query results: [$($queryResult | Out-String)]." -Level Verbose

                $result = [int]($queryResult | Select-Object -ExpandProperty Result)
                if ($result -eq 0)
                {
                    $knownIssueDetected = $false
                    break
                }
                
                $resultMessage = $queryResult | Select-Object -ExpandProperty ResultMessage
                if (!($resultMessage -match "System.Threading.Tasks.TaskCanceledException" -and $resultMessage -match "TfvcHttpClientWrapper.GetItemsPagedAsync"))
                {
                    $knownIssueDetected = $false
                    break
                }
            }
            
            if ($knownIssueDetected)
            {
                # TODO: Would be cool if we can also log the TFVC repository name in the message below.
                Write-Log "There is at least one TFVC repository for which indexing seems to be failing continuously with a timeout exception. This can result in stale or no search results from the affected TFVC repository." -Level Warn
                return "Request-TfvcSProcHotfix"
            }
        }
        #else this means no job executed for this job Id.
    }

    return @() # No actions identified
}