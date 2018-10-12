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
    
	[Parameter(Mandatory=$True, Position=4, HelpMessage="Enter operation type 'Add' for adding more folders, 'Delete' for deleting all the folders in the list, 'Fetch' for fetching list of folders present in exclusion list.")]
    [string]$OperationType,
	
    [Parameter(Mandatory=$True, Position=5, HelpMessage="Specify comma separated list of folders to Add/Remove from Indexing. This is ignored for 'Delete' and 'Fetch' Operation")][AllowEmptyString()]
    [string]$CommaSeparatedFoldersToAddForAddOperation
)

Import-Module .\Common.psm1 -Force

function AddExcludedFolders
{
	$Params = "CollectionId='$CollectionID'", "FolderPaths='$CommaSeparatedFoldersToAddForAddOperation'"
	$SqlFullPath = Join-Path $PWD -ChildPath 'SqlScripts\TfvcExcludedFolders\AddFoldersInExclusionList.sql'
	Invoke-Sqlcmd -InputFile $SqlFullPath -serverInstance $SQLServerInstance -database $CollectionDatabaseName -Variable $Params
	Write-Host "Added Given folders to Indexing Exclusion list" -ForegroundColor Yellow
}

function FetchExcludedFoldersList
{
	$Params = "CollectionId='$CollectionID'"
	$SqlFullPath = Join-Path $PWD -ChildPath 'SqlScripts\TfvcExcludedFolders\FetchFoldersInExclusionList.sql'
	$QueryResults = Invoke-Sqlcmd -InputFile $SqlFullPath -serverInstance $SQLServerInstance -database $CollectionDatabaseName -Variable $Params
	
	$ExcludedFoldersList = $QueryResults | Select-object -ExpandProperty ExcludedFolders	
	Write-Host "Folders present in Indexing Exclusion list are: '$ExcludedFoldersList'" -ForegroundColor Yellow
}

function DeleteAllExcludedFolders
{
	$Params = "CollectionId='$CollectionID'"
	$SqlFullPath = Join-Path $PWD -ChildPath 'SqlScripts\TfvcExcludedFolders\DeleteAllFoldersInExclusionList.sql'
	Invoke-Sqlcmd -InputFile $SqlFullPath -serverInstance $SQLServerInstance -database $CollectionDatabaseName -Variable $Params
	Write-Host "Added Given folders to Indexing Exclusion list" -ForegroundColor Yellow
}

[System.ENVIRONMENT]::CurrentDirectory = $PWD
Push-Location
ImportSQLModule

$CollectionID = ValidateCollectionName $SQLServerInstance $ConfigurationDatabaseName $CollectionName

switch ($OperationType)
{
    "Add" 
        {
            Write-Host "Adding folders to exclusion list..." -ForegroundColor Green
            AddExcludedFolders
        }
    "Fetch" 
        {
            Write-Host "Fetching folders present in exclusion list..." -ForegroundColor Green
            FetchExcludedFoldersList
        }
    "Delete"
        {
            Write-Host "Deleting all the folders from exclusion list..." -ForegroundColor Green
            DeleteAllExcludedFolders
        }
}

Pop-Location
