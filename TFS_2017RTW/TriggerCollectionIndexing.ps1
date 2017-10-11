[CmdletBinding()]
Param(
    [Parameter(Mandatory=$True, Position=0, HelpMessage="The Server Instance against which the script is to run.")]
    [string]$SQLServerInstance,

    [Parameter(Mandatory=$True, Position=1, HelpMessage="Collection Database name.")]
    [string]$CollectionDatabaseName,

    [Parameter(Mandatory=$True, Position=2, HelpMessage="Configuration DB")]
    [string]$ConfigurationDatabaseName,

    [Parameter(Mandatory=$True, Position=3, HelpMessage="Enter the Collection Name here.")]
    [string]$CollectionName
)

[System.ENVIRONMENT]::CurrentDirectory = $PWD
Push-Location

$moduleCheck = Get-Module -List SQLPS
if($moduleCheck)
{
    Import-Module -Name SQLPS -DisableNameChecking
}
else
{
    Write-Error "Cannot load module SQLPS. Please try from a machine running SQL Server 2012 or higher."
    Pop-Location
    exit
}

$queryResults = Invoke-Sqlcmd -Query "Select HostID from [dbo].[tbl_ServiceHost] where Name = '$CollectionName'" -serverInstance $SQLServerInstance -database $ConfigurationDatabaseName  -Verbose

$CollectionID = $queryResults  | Select-object  -ExpandProperty  HOSTID

if(!$CollectionID)
{
    throw "Invalid Collection Name: '$CollectionName'"
}

$isCollectionIndexed = Invoke-Sqlcmd -Query "Select RegValue from tbl_RegistryItems where ChildItem like '%IsCollectionIndexed%' and PartitionId > 0" -ServerInstance $SQLServerInstance -Database $CollectionDatabaseName

if($isCollectionIndexed.RegValue -eq "True")
{
    $Params = "CollectionId='$CollectionID'"
    Invoke-Sqlcmd -InputFile "$PWD\SqlScripts\CleanUpCollectionIndexingState.sql" -serverInstance $SQLServerInstance -database $CollectionDatabaseName
    Write-Host "Cleaned up the Collection Indexing state..." -ForegroundColor Yellow

    Invoke-Sqlcmd -InputFile "$PWD\SqlScripts\AddExtensionInstallJobData.sql" -serverInstance $SQLServerInstance -database $CollectionDatabaseName  -Verbose -Variable $Params
    Write-Host "Added the indexing job data..." -ForegroundColor Yellow

    Invoke-Sqlcmd -InputFile "$PWD\SqlScripts\QueueExtensionInstallIndexing.sql" -serverInstance $SQLServerInstance -database $ConfigurationDatabaseName  -Verbose -Variable $Params
    Write-Host "Successfully queued the Indexing job for the collection!!" -ForegroundColor Green
}
else
{
    Write-Host "No jobs queued. Please install the extension for the collection." -ForegroundColor DarkYellow
}

Pop-Location
