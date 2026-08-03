[CmdletBinding()]
Param
(        
    [Parameter(Mandatory=$True)]
    [string] $SQLServerInstance,

    [Parameter(Mandatory=$True)]
    [string] $ConfigurationDatabaseName,

    [Parameter(Mandatory=$True)]
    [string] $CollectionName,

    [Parameter(Mandatory=$True)]
    [uri] $ElasticsearchServiceUrl,

    [Parameter(Mandatory=$True)]
    [string] $FileOrFolderPath
)

if(!$FileOrFolderPath.StartsWith("$/"))
{
    throw "Please provide proper Tfvc file/folder path that starts with $/"
}

$CollectionId = Invoke-Sqlcmd -Query "Select HostID from dbo.tbl_ServiceHost WHERE Name = '$CollectionName' AND HostType = 4" -ServerInstance $SQLServerInstance -Database $ConfigurationDatabaseName | Select-Object -ExpandProperty HostId
if (!$CollectionId)
{
    throw "Collection with name [$CollectionName] not found."
}

$WildChar = "*";
$body = @"
{
    "query": {
        "bool": {
        "must": [ {
            "term": {
            "collectionId": {
                "value": "$CollectionId"
            }}},{
            "wildcard": {
            "filePathOriginal": {
                "value": "$FileOrFolderPath$WildChar"
            }
            }}]
    }}
}
"@


Write-Host "Attempting delete for all files under path (honouring case sensitivity): $FileOrFolderPath"
$Command = "code*/_delete_by_query"
$ESDeleteResponse = Invoke-WebRequest -Method POST -Uri $ElasticsearchServiceUrl$Command -Body $Body -ContentType "application/json"
Write-Host "Delete operation response: $ESDeleteResponse"