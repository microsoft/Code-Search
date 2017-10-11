function ImportSQLModule
{
    $moduleCheck = Get-Module -List SQLSERVER
    if($moduleCheck)
    {
    Import-Module -Name SQLSERVER -DisableNameChecking
        Write-Host "Loaded SQLSERVER module..." -ForegroundColor Green
    }
    else
    {
    Write-Host "Cannot load module SQLSERVER. Trying to load SQLPS module." -ForegroundColor Yellow

        $moduleCheck = Get-Module -List SQLPS

        if($moduleCheck)
        {
        Import-Module -Name SQLPS -DisableNameChecking
            Write-Host "Loaded SQLPS module..." -ForegroundColor Green
        }
        else
        {
            Write-Host "Cannot load SQLPS as well. Try running the script from a machine with SQL Server 2014 or higher installed or powershell 5.0" -ForegroundColor Red
            Pop-Location
        exit
        }
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
