[CmdletBinding()]
Param(
    [Parameter(Mandatory=$True, Position=0, HelpMessage="The Server Instance against which the script is to run.")]
    [string]$ServerInstance,
   
    [Parameter(Mandatory=$True, Position=1, HelpMessage="Collection Database name.")]
    [string]$CollectionDatabaseName,
    
    [Parameter(Mandatory=$True, Position=2, HelpMessage="Configuration DB")]
    [string]$ConfigurationDatabaseName,

    [Parameter(Mandatory=$True, Position=3, HelpMessage="The value here can be either 'Git_Repository/Tfs_Repository' or 'Collection', based on if you want to do some GIT/TFVC repository re-indexing or collection")]
    [string]$IndexingUnitType,
   
    [Parameter(Mandatory=$True, Position=4, HelpMessage="Enter the Collection Name here.")]
    [string]$CollectionName,
    
    [Parameter(Mandatory=$True, Position=5, HelpMessage="Update the tfvc/git repository name here. For Repairing/Re-indexing a collection, this can be any string.")]
    [string]$RepositoryName,
    
    [Parameter(Mandatory=$True, Position=6, HelpMessage="Update the type of repository, use 'Git_Repository' for git repos and 'Tfs_Repository' for TFVC projects.")]
    [string]$RepositoryType
)

[System.ENVIRONMENT]::CurrentDirectory = $PWD
Push-Location
Import-Module -Name SQLPS 

$queryResults = Invoke-Sqlcmd -Query "Select HostID from [dbo].[tbl_ServiceHost] where Name = '$CollectionName'" -serverInstance $ServerInstance -database $ConfigurationDatabaseName  -Verbose 

$CollectionID = $queryResults  | Select-object  -ExpandProperty  HOSTID

if(!$CollectionID)
{
	throw "Invalid Collection Name: '$CollectionName'"
}

$addDataParams = "IndexingUnitType='$IndexingUnitType'","CollectionId='$CollectionID'","RepositoryName='$RepositoryName'","RepositoryType='$RepositoryType'"
Invoke-Sqlcmd -InputFile "AddDataRe-IndexingJob.sql" -serverInstance $ServerInstance -database $CollectionDatabaseName  -Verbose -Variable $addDataParams
$addJobParams = "CollectionID='$CollectionID'"
Invoke-Sqlcmd -InputFile "QueueRe-IndexingJob.sql" -serverInstance $ServerInstance -database $ConfigurationDatabaseName  -Verbose -Variable $addJobParams
Pop-Location
