Set-StrictMode -Version Latest

function Remove-Index
{
    <#
    .SYNOPSIS
    Deletes an index from Elasticsearch. Name of the index is passed as value of parameter $AdditionalParam.
    #>
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

    $indexToRemove = $AdditionalParam
    $indexExists = (Invoke-ElasticsearchCommand -ElasticsearchServiceUrl $ElasticsearchServiceUrl -ElasticsearchServiceCredential $ElasticsearchServiceCredential -Method Head -Command $indexToRemove -Verbose:$VerbosePreference).StatusCode -eq 200
    if ($indexExists)
    {
        $message = "Delete index [$AdditionalParam] in Elasticsearch"
        if ($PSCmdlet.ShouldProcess($message.ToUpperInvariant(), "Are you sure you want to $($message)?".ToUpperInvariant(), "Confirm"))
        {
            $response = Invoke-ElasticsearchCommand -ElasticsearchServiceUrl $ElasticsearchServiceUrl -ElasticsearchServiceCredential $ElasticsearchServiceCredential -Method Delete -Command $indexToRemove -Verbose:$VerbosePreference
            if ($response.Status -eq 200)
            {
                Write-Log "Deleted index [$indexToRemove]."
            }
            else
            {
                Write-Log "Deletion of Elasticsearch index failed with error: [$($response | Out-String)]."
            }
        }
    }
    else
    {
        Write-Log "Index [$indexToRemove] does not exist."
    }
}