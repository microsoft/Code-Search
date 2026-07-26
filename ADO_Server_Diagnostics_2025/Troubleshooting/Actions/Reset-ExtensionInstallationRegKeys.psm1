Set-StrictMode -Version Latest

function Reset-ExtensionInstallationRegKeys
{
    [CmdletBinding(SupportsShouldProcess=$True, ConfirmImpact = "None")]
    Param
    (
        [Parameter(Mandatory=$True)]
        [string] $SQLServerInstance,
        
        [Parameter(Mandatory=$False)]
        [uri] $ElasticsearchServiceUrl,
        
        [Parameter(Mandatory=$False)]
        [PSCredential] $ElasticsearchServiceCredential,
       
        [Parameter(Mandatory=$False)]
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

    $regKey = "\Service\ALMSearch\Settings\IsExtensionOperationInProgress\$EntityType\Uninstalled"
    Set-ServiceRegistryValue -SQLServerInstance $SQLServerInstance -CollectionDatabaseName $CollectionDatabaseName -CollectionName $CollectionName -RegistryPath $regKey -Value $null
    Write-Log "Removed registry [$regKey] from [$CollectionDatabaseName] database."
}