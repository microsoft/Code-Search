Set-StrictMode -Version Latest

function Test-ElasticsearchHealth
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
        [string] $ConfigurationDatabaseName,
       
        [Parameter(Mandatory=$True)]
        [string] $CollectionDatabaseName,

        [Parameter(Mandatory=$True)]
        [string] $CollectionName,

        [Parameter(Mandatory=$True)]
        [ValidateSet("Code", "WorkItem", "Wiki")]
        [string] $EntityType
    )

    # Verify connection parameters are correct
    Confirm-ElasticsearchIsReachable -ElasticsearchServiceUrl $ElasticsearchServiceUrl -Verbose:$VerbosePreference

    # Verify cluster health is green
    $clusterHealth = (Invoke-ElasticsearchCommand -ElasticsearchServiceUrl $ElasticsearchServiceUrl -Method Get -Command "_cluster/health" -Verbose:$VerbosePreference).Content | ConvertFrom-Json
    Write-Log "Elasticsearch cluster health is [$clusterHealth]."
    $clusterState = $clusterHealth.status
    
    if ($clusterState -ne "green")
    {
        Write-Log "Elasticsearch cluster state is [$clusterState]." -Level Error
        return "Request-FixElasticsearchClusterState"
    }
    else
    {
        Write-Log "Elasticsearch cluster state is [$clusterState]."
    }

    # Verify number of documents for given collection and entity type is greater than zero
    $collectionId = Get-CollectionId -SqlServerInstance $SQLServerInstance -ConfigurationDatabaseName $ConfigurationDatabaseName -CollectionName $CollectionName
    
    $body = @"
    {
        "size": 0,
        "query": {
            "term": {
                "collectionId": "$collectionId"
            }
        },
        "aggs": {
            "collections": {
                "terms": {
                    "field": "collectionId",
                    "size": 1000
                },
                "aggs": {
                    "indices": {
                        "terms": {
                            "field": "_index",
                            "size": 1000
                        },
                        "aggs": {
                            "mappings": {
                                "terms": {
                                    "field": "_type",
                                    "size": 1000
                                }
                            }
                        }
                    }
                }
            }
        }
    }
"@

    $docCountResponse = (Invoke-ElasticsearchCommand -ElasticsearchServiceUrl $ElasticsearchServiceUrl -Method Post -Command "$($EntityType.ToLowerInvariant())*/_search?filter_path=aggregations.collections.buckets.key,aggregations.collections.buckets.indices.buckets.key,aggregations.collections.buckets.indices.buckets.mappings.buckets" -Body $body -Verbose:$VerbosePreference).Content | ConvertFrom-Json
    Write-Log "Collection documents per index per mapping for entity type [$EntityType]`:`r`n$($docCountResponse | ConvertTo-Json -Depth 20)" -Level Verbose
    if ([bool]$docCountResponse.PSobject.Properties.Item("aggregations"))
    {
        $indices = @($docCountResponse.aggregations.collections.buckets[0].indices.buckets)
        if ($indices.Count -gt 1)
        {
            Write-Log "Documents for entity type [$EntityType] and collection [$CollectionName] are indexed in more than one indices." -Level Warn
            return "Remove-OrphanIndexedDocuments"
        }
        else
        {
            $indexName = $indices[0].key
            $mappings = @($indices[0].mappings.buckets)
            if ($mappings.Count -gt 1)
            {
                Write-Log "Documents for entity type [$EntityType] and collection [$CollectionName] are indexed in more than one mapping of index [$indexName]." -Level Error
                return "Remove-OrphanIndexedDocuments"
            }
            else
            {
                Write-Log "Number of documents indexed for entity type [$EntityType] and collection [$CollectionName] in index [$($indices[0].key)] and mapping [$($mappings[0].key)] = [$($mappings[0].doc_count)]."
            }
        }
    }
    else # Empty response
    {
        # If bulk indexing has just stated, it is possible to get zero results at first. We don't want to log a warning message in that case.
        if (!(Test-BulkIndexingIsInProgress `
            -SQLServerInstance $SQLServerInstance `
            -ConfigurationDatabaseName $ConfigurationDatabaseName `
            -CollectionDatabaseName $CollectionDatabaseName `
            -CollectionName $CollectionName `
            -EntityType $EntityType))
        {
            Write-Log "[MANUAL ACTION MAY BE REQUIRED] No document for entity type [$EntityType] and collection [$CollectionName] is indexed in Elasticsearch. If this is not expected, consider executing Restart-Indexing action." -Level Attention
        }
    }

    return @() # No actions identified
}