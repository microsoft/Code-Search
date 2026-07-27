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
    [string]$RepositoryName,

    [Parameter(Mandatory=$False)]
    [switch]$TrustServerCertificate
)
$trustCertParam = if ($TrustServerCertificate) { @{TrustServerCertificate = $true} } else { @{} }

Import-Module .\Common.psm1 -Force

[System.ENVIRONMENT]::CurrentDirectory = $PWD
Push-Location
ImportSQLModule

$CollectionID = ValidateCollectionName $SQLServerInstance $ConfigurationDatabaseName $CollectionName @trustCertParam

if(IsExtensionInstalled $SQLServerInstance $CollectionDatabaseName "IsCollectionIndexed" @trustCertParam)
{
    $addDataParams = "IndexingUnitType='$IndexingUnitType'","CollectionId='$CollectionID'","RepositoryName='$RepositoryName'","RepositoryType='$IndexingUnitType'"
    $SqlFullPath = Join-Path $PWD -ChildPath 'SqlScripts\AddCodeRe-IndexingJobData.sql'
    Invoke-Sqlcmd -InputFile $SqlFullPath -serverInstance $SQLServerInstance -database $CollectionDatabaseName -Variable $addDataParams @trustCertParam
    Write-Host "Added the job data as '$addDataParams'" -ForegroundColor Cyan

    $queueJobParams = "CollectionID='$CollectionID'"
    $SqlFullPath = Join-Path $PWD -ChildPath 'SqlScripts\QueueCodeRe-IndexingJob.sql'
    Invoke-Sqlcmd -InputFile $SqlFullPath -serverInstance $SQLServerInstance -database $ConfigurationDatabaseName -Variable $queueJobParams @trustCertParam
    Write-Host "Successfully queued re-indexing job for the repository." -ForegroundColor Green
}
else
{
    Write-Host "No jobs queued. Please install the extension for the collection." -ForegroundColor DarkYellow
}
Pop-Location
