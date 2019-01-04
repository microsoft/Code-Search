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

        [Parameter(Mandatory=$True)]
        [System.Management.Automation.PSCredential]$Credential,

        [Parameter(Mandatory=$False)]
        [string]$LogFilePath
    )

    if ($LogFilePath -and !(Test-Path -Path $LogFilePath -PathType Leaf))
    {
        throw "Log file path [$LogFilePath] does not exist"
    }
    
    if ($Method -eq 'Get')
    {
        $response = Invoke-WebRequest -Method $Method -Uri $Uri -Credential $Credential -ContentType "application/json"
    }
    else
    {
        $response = Invoke-WebRequest -Method $Method -Uri $Uri -Body $Body -Credential $Credential -ContentType "application/json"
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

# Fetch credential from user for accessing Elasticsearch cluster
$credential = Get-Credential -Message "Enter your credential for connecting to $ElasticsearchServerUrl"

try
{
    $esDiagDir = Join-Path $PWD "ElasticsearchDiagnostics"
    New-Item -ItemType Directory -Force -Path $esDiagDir | Out-Null

    $commandsFilePath = Join-Path $esDiagDir "commands.txt"
    Set-Content -Path $commandsFilePath ""

    # Basic connectivity test
    $response = Invoke-ElasticsearchCommand -Method Get -Uri $ElasticsearchServerUrl -Credential $credential -LogFilePath $commandsFilePath -ErrorAction Stop

    # _cluster/health
    $clusterHealth = Invoke-ElasticsearchCommand -Method Get -Uri "$($ElasticsearchServerUrl)_cluster/health" -Credential $credential -LogFilePath $commandsFilePath -ErrorAction Stop

    $unassignedShardsCount = $(ConvertFrom-Json $clusterHealth)."unassigned_shards"
    if ($unassignedShardsCount -gt 0)
    {
        # _cluster/allocation/explain
        $allocationExplanation = Invoke-ElasticsearchCommand -Method Get -Uri "$($ElasticsearchServerUrl)_cluster/allocation/explain" -Credential $credential -LogFilePath $commandsFilePath -ErrorAction Stop
    }
    
    # _cat/shards
    $shards = Invoke-ElasticsearchCommand -Method Get -Uri "$($ElasticsearchServerUrl)_cat/shards?v" -Credential $credential -LogFilePath $commandsFilePath -ErrorAction Stop

    # _mapping
    $mappings = Invoke-ElasticsearchCommand -Method Get -Uri "$($ElasticsearchServerUrl)_mapping" -Credential $credential -LogFilePath $commandsFilePath -ErrorAction Stop

    # _cat/nodes
    $nodes = Invoke-ElasticsearchCommand -Method Get -Uri "$($ElasticsearchServerUrl)_cat/nodes?v" -Credential $credential -LogFilePath $commandsFilePath -ErrorAction Stop

    # _settings
    $nodeSettings = Invoke-ElasticsearchCommand -Method Get -Uri "$($ElasticsearchServerUrl)_settings" -Credential $credential -LogFilePath $commandsFilePath -ErrorAction Stop

    # _cluster/settings
    $clusterSettings = Invoke-ElasticsearchCommand -Method Get -Uri "$($ElasticsearchServerUrl)_cluster/settings" -Credential $credential -LogFilePath $commandsFilePath -ErrorAction Stop

    # _aliases
    $aliases = Invoke-ElasticsearchCommand -Method Get -Uri "$($ElasticsearchServerUrl)_aliases" -Credential $credential -LogFilePath $commandsFilePath -ErrorAction Stop

    $esDiagonisticsZip = "Elasticsearch_Diagnostic.zip"
    Write-Host "Compressing data to $esDiagonisticsZip..." -ForegroundColor Green
    Compress-Archive -Force -Path $esDiagDir -DestinationPath $esDiagonisticsZip
}
finally
{
    Remove-Item $esDiagDir -Force -Recurse -ErrorAction Ignore
}