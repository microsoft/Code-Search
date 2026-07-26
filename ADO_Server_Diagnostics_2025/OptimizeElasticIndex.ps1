# Azure DevOps Server 2025 - Elasticsearch 8.14
# Script to optimize Elasticsearch indices for Azure DevOps Server 2025
#
# PURPOSE: Optimizes Elasticsearch indices by removing deleted documents and reducing disk space.
#          Use this to improve search performance and reduce storage usage.
#
# WARNING: This operation can be resource-intensive and may impact search performance during execution.
#          Run during maintenance windows for production systems.
#
# USAGE: .\OptimizeElasticIndex.ps1 -ElasticServerUrl <url> -IndexName <index_pattern>
#
# EXAMPLES:
#   .\OptimizeElasticIndex.ps1 -ElasticServerUrl "http://localhost:9200" -IndexName "code*"
#   .\OptimizeElasticIndex.ps1 -ElasticServerUrl "http://elastic-server:9200" -IndexName "workitem*"
#   .\OptimizeElasticIndex.ps1 -ElasticServerUrl "https://elastic.domain.com:9200" -IndexName "specific_index_name"
#
[CmdletBinding()]
Param(
    [Parameter(Mandatory=$True, HelpMessage="Elasticsearch server URL with protocol and port (e.g., 'http://localhost:9200')")]
    [string]$ElasticServerUrl,

    [Parameter(Mandatory=$True, HelpMessage="Index name or pattern (e.g., 'code*' for all code indices, 'workitem*' for work items, or specific index name)")]
    [string]$IndexName
)

function OptimizeIndex
{
    $optimizeCommand = $ElasticServerUrl +"/" + $IndexName + "/_forcemerge?only_expunge_deletes=true"
    $response = Invoke-RestMethod $optimizeCommand -Method Post -ContentType "application/json" -Credential (Get-Credential)
}

Write-Host -ForegroundColor Red @"
The optimize index operation you are going to execute will expunge all deleted documents of a given index.
This operation could cause very large shards to remain on disk until all the documents present in the index are just deleted documents.
Proceed with this operation if and only if it is absolutely required. 
"@

Write-Host "Do you want to continue - Yes or No? " -NoNewline -ForegroundColor Magenta
$userInput = Read-Host

if($userInput -like "Yes")
{
    Write-Host "Starting optimize index operation.." -ForegroundColor Green
    OptimizeIndex
    Write-Host "Initiated optimize operation.This operation executes at the background and will auto complete." -ForegroundColor Green
   
}
else
{
    Write-Warning "Exiting! No optimize operation was performed for the given index." -ForegroundColor Cyan
}