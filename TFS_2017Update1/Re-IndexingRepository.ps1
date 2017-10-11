[CmdletBinding()]
Param(
    [Parameter(Mandatory=$True, Position=0, HelpMessage="The Server Instance against which the script is to run.")]
    [string]$SQLServerInstance,

    [Parameter(Mandatory=$True, Position=1, HelpMessage="Collection Database name.")]
    [string]$CollectionDatabaseName,

    [Parameter(Mandatory=$True, Position=2, HelpMessage="Configuration DB")]
    [string]$ConfigurationDatabaseName,

    [Parameter(Mandatory=$True, Position=3, HelpMessage="The value here can be either 'Git_Repository/TFVC_Repository', based on if you want to do some GIT/TFVC repository re-indexing")]
    [string]$IndexingUnitType,

    [Parameter(Mandatory=$True, Position=4, HelpMessage="Enter the Collection Name here.")]
    [string]$CollectionName,

    [Parameter(Mandatory=$True, Position=5, HelpMessage="Update the tfvc/git repository name here.")]
    [string]$RepositoryName
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

$isCollectionIndexed = Invoke-Sqlcmd -Query "Select RegValue from tbl_RegistryItems where ChildItem like '%IsCollectionIndexed%' and PartitionId > 0" -ServerInstance $SQLServerInstance -Database $CollectionDatabaseName

if($isCollectionIndexed.RegValue -eq "True")
{
    $addDataParams = "IndexingUnitType='$IndexingUnitType'","CollectionId='$CollectionID'","RepositoryName='$RepositoryName'","RepositoryType='$IndexingUnitType'"
    $SqlFullPath = Join-Path $PWD -ChildPath 'SqlScripts\AddDataRe-IndexingJob.sql'
    Invoke-Sqlcmd -InputFile $SqlFullPath -serverInstance $SQLServerInstance -database $CollectionDatabaseName -Variable $addDataParams
    Write-Host "Added the job data as '$addDataParams'" -ForegroundColor Cyan

    $queueJobParams = "CollectionID='$CollectionID'"
    $SqlFullPath = Join-Path $PWD -ChildPath 'SqlScripts\QueueRe-IndexingJob.sql'
    Invoke-Sqlcmd -InputFile $SqlFullPath -serverInstance $SQLServerInstance -database $ConfigurationDatabaseName -Variable $queueJobParams
    Write-Host "Successfully queued re-indexing job for the repository." -ForegroundColor Green
}
else
{
    Write-Host "No jobs queued. Please install the extension for the collection." -ForegroundColor DarkYellow
}
Pop-Location
