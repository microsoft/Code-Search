Set-StrictMode -Version Latest

function Request-FixElasticsearchClusterState
{
    [CmdletBinding(SupportsShouldProcess=$True, ConfirmImpact = "None")]
    Param
    (
        [Parameter(Mandatory=$False)]
        [string] $SQLServerInstance,

        [Parameter(Mandatory=$True)]
        [uri] $ElasticsearchServiceUrl,

        [Parameter(Mandatory=$True)]
        [PSCredential] $ElasticsearchServiceCredential,

        [Parameter(Mandatory=$False)]
        [string] $ConfigurationDatabaseName,

        [Parameter(Mandatory=$False)]
        [string] $CollectionDatabaseName,

        [Parameter(Mandatory=$False)]
        [string] $CollectionName,

        [Parameter(Mandatory=$False)]
        [ValidateSet("Code", "WorkItem", "Wiki")]
        [string] $EntityType,

        [Parameter(Mandatory=$False)]
        [string] $AdditionalParam
    )

    $response = Invoke-ElasticsearchCommand -ElasticsearchServiceUrl $ElasticsearchServiceUrl -ElasticsearchServiceCredential $ElasticsearchServiceCredential -Method Get -Command "_cluster/allocation/explain" -Verbose:$VerbosePreference
    if ($response.StatusCode -eq 200)
    {
        $clusterAllocationExplanation = $response.Content | ConvertFrom-Json | ConvertTo-Json -Depth 20 # The double convert is for formatting the JSON
        Write-Log "[MANUAL ACTION REQUIRED] Analyse the cluster allocation explanation respose below and try to mitigate the problem. Sometimes this state can be temporary so execute Repair-Search again. If you are unable to fix the cluster state, please contact support.`r`n$clusterAllocationExplanation" -Level Attention
    }
    elseif ($response.StatusCode -eq 400) # It can happen that the cluster was recovering. We saw it in red/yellow state before but here it becomes green. Then this API returns this status code
    {
        Write-Log "[MANUAL ACTION REQUIRED] It seems like the Elasticsearch cluster just became healthy. You may want to run Repair-Search one more time just to be sure." -Level Attention
    }
    else
    {
        throw "Cluster allocation explain API returned with an unexpected status code [$($response.StatusCode)]. Error: [$($response.ErrorMessage)]."
    }
}