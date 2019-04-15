Set-StrictMode -Version Latest

function Remove-Index
{
    [CmdletBinding(SupportsShouldProcess=$True, ConfirmImpact = "High")]
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

        [Parameter(Mandatory=$True)]
        [string] $AdditionalParam
    )

    if ($PSCmdlet.ShouldProcess("Index [$AdditionalParam]", "Delete"))
    {
        $indexToRemove = $AdditionalParam
        $indexExists = (Invoke-ElasticsearchCommand -ElasticsearchServiceUrl $ElasticsearchServiceUrl -ElasticsearchServiceCredential $ElasticsearchServiceCredential -Method Head -Command $indexToRemove -Verbose:$VerbosePreference).StatusCode -eq 200
        if ($indexExists)
        {
            Write-Log "Deleting index [$indexToRemove]..."
            Invoke-ElasticsearchCommand -ElasticsearchServiceUrl $ElasticsearchServiceUrl -ElasticsearchServiceCredential $ElasticsearchServiceCredential -Method Delete -Command $indexToRemove -Verbose:$VerbosePreference
        }
        else
        {
            Write-Log "Index [$indexToRemove] is already deleted."
        }
    }
}