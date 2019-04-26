Set-StrictMode -Version Latest

function Request-Upgrade
{
    <#
    .SYNOPSIS
    Prompts a message to the user to upgrade Team Foundation Server to a newer version where issues detected are fixed.
    Product name to upgrade to is passed as value of parameter $AdditionalParam.
    #>
    [CmdletBinding(SupportsShouldProcess=$True, ConfirmImpact = "None")]
    Param
    (
        [Parameter(Mandatory=$False)]
        [string] $SQLServerInstance,
        
        [Parameter(Mandatory=$False)]
        [uri] $ElasticsearchServiceUrl,
        
        [Parameter(Mandatory=$False)]
        [PSCredential] $ElasticsearchServiceCredential,
       
        [Parameter(Mandatory=$False)]
        [string] $ConfigurationDatabaseName,
       
        [Parameter(Mandatory=$False)]
        [string] $CollectionDatabaseName,

        [Parameter(Mandatory=$False)]
        [string] $CollectionName,

        [Parameter(Mandatory=$False)]
        [ValidateSet("Code", "WorkItem")]
        [string] $EntityType,
        
        [Parameter(Mandatory=$True)]
        [ValidateSet("Tfs2018U2", "Tfs2018U3", "ADOServer2019")]
        [string] $AdditionalParam
    )

    switch ($AdditionalParam)
    {
        "Tfs2018U2" 
        { 
            $productName = "Team Foundation Server 2018 Update 2"
            $productUrl = "https://docs.microsoft.com/visualstudio/releasenotes/tfs2018-update2"
            break
        }

        "Tfs2018U3"
        { 
            $productName = "Team Foundation Server 2018 Update 3"
            $productUrl = "https://docs.microsoft.com/visualstudio/releasenotes/tfs2018-update3"
            break
        }

        "ADOServer2019"
        { 
            $productName = "Azure DevOps Server 2019"
            $productUrl = "https://docs.microsoft.com/azure/devops/server/release-notes/azuredevops2019"
            break
        }

        default
        {
            throw "Product [$AdditionalParam] is not a recommended/supported version to upgrade to. This is a code bug."
        }
    }

    Write-Log "[MANUAL ACTION REQUIRED] Certain issues were identified which can be best fixed by upgrading. Please upgrade to $productName ($productUrl) or above. If you cannot and the issue still persists, please contact support." -Level Attention
}