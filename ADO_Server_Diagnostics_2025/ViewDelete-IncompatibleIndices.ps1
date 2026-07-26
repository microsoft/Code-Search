<# 
Execute this script to identify any active indexes that are incompatible. If any indexes are in use, 
reindex the collection using the TriggerCollection script, and then rerun this script with the Delete action selected.
#>

param (
    [Parameter(Mandatory = $true, Position = 0, HelpMessage = "The Server Instance against which the script is to run.")]
    [string]$SQLServerInstance,

    [Parameter(Mandatory = $true, Position = 1, HelpMessage = "Collection Database name.")]
    [string]$CollectionDatabaseName,

    [Parameter(Mandatory = $true, Position = 2, HelpMessage = "Elasticsearch URL.")]
    [string]$URL,

    [Parameter(Mandatory = $true, Position = 3, HelpMessage = "Elasticsearch UserName.")]
    [string]$UserName,

    [Parameter(Mandatory = $true, Position = 4, HelpMessage = "Elasticsearch Password.")]
    [string]$Password,

    [Parameter(Mandatory = $true, Position = 5, HelpMessage = "Action to perform.")]
    [ValidateSet("Delete", "View")]
    [string]$Action
)

$indicesFilePath = Join-Path $PSScriptRoot "indices.txt"
$settingsFilePath = Join-Path $PSScriptRoot "settings.txt"
$outputFilePath = Join-Path $PSScriptRoot "output.txt"

if (!(Test-Path $indicesFilePath)) {
    New-Item $indicesFilePath -ItemType File
}

if (!(Test-Path $settingsFilePath)) {
    New-Item $settingsFilePath -ItemType File
}

if (!(Test-Path $outputFilePath)) {
    New-Item $outputFilePath -ItemType File
}

$getIndicesCommand = 'curl -u ' + $UserName + ':' + $Password + ' ' + $URL + '/_cat/indices?h=index > ' + $indicesFilePath
Write-Host $getIndicesCommand
Start-Process -Verb RunAs cmd.exe -Args '/c', $getIndicesCommand

$indices = Get-Content -Path $indicesFilePath

foreach ($index in $indices) {
    Remove-Item $settingsFilePath -ErrorAction SilentlyContinue
    New-Item $settingsFilePath -ItemType File -Force

    $getIndexSettingsCommand = 'curl -u ' + $UserName + ':' + $Password + ' ' + $URL + '/' + $index + '/_settings?pretty -k > ' + $settingsFilePath
    Write-Host $getIndexSettingsCommand
    Start-Process -Verb RunAs cmd.exe -Args '/c', $getIndexSettingsCommand

    Start-Sleep -Seconds 1

    $json = Get-Content -Path $settingsFilePath -Raw | ConvertFrom-Json
    $indexName = $index
    $createdVersion = $json[0].$indexName.settings.index.version.created

    Write-Host "Index Name: $indexName" -ForegroundColor DarkYellow
    Write-Host "Created Version for {$indexName}: $createdVersion" -ForegroundColor Green

    $settings = Get-Content -Path $settingsFilePath
    Add-Content $outputFilePath $settings

    if ($createdVersion.StartsWith("5")) {
        
        $Params = "IndexName='$indexName'"
        $sqlFullPath = Join-Path $PSScriptRoot 'SqlScripts\GetActiveIncompatibleIndex.sql'
        $result = Invoke-Sqlcmd -InputFile $sqlFullPath -ServerInstance $SQLServerInstance -Database $CollectionDatabaseName -Verbose -Variable $params

        Write-Host "Result: $($result.Count)" -ForegroundColor Red

        foreach ($row in $result) {
            $TFSEntityId = $row.TFSEntityId
            $EntityType = $row.EntityType
            $IndexingUnitType = $row.IndexingUnitType
            $IndexingUnitId = $row.IndexingUnitId

            Write-Host "TFSEntityId: $TFSEntityId, EntityType: $EntityType, IndexingUnitType: $IndexingUnitType, IndexingUnitId: $IndexingUnitId" -ForegroundColor Red
        }

        if ($result.Count -eq 0 -and $Action -eq 'Delete') {
            Write-Host "Deleting Incompatible Index: $indexName" -ForegroundColor Green

            $delCommand = 'curl -u ' + $UserName + ':' + $Password + ' -X DELETE ' + $URL + '/' + $indexName + '?pretty -k'
            Write-Host $delCommand -ForegroundColor Yellow
            Start-Process -Verb RunAs cmd.exe -Args '/c', $delCommand
        }
    }

    Start-Sleep -Seconds 2
}
