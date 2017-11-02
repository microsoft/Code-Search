[CmdletBinding()]
Param(
    [Parameter(Mandatory=$True, Position=0, HelpMessage="The SQL Server Instance against which the script is to run.")]
    [string]$SQLServerInstance,
      
    [Parameter(Mandatory=$True, Position=1, HelpMessage="Configuration DB")]
    [string]$ConfigurationDatabaseName,
	     
    [Parameter(Mandatory=$True, Position=2, HelpMessage="Enter the number of days since when the tbl_JobHistory data needs to be fetched")]
    [string]$Days
)

function ConfigurationDBSearchStatus
{
	$configLogDir = Join-Path $PWD -ChildPath 'ConfigurationDBDiagonistics'
	New-Item -ItemType Directory -Force -Path $configLogDir
	
	## Query ServiceHost data
	
	$ServiceHostLogPath = Join-Path $configLogDir -ChildPath 'ServiceHost.csv'
	Write-Host "Fetching Service Host data into $ServiceHostLogPath ..." -ForegroundColor Green
	Set-Content -Path $ServiceHostLogPath ([Environment]::NewLine)
	
	$SqlFullPath = Join-Path $PWD -ChildPath 'ConfigurationDBDiagnosticScripts\ServiceHostData.sql'
	$queryResults = Invoke-Sqlcmd -InputFile $SqlFullPath -serverInstance $SQLServerInstance -database $ConfigurationDatabaseName
	
	foreach($row in $queryResults)
	{
		$serviceHostEntry =  "{0},{1},{2},{3},{4},{5}" -f `
               $row.Item(0),$row.Item(1),$row.Item(2),$row.Item(3),$row.Item(4),$row.Item(5),([Environment]::NewLine)
		Add-Content -Path $ServiceHostLogPath $serviceHostEntry
	}
	
	## Query Search Connection URL data
	
	$SearchConnectionUrlRegistryLogPath = Join-Path $configLogDir -ChildPath 'SearchConnectionUrlRegistries.csv'
	Write-Host "Fetching Search URL config data into $SearchConnectionUrlRegistryLogPath ..." -ForegroundColor Green
	Set-Content -Path $SearchConnectionUrlRegistryLogPath ([Environment]::NewLine)
	
	$SqlFullPath = Join-Path $PWD -ChildPath 'ConfigurationDBDiagnosticScripts\SearchConnectionUrlData.sql'
	$queryResults = Invoke-Sqlcmd -InputFile $SqlFullPath -serverInstance $SQLServerInstance -database $ConfigurationDatabaseName
	
	foreach($row in $queryResults)
	{
		$searchConnectionUrlRegEntry =  "{0},{1},{2}" -f `
               $row.Item(0),$row.Item(1),$row.Item(2),([Environment]::NewLine)
		Add-Content -Path $SearchConnectionUrlRegistryLogPath $searchConnectionUrlRegEntry
	}
	
	## Query Extension Data
	
	$ExtensionRegistryLogPath = Join-Path $configLogDir -ChildPath 'ExtensionRegistries.csv'
	Write-Host "Fetching Extension status data into $ExtensionRegistryLogPath ..." -ForegroundColor Green
	Set-Content -Path $ExtensionRegistryLogPath ([Environment]::NewLine)
	
	$SqlFullPath = Join-Path $PWD -ChildPath 'ConfigurationDBDiagnosticScripts\ExtensionData.sql'
	$queryResults = Invoke-Sqlcmd -InputFile $SqlFullPath -serverInstance $SQLServerInstance -database $ConfigurationDatabaseName
	
	foreach($row in $queryResults)
	{
		$extensionRegEntry =  "{0},{1},{2}" -f `
               $row.Item(0),$row.Item(1),$row.Item(2),([Environment]::NewLine)
		Add-Content -Path $ExtensionRegistryLogPath $extensionRegEntry
	}
	
	## Query Job Throttling Data
	
	$JobThrottlingRegistryLogPath = Join-Path $configLogDir -ChildPath 'JobThrottlingRegistries.csv'
	Write-Host "Fetching Job Throttling config data into $JobThrottlingRegistryLogPath ..." -ForegroundColor Green
	Set-Content -Path $JobThrottlingRegistryLogPath ([Environment]::NewLine)
	
	$SqlFullPath = Join-Path $PWD -ChildPath 'ConfigurationDBDiagnosticScripts\JobThrottlingData.sql'
	$queryResults = Invoke-Sqlcmd -InputFile $SqlFullPath -serverInstance $SQLServerInstance -database $ConfigurationDatabaseName
	
	foreach($row in $queryResults)
	{
		$jobThrottlingRegEntry =  "{0},{1},{2}" -f `
               $row.Item(0),$row.Item(1),$row.Item(2),([Environment]::NewLine)
		Add-Content -Path $JobThrottlingRegistryLogPath $jobThrottlingRegEntry
	}
	
	## Query Search Registry Settings data
	
	$SearchRegistryLogPath = Join-Path $configLogDir -ChildPath 'SearchSettingRegistries.csv'
	Write-Host "Fetching Search registry data into $SearchRegistryLogPath ..." -ForegroundColor Green
	Set-Content -Path $SearchRegistryLogPath ([Environment]::NewLine)
	
	$SqlFullPath = Join-Path $PWD -ChildPath 'ConfigurationDBDiagnosticScripts\SearchRegistryData.sql'
	$queryResults = Invoke-Sqlcmd -InputFile $SqlFullPath -serverInstance $SQLServerInstance -database $ConfigurationDatabaseName
	
	foreach($row in $queryResults)
	{
		$searchRegEntry =  "{0},{1},{2}" -f `
               $row.Item(0),$row.Item(1),$row.Item(2),([Environment]::NewLine)
		Add-Content -Path $SearchRegistryLogPath $searchRegEntry
	}
		
	## Query JobQueue Data
	
	$JobQueueLogPath = Join-Path $configLogDir -ChildPath 'JobQueue.csv'
	Write-Host "Fetching JobQueue data into $JobQueueLogPath ..." -ForegroundColor Green
	Set-Content -Path $JobQueueLogPath ([Environment]::NewLine)
	
	$SqlFullPath = Join-Path $PWD -ChildPath 'ConfigurationDBDiagnosticScripts\JobQueueData.sql'
	$queryResults = Invoke-Sqlcmd -InputFile $SqlFullPath -serverInstance $SQLServerInstance -database $ConfigurationDatabaseName
	
	foreach($row in $queryResults)
	{
		$queueEntry =  "{0},{1},{2},{3}" -f `
               $row.Item(0),$row.Item(1),$row.Item(2),$row.Item(3),([Environment]::NewLine)
		Add-Content -Path $JobQueueLogPath $queueEntry
	}
	
	## Query JobHistory Data
	
	$JobHistoryLogPath = Join-Path $configLogDir -ChildPath 'JobHistory.csv'
	Write-Host "Fetching Job History data into $JobHistoryLogPath ..." -ForegroundColor Green
	Set-Content -Path $JobHistoryLogPath ([Environment]::NewLine)

	$jobHistoryQueryParams = "DaysAgo='$Days'"

	$SqlFullPath = Join-Path $PWD -ChildPath 'ConfigurationDBDiagnosticScripts\JobHistoryData.sql'
	$queryResults = Invoke-Sqlcmd -InputFile $SqlFullPath -serverInstance $SQLServerInstance -database $ConfigurationDatabaseName -Variable $jobHistoryQueryParams
	
	foreach($row in $queryResults)
	{
		$historyEntry =  "{0},{1},{2},{3},{4},{5},{6}" -f `
               $row.Item(0),$row.Item(1),$row.Item(2),$row.Item(3),$row.Item(4),$row.Item(5),$row.Item(6),([Environment]::NewLine)
		Add-Content -Path $JobHistoryLogPath $historyEntry
	}
	
	$configurationDBDiagonisticsZip = [string]::Format("{0}_Diagnostic.zip", $ConfigurationDatabaseName)
	Write-Host "Compressing data to $configurationDBDiagonisticsZip ..." -ForegroundColor Green
	Compress-Archive -Force -Path $configLogDir -DestinationPath $configurationDBDiagonisticsZip
	
	Remove-Item $configLogDir -Recurse -ErrorAction Ignore
}

Import-Module .\Common.psm1 -Force
Write-Host "Extracting Search diagnostics data from '$ConfigurationDatabaseName' database" -ForegroundColor Green

[System.ENVIRONMENT]::CurrentDirectory = $PWD
Push-Location
ImportSQLModule

ConfigurationDBSearchStatus

Pop-Location