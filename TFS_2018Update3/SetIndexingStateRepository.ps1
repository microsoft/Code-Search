<#
This script sets the indexing state of the given repository to On or Off.
#>

[CmdletBinding()]
Param(
    [Parameter(Mandatory=$True, Position=0, HelpMessage="The Server Instance against which the script is to run.")]
    [string]$SQLServerInstance,

    [Parameter(Mandatory=$True, Position=1, HelpMessage="Collection Database name.")]
    [string]$CollectionDatabaseName,

    [Parameter(Mandatory=$True, Position=2, HelpMessage="Configuration DB")]
    [string]$ConfigurationDatabaseName,

    [Parameter(Mandatory=$True, Position=3, HelpMessage="Enter the Collection Name here.")]
    [string]$CollectionName,

    [Parameter(Mandatory=$True, Position=4, HelpMessage="Update the Project name here.")]
    [string]$ProjectName,

    [Parameter(Mandatory=$True, Position=5, HelpMessage="Update the Repository name here.")]
    [string]$RepositoryName,

    [Parameter(Mandatory=$True, Position=6, HelpMessage="Set the Indexing State here.")]
    [string]$IndexingState
)

if ([string]::IsNullOrWhiteSpace($SQLServerInstance) -Or [string]::IsNullOrWhiteSpace($CollectionDatabaseName) -Or [string]::IsNullOrWhiteSpace($ConfigurationDatabaseName) -Or [string]::IsNullOrWhiteSpace($CollectionName) -Or [string]::IsNullOrWhiteSpace($ProjectName) -Or [string]::IsNullOrWhiteSpace($RepositoryName)) {
    Throw "None of the values supplied can be null or empty. Please retry"
}

if ("On","Off" -NotContains $IndexingState)
{
    Throw "$($IndexingState) is not a valid State! Please use On/Off"
}

Import-Module .\Common.psm1 -Force

[System.ENVIRONMENT]::CurrentDirectory = $PWD
Push-Location
ImportSQLModule

$CollectionID = ValidateCollectionName $SQLServerInstance $ConfigurationDatabaseName $CollectionName

if(IsExtensionInstalled $SQLServerInstance $CollectionDatabaseName "IsCollectionIndexed")
{
    $IndexingStateParams = "CollectionId='$CollectionID'","ProjectName='$ProjectName'","RepositoryName='$RepositoryName'","IndexingState='$IndexingState'"
    $SqlFullPath = Join-Path $PWD -ChildPath 'SqlScripts\AddRepositoryUpdateMetadataChangeEvent.sql'
    Invoke-Sqlcmd -InputFile $SqlFullPath -serverInstance $SQLServerInstance -database $CollectionDatabaseName -Variable $IndexingStateParams

    <#
        Let's queue the maintenance job now so that the event added above is processed immediately. Otherwise, it would wait for the next check-in/periodic job run to get processed.
    #>

    $QueueMaintenanceJobParams = "CollectionId='$CollectionID'"
    $SqlFullPath = Join-Path $PWD -ChildPath 'SqlScripts\QueuePeriodicMaintenanceJob.sql'
    Invoke-Sqlcmd -InputFile $SqlFullPath -serverInstance $SQLServerInstance -database $ConfigurationDatabaseName -Variable $QueueMaintenanceJobParams

    Write-Host "Marked state of Repository '$RepositoryName' in Collection '$CollectionName' to '$IndexingState'" -ForegroundColor Cyan
}
else
{
    Write-Host "Indexing State not updated. Please install the extension for the collection." -ForegroundColor DarkYellow
}
Pop-Location
