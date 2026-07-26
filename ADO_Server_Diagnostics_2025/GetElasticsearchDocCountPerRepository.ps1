# Azure DevOps Server 2025 - Elasticsearch 8.14
# Script to fetch repository document counts from Elasticsearch
#
# PURPOSE: Retrieves document count statistics per repository from Elasticsearch.
#          Useful for monitoring indexing progress and troubleshooting search issues.
#
# USAGE: .\GetElasticsearchDocCountPerRepository.ps1 -Uri <elasticsearch_url> -Destination <output_path>
#
# EXAMPLES:
#   .\GetElasticsearchDocCountPerRepository.ps1 -Uri "http://localhost:9200" -Destination "C:\temp\doc_counts.json"
#   .\GetElasticsearchDocCountPerRepository.ps1 -Uri "http://elastic-server:9200" -Destination ".\repository_stats.json"
#
# OUTPUT: Creates a JSON file with document counts grouped by collection, project, and repository.
#         Format matches Elasticsearch nested aggregation query results.
#
# NOTE: Check Elasticsearch indices at http://localhost:9200/_cat/indices
#       Look for index names like codesearchshared*, wikisearchshared*, etc.
#
[CmdletBinding()]
Param(
    [Parameter(Mandatory=$True, Position=0, HelpMessage="Elasticsearch URL with protocol and port (e.g., 'http://localhost:9200')")]
    [String]
    $Uri,

    [Parameter(Mandatory=$True, Position=1, HelpMessage="Full path where the output JSON file will be saved (e.g., 'C:\temp\output.json')")]
    [String]
    $Destination
)

$contractTypes= @{}
$contractTypes.Add("SourceNoDedupeFileContract", ("collectionId", "collectionNameOriginal", "projectId", "projectNameOriginal", "repoId", "repoNameOriginal"))
$contractTypes.Add("SourceNoDedupeFileContractV2", ("collectionId", "collectionNameOriginal", "projectId", "projectNameOriginal", "repositoryId", "repoNameOriginal"))
$contractTypes.Add("SourceNoDedupeFileContractV3", ("collectionId", "collectionNameOriginal", "projectId", "projectNameOriginal", "repositoryId", "repoNameOriginal"))

#Get the contract type from the given ElasticSearch instance.
$contractTypesList = ("SourceNoDedupeFileContractV3", "SourceNoDedupeFileContractV2", "SourceNoDedupeFileContract")
$indices = "code_*" 
$mappingUri =  $Uri+"/"+$indices+"/_mapping"
$credentials = Get-Credential  # Prompt the user to enter their credentials
try
{
    $mappingResponse = Invoke-WebRequest -Uri $mappingUri -Method Get -Credential $credentials
    $mappingObject = convertFrom-Json -InputObject $mappingResponse.Content 
    $index = $mappingObject.psobject.properties.name[0]
    foreach ( $type in $contractTypesList)
    {
        if ($type -in $mappingObject.$index.mappings.psobject.properties.name)
            {
                $contractType = $type
                break
            }
    }
}
catch
{
    $errorMsg = $_ | Out-String
    Write-Host $errorMsg -ForegroundColor Red
    return
}

if(!$contractType)
{
    Write-Host "The document contract type is not supported." -ForegroundColor Red
    return
}

$fieldNames = $contractTypes[$contractType]
$Uri = $Uri+"/"+$indices+"/"+$contractType+"/_search"
$outputFile = "RepositoryCount.json"
$Destination = Join-Path $Destination $outputFile
$Body = "{{
   `"size`":0,
   `"aggregations`": {{
      `"collectionid`": {{
         `"terms`": {{
            `"field`": `"{0}`",
            `"size`": 5000
         }},
         `"aggregations`": {{
            `"collectionname`": {{
               `"terms`": {{
                  `"field`": `"{1}`",
                  `"size`": 1
               }},
               `"aggregations`": {{
                  `"projectid`": {{
                     `"terms`": {{
                        `"field`": `"{2}`",
                        `"size`": 5000
                     }},
                     `"aggregations`": {{
                        `"projectname`": {{
                           `"terms`": {{
                              `"field`": `"{3}`",
                              `"size`": 1
                           }},
                           `"aggregations`": {{
                              `"repositoryid`": {{
                                 `"terms`": {{
                                    `"field`": `"{4}`",
                                    `"size`": 5000
                                 }},
                                 `"aggregations`": {{
                                    `"repositoryname`": {{
                                       `"terms`": {{
                                          `"field`": `"{5}`",
                                          `"size`": 1
                                       }}
                                    }}
                                 }}
                              }}
                           }}
                        }}
                     }}
                  }}
               }}
            }}
         }}
      }}
   }}
}}" -f ($fieldNames)

try
{
    Write-Host "Fetching repository data From Elasticsearch: $Uri"
    $response = Invoke-WebRequest -Uri $Uri -Method 'POST' -Body $Body
    $responseObject = convertFrom-Json -InputObject $response.Content
    $aggregationsJson = convertTo-Json -InputObject $responseObject.aggregations -Depth 20
    Out-File -FilePath $Destination -InputObject $aggregationsJson
    Write-Host "Successfully wrote repository document count data to: $Destination" -ForegroundColor Green
}
catch
{
    $errorMsg = $_ | Out-String
    Write-Host $errorMsg -ForegroundColor Red
}