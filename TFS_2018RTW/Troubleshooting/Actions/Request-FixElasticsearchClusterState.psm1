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

        [Parameter(Mandatory=$False)]
        [string] $ConfigurationDatabaseName,

        [Parameter(Mandatory=$False)]
        [string] $CollectionDatabaseName,

        [Parameter(Mandatory=$False)]
        [string] $CollectionName,

        [Parameter(Mandatory=$False)]
        [ValidateSet("Code", "WorkItem")]
        [string] $EntityType,

        [Parameter(Mandatory=$False)]
        [string] $AdditionalParam
    )

    $response = Invoke-ElasticsearchCommand -ElasticsearchServiceUrl $ElasticsearchServiceUrl -Method Get -Command "_cat/shards?v&h=index,shard,prirep,state,docs,store,ip,node,unassigned.reason,unassigned.details" -Verbose:$VerbosePreference
    if ($response.StatusCode -eq 200)
    {
        Write-Log "[MANUAL ACTION REQUIRED] Analyse the _cat/shards response below and try to mitigate the problem for UNASSIGNED shards. Sometimes this state can be temporary so execute Repair-Search again. If you are unable to fix the cluster state, please contact support.`r`n$($response.Content)" -Level Attention
    }
    else
    {
        throw "_cat/shards API returned with an unexpected status code [$($response.StatusCode)]. Error: [$($response.ErrorMessage)]."
    }
}