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

$moduleCheck = Get-Module -List SQLPS
if($moduleCheck)
{
    Import-Module -Name SQLPS -DisableNameChecking
}
else
{
    Write-Error "Cannot load module SQLPS. Please try from a machine running SQL Server 2012 or higher."
}

$queryResults = Invoke-Sqlcmd -Query "Select HostID from [dbo].[tbl_ServiceHost] where Name = '$CollectionName'" -ServerInstance $SQLServerInstance -Database $ConfigurationDatabaseName  -Verbose 

$CollectionID = $queryResults  | Select-object  -ExpandProperty  HOSTID

if(!$CollectionID)
{
    throw "Invalid Collection Name: '$CollectionName'"
}

$isCollectionIndexed = Invoke-Sqlcmd -Query "Select RegValue from tbl_RegistryItems where ChildItem like '%IsCollectionIndexed%' and PartitionId > 0" -ServerInstance $SQLServerInstance -Database $CollectionDatabaseName

if($isCollectionIndexed.RegValue -eq "True")
{
    $Params = "CollectionId='$CollectionID'", "EntityTypeString='Code'", "EntityTypeInt=1"
    $SqlFullPath = Join-Path $PSScriptRoot -ChildPath 'SqlScripts\CleanUpCollectionIndexingState.sql'
    Invoke-Sqlcmd -InputFile $SqlFullPath -ServerInstance $SQLServerInstance -Database $CollectionDatabaseName -Verbose -Variable $Params
    Write-Host "Cleaned up the code collection indexing state." -ForegroundColor Yellow

    $SqlFullPath = Join-Path $PSScriptRoot -ChildPath 'SqlScripts\AddExtensionInstallJobData.sql'
    Invoke-Sqlcmd -InputFile $SqlFullPath -ServerInstance $SQLServerInstance -Database $CollectionDatabaseName -Verbose -Variable $Params
    Write-Host "Added the indexing job data." -ForegroundColor Yellow

    $SqlFullPath = Join-Path $PSScriptRoot -ChildPath 'SqlScripts\QueueExtensionInstallIndexing.sql'
    Invoke-Sqlcmd -InputFile $SqlFullPath -ServerInstance $SQLServerInstance -Database $ConfigurationDatabaseName -Verbose -Variable $Params
    Write-Host "Successfully queued the code indexing job for the collection." -ForegroundColor Green
}
else
{
    Write-Host "No jobs queued. Please install the extension for the collection." -ForegroundColor DarkYellow
}
