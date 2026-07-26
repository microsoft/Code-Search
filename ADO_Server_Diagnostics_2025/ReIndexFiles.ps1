<#
This script configures a path of a repository for re-indexing.
#>

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

    [Parameter(Mandatory=$True, Position=4, HelpMessage="Update the Project name here.")]
    [string]$ProjectName,

    [Parameter(Mandatory=$True, Position=5, HelpMessage="Update the Repository name here.")]
    [string]$RepositoryName,

    [Parameter(Mandatory=$True, Position=6, HelpMessage="File/Folder which has to be re-indexed.")]
    [string]$Path
)

IF ([string]::IsNullOrWhiteSpace($SQLServerInstance) -Or 
    [string]::IsNullOrWhiteSpace($CollectionDatabaseName) -Or 
    [string]::IsNullOrWhiteSpace($ConfigurationDatabaseName) -Or 
    [string]::IsNullOrWhiteSpace($CollectionName) -Or 
    [string]::IsNullOrWhiteSpace($ProjectName) -Or 
    [string]::IsNullOrWhiteSpace($RepositoryName) -Or
    [string]::IsNullOrWhiteSpace($Path)) 
{
    Throw "None of the values supplied can be null or empty. Please retry"
}

IF (-not ($Path.StartsWith("/") -or $Path.StartsWith("$/")))
{
    Throw "Please provide the full path of the file/folder. For Git repositories, it should start with '/' and for TFVC repositories it should start with '$/'."
}

IF ($Path.EndsWith("/"))
{
    Throw "File/Folder path should not have a trailing '/'."
}

IF ($Path.Contains("\"))
{
    Throw "Invalid character '\' present in the path, use '/' only in the full file path/folder."
}

Import-Module .\Common.psm1 -Force

[System.ENVIRONMENT]::CurrentDirectory = $PWD
Push-Location
ImportSQLModule

$CollectionID = ValidateCollectionName $SQLServerInstance $ConfigurationDatabaseName $CollectionName

if(IsExtensionInstalled $SQLServerInstance $CollectionDatabaseName "IsCollectionIndexed")
{
    $AddFilesParams = "CollectionId='$CollectionID'","ProjectName='$ProjectName'","RepositoryName='$RepositoryName'","Path='$Path'"
    $SqlFullPath = Join-Path $PWD -ChildPath 'SqlScripts\AddFilesToBeIndexed.sql'
    $queryResults = Invoke-Sqlcmd -InputFile $SqlFullPath -serverInstance $SQLServerInstance -database $CollectionDatabaseName -Variable $AddFilesParams
    
    if ($queryResults)
    {
        <#
            Let's queue the maintenance job now so that the event added above is processed immediately. Otherwise, it would wait for the next check-in/periodic job run to get processed.
        #>

        $QueueMaintenanceJobParams = "CollectionId='$CollectionID'"
        $SqlFullPath = Join-Path $PWD -ChildPath 'SqlScripts\QueuePeriodicMaintenanceJob.sql'
        Invoke-Sqlcmd -InputFile $SqlFullPath -serverInstance $SQLServerInstance -database $ConfigurationDatabaseName -Variable $QueueMaintenanceJobParams

        Write-Host "Configured path '$Path' of Repository '$RepositoryName' in Collection '$CollectionName' for re-indexing." -ForegroundColor Green
    }
    else
    {
        Write-Host "Path '$Path' not configured for re-indexing." -ForegroundColor Yellow
    }
}
else
{
    Write-Host "Code Search extension is not installed on this collection, can not run this script." -ForegroundColor Yellow
}

Pop-Location
