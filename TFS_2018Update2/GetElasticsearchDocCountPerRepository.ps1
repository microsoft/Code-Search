#Fetch repository documents count data from provided ES instance.
#Run the script with script <ES Connection String> <Destination>
#Output will be stored in a single json file at the given destination.
#Format of the output is same as the one returned by elasticsearch for nested aggregation queries.
[CmdletBinding()]
Param(
    [Parameter(Mandatory=$True, Position=0, HelpMessage="URI for ElasticSearch instance.")]
    [String]
    $Uri,

    [Parameter(Mandatory=$True, Position=1, HelpMessage="Destination where the output file will be saved.")]
    [String]
    $Destination
)

$contractTypes= @{}
$contractTypes.Add("SourceNoDedupeFileContract", ("collectionId", "collectionNameOriginal", "projectId", "projectNameOriginal", "repoId", "repoNameOriginal"))
$contractTypes.Add("SourceNoDedupeFileContractV2", ("collectionId", "collectionNameOriginal", "projectId", "projectNameOriginal", "repositoryId", "repoNameOriginal"))
$contractTypes.Add("SourceNoDedupeFileContractV3", ("collectionId", "collectionNameOriginal", "projectId", "projectNameOriginal", "repositoryId", "repoNameOriginal"))

#Get the contract type from the given ElasticSearch instance.
$contractTypesList = ("SourceNoDedupeFileContractV3", "SourceNoDedupeFileContractV2", "SourceNoDedupeFileContract")
$indices = "codesearchshared*"
$mappingUri =  $Uri+"/"+$indices+"/_mapping"
try
{
    $mappingResponse = Invoke-WebRequest -Uri $mappingUri -Method Get
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