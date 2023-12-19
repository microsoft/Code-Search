Set-StrictMode -Version Latest

function Remove-OrphanIndexedDocuments
{
    [CmdletBinding(SupportsShouldProcess=$True, ConfirmImpact = "High")]
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
        [string] $EntityType,

        [Parameter(Mandatory=$False)]
        [string] $AdditionalParam
    )

    # Get collection Id, index name and mapping name from collection indexing unit
    $sqlQueryProperties = "EntityType='$EntityType'"
    $sqlFullPath = "$PSScriptRoot\..\SqlScripts\GetCollectionIndexingUnitDetails.sql"
    $queryResults = Invoke-Sqlcmd -InputFile $sqlFullPath -ServerInstance $SQLServerInstance -Database $CollectionDatabaseName -Variable $sqlQueryProperties
    if ($queryResults)
    {
        Write-Log "SQL query results: [$($queryResults | Out-String)]." -Level Verbose
        $collectionId = [guid]($queryResults | Select-Object -ExpandProperty TfsEntityId)
        $indexName = $queryResults | Select-Object -ExpandProperty IndexingIndexName
        $documentContractType = $queryResults | Select-Object -ExpandProperty IndexContractType 
        $mappingName = Get-MappingName -DocumentContractType $documentContractType
        Write-Log "Collection Id: [$collectionId], Index name: [$indexName], Mapping name: [$mappingName]" -Level Verbose

        $body = @"
        {
            "query": {
                "bool": {
                    "must": {
                        "term": { "collectionId": "$collectionId" }
                    },
                    "must_not": {
                        "bool": {
                            "must": [
                                { "term": { "_index": "$indexName" } },
                                { "term": { "_type": "$mappingName" } }
                            ]
                        }
                    }
                }
            }
        }
"@

        # Get the number of documents to be deleted first
        $url = "$($EntityType.ToLowerInvariant())*/_count"
        $response = Invoke-ElasticsearchCommand -ElasticsearchServiceUrl $ElasticsearchServiceUrl -ElasticsearchServiceCredential $ElasticsearchServiceCredential -Method Post -Command $url -Body $body -Verbose:$VerbosePreference
        if ($response.StatusCode -eq 200)
        {
            $impactedDocumentCount = ($response.Content | ConvertFrom-Json).count
            if ($impactedDocumentCount -gt 0)
            {
                $message = "Clean-up [$impactedDocumentCount] [$EntityType] documents of collection [$CollectionName] indexed in unexpected indices/mappings"
                if ($PSCmdlet.ShouldProcess($message.ToUpperInvariant(), "Are you sure you want to $($message)? This can take a long time if the number of documents to delete is large.".ToUpperInvariant(), "Confirm"))
                {
                    Remove-IndexedDocumentsInBatches -ElasticsearchServiceUrl $ElasticsearchServiceUrl -ElasticsearchServiceCredential $ElasticsearchServiceCredential -IndexPattern "$($EntityType.ToLowerInvariant())*" -Body $body
                    Write-Log "Completed deletion of all orphan indexed documents from Elasticsearch."
                }
            }
        }
        else
        {
            Write-Log "Delete request failed with response: [$($response | ConvertTo-Json)]." -Level Error
        }
    }
    else
    {
        throw "$EntityType collection indexing unit does not exist. This should have been caught earlier and this analyzer not invoked."
    }
}