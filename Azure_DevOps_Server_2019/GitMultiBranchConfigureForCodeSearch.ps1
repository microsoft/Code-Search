[CmdletBinding()]
Param(
    [Parameter(Mandatory=$True, Position=0, HelpMessage="The Server Instance against which the script is to run.")]
    [string]$SQLServerInstance,

	[Parameter(Mandatory=$True, Position=2, HelpMessage="Collection DB")]
    [string]$CollectionDatabaseName,
	
	[Parameter(Mandatory=$True, Position=2, HelpMessage="Configuration DB")]
    [string]$ConfigurationDatabaseName,
	
    [Parameter(Mandatory=$True, Position=3, HelpMessage="Enter the Collection Name here.")]
    [string]$CollectionName,
	
	[Parameter(Mandatory=$True, Position=3, HelpMessage="Enter number of branches that you want to configure for Code Search for Git repositories.")]
    [string]$NumberOfBranches
)

ImportSQLModule

$CollectionID = ValidateCollectionName $SQLServerInstance $ConfigurationDatabaseName $CollectionName

$Params = "CollectionId='$CollectionID'", "BranchCountToConfigure='$NumberOfBranches'"
$SqlFullPath = Join-Path $PSScriptRoot -ChildPath 'SqlScripts\GitMultiBranchConfigChange.sql'
Invoke-Sqlcmd -InputFile $SqlFullPath -serverInstance $SQLServerInstance -database $CollectionDatabaseName -Variable $Params
Write-Host "Changed the number of branches configured to '$NumberOfBranches'." -NoNewLine
Write-Host " Note that it may take upto 12 hours for Search to start indexing the newly configured branches after those are configured via settings page." -ForegroundColor Green
