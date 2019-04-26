Set-StrictMode -Version Latest

function Enable-IndexingFeatureFlags
{
    [CmdletBinding(SupportsShouldProcess=$True, ConfirmImpact = "High")]
    Param
    (
        [Parameter(Mandatory=$True)]
        [string] $SQLServerInstance,
        
        [Parameter(Mandatory=$False)]
        [uri] $ElasticsearchServiceUrl,
        
        [Parameter(Mandatory=$True)]
        [string] $ConfigurationDatabaseName,
       
        [Parameter(Mandatory=$True)]
        [string] $CollectionDatabaseName,

        [Parameter(Mandatory=$True)]
        [string] $CollectionName,

        [Parameter(Mandatory=$True)]
        [ValidateSet("Code", "WorkItem")]
        [string] $EntityType,
        
        [Parameter(Mandatory=$False)]
        [string] $AdditionalParam
    )

    $message = "Enable indexing of [$EntityType] in collection [$CollectionName]"
    if ($PSCmdlet.ShouldProcess($message.ToUpperInvariant(), "Are you sure you want to $($message)?".ToUpperInvariant(), "Confirm"))
    {
        Write-Log "Enabling [$EntityType] indexing feature flags for collection [$CollectionName]..."
        switch ($EntityType)
        {
            "Code"
            {
                Set-FeatureFlag -SQLServerInstance $SQLServerInstance -ConfigurationDatabaseName $ConfigurationDatabaseName -FeatureName "Search.Server.IndexingJobs" -State On
                Set-FeatureFlag -SQLServerInstance $SQLServerInstance -CollectionDatabaseName $CollectionDatabaseName -CollectionName $CollectionName -FeatureName "Search.Server.IndexingJobs" -State On
                Set-FeatureFlag -SQLServerInstance $SQLServerInstance -ConfigurationDatabaseName $ConfigurationDatabaseName -FeatureName "Search.Server.ContinuousIndexing" -State On
                Set-FeatureFlag -SQLServerInstance $SQLServerInstance -CollectionDatabaseName $CollectionDatabaseName -CollectionName $CollectionName -FeatureName "Search.Server.ContinuousIndexing" -State On
                break
            }

            "WorkItem"
            {
                Set-FeatureFlag -SQLServerInstance $SQLServerInstance -ConfigurationDatabaseName $ConfigurationDatabaseName -FeatureName "Search.Server.WorkItem.Indexing" -State On
                Set-FeatureFlag -SQLServerInstance $SQLServerInstance -CollectionDatabaseName $CollectionDatabaseName -CollectionName $CollectionName -FeatureName "Search.Server.WorkItem.Indexing" -State On
                Set-FeatureFlag -SQLServerInstance $SQLServerInstance -ConfigurationDatabaseName $ConfigurationDatabaseName -FeatureName "Search.Server.WorkItem.ContinuousIndexing" -State On
                Set-FeatureFlag -SQLServerInstance $SQLServerInstance -CollectionDatabaseName $CollectionDatabaseName -CollectionName $CollectionName -FeatureName "Search.Server.WorkItem.ContinuousIndexing" -State On
                break
            }

            default
            {
                throw [System.NotImplementedException] "Support for entity type [$_] is not implemented."
            }
        }
        
        # Waiting for a few seconds for the feature flag changes to get processed
        Start-Sleep -Seconds 5
    }
}