Set-StrictMode -Version Latest

function Request-InstallSearchExtension
{
    [CmdletBinding(SupportsShouldProcess=$True, ConfirmImpact = "None")]
    Param
    (
        [Parameter(Mandatory=$False)]
        [string] $SQLServerInstance,
        
        [Parameter(Mandatory=$False)]
        [uri] $ElasticsearchServiceUrl,
        
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

    Write-Log "[MANUAL ACTION REQUIRED] $EntityType search extension is not installed. Please install it before proceeding further." -Level Attention
}