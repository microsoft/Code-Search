[CmdletBinding()]
Param(
    [Parameter(Mandatory=$True, HelpMessage="Enter the Elasticsearch server Url. eg: http://localhost:9200/")]
    [string]$ElasticServerUrl,

    [Parameter(Mandatory=$True, HelpMessage="Enter index name. Eg: code* for all code indices or a specific index name")]
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