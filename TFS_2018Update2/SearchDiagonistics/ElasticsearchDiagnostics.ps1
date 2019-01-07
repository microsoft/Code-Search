Param
(
    [Parameter(Mandatory=$True, HelpMessage="URL of Elasticsearch service. Example: http://es-server:9200")]
    [Uri]$ElasticsearchServerUrl
)

function Invoke-ElasticsearchCommand
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$True)]
        [Microsoft.PowerShell.Commands.WebRequestMethod]$Method,

        [Parameter(Mandatory=$True)]
        [Uri]$Uri,

        [Parameter(Mandatory=$False)]
        [string]$Body,

        [Parameter(Mandatory=$False)]
        [string]$LogFilePath
    )

    if ($LogFilePath -and !(Test-Path -Path $LogFilePath -PathType Leaf))
    {
        throw "Log file path [$LogFilePath] does not exist"
    }
    
    if ($Method -eq 'Get')
    {
        $response = Invoke-WebRequest -Method $Method -Uri $Uri -ContentType "application/json"
    }
    else
    {
        $response = Invoke-WebRequest -Method $Method -Uri $Uri -Body $Body -ContentType "application/json"
    }

    $output = "Timestamp: [$([System.DateTime]::UtcNow.ToString(`"o`"))]`r`n"
    $output += "Request:`r`nMethod [$Method] Uri [$Uri] Body [$Body]`r`n"
    $output += "Response:`r`n$($response.Content)`r`n"
    Write-Verbose $output

    if ($LogFilePath)
    {
        Add-Content -Path $commandsFilePath -Value $output
    }

    return $response.Content
}

try
{
    $esDiagDir = Join-Path $PWD "ElasticsearchDiagnostics"
    New-Item -ItemType Directory -Force -Path $esDiagDir | Out-Null

    $commandsFilePath = Join-Path $esDiagDir "commands.txt"
    Set-Content -Path $commandsFilePath ""

    # Basic connectivity test
    $response = Invoke-ElasticsearchCommand -Method Get -Uri $ElasticsearchServerUrl -LogFilePath $commandsFilePath -ErrorAction Stop

    # _cluster/health
    $clusterHealth = Invoke-ElasticsearchCommand -Method Get -Uri "$($ElasticsearchServerUrl)_cluster/health" -LogFilePath $commandsFilePath -ErrorAction Stop

    $unassignedShardsCount = $(ConvertFrom-Json $clusterHealth)."unassigned_shards"
    if ($unassignedShardsCount -gt 0)
    {
        # _cluster/allocation/explain
        $allocationExplanation = Invoke-ElasticsearchCommand -Method Get -Uri "$($ElasticsearchServerUrl)_cluster/allocation/explain" -LogFilePath $commandsFilePath -ErrorAction Stop
    }
    
    # _cat/shards
    $shards = Invoke-ElasticsearchCommand -Method Get -Uri "$($ElasticsearchServerUrl)_cat/shards?v" -LogFilePath $commandsFilePath -ErrorAction Stop

    # _mapping
    $mappings = Invoke-ElasticsearchCommand -Method Get -Uri "$($ElasticsearchServerUrl)_mapping" -LogFilePath $commandsFilePath -ErrorAction Stop

    # _cat/nodes
    $nodes = Invoke-ElasticsearchCommand -Method Get -Uri "$($ElasticsearchServerUrl)_cat/nodes?v" -LogFilePath $commandsFilePath -ErrorAction Stop

    # _settings
    $nodeSettings = Invoke-ElasticsearchCommand -Method Get -Uri "$($ElasticsearchServerUrl)_settings" -LogFilePath $commandsFilePath -ErrorAction Stop

    # _cluster/settings
    $clusterSettings = Invoke-ElasticsearchCommand -Method Get -Uri "$($ElasticsearchServerUrl)_cluster/settings" -LogFilePath $commandsFilePath -ErrorAction Stop

    # _aliases
    $aliases = Invoke-ElasticsearchCommand -Method Get -Uri "$($ElasticsearchServerUrl)_aliases" -LogFilePath $commandsFilePath -ErrorAction Stop

    $esDiagonisticsZip = "Elasticsearch_Diagnostic.zip"
    Write-Host "Compressing data to $esDiagonisticsZip..." -ForegroundColor Green
    Compress-Archive -Force -Path $esDiagDir -DestinationPath $esDiagonisticsZip
}
finally
{
    Remove-Item $esDiagDir -Force -Recurse -ErrorAction Ignore
}