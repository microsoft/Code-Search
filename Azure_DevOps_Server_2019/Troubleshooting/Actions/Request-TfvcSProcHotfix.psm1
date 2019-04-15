Set-StrictMode -Version Latest

function Request-TfvcSProcHotfix
{
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
        [ValidateSet("Code", "WorkItem", "Wiki")]
        [string] $EntityType,
        
        [Parameter(Mandatory=$False)]
        [string] $AdditionalParam
    )

    Write-Log "[MANUAL ACTION REQUIRED] There is a performance bug in a SQL stored procedure in TFS 2018 Update 2 due to which crawling TFVC files can time out. It was fixed in TFS 2018 Update 3. Either upgrade to TFS 2018 Update 3 or above, or request for a SQL hotfix from support team to get rid of this bug.`r`n`r`n" -Level Warn
    Write-Log "[FOR SUPPORT TEAM] Find the SPROC to be hotfixed at https://dev.azure.com/mseng/b924d696-3eae-4116-8443-9a18392d8544/_apis/git/repositories/0d32bfdc-56d7-4d3a-afe2-a5fc4011a0a7/Items?path=%2F.attachments%2Fhotfix_prc_QueryItemsPaged-db5a44c2-83fd-4b42-8a79-490ba5b4c78d.sql&download=false&resolveLfs=true&%24format=octetStream&api-version=5.0-preview.1. If anything goes wrong, rollback using https://dev.azure.com/mseng/b924d696-3eae-4116-8443-9a18392d8544/_apis/git/repositories/0d32bfdc-56d7-4d3a-afe2-a5fc4011a0a7/Items?path=%2F.attachments%2Frollback%20prc_QueryItemsPaged-cfe82e02-0b87-430e-a3cc-c4e265316b83.txt&download=false&resolveLfs=true&%24format=octetStream&api-version=5.0-preview.1." -Level Warn
}