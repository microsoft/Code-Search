# Azure DevOps Server 2025 - Elasticsearch 8.14
# Script to trigger collection indexing for Azure DevOps Server 2025
#
# PURPOSE: This script triggers indexing for a specific collection and entity type.
#          Use this when search is not working or after major changes that require re-indexing.
#
# USAGE: .\TriggerCollectionIndexing.ps1 -SQLServerInstance <server> -CollectionDatabaseName <db> -ConfigurationDatabaseName <config_db> -CollectionName <collection> -EntityType <type>
#
# EXAMPLES:
#   .\TriggerCollectionIndexing.ps1 -SQLServerInstance "." -CollectionDatabaseName "AzureDevOps_DefaultCollection" -ConfigurationDatabaseName "AzureDevOps_Configuration" -CollectionName "DefaultCollection" -EntityType "All"
#   .\TriggerCollectionIndexing.ps1 -SQLServerInstance "MYSERVER\SQLEXPRESS" -CollectionDatabaseName "AzureDevOps_MyProject" -ConfigurationDatabaseName "AzureDevOps_Configuration" -CollectionName "MyProject" -EntityType "Code"
#
[CmdletBinding()]
Param
(
    [Parameter(Mandatory=$True, Position=0, HelpMessage="SQL Server instance name (e.g., '.', 'ServerName', 'ServerName\InstanceName')")]
    [string]$SQLServerInstance,
   
    [Parameter(Mandatory=$True, Position=1, HelpMessage="Collection database name (e.g., 'AzureDevOps_DefaultCollection')")]
    [string]$CollectionDatabaseName,
    
    [Parameter(Mandatory=$True, Position=2, HelpMessage="Configuration database name (usually 'AzureDevOps_Configuration')")]
    [string]$ConfigurationDatabaseName,
   
    [Parameter(Mandatory=$True, Position=3, HelpMessage="Collection name as shown in Admin Console (e.g., 'DefaultCollection')")]
    [string]$CollectionName,
    
    [Parameter(Mandatory=$True, Position=4, HelpMessage="Entity type to index: All (everything), Code (source code), WorkItem (work items), Wiki (wiki pages)")]
    [ValidateSet("All", "Code", "WorkItem", "Wiki")]
    [string]$EntityType
)

Import-Module "$PSScriptRoot\Common.psm1" -Force

function TriggerCodeIndexing
{
    if(IsExtensionInstalled $SQLServerInstance $CollectionDatabaseName "IsCollectionIndexed")
    {
        $Params = "CollectionId='$CollectionID'", "EntityTypeString='Code'", "EntityTypeInt=1"
        $SqlFullPath = Join-Path $PSScriptRoot -ChildPath 'SqlScripts\CleanUpCollectionIndexingState.sql'
        Invoke-Sqlcmd -InputFile $SqlFullPath -ServerInstance $SQLServerInstance -Database $CollectionDatabaseName -Verbose -Variable $Params
        Write-Host "Cleaned up the Code Collection Indexing state." -ForegroundColor Yellow

        $SqlFullPath = Join-Path $PSScriptRoot -ChildPath 'SqlScripts\QueueCodeExtensionInstallIndexing.sql'
        Invoke-Sqlcmd -InputFile $SqlFullPath -ServerInstance $SQLServerInstance -Database $ConfigurationDatabaseName  -Verbose -Variable $Params
        Write-Host "Successfully queued the code Indexing job for the collection!!" -ForegroundColor Green
    }
    else
    {
        Write-Host "No jobs queued. Please install the Code Search extension for the collection." -ForegroundColor DarkYellow
    }
}

function TriggerWorkItemIndexing
{
    if(IsExtensionInstalled $SQLServerInstance $CollectionDatabaseName "IsCollectionIndexedForWorkItem")
    {
        $Params = "CollectionId='$CollectionID'", "EntityTypeString='WorkItem'", "EntityTypeInt=4"
        $SqlFullPath = Join-Path $PSScriptRoot -ChildPath 'SqlScripts\CleanUpCollectionIndexingState.sql'
        Invoke-Sqlcmd -InputFile $SqlFullPath -ServerInstance $SQLServerInstance -Database $CollectionDatabaseName -Verbose -Variable $Params
        Write-Host "Cleaned up the WorkItem Collection Indexing state." -ForegroundColor Yellow

        $SqlFullPath = Join-Path $PSScriptRoot -ChildPath 'SqlScripts\QueueWorkItemExtensionInstallIndexing.sql'
        Invoke-Sqlcmd -InputFile $SqlFullPath -ServerInstance $SQLServerInstance -Database $ConfigurationDatabaseName  -Verbose -Variable $Params
        Write-Host "Successfully queued the WorkItem Indexing job for the collection!!" -ForegroundColor Green
    }
    else
    {
        Write-Host "No jobs queued. Please install the WorkItem search extension for the collection." -ForegroundColor DarkYellow
    }
}

function TriggerWikiIndexing
{
    if(IsExtensionInstalled $SQLServerInstance $CollectionDatabaseName "IsCollectionIndexedForWiki")
    {
        $Params = "CollectionId='$CollectionID'", "EntityTypeString='Wiki'", "EntityTypeInt=6"
        $SqlFullPath = Join-Path $PSScriptRoot -ChildPath 'SqlScripts\CleanUpCollectionIndexingState.sql'
        Invoke-Sqlcmd -InputFile $SqlFullPath -ServerInstance $SQLServerInstance -Database $CollectionDatabaseName -Verbose -Variable $Params
        Write-Host "Cleaned up the Wiki Collection Indexing state." -ForegroundColor Yellow

        $SqlFullPath = Join-Path $PSScriptRoot -ChildPath 'SqlScripts\QueueWikiExtensionInstallIndexing.sql'
        Invoke-Sqlcmd -InputFile $SqlFullPath -ServerInstance $SQLServerInstance -Database $ConfigurationDatabaseName  -Verbose -Variable $Params
        Write-Host "Successfully queued the Wiki Indexing job for the collection!!" -ForegroundColor Green
    }
    else
    {
        Write-Host "No jobs queued. Please install the Wiki search extension for the collection." -ForegroundColor DarkYellow
    }
}

ImportSQLModule

$CollectionID = ValidateCollectionName $SQLServerInstance $ConfigurationDatabaseName $CollectionName

switch ($EntityType)
{
    "All" 
        {
            TriggerCodeIndexing
            TriggerWorkItemIndexing
            TriggerWikiIndexing
        }
    "WorkItem" 
        {
            TriggerWorkItemIndexing
        }
    "Code"
        {
            TriggerCodeIndexing
        }
    "Wiki"
        {
            TriggerWikiIndexing
        }
    default 
        {
            Write-Host "Enter a valid EntityType i.e. Code or WorkItem or Wiki or All" -ForegroundColor Red
        }
}
