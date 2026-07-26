Set-StrictMode -Version Latest

function Test-IndicesHaveUnsupportedMappings
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

    $actionsRecommended = @()

    # This analyzer will not require an update in the future because in latest releases, there is only one mapping per index.
    # As a result, we won't need to delete indices having unsupported mappings because then there would be no chance of mapping
    # collision.
    $unsupportedMappingNames = 
    @{
        "Code" = @("SourceNoDedupeFileContract", "SourceNoDedupeFileContractV2")
    }
    
    if (!$unsupportedMappingNames.ContainsKey($EntityType))
    {
        Write-Log "This analyzer is not supported for entity type [$EntityType]."
        return @()
    }

    # Make sure the unsupported mappings defined above are not actually supported. This is just to make sure the script has no bugs.
    $supportedDocumentContractType = Get-SupportedDocumentContractType -SQLServerInstance $SQLServerInstance -ConfigurationDatabaseName $ConfigurationDatabaseName -EntityType $EntityType
    $supportedMapping = Get-MappingName -DocumentContractType $supportedDocumentContractType
    if ($unsupportedMappingNames[$EntityType].Contains($supportedMapping))
    {
        throw "List of unsupported mapping names and/or expected mapping name are incorrectly setup. They both have [$mappingName] in common. Fix the bug in the script."
    }
    
    # Get all indices with unsupported mappings
    foreach ($unsupportedMappingName in $unsupportedMappingNames[$EntityType])
    {
        $command = "_mapping/$unsupportedMappingName"
        $response = Invoke-ElasticsearchCommand -ElasticsearchServiceUrl $ElasticsearchServiceUrl -ElasticsearchServiceCredential $ElasticsearchServiceCredential -Method Get -Command $command -Verbose:$VerbosePreference
        
        $indicesWithUnsupportedMapping = @()
        if ($response.StatusCode -eq 200)
        {
            # Indices with unsupported mapping is present. Find them.
            $indices = $($response.Content | ConvertFrom-Json).PSObject.Properties.Name
            foreach ($index in $indices)
            {
                $indicesWithUnsupportedMapping += $index
            }
        }
        elseif ($response.StatusCode -eq 404)
        {
            # This is the expected scenario - Unsupported mapping not found
        }
        else
        {
            throw "GET $command failed with status code [$($response.StatusCode)] unexpectedly."
        }

        if ($indicesWithUnsupportedMapping.Count -eq 0)
        {
            continue
        }

        foreach ($index in $indicesWithUnsupportedMapping)
        {
            Write-Log "Index [$index] has unsupported mapping [$unsupportedMappingName]. It must be deleted." -Level Error
            $actionsRecommended += "Remove-Index $index"
        }

        # Get the list of collections indexed in these indices
        $body = @"
        {
            "size": 0,
            "aggs": {
                "collections": {
                    "terms": {
                        "field": "collectionId",
                        "size": 1000
                    }
                }
            }
        }
"@

        $command = "$($indicesWithUnsupportedMapping -join ',')/_search?filter_path=aggregations.collections.buckets"
        $response = Invoke-ElasticsearchCommand -ElasticsearchServiceUrl $ElasticsearchServiceUrl -ElasticsearchServiceCredential $ElasticsearchServiceCredential -Method Post -Command $command -Body $body -Verbose:$VerbosePreference
        if ($response.StatusCode -ne 200)
        {
            throw "Failed to execute Elasticsearch request with following error: [$($response.ErrorMessage)]"
        }

        $aggregationResponse = $response.Content | ConvertFrom-Json
        foreach ($collection in $aggregationResponse.aggregations.collections.buckets)
        {
            $affectedCollectionId = $collection.key
            $affectedCollectionName = Get-CollectionName -SQLServerInstance $SQLServerInstance -ConfigurationDatabaseName $ConfigurationDatabaseName -CollectionId $affectedCollectionId
            if ($affectedCollectionName -eq $CollectionName)
            {
                Write-Log "Collection [$affectedCollectionName] has [$($collection.doc_count)] documents in the index to be deleted. It must be re-indexed." -Level Error
                $actionsRecommended += "Restart-Indexing"
            }
            else
            {
                Write-Log "[MANUAL ACTION REQUIRED] Collection [$affectedCollectionName] has [$($collection.doc_count)] documents in the index to be deleted. $EntityType search and indexing might both be failing for this collection. Please execute Repair-Search for this collection separately." -Level Attention
            }
        }
    }

    return $actionsRecommended
}