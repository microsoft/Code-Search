Set-StrictMode -Version Latest

function Test-FaultInJobInInfiniteRetries
{
    [CmdletBinding(SupportsShouldProcess=$True, ConfirmImpact = "None")]
    [OutputType([string[]])]
    Param
    (
        [Parameter(Mandatory=$True)]
        [string] $SQLServerInstance,

        [Parameter(Mandatory=$False)]
        [uri] $ElasticsearchServiceUrl,

        [Parameter(Mandatory=$False)]
        [PSCredential] $ElasticsearchServiceCredential,

        [Parameter(Mandatory=$True)]
        [string] $ConfigurationDatabaseName,

        [Parameter(Mandatory=$True)]
        [string] $CollectionDatabaseName,

        [Parameter(Mandatory=$True)]
        [string] $CollectionName,

        [Parameter(Mandatory=$True)]
        [ValidateSet("Code", "WorkItem", "Wiki")]
        [string] $EntityType
    )
    
    # Get the latest fault-in job result message
    $collectionId = Get-CollectionId -SqlServerInstance $SQLServerInstance -ConfigurationDatabaseName $ConfigurationDatabaseName -CollectionName $CollectionName
    $faultInJobId = Get-AccountFaultInJobId -EntityType $EntityType
    $faultInJobResultMessage = Invoke-Sqlcmd -Query "SELECT TOP(1) ResultMessage FROM dbo.tbl_JobHistory WHERE JobSource = '$collectionId' AND JobId = '$faultInJobId' AND Result IN (0, 2) ORDER BY StartTime DESC" -ServerInstance $SQLServerInstance -Database $ConfigurationDatabaseName | Select-Object -ExpandProperty ResultMessage

    # Check if it contains the message indicating it is waiting for extension uninstallation, and return action if required
    if ($faultInJobResultMessage -and $faultInJobResultMessage.Contains("Requeue the Account Fault-In job since Extension Uninstall sequence is still in progress"))
    {
        Write-Log "$EntityType indexing is blocked due to incorrect values of some registry keys." -Level Error
        return "Reset-ExtensionInstallationRegKeys"
    }

    return @() # No actions identified
}