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

$queryResults = Invoke-Sqlcmd -Query "Select HostID from [dbo].[tbl_ServiceHost] where Name = '$CollectionName'" -serverInstance $SQLServerInstance -database $ConfigurationDatabaseName

$CollectionID = $queryResults  | Select-object  -ExpandProperty  HOSTID

if(!$CollectionID)
{
    throw "Invalid Collection Name: '$CollectionName'"
}

# Fix the index name in all repo indexing units
$fixIndexingIndexNameParams = "CollectionId='$CollectionID'"
$SqlFullPath = Join-Path $PWD -ChildPath 'SqlScripts\FixIndexingIndexName.sql'
Invoke-Sqlcmd -InputFile $SqlFullPath -serverInstance $SQLServerInstance -database $CollectionDatabaseName -Variable $fixIndexingIndexNameParams
Write-Host "Fixed the indexing index name in all repo indexing units" -ForegroundColor Cyan

Pop-Location
