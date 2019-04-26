Set-StrictMode -Version Latest

function Test-GeneralTfvcIssues
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
    $tfvcRepoCount = [int](Invoke-Sqlcmd -Query "SELECT COUNT(1) AS TfvcRepoCount FROM Search.tbl_IndexingUnit WHERE EntityType = 'Code' AND IndexingUnitType = 'TFVC_Repository' AND IsDeleted = 0 AND PartitionId = 1" -ServerInstance $SQLServerInstance -Database $CollectionDatabaseName | Select-Object -ExpandProperty TfvcRepoCount)
    if ($tfvcRepoCount -eq 0)
    {
        Write-Log "This analyzer is only valid for TFVC repositories. No TFVC repository was found in collection [$CollectionName]."
        return @()
    }

    $message = 
@"
There are a few known issues related to indexing TFVC files in the current version of Team Foundation Server.
* tf destroy is not processed
    DESCRIPTION: Search does not delete destroyed TFVC files from Elasticsearch.
    IMPACT: Code search will return destroyed TFVC files in the result.
    MITIGATION: Deleting the destroyed files from Elasticsearch will fix the problem. But if tf destroy is executed again, the problem will 
        surface again. Till this bug is not fixed, please delete the TFVC files, wait for a day and only then destroy them. Once Search
        processes the deletion, it is safe to destroy the file.

* TFVC indexing bugs
    DESCRIPTION: Multiple code bugs result in either slow indexing, or repeated indexing failures, or unintentionally ignoring certain changesets of TFVC files/folders.
    IMPACT: These bugs result in outdated code search results.
    FIX: These issues are fixed in newer versions of Team Foundation Server.
"@

    Write-Log $message -Level Warn

    return @("Request-Upgrade Tfs2018U2")
}