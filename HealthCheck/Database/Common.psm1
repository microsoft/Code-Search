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

function WriteLogToConsoleAndFile
{
    Param
    (
        [string] $Log,
        [string] $Level,
        [string] $LogFilePath
    )

    # Default Info
    $foregroundColor = "Green"

    if ($Level -eq "Info")
    {
        $foregroundColor = "Green"  
    }
    elseif ($Level -eq "Warn")
    {
        $foregroundColor = "Yellow"
    }
	elseif ($Level -eq "Error")
	{
        $foregroundColor = "Red"
    }

    Write-Host $Log -ForegroundColor $foregroundColor
    Add-Content -Path $LogFilePath $Log
}

function DBDataSyncTest
{
    Param
    (
        [string] $SQLServerInstance,
        [string] $ConfigurationDatabaseName,
        [string] $CollectionDatabaseName,
        [string] $CollectionName,
        [string] $SearchUrl,
        [string] $LogFileName
    )

    $LogFilePath = Join-Path $PWD -ChildPath $LogFileName

    WriteLogToConsoleAndFile "[DBDataSyncTest] Performing basic Configuration and Collection DB sanity tests ... " -LogFilePath $LogFilePath

    # [TEST 1] Verify SearchUrl setting in Configuration DB
    WriteLogToConsoleAndFile "[DBDataSyncTest 1] Verifying SearchURL settings in Configuration DB ..." -LogFilePath $LogFilePath

    $queryResults = Invoke-Sqlcmd  -Query "SELECT ParentPath, ChildItem, RegValue FROM tbl_RegistryItems where PartitionId > 0 and ChildItem like '%SearchPlatformConnectionString\%'" -serverInstance $SQLServerInstance -database $ConfigurationDatabaseName

    # #\Service\ALMSearch\Settings\ATSearchPlatformConnectionString\ 
    # #\Service\ALMSearch\Settings\JobAgentSearchPlatformConnectionString\
    $expectedSearchUrlRegEntries = 2

    foreach($row in $queryResults)
    {
        if ($row.Item(2) -ne $SearchUrl)
        {
            WriteLogToConsoleAndFile "[ERROR] Invalid Search URL registry data '$($row.Item(2))' for $($row.Item(0))$($row.Item(1))." -Level "Error" -LogFilePath $LogFilePath
        }
    }

    if ($queryResults.Length -ne $expectedSearchUrlRegEntries)
    {
        WriteLogToConsoleAndFile "[ERROR] Invalid number of Search URL registries: $(@($queryResults).Count). Expected $expectedSearchUrlRegEntries entries." -Level "Error" -LogFilePath $LogFilePath
    }
	

    # [TEST 2] Verify IsSearchConfigured setting in Configuration DB 
    WriteLogToConsoleAndFile "[DBDataSyncTest 2] Verifying IsSearchConfigured setting in Configuration DB ..." -LogFilePath $LogFilePath

    $queryResults = Invoke-Sqlcmd -Query "SELECT RegValue FROM tbl_RegistryItems where PartitionId > 0 and ChildItem like '%IsSearchConfigured\%'" -serverInstance $SQLServerInstance -database $ConfigurationDatabaseName

    if (@($queryResults).Count -ne 1)
    {
        WriteLogToConsoleAndFile "[ERROR] Missing #\Service\ALMSearch\Settings\IsSearchConfigured\ entry in Configuration DB's tbl_RegistryItems.'" -Level "Error" -LogFilePath $LogFilePath
    }

    if ($queryResults[0] -ne 'True')
    {
        WriteLogToConsoleAndFile "[ERROR] #\Service\ALMSearch\Settings\IsSearchConfigured\ not set to 'True' in Configuration DB's tbl_RegistryItems" -Level "Error" -LogFilePath $LogFilePath
    }
	

    # [TEST 3] Verify primary indexing FFs in Configuration DB
    WriteLogToConsoleAndFile "[DBDataSyncTest 3] Verifying primary indexing FFs in Configuration DB ..." -LogFilePath $LogFilePath
	
    #\FeatureAvailability\Entries\Search.Server.Code.CrudOperations\ AvailabilityState\ 1
    #\FeatureAvailability\Entries\Search.Server.Code.Indexing\ AvailabilityState\ 1
    #\FeatureAvailability\Entries\Search.Server.Wiki.Indexing\ AvailabilityState\ 1
    #\FeatureAvailability\Entries\Search.Server.Wiki.ContinuousIndexing\ AvailabilityState\ 1
    #\FeatureAvailability\Entries\Search.Server.WorkItem.Indexing\ AvailabilityState\ 1
    #\FeatureAvailability\Entries\Search.Server.WorkItem.CrudOperations\ AvailabilityState\ 1
    $expectedFFEntries = 6
	
    $SqlFullPath = Join-Path $PWD -ChildPath 'SearchFFData.sql'
    $queryResults = Invoke-Sqlcmd -InputFile $SqlFullPath -serverInstance $SQLServerInstance -database $ConfigurationDatabaseName

    foreach($row in $queryResults)
    {
        if ($row.Item(2) -ne 1)
        {
            WriteLogToConsoleAndFile "[ERROR] Invalid Search FF state $($row.Item(2)) for $($row.Item(0))$($row.Item(1))." -Level "Error" -LogFilePath $LogFilePath
        }
    }
	
    if ($queryResults.Length -ne $expectedFFEntries)
    {
        WriteLogToConsoleAndFile "[ERROR] Invalid number of Search FFs : $(@($queryResults).Count). Expected $expectedFFEntries entries." -Level "Error" -LogFilePath $LogFilePath
    }
	
	
    # [TEST 4] Verify primary indexing FFs are not overridden in Collection DB
    WriteLogToConsoleAndFile "[DBDataSyncTest 4] Verifying primary indexing FFs are not overridden in Collection DB ..." -LogFilePath $LogFilePath
	
    #\FeatureAvailability\Entries\Search.Server.Code.CrudOperations\
    #\FeatureAvailability\Entries\Search.Server.Code.Indexing\
    #\FeatureAvailability\Entries\Search.Server.Wiki.Indexing\
    #\FeatureAvailability\Entries\Search.Server.Wiki.ContinuousIndexing\
    #\FeatureAvailability\Entries\Search.Server.WorkItem.Indexing\
    #\FeatureAvailability\Entries\Search.Server.WorkItem.CrudOperations\ 

    $SqlFullPath = Join-Path $PWD -ChildPath 'SearchFFData.sql'
    $queryResults = Invoke-Sqlcmd -InputFile $SqlFullPath -serverInstance $SQLServerInstance -database $CollectionDatabaseName

    foreach($row in $queryResults)
    {
        WriteLogToConsoleAndFile "[ERROR] Search FF $($row.Item(0))$($row.Item(1)) should not be overridden in $CollectionDatabaseName" -Level "Error" -LogFilePath $LogFilePath
    }
	
	
    # [TEST 5] Verify search extensions are installed for this collection
    WriteLogToConsoleAndFile "[DBDataSyncTest 5] Verifying search extensions are installed for this collection ..." -LogFilePath $LogFilePath
	
    # vss-code-search
    # vss-wiki-searchonprem
    # vss-workitem-searchonprem
    $expectedExtensions = 'vss-code-search', 'vss-wiki-searchonprem','vss-workitem-searchonprem'
	
    $queryResults = Invoke-Sqlcmd -Query "SELECT ExtensionName FROM [Extension].[tbl_InstalledExtension] where PublisherName = 'ms' and ExtensionName like '%search%'" -serverInstance $SQLServerInstance -database $CollectionDatabaseName
	
    [Collections.ArrayList]$installedExtensions = New-Object System.Collections.ArrayList($null)
    foreach($row in $queryResults)
    {
        [void]$installedExtensions.Add($($row.Item(0)))
    }
	
    foreach ($extension in $expectedExtensions) 
    {
        if (-not($installedExtensions.Contains($extension)))
        {
            WriteLogToConsoleAndFile "[WARNING] Search extension $extension not installed currently." -Level "Warn" -LogFilePath $LogFilePath
        }
    }
	
	
    # [TEST 6] Verify IsExtensionOperationInProgress status for Installed & Uninstalled
    WriteLogToConsoleAndFile "[DBDataSyncTest 6] Verifying IsExtensionOperationInProgress status for Installed & Uninstalled ..." -LogFilePath $LogFilePath
	
    $queryResults = Invoke-Sqlcmd -Query "SELECT [ParentPath],[ChildItem],[RegValue] FROM tbl_RegistryItems where ParentPath like '%IsExtensionOperationInProgress%'" -serverInstance $SQLServerInstance -database $CollectionDatabaseName
	
    [Collections.ArrayList]$installedExtensions = New-Object System.Collections.ArrayList($null)
    foreach($row in $queryResults)
    {
        $parentPath = $row | Select-object -ExpandProperty ParentPath
        $childItem = $row | Select-object -ExpandProperty ChildItem
        $regValue = $row | Select-object -ExpandProperty RegValue
        if ($regValue -eq 'True')
        {
            WriteLogToConsoleAndFile "[WARNING] $parentPath$childItem set to True. The operation could be stuck indefinitely in InProgress state." -Level "Warn" -LogFilePath $LogFilePath
        }
    }

	
    # [TEST 7] Verify Collection IU properties' Index and Query URL match the configuration DB URL
    # i.e. Connection string from properties <IndexESConnectionString>{URL}</IndexESConnectionString>
    #                                        <QueryESConnectionString>{URL}</QueryESConnectionString>
    WriteLogToConsoleAndFile "[DBDataSyncTest 7] Verifying Collection IU properties' Index and Query URL match the configuration DB connection URL ..." -LogFilePath $LogFilePath
	
    $queryResults = Invoke-Sqlcmd -Query "Select HostID from [dbo].[tbl_ServiceHost] where Name = '$CollectionName' and HostType = 4" -serverInstance $SQLServerInstance -database $ConfigurationDatabaseName -Verbose
    $CollectionID = $queryResults  | Select-object  -ExpandProperty  HOSTID
    $CollectionPropUrlParams = "CollectionId='$CollectionID'"
		
    $SqlFullPath = Join-Path $PWD -ChildPath 'SearchCollectionProperties.sql'
    $queryResults = Invoke-Sqlcmd -InputFile $SqlFullPath -serverInstance $SQLServerInstance -database $CollectionDatabaseName -Variable $CollectionPropUrlParams
	
    foreach($row in $queryResults)
    {
        $entityType = $row | Select-object  -ExpandProperty  EntityType
        $colIndexESConnectionString = $row | Select-object  -ExpandProperty  IndexESConnectionString
        $colQueryESConnectionString = $row | Select-object  -ExpandProperty  QueryESConnectionString
        if ($colIndexESConnectionString -ne $SearchUrl)
        {
            WriteLogToConsoleAndFile "[ERROR] Invalid Search URL in Collection IU properties' IndexESConnectionString : $colIndexESConnectionString for EntityType $entityType." -Level "Error" -LogFilePath $LogFilePath
        }
        if ($colQueryESConnectionString -ne $SearchUrl)
        {
            WriteLogToConsoleAndFile "[ERROR] Invalid Search URL in Collection IU properties' QueryESConnectionString : $colQueryESConnectionString for EntityType $entityType." -Level "Error" -LogFilePath $LogFilePath
        }
    }
	
	
    # [TEST 8] Verify Collection IU properties' ES ContractTypes for Indexing and Query
    # i.e. <IndexContractType>{contractType}</IndexContractType>
    #      <QueryContractType>{contractType}</QueryContractType>
    WriteLogToConsoleAndFile "[DBDataSyncTest 8] Verifying Collection IU properties' ES ContractTypes for Indexing and Query ..." -LogFilePath $LogFilePath
	
    # REVISIT: We can probably move these settings to a configuration file and get the script pick up from there.
    $expectedContractTypeSetForEntities = @{}
    $expectedContractTypeSetForEntities.Add('Code', 'SourceNoDedupeFileContractV3')	
    $expectedContractTypeSetForEntities.Add('WorkItem', 'WorkItemContract')	
    $expectedContractTypeSetForEntities.Add('Wiki', 'WikiContract')	

    foreach($row in $queryResults)
    {
        $entityType = $row | Select-object  -ExpandProperty  EntityType
        $colIndexContractType = $row | Select-object  -ExpandProperty  IndexContractType
        $colQueryContractType = $row | Select-object  -ExpandProperty  QueryContractType
        if ($colIndexContractType -ne $expectedContractTypeSetForEntities[$entityType])
        {
            WriteLogToConsoleAndFile "[ERROR] Invalid ES contract type in Collection IU properties' IndexContractType : $colIndexContractType for EntityType $entityType." -Level "Error" -LogFilePath $LogFilePath
        }
        if ($colQueryContractType -ne $expectedContractTypeSetForEntities[$entityType])
        {
            WriteLogToConsoleAndFile "[ERROR] Invalid  ES contract type in Collection IU properties' QueryContractType : $colQueryContractType for EntityType $entityType." -Level "Error" -LogFilePath $LogFilePath
        }
    }
}