<#
This scripts cleans the shard details table from the configuration database
#>

[CmdletBinding()]
Param(
    [Parameter(Mandatory=$True, Position=0, HelpMessage="The Server Instance against which the script is to run.")]
    [string]$SQLServerInstance,

    [Parameter(Mandatory=$True, Position=1, HelpMessage="Configuration DB")]
    [string]$ConfigurationDatabaseName
)

function CleanupShardDetails
{
    $SqlFullPath = Join-Path $PWD -ChildPath 'SqlScripts\CleanUpShardDetailsTable.sql'
    Invoke-Sqlcmd -InputFile $SqlFullPath -serverInstance $SQLServerInstance -database $ConfigurationDatabaseName  -Verbose
    Write-Host "Cleaned up the shard details..." -ForegroundColor Yellow
}

CleanupShardDetails