function ImportSQLModule
{
    $moduleCheck = Get-Module -List SQLPS
    if($moduleCheck)
    {
	    Import-Module -Name SQLPS -DisableNameChecking
        Write-Host "Loaded SQLPS module..." -ForegroundColor Green
    }
    else
    {
	    Write-Error "Cannot load module SQLPS. Please try from a machine running SQL Server 2012 or higher."
        Pop-Location
	    exit
    }
}

function ValidateCollectionName
{
    [CmdletBinding()]
    [OutputType([string])]
    Param
    (
        [string] $SQLServerInstance,
        [string] $ConfigurationDatabaseName,
        [string] $CollectionName
    )

    $queryResults = Invoke-Sqlcmd -Query "Select HostID from [dbo].[tbl_ServiceHost] where Name = '$CollectionName'" -serverInstance $SQLServerInstance -database $ConfigurationDatabaseName  -Verbose 

    $CollectionID = $queryResults  | Select-object  -ExpandProperty  HOSTID

    if(!$CollectionID)
    {
	    throw "Invalid Collection Name: '$CollectionName'"
    }

    return $CollectionID
}

function IsExtensionInstalled
{
    [CmdletBinding()]
    [OutputType([boolean])]
    Param
    (
        [string] $SQLServerInstance,
        [string] $CollectionDatabaseName,
        [string] $RegValue
    )

    return $true

    $isCollectionIndexed = Invoke-Sqlcmd -Query "Select RegValue from tbl_RegistryItems where ChildItem like '%$RegValue%' and PartitionId > 0" -ServerInstance $SQLServerInstance -Database $CollectionDatabaseName
    
    if($isCollectionIndexed.RegValue -eq "True")
    {
        return $true
    }
    else
    {
        return $false
    }
}
