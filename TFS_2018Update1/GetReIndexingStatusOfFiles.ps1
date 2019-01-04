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

    [Parameter(Mandatory=$True, Position=6, HelpMessage="File/Folder for which re-index status has to be checked.")]
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
    $GetReIndexingStatusParams = "CollectionId='$CollectionID'","ProjectName='$ProjectName'","RepositoryName='$RepositoryName'","Path='$Path'"
    $SqlFullPath = Join-Path $PWD -ChildPath 'SqlScripts\GetReIndexingStatusOfFiles.sql'
    $queryResults = Invoke-Sqlcmd -InputFile $SqlFullPath -serverInstance $SQLServerInstance -database $CollectionDatabaseName -Variable $GetReIndexingStatusParams
    
    if ($queryResults)
    {
        $msg = $queryResults.Count.ToString() + " files/folders are yet to be indexed in repository '$RepositoryName'."
        Write-Host $msg -ForegroundColor Yellow
    }
    else
    {
        Write-Host "Could not determine number of files/folders yet to be indexed in repository '$RepositoryName'." -ForegroundColor Yellow
    }
}
else
{
    Write-Host "Code Search extension is not installed on this collection, can not run this script." -ForegroundColor Yellow
}

Pop-Location
