#Display respository indexing status for a given collection.

[CmdletBinding()]
Param(
    
    [Parameter(Mandatory=$True, Position=0, HelpMessage="Collection name.")]
    [String]
    $userCollection,

    [Parameter(Mandatory=$True, Position=1, HelpMessage="Project name.")]
    [String]
    $userProject,

    [Parameter(Mandatory=$True, Position=2, HelpMessage="Repository name.")]
    [String]
    $userRepository,

    [Parameter(Mandatory=$True, Position=3, HelpMessage="Location of previous Elasticsearch aggregation output.")]
    [String]
    $Source,

    [Parameter(Mandatory=$True, Position=4, HelpMessage="URI for Elasticsearch instance.")]
    [String]
    $Uri
)


function getRepositoryIndexingStatus
{
    $contractTypes= @{}
    $contractTypes.Add("SourceNoDedupeFileContract", ("collectionId", "collectionNameOriginal", "projectId", "projectNameOriginal", "repoId", "repoNameOriginal"))
    $contractTypes.Add("SourceNoDedupeFileContractV2", ("collectionId", "collectionNameOriginal", "projectId", "projectNameOriginal", "repositoryId", "repoNameOriginal"))
    $contractTypes.Add("SourceNoDedupeFileContractV3", ("collectionId", "collectionNameOriginal", "projectId", "projectNameOriginal", "repositoryId", "repoNameOriginal"))

    #Get the contract type from the given ElasticSearch instance.
    $contractTypesList = ("SourceNoDedupeFileContractV3", "SourceNoDedupeFileContractV2", "SourceNoDedupeFileContract")
    $indices = "codesearchshared*"
    $mappingUri =  $Uri+"/"+$indices+"/_mapping"
    $credentials = Get-Credential  #Prompt the user to enter their credentials
    try
    {
        $mappingResponse = Invoke-WebRequest -Uri $mappingUri -Method Get -Credential $credentials
        $mappingObject = convertFrom-Json -InputObject $mappingResponse.Content
        $index = $mappingObject.psobject.properties.name[0]
        foreach ( $type in $contractTypesList)
        {
            if ($type -in $mappingObject.$index."mappings".psobject.properties.name)
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
    $sourceFile = "RepositoryCount.json"
    $Source = Join-Path $Source $sourceFile
    if(!(Test-Path -Path $source -PathType Leaf))
    {
        Write-Host "$Source not found. This script depends on the output of GetElasticSearchDocCountPerRepository.ps1. Please provide the location of previous script's output." -ForegroundColor Red
        return
    }
    $Body = "{{
       `"size`": 0,
       `"query`": {{
          `"filtered`": {{
             `"filter`": {{
                `"term`": {{
                   `"{0}`": `"{1}`"
                }}
             }}
          }}
       }},
       `"aggregations`": {{
          `"projectname`": {{
             `"terms`": {{
                `"field`": `"{2}`",
                `"size`": 5000
             }},
             `"aggregations`": {{
                `"repositoryname`": {{
                   `"terms`": {{
                      `"field`": `"{3}`",
                      `"size`": 5000
                   }}
                }}
             }}
          }}
       }}
    }}" -f ($fieldNames[1],$userCollection, $fieldNames[3], $fieldNames[5])

    try
    {
        $previousContentObject = Get-Content -Path $Source | Out-String | ConvertFrom-Json
        $response = Invoke-WebRequest -Uri $Uri -Method 'POST' -Body $Body
        $responseObject = convertFrom-Json -InputObject $response.Content
        $collectionFound = $False
        foreach ($collection in $previousContentObject.collectionid.buckets)
        {
            if ($collection.collectionname.buckets[0].key -eq $userCollection)
            {
                $collectionFound = $True
                $projectFound = $False
                foreach($project in $collection.collectionname.buckets[0].projectid.buckets)
                {
                    if($project.projectname.buckets[0].key -eq $userProject)
                    {
                        $projectFound = $True
                        $repositoryFound = $False
                        foreach($repository in $project.projectname.buckets[0].repositoryid.buckets)
                        {
                            if($repository.repositoryname.buckets[0].key -eq $userRepository)
                            {
                                $repositoryFound = $True
                                $totalDoc =  $repository.repositoryname.buckets[0].doc_count
                                break
                            }
                        }
                        if(!$repositoryFound)
                        {
                            Write-Host "Repository $userRepository not found in previous Elasticsearch data." -ForegroundColor Red
                            return
                        }
                        break      
                    }
                }
                if(!$projectFound)
                {
                    Write-Host "Project $userProject not found in previous Elasticsearch data" -ForegroundColor Red
                    return
                }
                break
            }
    }
        if(!$collectionFound)
        {
            Write-Host "Collection $userCollection not found in previous Elastocsearch data." -ForegroundColor Red
            return
        }
        $indexedDoc = 0
        if($responseObject.hits.total -ne 0)
        {
            foreach($project in $responseObject.aggregations.projectname.buckets)
            {
                if($project.key -eq $userProject)
                {
                    foreach($repository in $project.repositoryname.buckets)
                    {
                        if($repository.key -eq $userRepository)
                        {
                            $indexedDoc = $repository.doc_count
                            break
                        }
                    }
                    break
                }
            }
        }
        Write-Host "Total doc in repository $userRepository is $totalDoc and indexed is $indexedDoc" 
    }
    catch
    {
        $errorMsg = $_ | Out-String
        Write-Host $errorMsg -ForegroundColor Red
    }
}

getRepositoryIndexingStatus