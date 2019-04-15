Set-StrictMode -Version Latest

function Remove-OrphanIndexedDocuments
{
    [CmdletBinding(SupportsShouldProcess=$True, ConfirmImpact = "High")]
    Param
    (
        [Parameter(Mandatory=$True)]
        [string] $SQLServerInstance,

        [Parameter(Mandatory=$True)]
        [uri] $ElasticsearchServiceUrl,

        [Parameter(Mandatory=$True)]
        [PSCredential] $ElasticsearchServiceCredential,

        [Parameter(Mandatory=$True)]
        [string] $ConfigurationDatabaseName,

        [Parameter(Mandatory=$True)]
        [string] $CollectionDatabaseName,

        [Parameter(Mandatory=$True)]
        [string] $CollectionName,

        [Parameter(Mandatory=$True)]
        [ValidateSet("Code", "WorkItem", "Wiki")]
        [string] $EntityType,

        [Parameter(Mandatory=$False)]
        [string] $AdditionalParam
    )

    if ($PSCmdlet.ShouldProcess("Documents of entity type [$EntityType] of collection [$CollectionName] indexed in unexpected indices/mappings", "Delete"))
    {
        throw [System.NotImplementedException]

        # Get all indices for the given entity type
        # Get collection Id
        # Delete documents in batches and log progress
    }
}