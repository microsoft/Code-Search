# Azure DevOps Server 2025 - Elasticsearch 8.14
# Script for re-indexing specific code repositories in Azure DevOps Server 2025
#
# PURPOSE: Re-indexes a specific Git or TFVC repository when search is not working for that repository.
#          Use this instead of full collection re-indexing when only specific repositories have issues.
#
# USAGE: .\Re-IndexingCodeRepository.ps1 -SQLServerInstance <server> -CollectionDatabaseName <db> -ConfigurationDatabaseName <config_db> -IndexingUnitType <type> -CollectionName <collection> -RepositoryName <repo>
#
# EXAMPLES:
#   .\Re-IndexingCodeRepository.ps1 -SQLServerInstance "." -CollectionDatabaseName "AzureDevOps_DefaultCollection" -ConfigurationDatabaseName "AzureDevOps_Configuration" -IndexingUnitType "Git_Repository" -CollectionName "DefaultCollection" -RepositoryName "MyProject"
#   .\Re-IndexingCodeRepository.ps1 -SQLServerInstance "MYSERVER" -CollectionDatabaseName "AzureDevOps_MyCollection" -ConfigurationDatabaseName "AzureDevOps_Configuration" -IndexingUnitType "TFVC_Repository" -CollectionName "MyCollection" -RepositoryName "$/MyTFVCProject"
#
[CmdletBinding()]
Param(
    [Parameter(Mandatory=$True, Position=0, HelpMessage="SQL Server instance name (e.g., '.', 'ServerName', 'ServerName\InstanceName')")]
    [string]$SQLServerInstance,
   
    [Parameter(Mandatory=$True, Position=1, HelpMessage="Collection database name (e.g., 'AzureDevOps_DefaultCollection')")]
    [string]$CollectionDatabaseName,
    
    [Parameter(Mandatory=$True, Position=2, HelpMessage="Configuration database name (usually 'AzureDevOps_Configuration')")]
    [string]$ConfigurationDatabaseName,

    [Parameter(Mandatory=$True, Position=3, HelpMessage="Repository type: 'Git_Repository' for Git repos or 'TFVC_Repository' for TFVC repos")]
    [ValidateSet("Git_Repository", "TFVC_Repository")]
    [string]$IndexingUnitType,
   
    [Parameter(Mandatory=$True, Position=4, HelpMessage="Collection name as shown in Admin Console (e.g., 'DefaultCollection')")]
    [string]$CollectionName,
    
    [Parameter(Mandatory=$True, Position=5, HelpMessage="Repository name (Git repo name or TFVC path like '$/ProjectName')")]
    [string]$RepositoryName
)

Import-Module .\Common.psm1 -Force

[System.ENVIRONMENT]::CurrentDirectory = $PWD
Push-Location
ImportSQLModule

$CollectionID = ValidateCollectionName $SQLServerInstance $ConfigurationDatabaseName $CollectionName

if(IsExtensionInstalled $SQLServerInstance $CollectionDatabaseName "IsCollectionIndexed")
{
    $addDataParams = "IndexingUnitType='$IndexingUnitType'","CollectionId='$CollectionID'","RepositoryName='$RepositoryName'","RepositoryType='$IndexingUnitType'"
    $SqlFullPath = Join-Path $PWD -ChildPath 'SqlScripts\AddCodeRe-IndexingJobData.sql'
    Invoke-Sqlcmd -InputFile $SqlFullPath -serverInstance $SQLServerInstance -database $CollectionDatabaseName -Variable $addDataParams
    Write-Host "Added the job data as '$addDataParams'" -ForegroundColor Cyan

    $queueJobParams = "CollectionID='$CollectionID'"
    $SqlFullPath = Join-Path $PWD -ChildPath 'SqlScripts\QueueCodeRe-IndexingJob.sql'
    Invoke-Sqlcmd -InputFile $SqlFullPath -serverInstance $SQLServerInstance -database $ConfigurationDatabaseName -Variable $queueJobParams
    Write-Host "Successfully queued re-indexing job for the repository." -ForegroundColor Green
}
else
{
    Write-Host "No jobs queued. Please install the extension for the collection." -ForegroundColor DarkYellow
}
Pop-Location
