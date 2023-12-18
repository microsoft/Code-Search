[CmdletBinding()]
Param
(
    [Parameter(Mandatory=$True, Position=0, HelpMessage="The Server Instance against which the script is to run.")]
    [string]$SQLServerInstance,
   
    [Parameter(Mandatory=$True, Position=1, HelpMessage="Collection Database name.")]
    [string]$CollectionDatabaseName,
    
    [Parameter(Mandatory=$True, Position=2, HelpMessage="Configuration Database name.")]
    [string]$ConfigurationDatabaseName,
   
    [Parameter(Mandatory=$True, Position=3, HelpMessage="Collection name.")]
    [string]$CollectionName,
    
    [Parameter(Mandatory=$True, Position=4, HelpMessage="Trigger collection indexing for Code, WorkItem, Wiki or All")]
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
