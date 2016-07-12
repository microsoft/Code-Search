[CmdletBinding()]
Param(
    [Parameter(Mandatory=$True, Position=0, HelpMessage="The Server Instance against which the script is to run.")]
    [string]$ServerInstance,

    [Parameter(Mandatory=$True, Position=1, HelpMessage="Configuration DB")]
    [string]$ConfigurationDatabaseName
)
[System.ENVIRONMENT]::CurrentDirectory = $PWD
Push-Location
Import-Module -Name SQLPS 
Invoke-Sqlcmd -InputFile "StopSearchIndexing.sql" -serverInstance $ServerInstance -database $ConfigurationDatabaseName  -Verbose 
Pop-Location