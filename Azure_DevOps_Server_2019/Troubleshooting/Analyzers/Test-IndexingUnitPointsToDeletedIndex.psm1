Set-StrictMode -Version Latest

function Test-IndexingUnitPointsToDeletedIndex
{
    [CmdletBinding(SupportsShouldProcess=$True, ConfirmImpact = "None")]
    [OutputType([string[]])]
    Param
    (
        [Parameter(Mandatory=$True)]
        [string] $SQLServerInstance,
        
        [Parameter(Mandatory=$True)]
        [uri] $ElasticsearchServiceUrl,
        
        [Parameter(Mandatory=$True)]
        [PSCredential] $ElasticsearchServiceCredential,
       
        [Parameter(Mandatory=$True)]
        [string] $ConfigurationDatabaseName,
       
        [Parameter(Mandatory=$True)]
        [string] $CollectionDatabaseName,

        [Parameter(Mandatory=$True)]
        [string] $CollectionName,

        [Parameter(Mandatory=$True)]
        [ValidateSet("Code", "WorkItem", "Wiki")]
        [string] $EntityType
    )

    # Get indexing indices from all indexing units
    $sqlQueryProperties = "EntityType='$EntityType'"
    $SqlFullPath = "$PSScriptRoot\..\SqlScripts\SearchIndexingIndices.sql"
    $queryResults = Invoke-Sqlcmd -InputFile $SqlFullPath -ServerInstance $SQLServerInstance -Database $CollectionDatabaseName -Variable $sqlQueryProperties
    if ($queryResults)
    {
        Write-Verbose "SQL query results: [$($queryResults | Out-String)]."
        
        $indexingIndexNames = @($queryResults | Select-Object -ExpandProperty IndexingIndexName | select -Unique | where { $_ }) # De-duplicating and removing empty values
        if (!$indexingIndexNames)
        {
            Write-Log "No $EntityType indexing unit with indexing index name found. If re-indexing has just started, this is expected." -Level Warn
            return @() # No actions identified
        }

        if ($indexingIndexNames.Count -gt 1)
        {
            Write-Log "Indexing units of collection [$CollectionName] have properties containing more than one indexing index [$indexingIndexNames]. Re-indexing is required to fix this state." -Level Error
            return "Restart-Indexing"
        }

        $indexNameInSql = $indexingIndexNames[0]

        # Check if the index exists in Elasticsearch. If not, recommend re-indexing
        $indexExists = (Invoke-ElasticsearchCommand -ElasticsearchServiceUrl $ElasticsearchServiceUrl -ElasticsearchServiceCredential $ElasticsearchServiceCredential -Method Head -Command $indexNameInSql -Verbose:$VerbosePreference).StatusCode -eq 200
        if (!$indexExists)
        {
            Write-Log "Indexing index name in SQL [$indexNameInSql] does not exist in Elasticsearch cluster at [$ElasticsearchServiceUrl]. Re-indexing is required." -Level Error
            return "Restart-Indexing"
        }
    }
    else
    {
        Write-Log "No $EntityType indexing unit with indexing index name found. If re-indexing has just started, this is expected." -Level Warn
    }

    return @() # No actions identified
}