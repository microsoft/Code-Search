[CmdletBinding()]
Param(
	[Parameter(Mandatory=$True, Position=0, HelpMessage="The SQL Server Instance against which the script is to run.")]
    [string]$SQLServerInstance,
    
    [Parameter(Mandatory=$True, Position=1, HelpMessage="Configuration Database name")]
    [string]$ConfigurationDatabaseName,
	
    [Parameter(Mandatory=$True, Position=2, HelpMessage="Collection Database name.")]
    [string]$CollectionDatabaseName,
       
    [Parameter(Mandatory=$True, Position=3, HelpMessage="Collection Name")]
    [string]$CollectionName,
	
	[Parameter(Mandatory=$True, Position=4, HelpMessage="Search Url as listed in the TFS Admin Console Search feature page")]
    [string]$SearchUrl
)

Import-Module .\Common.psm1 -Force

[System.ENVIRONMENT]::CurrentDirectory = $PWD
Push-Location
ImportSQLModule

$LogFile = "SearchDBSanityCheck.log"
DBDataSyncTest $SQLServerInstance $ConfigurationDatabaseName $CollectionDatabaseName $CollectionName $SearchUrl $LogFile

Pop-Location
