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

Import-Module .\Common.psm1 -Force

[System.ENVIRONMENT]::CurrentDirectory = $PWD
Push-Location
ImportSQLModule

$CollectionID = ValidateCollectionName $SQLServerInstance $ConfigurationDatabaseName $CollectionName

# Fix the index name in all repo indexing units
$fixIndexingIndexNameParams = "CollectionId='$CollectionID'"
$SqlFullPath = Join-Path $PWD -ChildPath 'SqlScripts\FixIndexingIndexName.sql'
Invoke-Sqlcmd -InputFile $SqlFullPath -serverInstance $SQLServerInstance -database $CollectionDatabaseName -Variable $fixIndexingIndexNameParams
Write-Host "Fixed the indexing index name in all repo indexing units" -ForegroundColor Cyan

Pop-Location
